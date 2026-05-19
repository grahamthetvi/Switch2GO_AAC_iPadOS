let preferredVoice: SpeechSynthesisVoice | null = null

function pickVoice(): SpeechSynthesisVoice | null {
  if (preferredVoice) return preferredVoice
  const voices = speechSynthesis.getVoices()
  preferredVoice =
    voices.find((v) => v.lang.startsWith('en') && v.localService) ??
    voices.find((v) => v.lang.startsWith('en')) ??
    voices[0] ??
    null
  return preferredVoice
}

if (typeof speechSynthesis !== 'undefined') {
  speechSynthesis.onvoiceschanged = () => {
    preferredVoice = null
  }
}

export function speak(text: string): void {
  if (!text.trim() || typeof speechSynthesis === 'undefined') return
  speechSynthesis.cancel()
  const utterance = new SpeechSynthesisUtterance(text)
  const voice = pickVoice()
  if (voice) utterance.voice = voice
  utterance.rate = 0.95
  speechSynthesis.speak(utterance)
}
