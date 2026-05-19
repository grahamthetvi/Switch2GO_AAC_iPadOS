import { symbolEmoji } from '../data/symbols'
import { CATEGORY_SVG_PATHS } from '../data/categorySymbolPaths'

interface CategorySymbolProps {
  symbolId: string | null | undefined
  className?: string
}

/** Preset category icons as inline SVG; custom symbols fall back to emoji. */
export function CategorySymbol({ symbolId, className = 'category-symbol' }: CategorySymbolProps) {
  const id = symbolId ?? 'folder'
  const path = CATEGORY_SVG_PATHS[id]

  if (path) {
    return (
      <svg
        className={className}
        viewBox="0 0 24 24"
        width="1em"
        height="1em"
        fill="currentColor"
        aria-hidden
      >
        <path d={path} />
      </svg>
    )
  }

  return (
    <span className={`${className} category-symbol-emoji`} aria-hidden>
      {symbolEmoji(id)}
    </span>
  )
}
