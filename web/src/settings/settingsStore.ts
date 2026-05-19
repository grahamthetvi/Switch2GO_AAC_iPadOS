import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { Locale } from '../i18n/i18n'

export type SelectionMode = 'none' | 'eyeGaze' | 'face'
export type TrackingMode = '2D' | '3D'
export type SmoothingMode = 'none' | 'simple' | 'kalman' | 'adaptive' | 'combined'
export type EyeSelection = 'both' | 'left' | 'right'

const DEFAULT_SYMBOL_COLORS = [
  0xffe53935, 0xff1e88e5, 0xff43a047, 0xfffb8c00,
  0xff8e24aa, 0xff00acc1, 0xfff06292, 0xffffee58, 0xff78909c,
]

export interface SettingsState {
  symbolCount: number
  dwellTime: number
  sensitivity: number
  useGPU: boolean
  trackingMode: TrackingMode
  smoothingMode: SmoothingMode
  eyeSelection: EyeSelection
  gazeAmplification: number
  enableOutOfBoundsHiding: boolean
  showTrackingErrorBanner: boolean
  enableDoubleBlinkRecenter: boolean
  enableAutoRecenter: boolean
  enableRepeatDwell: boolean
  repeatDwellDelay: number
  headCameraPosition: string
  headCameraOffsetYaw: number
  headCameraOffsetPitch: number
  headSensitivityX: number
  headSensitivityY: number
  selectionMode: SelectionMode
  appBorderColor: number
  symbolColors: Record<number, number>
  hasSeenOnboarding: boolean
  onboardingRequested: boolean
  locale: Locale
  showDebugCameraPreview: boolean
  enableTrackingDiagnostics: boolean
  debugCameraRotation: number

  setSymbolCount: (n: number) => void
  setDwellTime: (t: number) => void
  setSensitivity: (s: number) => void
  setUseGPU: (v: boolean) => void
  setTrackingMode: (m: TrackingMode) => void
  setSmoothingMode: (m: SmoothingMode) => void
  setEyeSelection: (e: EyeSelection) => void
  setGazeAmplification: (v: number) => void
  setEnableOutOfBoundsHiding: (v: boolean) => void
  setShowTrackingErrorBanner: (v: boolean) => void
  setEnableDoubleBlinkRecenter: (v: boolean) => void
  setEnableAutoRecenter: (v: boolean) => void
  setEnableRepeatDwell: (v: boolean) => void
  setRepeatDwellDelay: (t: number) => void
  setHeadCameraPosition: (p: string) => void
  setHeadCameraOffsetYaw: (v: number) => void
  setHeadCameraOffsetPitch: (v: number) => void
  setHeadSensitivityX: (v: number) => void
  setHeadSensitivityY: (v: number) => void
  setSelectionMode: (m: SelectionMode) => void
  setAppBorderColor: (hex: number) => void
  getSymbolColor: (position: number) => number
  setSymbolColor: (position: number, hex: number) => void
  resetColorsToDefaults: () => void
  resetToDefaults: () => void
  setHasSeenOnboarding: (v: boolean) => void
  requestOnboarding: () => void
  clearOnboardingRequest: () => void
  setLocale: (locale: Locale) => void
  setShowDebugCameraPreview: (v: boolean) => void
  setEnableTrackingDiagnostics: (v: boolean) => void
  setDebugCameraRotation: (v: number) => void
}

const defaultSettings = {
  symbolCount: 2,
  dwellTime: 1.0,
  sensitivity: 1,
  useGPU: false,
  trackingMode: '2D' as TrackingMode,
  smoothingMode: 'adaptive' as SmoothingMode,
  eyeSelection: 'both' as EyeSelection,
  gazeAmplification: 1.0,
  enableOutOfBoundsHiding: true,
  showTrackingErrorBanner: true,
  enableDoubleBlinkRecenter: true,
  enableAutoRecenter: true,
  enableRepeatDwell: false,
  repeatDwellDelay: 1.0,
  headCameraPosition: 'left',
  headCameraOffsetYaw: 4.0,
  headCameraOffsetPitch: 0.0,
  headSensitivityX: 2.0,
  headSensitivityY: 2.5,
  selectionMode: 'none' as SelectionMode,
  appBorderColor: 0xff000000,
  symbolColors: {} as Record<number, number>,
  hasSeenOnboarding: false,
  onboardingRequested: false,
  locale: 'en' as Locale,
  showDebugCameraPreview: false,
  enableTrackingDiagnostics: false,
  debugCameraRotation: -1,
}

export const useSettings = create<SettingsState>()(
  persist(
    (set, get) => ({
      ...defaultSettings,

      setSymbolCount: (n) => set({ symbolCount: Math.min(4, Math.max(1, n)) }),
      setDwellTime: (t) => set({ dwellTime: Math.min(5, Math.max(0.5, t)) }),
      setSensitivity: (s) => set({ sensitivity: s }),
      setUseGPU: (v) => set({ useGPU: v }),
      setTrackingMode: (m) => set({ trackingMode: m }),
      setSmoothingMode: (m) => set({ smoothingMode: m }),
      setEyeSelection: (e) => set({ eyeSelection: e }),
      setGazeAmplification: (v) => set({ gazeAmplification: Math.min(2, Math.max(1, v)) }),
      setEnableOutOfBoundsHiding: (v) => set({ enableOutOfBoundsHiding: v }),
      setShowTrackingErrorBanner: (v) => set({ showTrackingErrorBanner: v }),
      setEnableDoubleBlinkRecenter: (v) => set({ enableDoubleBlinkRecenter: v }),
      setEnableAutoRecenter: (v) => set({ enableAutoRecenter: v }),
      setEnableRepeatDwell: (v) => set({ enableRepeatDwell: v }),
      setRepeatDwellDelay: (t) => set({ repeatDwellDelay: Math.min(5, Math.max(0.5, t)) }),
      setHeadCameraPosition: (p) => set({ headCameraPosition: p }),
      setHeadCameraOffsetYaw: (v) => set({ headCameraOffsetYaw: v }),
      setHeadCameraOffsetPitch: (v) => set({ headCameraOffsetPitch: v }),
      setHeadSensitivityX: (v) => set({ headSensitivityX: Math.min(4, Math.max(1, v)) }),
      setHeadSensitivityY: (v) => set({ headSensitivityY: Math.min(4, Math.max(1, v)) }),
      setSelectionMode: (m) => set({ selectionMode: m }),
      setAppBorderColor: (hex) => set({ appBorderColor: hex }),
      getSymbolColor: (position) => {
        const colors = get().symbolColors
        if (colors[position] != null) return colors[position]
        return DEFAULT_SYMBOL_COLORS[(position - 1) % DEFAULT_SYMBOL_COLORS.length] ?? DEFAULT_SYMBOL_COLORS[0]
      },
      setSymbolColor: (position, hex) =>
        set((s) => ({ symbolColors: { ...s.symbolColors, [position]: hex } })),
      resetColorsToDefaults: () => set({ symbolColors: {} }),
      resetToDefaults: () => set({ ...defaultSettings, symbolColors: {} }),
      setHasSeenOnboarding: (v) => set({ hasSeenOnboarding: v }),
      requestOnboarding: () => set({ onboardingRequested: true }),
      clearOnboardingRequest: () => set({ onboardingRequested: false }),
      setLocale: (locale) => set({ locale }),
      setShowDebugCameraPreview: (v) => set({ showDebugCameraPreview: v }),
      setEnableTrackingDiagnostics: (v) => set({ enableTrackingDiagnostics: v }),
      setDebugCameraRotation: (v) => set({ debugCameraRotation: v }),
    }),
    { name: 'switch2go-settings' },
  ),
)

export function hexToCss(hex: number): string {
  const a = ((hex >> 24) & 0xff) / 255
  const r = (hex >> 16) & 0xff
  const g = (hex >> 8) & 0xff
  const b = hex & 0xff
  return a < 1 ? `rgba(${r},${g},${b},${a})` : `rgb(${r},${g},${b})`
}
