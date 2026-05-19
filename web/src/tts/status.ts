export type TtsState = 'idle' | 'loading' | 'speaking' | 'error'

export interface TtsStatus {
  state: TtsState
  message: string | null
}

type TtsStatusListener = (status: TtsStatus) => void

let status: TtsStatus = { state: 'idle', message: null }
const listeners = new Set<TtsStatusListener>()

export function getTtsStatus(): TtsStatus {
  return status
}

export function subscribeTtsStatus(listener: TtsStatusListener): () => void {
  listeners.add(listener)
  listener(status)
  return () => listeners.delete(listener)
}

export function setTtsStatus(next: TtsStatus): void {
  status = next
  for (const listener of listeners) listener(status)
}

export function clearTtsError(): void {
  if (status.state === 'error') {
    setTtsStatus({ state: 'idle', message: null })
  }
}
