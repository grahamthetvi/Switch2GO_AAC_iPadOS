/**
 * Switch2GO AAC - Arduino Micro USB HID Switch Controller
 *
 * Connects to iPad via USB and acts as a keyboard. When physical switches
 * are pressed, sends key presses (1, 2, 3, 4) that the app maps to phrase tiles.
 *
 * HARDWARE:
 * - Arduino Micro (or Leonardo - both have native USB HID via ATmega32U4)
 * - 1-4 momentary switches (e.g. AbleNet Jelly Bean, Clevy, etc.)
 * - Connect to iPad via Apple Lightning-to-USB Camera Adapter
 *
 * WIRING:
 * - One side of each switch → GND
 * - Other side of each switch → Digital pin (see SWITCH_PINS below)
 * - Uses internal pull-up: pin reads HIGH when open, LOW when pressed
 *
 * APP SETUP (Switch2GO):
 * - Settings → Switch Control → Enable External Switches
 * - Mode "Switch to Phrase": wire 2–4 switches; keys 1–4 → phrases 1–4
 * - Mode "Scan & Select": wire 2 switches only; key 1 = Select, key 2 = Next
 * - Key mapping in the app must match SWITCH_KEYS below (default 1–4)
 *
 * NOTE: iPad may show "This accessory is not supported" on connect — dismiss it,
 * the keyboard HID still works fine.
 */

#include <Keyboard.h>

// ============================================================================
// CONFIGURATION — Adjust for your hardware
// ============================================================================

#define NUM_SWITCHES    4

// Digital pins for each switch (Arduino Micro: D2-D12, A0-A5 available)
// Switch 1 → Phrase 1 (top-left), Switch 2 → Phrase 2, etc.
const int SWITCH_PINS[NUM_SWITCHES] = { A2, A3, A4, A5 };

// ASCII characters to send — Keyboard.h handles the HID translation internally
const char SWITCH_KEYS[NUM_SWITCHES] = { '1', '2', '3', '4' };

// Built-in LED (Arduino Micro: pin 13)
#define LED_PIN         13

// Debounce time in milliseconds
#define DEBOUNCE_MS     50

// LED flash duration in milliseconds (non-blocking)
#define LED_FLASH_MS    30

// ============================================================================
// State
// ============================================================================

bool          switchState[NUM_SWITCHES]      = {};
bool          lastRawState[NUM_SWITCHES]     = {};
unsigned long lastDebounceTime[NUM_SWITCHES] = {};

unsigned long lastLedOnTime = 0;  // When the LED was turned on
bool          isLedOn       = false; // Is the LED currently flashing?

// ============================================================================
// Setup
// ============================================================================
void setup() {
  Serial.begin(115200);
  Serial.println(F("\n=== Switch2GO USB Switch Controller ==="));

  for (int i = 0; i < NUM_SWITCHES; i++) {
    pinMode(SWITCH_PINS[i], INPUT_PULLUP);
    Serial.print(F("  Switch "));
    Serial.print(i + 1);
    Serial.print(F(" -> Pin "));
    Serial.print(SWITCH_PINS[i]);
    Serial.print(F(" (key '"));
    Serial.print(SWITCH_KEYS[i]);
    Serial.println(F("')"));
  }

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Keyboard.begin();
  Keyboard.releaseAll(); // Ensure no keys are stuck on startup
  Serial.println(F("USB Keyboard ready. Connect to iPad."));
}

// ============================================================================
// Main Loop
// ============================================================================
void loop() {
  unsigned long now = millis();

  // --- Read and debounce switches ---
  for (int i = 0; i < NUM_SWITCHES; i++) {
    // Active LOW: pressed = pin reads LOW (switch connects pin to GND)
    bool rawPressed = (digitalRead(SWITCH_PINS[i]) == LOW);

    if (rawPressed != lastRawState[i]) {
      lastDebounceTime[i] = now;
      lastRawState[i] = rawPressed;
    }

    if ((now - lastDebounceTime[i]) >= DEBOUNCE_MS) {
      if (rawPressed != switchState[i]) {
        switchState[i] = rawPressed;
        onSwitchChanged(i, rawPressed);
      }
    }
  }

  // --- Non-blocking LED off (Rollover-safe) ---
  if (isLedOn && (now - lastLedOnTime >= LED_FLASH_MS)) {
    digitalWrite(LED_PIN, LOW);
    isLedOn = false;
  }

  delay(1);
}

// ============================================================================
// Switch Event Handler
// ============================================================================
void onSwitchChanged(int switchIndex, bool pressed) {
  Serial.print(F("Switch "));
  Serial.print(switchIndex + 1);
  Serial.println(pressed ? F(" PRESSED") : F(" RELEASED"));

  if (pressed) {
    Keyboard.press(SWITCH_KEYS[switchIndex]);

    // Non-blocking LED flash
    digitalWrite(LED_PIN, HIGH);
    lastLedOnTime = millis();
    isLedOn = true;
  } else {
    Keyboard.release(SWITCH_KEYS[switchIndex]);
  }
}
