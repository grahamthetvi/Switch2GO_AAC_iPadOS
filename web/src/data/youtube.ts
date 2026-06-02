export const MEDIA_YOUTUBE_PREFIX = 'youtube:'

const YOUTUBE_ID_PATTERNS = [
  /(?:youtube\.com\/watch\?.*[?&]v=|youtube\.com\/embed\/|youtube\.com\/shorts\/|youtu\.be\/)([\w-]{11})/,
  /^([\w-]{11})$/,
]

export function extractYouTubeVideoId(ref: string | null | undefined): string | null {
  if (!ref) return null
  const trimmed = ref.trim()
  if (trimmed.startsWith(MEDIA_YOUTUBE_PREFIX)) {
    const id = trimmed.slice(MEDIA_YOUTUBE_PREFIX.length)
    return id || null
  }
  for (const pattern of YOUTUBE_ID_PATTERNS) {
    const match = trimmed.match(pattern)
    if (match?.[1]) return match[1]
  }
  return null
}

export function normalizeYouTubeMediaRef(input: string | null | undefined): string | null {
  const videoId = extractYouTubeVideoId(input)
  return videoId ? `${MEDIA_YOUTUBE_PREFIX}${videoId}` : null
}

export function isYouTubeMediaRef(ref: string | null | undefined): boolean {
  return !!ref?.startsWith(MEDIA_YOUTUBE_PREFIX)
}
