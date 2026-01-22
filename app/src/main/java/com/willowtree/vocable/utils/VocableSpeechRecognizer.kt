package com.willowtree.vocable.utils

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import java.util.*

object VocableSpeechRecognizer {

    private var speechRecognizer: SpeechRecognizer? = null
    private val liveSpeechResult = MutableLiveData<SpeechResult>()
    val speechResult: LiveData<SpeechResult> = liveSpeechResult

    private val liveIsListening = MutableLiveData<Boolean>()
    val isListening: LiveData<Boolean> = liveIsListening

    sealed class SpeechResult {
        object ListeningStarted : SpeechResult()
        object ListeningStopped : SpeechResult()
        data class ChoicesParsed(val optionA: String, val optionB: String) : SpeechResult()
        data class Error(val message: String) : SpeechResult()
    }

    fun initialize(context: Context) {
        if (speechRecognizer == null && SpeechRecognizer.isRecognitionAvailable(context)) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        liveIsListening.postValue(true)
                        liveSpeechResult.postValue(SpeechResult.ListeningStarted)
                    }

                    override fun onBeginningOfSpeech() {
                        // Optional: Visual feedback that speech was detected
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        // Optional: Visual feedback for audio levels
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {
                        // Not used for our use case
                    }

                    override fun onEndOfSpeech() {
                        liveIsListening.postValue(false)
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val transcript = matches[0]
                            val parsedChoices = parseChoices(transcript)
                            if (parsedChoices != null) {
                                liveSpeechResult.postValue(SpeechResult.ChoicesParsed(parsedChoices.first, parsedChoices.second))
                            } else {
                                liveSpeechResult.postValue(SpeechResult.Error("Could not understand choices. Try saying 'option A or option B'"))
                            }
                        } else {
                            liveSpeechResult.postValue(SpeechResult.Error("No speech detected"))
                        }
                        liveSpeechResult.postValue(SpeechResult.ListeningStopped)
                    }

                    override fun onError(error: Int) {
                        val errorMessage = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                            SpeechRecognizer.ERROR_CLIENT -> "Client error"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required"
                            SpeechRecognizer.ERROR_NETWORK -> "Network error"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                            SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer busy"
                            SpeechRecognizer.ERROR_SERVER -> "Server error"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
                            else -> "Unknown error"
                        }
                        liveSpeechResult.postValue(SpeechResult.Error(errorMessage))
                        liveIsListening.postValue(false)
                        liveSpeechResult.postValue(SpeechResult.ListeningStopped)
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        // Optional: Show partial results for feedback
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {
                        // Not used for our use case
                    }
                })
            }
        }
    }

    fun startListening(context: Context) {
        if (speechRecognizer == null) {
            liveSpeechResult.postValue(SpeechResult.Error("Speech recognizer not available"))
            return
        }

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            liveSpeechResult.postValue(SpeechResult.Error("Microphone permission required"))
            return
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Say your choices like 'Pizza or Pasta'")
        }

        speechRecognizer?.startListening(intent)
    }

    fun stopListening() {
        speechRecognizer?.stopListening()
        liveIsListening.postValue(false)
        liveSpeechResult.postValue(SpeechResult.ListeningStopped)
    }

    fun shutdown() {
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    /**
     * Parses speech transcript to extract two choices in "X or Y" format
     * Supports various patterns like:
     * - "pizza or pasta"
     * - "option A or option B"
     * - "choice 1 or choice 2"
     */
    private fun parseChoices(transcript: String): Pair<String, String>? {
        // Convert to lowercase for easier matching
        val lowerTranscript = transcript.lowercase(Locale.getDefault()).trim()

        // Common patterns for "or"
        val orPatterns = listOf(
            "\\s+or\\s+",
            "\\s+\\|\\|\\s+",
            "\\s+versus\\s+",
            "\\s+vs\\s+"
        )

        for (pattern in orPatterns) {
            val regex = Regex(pattern)
            val parts = lowerTranscript.split(regex)
            if (parts.size == 2) {
                val optionA = parts[0].trim().capitalize(Locale.getDefault())
                val optionB = parts[1].trim().capitalize(Locale.getDefault())

                // Basic validation - ensure both options are not empty and reasonable length
                if (optionA.isNotBlank() && optionB.isNotBlank() &&
                    optionA.length <= 50 && optionB.length <= 50) {
                    return Pair(optionA, optionB)
                }
            }
        }

        return null
    }
}