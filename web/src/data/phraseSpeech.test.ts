import { describe, expect, it } from 'vitest'
import { normalizeSpokenText, phraseSpeechText } from './phraseSpeech'

describe('phraseSpeechText', () => {
  it('speaks the button label when spoken text is missing', () => {
    expect(phraseSpeechText('Bathroom', null)).toBe('Bathroom')
    expect(phraseSpeechText('Bathroom', undefined)).toBe('Bathroom')
    expect(phraseSpeechText('Bathroom', '   ')).toBe('Bathroom')
  })

  it('speaks the spoken text when it is set', () => {
    expect(phraseSpeechText('Bathroom', 'I need to use the bathroom')).toBe(
      'I need to use the bathroom',
    )
    expect(normalizeSpokenText('  Doctor  ')).toBe('Doctor')
  })
})
