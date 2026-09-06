import { useCallback, useEffect, useMemo, useState } from 'react'
import { useMediaPlayback } from '../media/MediaPlaybackContext'
import { useGamePlayback } from '../game/GamePlaybackContext'
import { Link, useParams } from 'react-router-dom'
import { DwellSelectable } from '../components/DwellSelectable'
import { PhraseMedia } from '../components/phrases/PhraseMedia'
import { loadPhrases, markPhraseSpoken } from '../data/repository'
import { phraseStyleToLabelStyle, phraseStyleToTileStyle } from '../data/phraseStyle'
import type { PhraseDisplay } from '../data/types'
import { useTranslation } from '../i18n/useTranslation'
import { hexToCss, useSettings } from '../settings/settingsStore'
import { prepareSpeech, speak } from '../tts/speak'
import { useTrackingActions, useTrackingState } from '../tracking/TrackingContext'
import { phraseIndexForSide, phraseIndexForSwitch } from '../tracking/userFacingLaterality'

export function PhrasesPage() {
  const { t, locale } = useTranslation()
  const { categoryId = '' } = useParams()
  const [phrases, setPhrases] = useState<PhraseDisplay[]>([])
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const settings = useSettings()
  const { armRaise, handGesture } = useTrackingState()
  const { subscribeArmRaise, subscribeHandGesture } = useTrackingActions()
  const { onPhraseSelected, cancelPending, state: mediaState } = useMediaPlayback()
  const {
    onPhraseSelected: onGamePhraseSelected,
    cancelPending: cancelGamePending,
    state: gameState,
  } = useGamePlayback()

  const isFullscreenActive = mediaState.phase === 'playing' || gameState.phase === 'playing'

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
    setPage(0)
  }, [symbolCount])

  const pagePhrases = useMemo(() => {
    const start = page * symbolCount
    return phrases.slice(start, start + symbolCount)
  }, [phrases, page, symbolCount])

  const selectPhrase = useCallback(
    async (phrase: PhraseDisplay) => {
      if (isFullscreenActive) return
      speak(phrase.text, locale)
      await markPhraseSpoken(phrase.id, phrase.isPreset)
      onPhraseSelected(phrase)
      onGamePhraseSelected(phrase)
    },
    [locale, onPhraseSelected, onGamePhraseSelected, isFullscreenActive],
  )

  useEffect(() => () => {
    cancelPending()
    cancelGamePending()
  }, [cancelPending, cancelGamePending])

  const speakPhrase = useCallback(
    (phrase: PhraseDisplay) => {
      prepareSpeech()
      speak(phrase.text, locale)
    },
    [locale],
  )

  const recordPhrase = useCallback(async (phrase: PhraseDisplay) => {
    await markPhraseSpoken(phrase.id, phrase.isPreset)
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (isFullscreenActive) return
      const switchIndex = '1234'.indexOf(e.key)
      const idx = phraseIndexForSwitch(switchIndex)
      if (idx >= 0 && idx < pagePhrases.length) {
        const phrase = pagePhrases[idx]
        prepareSpeech()
        speak(phrase.text, locale)
        void markPhraseSpoken(phrase.id, phrase.isPreset)
        onPhraseSelected(phrase)
        onGamePhraseSelected(phrase)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [pagePhrases, locale, onPhraseSelected, onGamePhraseSelected, isFullscreenActive])

  useEffect(() => {
    if (settings.selectionMode !== 'armRaise') return
    return subscribeArmRaise((side) => {
      if (symbolCount !== 2 || pagePhrases.length !== 2) return
      const idx = phraseIndexForSide(side)
      void selectPhrase(pagePhrases[idx])
    })
  }, [settings.selectionMode, subscribeArmRaise, pagePhrases, selectPhrase, symbolCount])

  useEffect(() => {
    if (settings.selectionMode !== 'handGesture') return
    return subscribeHandGesture((side) => {
      if (symbolCount !== 2 || pagePhrases.length !== 2) return
      const idx = phraseIndexForSide(side)
      void selectPhrase(pagePhrases[idx])
    })
  }, [settings.selectionMode, subscribeHandGesture, pagePhrases, selectPhrase, symbolCount])

  const borderColor = hexToCss(settings.appBorderColor)
  const armRaiseActive = settings.selectionMode === 'armRaise'
  const handGestureActive = settings.selectionMode === 'handGesture'
  const binarySelectionActive = armRaiseActive || handGestureActive
  const armRaiseReady = armRaiseActive && symbolCount === 2 && pagePhrases.length === 2
  const handGestureReady = handGestureActive && symbolCount === 2 && pagePhrases.length === 2
  const binarySelectionReady = armRaiseReady || handGestureReady

  const phraseGridStyle = useMemo(() => {
    switch (symbolCount) {
      case 1:
        return { gridTemplateColumns: '1fr', gridTemplateRows: '1fr' }
      case 2:
        return { gridTemplateColumns: '1fr 1fr', gridTemplateRows: '1fr' }
      case 3:
        return { gridTemplateColumns: '1fr 1fr', gridTemplateRows: '1fr 1fr' }
      default:
        return { gridTemplateColumns: '1fr 1fr', gridTemplateRows: '1fr 1fr' }
    }
  }, [symbolCount])

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
          {binarySelectionActive && !binarySelectionReady ? (
            <p className="arm-raise-hint">
              {armRaiseActive
                ? 'Arm raise selection works with 2 phrases per page (left and right). Change layout in Settings → CVI Display.'
                : 'Hand gesture selection works with 2 phrases per page (left and right). Change layout in Settings → CVI Display.'}
            </p>
          ) : null}
          {armRaiseReady ? (
            <p className="arm-raise-hint">
              Raise your left arm for the left phrase, or your right arm for the right phrase.
            </p>
          ) : null}
          {handGestureReady ? (
            <p className="arm-raise-hint">
              Open then close your left hand (or close then open) for the left phrase. Use your
              right hand for the right phrase.
            </p>
          ) : null}
          <div className="grid grid-phrases" style={phraseGridStyle}>
            {pagePhrases.map((phrase, index) => {
              const position = page * symbolCount + index + 1
              const posColor = hexToCss(settings.getSymbolColor(position))
              const tileStyle = phraseStyleToTileStyle(phrase.style, posColor)
              const labelStyle = phraseStyleToLabelStyle(phrase.style)
              const spanFullWidth = symbolCount === 3 && index === 2
              const armHighlighted =
                armRaiseReady &&
                ((index === phraseIndexForSide('left') && armRaise.armState.leftRaised) ||
                  (index === phraseIndexForSide('right') && armRaise.armState.rightRaised))
              const handHighlighted =
                handGestureReady &&
                ((index === phraseIndexForSide('left') && handGesture.handState.leftPose != null) ||
                  (index === phraseIndexForSide('right') && handGesture.handState.rightPose != null))
              const gestureHighlighted = armHighlighted || handHighlighted
              return (
                <DwellSelectable
                  key={phrase.id}
                  id={`phrase_${phrase.id}`}
                  className={`tile phrase-tile${gestureHighlighted ? ' arm-raise-highlight' : ''}`}
                  style={{
                    ...tileStyle,
                    ...(spanFullWidth ? { gridColumn: '1 / -1' } : undefined),
                  }}
                  onSpeak={() => {
                    if (isFullscreenActive) return
                    speakPhrase(phrase)
                  }}
                  onActivate={() => {
                    if (isFullscreenActive) return
                    void recordPhrase(phrase)
                  }}
                >
                  <PhraseMedia imageRef={phrase.style?.imageRef} />
                  <span className="tile-label" style={labelStyle}>
                    {phrase.text}
                  </span>
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
