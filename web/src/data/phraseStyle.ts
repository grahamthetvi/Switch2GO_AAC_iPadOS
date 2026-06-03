import type { CSSProperties } from 'react'
import type { PhraseStyle } from './types'

/** JSON on disk matches KMP PhraseStyleData (iOS/Android). */
interface RawPhraseStyle {
  backgroundColor?: number
  textColor?: number
  textSizeSp?: number
  fontSize?: number
  isBold?: boolean
  bold?: boolean
  borderColor?: number
  borderWidthDp?: number
  borderWidth?: number
  imageRef?: string | null
  mediaRef?: string | null
  mediaType?: 'video' | 'audio' | 'youtube' | null
  gameType?: 'cursor_rocket' | 'blocs' | 'pie_crazy' | null
  emoji?: string
}

export const EMOJI_PREFIX = 'emoji:'
export const BLOB_PREFIX = 'blob:'
export const MEDIA_BLOB_PREFIX = 'media:'
export const MEDIA_TYPE_VIDEO = 'video'
export const MEDIA_TYPE_AUDIO = 'audio'
export const MEDIA_TYPE_YOUTUBE = 'youtube'
export const GAME_TYPE_CURSOR_ROCKET = 'cursor_rocket'
export const GAME_TYPE_BLOCS = 'blocs'
export const GAME_TYPE_PIE_CRAZY = 'pie_crazy'

export const TEXT_SIZE_OPTIONS: { sp: number; label: string }[] = [
  { sp: 12, label: 'Small' },
  { sp: 16, label: 'Medium small' },
  { sp: 18, label: 'Medium' },
  { sp: 22, label: 'Medium large' },
  { sp: 26, label: 'Large' },
  { sp: 32, label: 'Extra large' },
  { sp: 40, label: 'Huge' },
]

export const BORDER_WIDTH_OPTIONS: { dp: number; label: string }[] = [
  { dp: 0, label: 'None' },
  { dp: 6, label: 'Thin' },
  { dp: 10, label: 'Medium' },
  { dp: 14, label: 'Thick' },
  { dp: 20, label: 'XL' },
  { dp: 28, label: 'XXL' },
]

const DEFAULT_BG = 0xff000000
const DEFAULT_TEXT = 0xff000000
const DEFAULT_BORDER = 0xffe53935

function colorToCss(hex: number): string {
  const a = ((hex >> 24) & 0xff) / 255
  const r = (hex >> 16) & 0xff
  const g = (hex >> 8) & 0xff
  const b = hex & 0xff
  return a < 1 ? `rgba(${r},${g},${b},${a})` : `rgb(${r},${g},${b})`
}

export function parsePhraseStyle(json: string | null): PhraseStyle | null {
  if (!json) return null
  try {
    const raw = JSON.parse(json) as RawPhraseStyle
    let imageRef = raw.imageRef ?? undefined
    if (!imageRef && raw.emoji) {
      imageRef = `${EMOJI_PREFIX}${raw.emoji}`
    }
    return {
      backgroundColor: raw.backgroundColor,
      textColor: raw.textColor,
      fontSize: raw.textSizeSp ?? raw.fontSize,
      bold: raw.isBold ?? raw.bold ?? false,
      borderColor: raw.borderColor,
      borderWidth: raw.borderWidthDp ?? raw.borderWidth,
      imageRef: imageRef ?? undefined,
      mediaRef: raw.mediaRef ?? undefined,
      mediaType: raw.mediaType ?? undefined,
      gameType: raw.gameType ?? undefined,
    }
  } catch {
    return null
  }
}

export function serializePhraseStyle(style: PhraseStyle): string {
  const payload: RawPhraseStyle = {
    backgroundColor: style.backgroundColor,
    textColor: style.textColor,
    textSizeSp: style.fontSize,
    isBold: style.bold ?? false,
    borderColor: style.borderColor,
    borderWidthDp: style.borderWidth,
    imageRef: style.imageRef ?? null,
    mediaRef: style.mediaRef ?? null,
    mediaType: style.mediaType ?? null,
    gameType: style.gameType ?? null,
  }
  return JSON.stringify(payload)
}

export function hasPhraseMedia(style: PhraseStyle | null | undefined): boolean {
  return !!(style?.mediaRef && style?.mediaType)
}

export function hasPhraseGame(style: PhraseStyle | null | undefined): boolean {
  return !!style?.gameType
}

export function isYouTubePhraseMedia(style: PhraseStyle | null | undefined): boolean {
  return style?.mediaType === MEDIA_TYPE_YOUTUBE && !!style.mediaRef
}

export function isBlobMediaRef(ref: string | null | undefined): boolean {
  return !!ref && ref.startsWith(MEDIA_BLOB_PREFIX)
}

export function extractEmojiFromRef(ref: string | null | undefined): string | null {
  if (!ref) return null
  if (ref.startsWith(EMOJI_PREFIX)) return ref.slice(EMOJI_PREFIX.length)
  return null
}

export function isBlobImageRef(ref: string | null | undefined): boolean {
  return !!ref && ref.startsWith(BLOB_PREFIX)
}

export function effectiveBackground(style: PhraseStyle | null): number {
  return style?.backgroundColor ?? DEFAULT_BG
}

export function effectiveTextColor(style: PhraseStyle | null): number {
  return style?.textColor ?? DEFAULT_TEXT
}

export function effectiveFontSize(style: PhraseStyle | null): number {
  return style?.fontSize ?? 18
}

export function phraseStyleToTileStyle(
  style: PhraseStyle | null,
  fallbackBackgroundCss: string,
): CSSProperties {
  const bg =
    style?.backgroundColor != null ? colorToCss(style.backgroundColor) : fallbackBackgroundCss
  const color = style?.textColor != null ? colorToCss(style.textColor) : '#ffffff'
  const borderWidth = style?.borderWidth ?? 0
  const borderColor =
    style?.borderColor != null ? colorToCss(style.borderColor) : colorToCss(DEFAULT_BORDER)

  return {
    background: bg,
    color,
    fontWeight: style?.bold ? 'bold' : undefined,
    border: borderWidth > 0 ? `${borderWidth}px solid ${borderColor}` : undefined,
  }
}

/** Text styles for phrase label (separate from tile chrome). */
export function phraseStyleToLabelStyle(style: PhraseStyle | null): CSSProperties {
  const color =
    style?.textColor != null ? colorToCss(style.textColor) : undefined
  const fontSize =
    style?.fontSize != null ? `${effectiveFontSize(style)}px` : undefined

  return {
    color,
    fontSize,
    fontWeight: style?.bold ? 'bold' : undefined,
  }
}

export const EMPTY_PHRASE_STYLE: PhraseStyle = {
  bold: false,
}
