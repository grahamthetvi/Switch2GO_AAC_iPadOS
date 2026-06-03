import { useEffect, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { OnboardingOverlay } from './components/onboarding/OnboardingOverlay'
import { GazeOverlay } from './components/GazeOverlay'
import { ensureDatabaseSeeded } from './data/seed'
import { CategoriesPage } from './pages/CategoriesPage'
import { PhrasesPage } from './pages/PhrasesPage'
import { SettingsPage } from './pages/SettingsPage'
import { AddCategoryPage } from './pages/settings/AddCategoryPage'
import { AddPhrasePage } from './pages/settings/AddPhrasePage'
import { AdvancedEyeTrackingPage } from './pages/settings/AdvancedEyeTrackingPage'
import { AppBorderColorPage } from './pages/settings/AppBorderColorPage'
import { CategoriesDisplayPage } from './pages/settings/CategoriesDisplayPage'
import { CVIDisplayPage } from './pages/settings/CVIDisplayPage'
import { EditCategoriesListPage } from './pages/settings/EditCategoriesListPage'
import { EditCategoryDetailPage } from './pages/settings/EditCategoryDetailPage'
import { EditPhraseDetailPage } from './pages/settings/EditPhraseDetailPage'
import { HeadTrackingPage } from './pages/settings/HeadTrackingPage'
import { PhraseStyleEditorPage } from './pages/settings/PhraseStyleEditorPage'
import { ResetAppPage } from './pages/settings/ResetAppPage'
import { SelectionModePage } from './pages/settings/SelectionModePage'
import { SwitchControlPage } from './pages/settings/SwitchControlPage'
import { TimingSensitivityPage } from './pages/settings/TimingSensitivityPage'
import { LanguagePage } from './pages/settings/LanguagePage'
import { PrivacyPolicyPage } from './pages/settings/PrivacyPolicyPage'
import { ThirdPartyNoticesPage } from './pages/settings/ThirdPartyNoticesPage'
import { DataBackupPage } from './pages/settings/DataBackupPage'
import { TroubleshootingPage } from './pages/settings/TroubleshootingPage'
import { useSettings } from './settings/settingsStore'
import { MediaPlaybackProvider } from './media/MediaPlaybackContext'
import { GamePlaybackProvider } from './game/GamePlaybackContext'
import { TrackingProvider } from './tracking/TrackingContext'
import { prepareSpeech } from './tts/speak'

export default function App() {
  const [ready, setReady] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const hasSeenOnboarding = useSettings((s) => s.hasSeenOnboarding)
  const onboardingRequested = useSettings((s) => s.onboardingRequested)
  const locale = useSettings((s) => s.locale)
  const showOnboarding = !hasSeenOnboarding || onboardingRequested

  useEffect(() => {
    document.documentElement.lang = locale
  }, [locale])

  useEffect(() => {
    const prime = () => prepareSpeech()
    window.addEventListener('pointerdown', prime, { capture: true, passive: true })
    window.addEventListener('touchstart', prime, { capture: true, passive: true })
    window.addEventListener('keydown', prime, { capture: true })
    return () => {
      window.removeEventListener('pointerdown', prime, { capture: true })
      window.removeEventListener('touchstart', prime, { capture: true })
      window.removeEventListener('keydown', prime, { capture: true })
    }
  }, [])

  useEffect(() => {
    ensureDatabaseSeeded()
      .then(() => setReady(true))
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load data'))
  }, [])

  if (error) {
    return (
      <div className="page">
        <p className="status error">{error}</p>
      </div>
    )
  }

  if (!ready) {
    return (
      <div className="page">
        <p className="status">Loading Switch2Go…</p>
      </div>
    )
  }

  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <TrackingProvider>
        <MediaPlaybackProvider>
          <GamePlaybackProvider>
          {showOnboarding && <OnboardingOverlay />}
          <GazeOverlay />
          <Routes>
          <Route path="/" element={<CategoriesPage />} />
          <Route path="/phrases/:categoryId" element={<PhrasesPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/settings/timing" element={<TimingSensitivityPage />} />
          <Route path="/settings/selection" element={<SelectionModePage />} />
          <Route path="/settings/cvi" element={<CVIDisplayPage />} />
          <Route path="/settings/categories-display" element={<CategoriesDisplayPage />} />
          <Route path="/settings/border-color" element={<AppBorderColorPage />} />
          <Route path="/settings/eye-tracking" element={<AdvancedEyeTrackingPage />} />
          <Route path="/settings/head-tracking" element={<HeadTrackingPage />} />
          <Route path="/settings/switch-control" element={<SwitchControlPage />} />
          <Route path="/settings/language" element={<LanguagePage />} />
          <Route path="/settings/backup" element={<DataBackupPage />} />
          <Route path="/settings/troubleshooting" element={<TroubleshootingPage />} />
          <Route path="/settings/privacy" element={<PrivacyPolicyPage />} />
          <Route path="/settings/licenses" element={<ThirdPartyNoticesPage />} />
          <Route path="/settings/reset" element={<ResetAppPage />} />
          <Route path="/settings/general" element={<Navigate to="/settings/timing" replace />} />
          <Route path="/settings/edit/categories" element={<EditCategoriesListPage />} />
          <Route path="/settings/edit/categories/new" element={<AddCategoryPage />} />
          <Route path="/settings/edit/categories/:categoryId" element={<EditCategoryDetailPage />} />
          <Route
            path="/settings/edit/categories/:categoryId/phrases/new"
            element={<AddPhrasePage />}
          />
          <Route path="/settings/edit/phrases/:phraseId" element={<EditPhraseDetailPage />} />
          <Route path="/settings/edit/phrases/:phraseId/style" element={<PhraseStyleEditorPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
          </GamePlaybackProvider>
        </MediaPlaybackProvider>
      </TrackingProvider>
    </BrowserRouter>
  )
}
