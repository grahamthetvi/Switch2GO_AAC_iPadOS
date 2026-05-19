import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { DwellSelectable } from '../components/DwellSelectable'
import { PhraseMedia } from '../components/phrases/PhraseMedia'
import { loadPhrases, markPhraseSpoken } from '../data/repository'
import { phraseStyleToTileStyle } from '../data/phraseStyle'
import type { PhraseDisplay } from '../data/types'
import { useTranslation } from '../i18n/useTranslation'
import { hexToCss, useSettings } from '../settings/settingsStore'
import { speak } from '../tts/speak'
import { useTracking } from '../tracking/TrackingContext'

export function PhrasesPage() {
  const { t, locale } = useTranslation()
  const { categoryId = '' } = useParams()
  const [phrases, setPhrases] = useState<PhraseDisplay[]>([])
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const settings = useSettings()
  const { dwell } = useTracking()

  const symbolCount = settings.symbolCount
  const totalPages = Math.max(1, Math.ceil(phrases.length / symbolCount))

  const refresh = useCallback(async () => {
    setLoading(true)
    setPhrases(await loadPhrases(categoryId))
    setLoading(false)
    setPage(0)
  }, [categoryId])

  useEffect(() => {
    void refresh()
  }, [refresh, locale])

  useEffect(() => {
    dwell.clearAllButtons()
    return () => dwell.clearAllButtons()
  }, [dwell, page, symbolCount])

  useEffect(() => {
    setPage(0)
  }, [symbolCount])

  const pagePhrases = useMemo(() => {
    const start = page * symbolCount
    return phrases.slice(start, start + symbolCount)
  }, [phrases, page, symbolCount])

  const selectPhrase = useCallback(
    async (phrase: PhraseDisplay) => {
      speak(phrase.text)
      await markPhraseSpoken(phrase.id, phrase.isPreset)
    },
    [],
  )

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const idx = '1234'.indexOf(e.key)
      if (idx >= 0 && idx < pagePhrases.length) {
        void selectPhrase(pagePhrases[idx])
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [pagePhrases, selectPhrase])

  const borderColor = hexToCss(settings.appBorderColor)
  const cols = symbolCount <= 2 ? 2 : 2

  return (
    <div className="page" style={{ background: borderColor }}>
      <header className="page-header">
        <Link to="/" className="back-btn">
          ← {t('back')}
        </Link>
        {totalPages > 1 && (
          <span className="page-indicator">
            {t('pageOf', { current: page + 1, total: totalPages })}
          </span>
        )}
      </header>

      {loading ? (
        <p className="status">{t('loadingPhrases')}</p>
      ) : phrases.length === 0 ? (
        <p className="status">No phrases in this category</p>
      ) : (
        <>
          <div
            className="grid grid-phrases"
            style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}
          >
            {pagePhrases.map((phrase, index) => {
              const position = page * symbolCount + index + 1
              const posColor = hexToCss(settings.getSymbolColor(position))
              const tileStyle = phraseStyleToTileStyle(phrase.style, posColor)
              return (
                <DwellSelectable
                  key={phrase.id}
                  id={`phrase_${phrase.id}`}
                  className="tile phrase-tile"
                  style={tileStyle}
                  onActivate={() => void selectPhrase(phrase)}
                >
                  <PhraseMedia imageRef={phrase.style?.imageRef} />
                  <span className="tile-label">{phrase.text}</span>
                </DwellSelectable>
              )
            })}
          </div>

          {totalPages > 1 && (
            <nav className="pager" aria-label="Phrase pages">
              <button
                type="button"
                disabled={page === 0}
                onClick={() => setPage((p) => Math.max(0, p - 1))}
              >
                Previous
              </button>
              <button
                type="button"
                disabled={page >= totalPages - 1}
                onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              >
                Next
              </button>
            </nav>
          )}
        </>
      )}
    </div>
  )
}
