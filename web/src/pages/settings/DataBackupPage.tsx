import { useRef, useState } from 'react'
import { backupFilename, exportBackupBlob, importBackupFromFile } from '../../data/backup'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'

export function DataBackupPage() {
  const { t } = useTranslation()
  const fileRef = useRef<HTMLInputElement>(null)
  const [status, setStatus] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [importStep, setImportStep] = useState(0)

  const exportData = async () => {
    setError(null)
    setStatus(null)
    try {
      const blob = await exportBackupBlob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = backupFilename()
      a.click()
      URL.revokeObjectURL(url)
      setStatus(t('dataBackup.exportDone'))
    } catch (e) {
      setError(e instanceof Error ? e.message : t('dataBackup.exportFailed'))
    }
  }

  const runImport = async (file: File) => {
    setError(null)
    setStatus(null)
    try {
      await importBackupFromFile(file)
      setStatus(t('dataBackup.importDone'))
      setImportStep(0)
      window.setTimeout(() => {
        window.location.href = import.meta.env.BASE_URL
      }, 800)
    } catch (e) {
      setError(e instanceof Error ? e.message : t('dataBackup.importFailed'))
      setImportStep(0)
    }
  }

  return (
    <SettingsLayout title={t('dataBackup.title')} backTo="/settings" backLabel={t('settingsBack')}>
      <section className="settings-section">
        <p className="settings-intro">{t('dataBackup.intro')}</p>

        <h2 className="settings-subheading">{t('dataBackup.exportHeading')}</h2>
        <p className="hint">{t('dataBackup.exportHint')}</p>
        <button type="button" className="primary-btn" onClick={() => void exportData()}>
          {t('dataBackup.exportButton')}
        </button>

        <hr className="settings-hub-divider" />

        <h2 className="settings-subheading">{t('dataBackup.importHeading')}</h2>
        <p className="hint">{t('dataBackup.importHint')}</p>
        <input
          ref={fileRef}
          type="file"
          accept="application/json,.json"
          className="hidden-file-input"
          onChange={(e) => {
            const file = e.target.files?.[0]
            e.target.value = ''
            if (file && importStep === 2) void runImport(file)
          }}
        />

        {importStep === 0 ? (
          <button type="button" className="secondary-btn" onClick={() => setImportStep(1)}>
            {t('dataBackup.importButton')}
          </button>
        ) : importStep === 1 ? (
          <>
            <p className="hint data-backup-warning">{t('dataBackup.importWarning')}</p>
            <button type="button" className="danger-btn" onClick={() => setImportStep(2)}>
              {t('dataBackup.importConfirm')}
            </button>
            <button type="button" className="text-btn" onClick={() => setImportStep(0)}>
              {t('dataBackup.cancel')}
            </button>
          </>
        ) : (
          <button type="button" className="danger-btn" onClick={() => fileRef.current?.click()}>
            {t('dataBackup.importChooseFile')}
          </button>
        )}

        {status ? <p className="status success">{status}</p> : null}
        {error ? <p className="status error">{error}</p> : null}
      </section>
    </SettingsLayout>
  )
}
