/**
 * ==============================================================================
 * PROJECT: Switch2GO AAC — Bluetooth Switch Interface
 * TARGET:  ESP32 (WROOM-32 / DevKitC)
 * LIBRARY: HijelHID_BLEKeyboard (BLE HID keyboard)
 * ==============================================================================
 *
 * Presents as a BLE keyboard named Switch2GO-XXXX (last two MAC bytes).
 * Sends keys 1–4 on physical switch press/release; BOOT button multi-tap
 * simulates switches when fewer than four are wired.
 *
 * Also exposes a custom GATT characteristic so the iPad can request a
 * momentary GPIO pulse (switch OUTPUT) for AbleNet PowerLink / appliances.
 *
 * HARDWARE (ESP32 DevKit V1):
 *   Switch 1 → GPIO 12 + GND
 *   Switch 2 → GPIO 13 + GND
 *   Switch 3 → GPIO 14 + GND
 *   Switch 4 → GPIO 27 + GND
 *   Onboard LED → GPIO 2
 *   BOOT button (GPIO 0) → multi-tap virtual switch (1–4 taps)
 *   PowerLink OUTPUT → GPIO 26 (see SWITCH_OUTPUT_PIN comment below)
 *
 * IPAD SETUP:
 *   1. Flash this sketch — see README.md "Arduino IDE setup (ESP32 firmware)".
 *   2. iPad Settings → Bluetooth → pair "Switch2GO-XXXX".
 *      After a firmware update that adds GATT services, Forget Device and re-pair
 *      so iPadOS refreshes the GATT table.
 *   3. Switch2GO app → Settings → Selection Mode → Switch Control →
 *      enable External Switches. Default keys 1–4 must match SWITCH_KEYS.
 *   4. Modes: Switch to Phrase (2–4 switches) or Scan & Select (2 switches;
 *      keys 1 = select, 2 = next).
 *   5. Environmental control: Settings → Switch Control → Connect ESP32 output,
 *      then enable “Send switch output” on the phrase that should pulse PowerLink.
 */

#include <HijelHID_BLEKeyboard.h>
#include <NimBLEDevice.h>
#include <esp_mac.h>

// ==========================================
// 1. SYSTEM CONFIGURATION
// ==========================================
#define NUM_SWITCHES 4  // Compile-time choice: 2, 3, or 4 active physical switches

// Pin Assignments for Standard ESP32 DevKitV1
const uint8_t SWITCH_PINS[4] = {12, 13, 14, 27}; // Switch 1, 2, 3, 4
const uint8_t LED_PIN = 2;                       // Onboard LED (GPIO 2)
const uint8_t MY_BOOT_PIN = 0;                   // Custom label to avoid ESP32 core conflict

// PowerLink / appliance OUTPUT (momentary switch closure).
// GPIO 26 — unused by switch inputs, LED, or BOOT; not a strapping pin.
// Idle LOW, pulse HIGH for SWITCH_OUTPUT_PULSE_MS.
//
// Wiring (do NOT put ESP32 GPIO across the 3.5mm jack directly):
//   GPIO 26 → current-limiting resistor (~330Ω) → optocoupler LED anode
//   Optocoupler LED cathode → GND
//   Optocoupler collector/emitter (dry contact) → AbleNet PowerLink 3.5mm
//     tip and sleeve (same as a capability switch). A 3.3V relay module
//     works the same way: coil driven by GPIO 26, contacts to the jack.
// PowerLink sees a ~150ms press and toggles the AC outlet.
const uint8_t SWITCH_OUTPUT_PIN = 26;
const unsigned long SWITCH_OUTPUT_PULSE_MS = 150;

// Custom GATT (iPad writes 0x01 to request a PowerLink pulse).
// 128-bit UUIDs so Core Bluetooth can find this service beside HID.
static const char* SWITCH_OUTPUT_SERVICE_UUID = "8e7c0001-4f52-4c4e-9353-5332474f3031";
static const char* SWITCH_OUTPUT_CHAR_UUID    = "8e7c0002-4f52-4c4e-9353-5332474f3031";
static const uint8_t SWITCH_OUTPUT_CMD_PULSE = 0x01;

// HID Mappings - Changed to uint8_t to resolve library type ambiguity
const uint8_t SWITCH_KEYS[4] = {'1', '2', '3', '4'};

// Timing Parameters (Milliseconds)
const unsigned long DEBOUNCE_MS = 50;      // Physical switch debounce threshold
const unsigned long LED_FLASH_MS = 30;     // Non-blocking indicator pulse duration
const unsigned long TAP_TIMEOUT_MS = 350;  // Multi-tap window for BOOT button

// ==========================================
// 2. STATE VARIABLES
// ==========================================
HijelHID_BLEKeyboard* bleKeyboard = nullptr; // Dynamically allocated to pass MAC name
char deviceName[20] = "Switch2GO-XXXX";

// Physical Switch Tracking Structures
struct SwitchState {
  uint8_t pin;
  bool lastRawState;
  bool debouncedState;
  unsigned long lastDebounceTime;
};
SwitchState switches[NUM_SWITCHES];

// BOOT Button Multi-Tap Tracking
bool lastBootRawState = HIGH;
bool debouncedBootState = HIGH;
unsigned long lastBootDebounceTime = 0;
unsigned long lastBootTapTime = 0;
int bootTapCount = 0;

// LED Pulse Management
unsigned long ledOffTime = 0;
bool ledActive = false;

// Switch OUTPUT (PowerLink) pulse — one selection = one press
volatile bool outputPulseRequested = false;
bool outputPulseActive = false;
unsigned long outputPulseEndTime = 0;
NimBLECharacteristic* switchOutputChar = nullptr;

// ==========================================
// 3. HELPER FUNCTIONS
// ==========================================
void triggerLedPulse() {
  digitalWrite(LED_PIN, HIGH);
  ledOffTime = millis() + LED_FLASH_MS;
  ledActive = true;
}

void processLedTimeout() {
  if (ledActive && millis() >= ledOffTime) {
    digitalWrite(LED_PIN, LOW);
    ledActive = false;
  }
}

void requestSwitchOutputPulse() {
  // Ignore overlapping requests so one iPad selection cannot stack pulses.
  if (outputPulseActive || outputPulseRequested) {
    Serial.println("[OUT] Pulse ignored (already active)");
    return;
  }
  outputPulseRequested = true;
}

void processSwitchOutput() {
  unsigned long now = millis();
  if (outputPulseRequested && !outputPulseActive) {
    outputPulseRequested = false;
    digitalWrite(SWITCH_OUTPUT_PIN, HIGH);
    outputPulseEndTime = now + SWITCH_OUTPUT_PULSE_MS;
    outputPulseActive = true;
    triggerLedPulse();
    Serial.printf("[OUT] PowerLink pulse START (%lums on GPIO %u)\n",
                  SWITCH_OUTPUT_PULSE_MS, SWITCH_OUTPUT_PIN);
  }
  if (outputPulseActive && now >= outputPulseEndTime) {
    digitalWrite(SWITCH_OUTPUT_PIN, LOW);
    outputPulseActive = false;
    Serial.println("[OUT] PowerLink pulse END");
  }
}

bool isPulseCommandByte(uint8_t cmd) {
  return cmd == SWITCH_OUTPUT_CMD_PULSE || cmd == 'P' || cmd == 'p' || cmd == '1';
}

class SwitchOutputCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
    (void)connInfo;
    std::string value = pChar->getValue();
    if (value.empty()) {
      return;
    }
    uint8_t cmd = static_cast<uint8_t>(value[0]);
    Serial.printf("[OUT] GATT write %u byte(s), cmd=0x%02X\n", (unsigned)value.size(), cmd);
    if (isPulseCommandByte(cmd)) {
      requestSwitchOutputPulse();
    }
  }
};

SwitchOutputCallbacks switchOutputCallbacks;

void setupSwitchOutputGatt() {
  NimBLEServer* pServer = NimBLEDevice::getServer();
  if (pServer == nullptr) {
    Serial.println("[OUT] GATT server missing — PowerLink output unavailable");
    return;
  }

  NimBLEService* pService = pServer->createService(SWITCH_OUTPUT_SERVICE_UUID);
  switchOutputChar = pService->createCharacteristic(
      SWITCH_OUTPUT_CHAR_UUID,
      NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR | NIMBLE_PROPERTY::READ
  );
  const uint8_t idle = 0x00;
  switchOutputChar->setValue(&idle, 1);
  switchOutputChar->setCallbacks(&switchOutputCallbacks);
  pService->start();

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  if (advertising != nullptr) {
    advertising->stop();
    advertising->addServiceUUID(SWITCH_OUTPUT_SERVICE_UUID);
    advertising->start();
  }

  Serial.printf("[OUT] PowerLink GATT ready (pulse GPIO %u, %lums)\n",
                SWITCH_OUTPUT_PIN, SWITCH_OUTPUT_PULSE_MS);
}

void handleSwitchAction(int index, bool isPressed) {
  if (bleKeyboard == nullptr || !bleKeyboard->isConnected()) return;

  uint8_t key = SWITCH_KEYS[index];
  if (isPressed) {
    bleKeyboard->press(key);
    Serial.printf("[HID] Switch %d PRESSED -> Sending ASCII code %d\n", index + 1, key);
    triggerLedPulse();
  } else {
    bleKeyboard->release(key);
    Serial.printf("[HID] Switch %d RELEASED -> Releasing ASCII code %d\n", index + 1, key);
  }
}

// ==========================================
// 4. CORE ARDUINO LIFECYCLE
// ==========================================
void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 2000);
  Serial.println("\n[SYSTEM] Initializing Switch2GO Firmware...");

  // Generate unique BLE Name using last 4 Hex digits of Base MAC
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  snprintf(deviceName, sizeof(deviceName), "Switch2GO-%02X%02X", mac[4], mac[5]);
  Serial.printf("[BLE] Broadcaster Identity: %s\n", deviceName);

  // Initialize HijelHID via pointer to pass custom runtime name
  bleKeyboard = new HijelHID_BLEKeyboard(deviceName, "Graham Labs", 100);
  bleKeyboard->begin();
  setupSwitchOutputGatt();

  // Configure LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  pinMode(SWITCH_OUTPUT_PIN, OUTPUT);
  digitalWrite(SWITCH_OUTPUT_PIN, LOW);

  // Initialize Physical Switches
  for (int i = 0; i < NUM_SWITCHES; i++) {
    switches[i].pin = SWITCH_PINS[i];
    switches[i].lastRawState = HIGH;
    switches[i].debouncedState = HIGH;
    switches[i].lastDebounceTime = 0;
    pinMode(switches[i].pin, INPUT_PULLUP);
  }

  // Initialize BOOT Switch
  pinMode(MY_BOOT_PIN, INPUT_PULLUP);

  Serial.println("[SYSTEM] Setup complete. Pair in iPad Settings → Bluetooth, then enable Switch Control in the app.");
}

void loop() {
  unsigned long currentMillis = millis();

  // A. Process Physical Switches
  for (int i = 0; i < NUM_SWITCHES; i++) {
    bool rawReading = digitalRead(switches[i].pin);

    if (rawReading != switches[i].lastRawState) {
      switches[i].lastDebounceTime = currentMillis;
    }

    if ((currentMillis - switches[i].lastDebounceTime) > DEBOUNCE_MS) {
      if (rawReading != switches[i].debouncedState) {
        switches[i].debouncedState = rawReading;
        bool isPressed = (switches[i].debouncedState == LOW);
        handleSwitchAction(i, isPressed);
      }
    }
    switches[i].lastRawState = rawReading;
  }

  // B. Process BOOT Button (Multi-Tap)
  bool bootRawReading = digitalRead(MY_BOOT_PIN);

  if (bootRawReading != lastBootRawState) {
    lastBootDebounceTime = currentMillis;
  }

  if ((currentMillis - lastBootDebounceTime) > DEBOUNCE_MS) {
    if (bootRawReading != debouncedBootState) {
      debouncedBootState = bootRawReading;
      if (debouncedBootState == LOW) {
        bootTapCount++;
        lastBootTapTime = currentMillis;
        triggerLedPulse();
        Serial.printf("[DEBUG] BOOT Tap detected. Queue: %d\n", bootTapCount);
      }
    }
  }
  lastBootRawState = bootRawReading;

  if (bootTapCount > 0 && (currentMillis - lastBootTapTime) > TAP_TIMEOUT_MS) {
    int targetIndex = bootTapCount - 1;
    if (targetIndex >= NUM_SWITCHES) {
      targetIndex = NUM_SWITCHES - 1;
    }

    Serial.printf("[VIRTUAL] Multi-tap: %d taps -> Switch %d\n", bootTapCount, targetIndex + 1);
    handleSwitchAction(targetIndex, true);
    delay(15);
    handleSwitchAction(targetIndex, false);

    bootTapCount = 0;
  }

  // C. Housekeeping
  processSwitchOutput();
  processLedTimeout();
  delay(1);
}
