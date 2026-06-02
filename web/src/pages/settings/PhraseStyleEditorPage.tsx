import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { PhraseMedia } from '../../components/phrases/PhraseMedia'
import { BorderWidthPickerModal } from '../../components/settings/BorderWidthPickerModal'
import { ColorPickerModal } from '../../components/settings/ColorPickerModal'
import { ImagePickerModal } from '../../components/settings/ImagePickerModal'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { updatePhraseStyle } from '../../data/crud'
import { deleteImageByRef } from '../../data/images'
import { deleteMediaByRef } from '../../data/media'
import { MediaPickerModal } from '../../components/settings/MediaPickerModal'
import { GamePickerModal } from '../../components/settings/GamePickerModal'
import { YouTubePickerModal } from '../../components/settings/YouTubePickerModal'
import {
  BORDER_WIDTH_OPTIONS,
  EMPTY_PHRASE_STYLE,
  effectiveBackground,
  effectiveFontSize,
  effectiveTextColor,
  extractEmojiFromRef,
  isYouTubePhraseMedia,
  GAME_TYPE_CURSOR_ROCKET,
  phraseStyleToTileStyle,
  TEXT_SIZE_OPTIONS,
} from '../../data/phraseStyle'
import { isYouTubeMediaRef } from '../../data/youtube'
import { getPresetPhraseText, loadPhrasesForEdit } from '../../data/repository'
import type { PhraseDisplay, PhraseStyle } from '../../data/types'
import { hexToCss } from '../../settings/settingsStore'

type ColorField = 'background' | 'text' | 'border'

export function PhraseStyleEditorPage() {
  const { phraseId = '' } = useParams()
  const [searchParams] = useSearchParams()
  const isPreset = searchParams.get('preset') === '1'
  const categoryId = searchParams.get('category') ?? ''
  const navigate = useNavigate()

  const [phrase, setPhrase] = useState<PhraseDisplay | null>(null)
  const [style, setStyle] = useState<PhraseStyle>({ ...EMPTY_PHRASE_STYLE })
  const [loading, setLoading] = useState(true)
  const [colorField, setColorField] = useState<ColorField | null>(null)
  const [showBorderWidth, setShowBorderWidth] = useState(false)
  const [showImagePicker, setShowImagePicker] = useState(false)
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [showVideoPicker, setShowVideoPicker] = useState(false)
  const [showAudioPicker, setShowAudioPicker] = useState(false)
  const [showYouTubePicker, setShowYouTubePicker] = useState(false)
  const [showGamePicker, setShowGamePicker] = useState(false)

  const backTo = categoryId
    ? `/settings/edit/phrases/${phraseId}?preset=${isPreset ? '1' : '0'}&category=${categoryId}`
    : '/settings/edit/categories'

  const refresh = useCallback(async () => {
    setLoading(true)
    if (categoryId) {
      const list = await loadPhrasesForEdit(categoryId)
      const found = list.find((p) => p.id === phraseId)
      if (found) {
        setPhrase(found)
        setStyle({ ...EMPTY_PHRASE_STYLE, ...found.style })
      }
    } else {
      setPhrase({
        id: phraseId,
        text: getPresetPhraseText(phraseId),
        sortOrder: 0,
        isPreset,
        style: null,
      })
    }
    setLoading(false)
  }, [categoryId, isPreset, phraseId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const persist = async (next: PhraseStyle) => {
    setStyle(next)
    await updatePhraseStyle(phraseId, isPreset, next)
  }

  const pickColor = (field: ColorField, hex: number) => {
    const next = { ...style }
    if (field === 'background') next.backgroundColor = hex
    else if (field === 'text') next.textColor = hex
    else next.borderColor = hex
    void persist(next)
    setColorField(null)
  }

  const borderLabel =
    BORDER_WIDTH_OPTIONS.find((o) => o.dp === (style.borderWidth ?? 0))?.label ?? 'Custom'

  const imageLabel = (() => {
    const emoji = extractEmojiFromRef(style.imageRef)
    if (emoji) return `Emoji: ${emoji}`
    if (style.imageRef) return 'Custom image'
    return 'None'
  })()

  const mediaLabel = (type: 'video' | 'audio') => {
    if (style.mediaType === type && style.mediaRef) {
      return `${type === 'video' ? 'Video' : 'Audio'}: Attached`
    }
    return `${type === 'video' ? 'Video' : 'Audio'}: None`
  }

  const youtubeLabel = isYouTubePhraseMedia(style)
    ? `YouTube: ${style.mediaRef}`
    : 'YouTube: None'

  const gameLabel =
    style.gameType === GAME_TYPE_CURSOR_ROCKET ? 'Game: Rocket cursor follower' : 'Game: None'

  const clearPreviousMedia = async (nextRef: string | null | undefined) => {
    if (!style.mediaRef || style.mediaRef === nextRef) return
    if (!isYouTubeMediaRef(style.mediaRef)) {
      await deleteMediaByRef(style.mediaRef)
    }
  }

  const resetStyle = async () => {
    if (style.imageRef) await deleteImageByRef(style.imageRef)
    if (style.mediaRef) await deleteMediaByRef(style.mediaRef)
    await persist({ bold: false })
  }

  const attachGame = async (gameType: string | null) => {
    if (gameType) {
      await clearPreviousMedia(null)
      await persist({
        ...style,
        gameType: gameType as PhraseStyle['gameType'],
        mediaRef: undefined,
        mediaType: undefined,
      })
      return
    }
    await persist({ ...style, gameType: undefined })
  }

  const attachMedia = async (
    mediaRef: string | null | undefined,
    mediaType: PhraseStyle['mediaType'],
  ) => {
    await clearPreviousMedia(mediaRef)
    await persist({
      ...style,
      mediaRef: mediaRef ?? undefined,
      mediaType: mediaType ?? undefined,
      gameType: undefined,
    })
  }

  const previewBg = hexToCss(0xff78909c)
  const previewStyle = phraseStyleToTileStyle(style, previewBg)

  if (loading || !phrase) {
    return (
      <SettingsLayout title="Edit Style" backTo={backTo} backLabel="← Phrase">
        <p className="status">{loading ? 'Loading…' : 'Phrase not found'}</p>
      </SettingsLayout>
    )
  }

  return (
    <SettingsLayout
      title="Edit Style"
      backTo={backTo}
      backLabel="← Phrase"
      actions={
        <button type="button" className="text-btn" onClick={() => navigate(backTo)}>
          Done
        </button>
      }
    >
      <section className="settings-section">
        <p className="hint">Preview</p>
        <div className="phrase-style-preview" style={previewStyle}>
          <PhraseMedia imageRef={style.imageRef} />
          <span
            className="tile-label"
            style={{
              color: hexToCss(effectiveTextColor(style)),
              fontSize: `${effectiveFontSize(style)}px`,
              fontWeight: style.bold ? 'bold' : 'normal',
            }}
          >
            {phrase.text}
          </span>
        </div>
      </section>

      <section className="settings-section style-options">
        <button type="button" className="picker-row" onClick={() => setColorField('background')}>
          <span>Background color</span>
          <span
            className="picker-preview"
            style={{ background: hexToCss(effectiveBackground(style)) }}
          />
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setColorField('text')}>
          <span>Text color</span>
          <span
            className="picker-preview"
            style={{ background: hexToCss(effectiveTextColor(style)) }}
          />
          <span className="picker-chevron">›</span>
        </button>
        <label className="toggle-row picker-row">
          <span>Bold text</span>
          <input
            type="checkbox"
            checked={!!style.bold}
            onChange={(e) => void persist({ ...style, bold: e.target.checked })}
          />
        </label>
        <label className="stack-label">
          Text size
          <select
            value={style.fontSize ?? 18}
            onChange={(e) => void persist({ ...style, fontSize: Number(e.target.value) })}
          >
            {TEXT_SIZE_OPTIONS.map(({ sp, label }) => (
              <option key={sp} value={sp}>
                {label} ({sp}px)
              </option>
            ))}
          </select>
        </label>
        <button type="button" className="picker-row" onClick={() => setColorField('border')}>
          <span>Border color</span>
          <span
            className="picker-preview"
            style={{
              background: hexToCss(style.borderColor ?? 0xffe53935),
            }}
          />
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowBorderWidth(true)}>
          <span>Border thickness: {borderLabel}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowImagePicker(true)}>
          <span>Image / emoji: {imageLabel}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowVideoPicker(true)}>
          <span>{mediaLabel('video')}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowAudioPicker(true)}>
          <span>{mediaLabel('audio')}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowYouTubePicker(true)}>
          <span>{youtubeLabel}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowGamePicker(true)}>
          <span>{gameLabel}</span>
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="danger-btn" onClick={() => void resetStyle()}>
          Reset to default
        </button>
      </section>

      {colorField === 'background' ? (
        <ColorPickerModal
          selectedHex={style.backgroundColor ?? effectiveBackground(style)}
          onSelect={(hex) => pickColor('background', hex)}
          onClose={() => setColorField(null)}
        />
      ) : null}
      {colorField === 'text' ? (
        <ColorPickerModal
          selectedHex={style.textColor ?? effectiveTextColor(style)}
          onSelect={(hex) => pickColor('text', hex)}
          onClose={() => setColorField(null)}
        />
      ) : null}
      {colorField === 'border' ? (
        <ColorPickerModal
          selectedHex={style.borderColor ?? 0xffe53935}
          onSelect={(hex) => pickColor('border', hex)}
          onClose={() => setColorField(null)}
        />
      ) : null}
      {showBorderWidth ? (
        <BorderWidthPickerModal
          selectedWidth={style.borderWidth ?? 0}
          onSelect={(width) => {
            void persist({ ...style, borderWidth: width })
            setShowBorderWidth(false)
          }}
          onClose={() => setShowBorderWidth(false)}
        />
      ) : null}
      {showImagePicker ? (
        <ImagePickerModal
          selectedImageRef={style.imageRef}
          showEmojiPicker={showEmojiPicker}
          onShowEmojiPicker={setShowEmojiPicker}
          onSelect={(ref) => {
            void (async () => {
              if (style.imageRef && style.imageRef !== ref) {
                await deleteImageByRef(style.imageRef)
              }
              await persist({ ...style, imageRef: ref })
            })()
          }}
          onClose={() => {
            setShowImagePicker(false)
            setShowEmojiPicker(false)
          }}
        />
      ) : null}
      {showVideoPicker ? (
        <MediaPickerModal
          mediaType="video"
          currentMediaRef={style.mediaRef}
          onSelect={(mediaRef, mediaType) => {
            void attachMedia(mediaRef, mediaType)
          }}
          onClose={() => setShowVideoPicker(false)}
        />
      ) : null}
      {showAudioPicker ? (
        <MediaPickerModal
          mediaType="audio"
          currentMediaRef={style.mediaRef}
          onSelect={(mediaRef, mediaType) => {
            void attachMedia(mediaRef, mediaType)
          }}
          onClose={() => setShowAudioPicker(false)}
        />
      ) : null}
      {showYouTubePicker ? (
        <YouTubePickerModal
          currentMediaRef={style.mediaRef}
          onSelect={(mediaRef, mediaType) => {
            void attachMedia(mediaRef, mediaType)
          }}
          onClose={() => setShowYouTubePicker(false)}
        />
      ) : null}
      {showGamePicker ? (
        <GamePickerModal
          currentGameType={style.gameType}
          onSelect={(gameType) => {
            void attachGame(gameType)
          }}
          onClose={() => setShowGamePicker(false)}
        />
      ) : null}
    </SettingsLayout>
  )
}
