package com.switch2go.aac.settings

import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.navigation.fragment.navArgs
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.IPhrasesUseCase
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentPhraseEditMenuBinding
import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.room.PhraseStyle
import com.switch2go.aac.utils.ILocalizedResourceUtility
import com.switch2go.aac.utils.PhraseTextBubble
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.koin.android.ext.android.inject

class PhraseEditMenuFragment : BaseFragment<FragmentPhraseEditMenuBinding>() {

    override val bindingInflater: BindingInflater<FragmentPhraseEditMenuBinding> =
        FragmentPhraseEditMenuBinding::inflate

    private val args: PhraseEditMenuFragmentArgs by navArgs()
    private val phrasesUseCase: IPhrasesUseCase by inject()
    private val localizedResourceUtility: ILocalizedResourceUtility by inject()

    private lateinit var phrase: Phrase
    private lateinit var category: Category
    private var currentPosition: Int = 0
    private var totalPhrases: Int = 0
    private var selectedPosition: Int = 0

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        phrase = args.phrase
        category = args.category

        setupUI()
        loadPhrasePosition()
    }

    override fun onResume() {
        super.onResume()
        refreshPhrase()
    }

    private fun setupUI() {
        // Display phrase text
        binding.phraseText.text = localizedResourceUtility.getTextFromPhrase(phrase)
        applyPhraseStyleToPreview(phrase.style)

        // Back button
        binding.backButton.action = {
            findNavController().popBackStack()
        }

        // Edit text button
        binding.editTextButton.action = {
            val action = PhraseEditMenuFragmentDirections
                .actionPhraseEditMenuFragmentToEditPhrasesKeyboardFragment(phrase)
            if (findNavController().currentDestination?.id == R.id.phraseEditMenuFragment) {
                findNavController().navigate(action)
            }
        }

        // Edit appearance/style button
        binding.editStyleButton.action = {
            val action = PhraseEditMenuFragmentDirections
                .actionPhraseEditMenuFragmentToPhraseStyleEditorFragment(phrase)
            if (findNavController().currentDestination?.id == R.id.phraseEditMenuFragment) {
                findNavController().navigate(action)
            }
        }

        // Move up button
        binding.moveUpButton.action = {
            viewLifecycleOwner.lifecycleScope.launch {
                phrasesUseCase.movePhraseUp(category.categoryId, phrase.phraseId)
                loadPhrasePosition()
                announcePositionChange()
            }
        }

        // Move down button
        binding.moveDownButton.action = {
            viewLifecycleOwner.lifecycleScope.launch {
                phrasesUseCase.movePhraseDown(category.categoryId, phrase.phraseId)
                loadPhrasePosition()
                announcePositionChange()
            }
        }

        // Move to position button
        binding.moveToPositionButton.action = {
            showPositionPicker()
        }

        // Delete button
        binding.deleteButton.action = {
            showDeleteConfirmation()
        }

        setupPositionPicker()
        setupDeleteConfirmation()
    }

    private fun loadPhrasePosition() {
        viewLifecycleOwner.lifecycleScope.launch {
            val phrases = phrasesUseCase.getPhrasesForCategory(category.categoryId)
                .sortedBy { it.sortOrder }
            
            totalPhrases = phrases.size
            currentPosition = phrases.indexOfFirst { it.phraseId == phrase.phraseId } + 1

            updatePositionIndicator()
            updateButtonStates()
        }
    }

    private fun refreshPhrase() {
        viewLifecycleOwner.lifecycleScope.launch {
            val phrases = phrasesUseCase.getPhrasesForCategory(category.categoryId)
            val refreshedPhrase = phrases.find { it.phraseId == phrase.phraseId }
            if (refreshedPhrase != null) {
                phrase = refreshedPhrase
                binding.phraseText.text = localizedResourceUtility.getTextFromPhrase(phrase)
                applyPhraseStyleToPreview(phrase.style)
            }
        }
    }

    private fun applyPhraseStyleToPreview(style: PhraseStyle?) {
        if (style == null) {
            binding.phraseText.background =
                ContextCompat.getDrawable(requireContext(), R.drawable.button_default_background)
            binding.phraseText.setTextColor(ContextCompat.getColor(requireContext(), R.color.textColor))
            binding.phraseText.textSize = 20f
            binding.phraseText.setTypeface(null, Typeface.BOLD)
            PhraseTextBubble.apply(binding.phraseText, null)
            return
        }

        val backgroundColor = style.effectiveBackgroundColor()
        val cornerRadius = 16f * binding.phraseText.resources.displayMetrics.density

        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = cornerRadius
            setColor(backgroundColor)
        }
        binding.phraseText.background = drawable
        binding.phraseText.setTextColor(style.effectiveTextColor())
        binding.phraseText.textSize = style.effectiveTextSize()
        binding.phraseText.setTypeface(
            null,
            if (style.isBold) Typeface.BOLD else Typeface.NORMAL
        )
        PhraseTextBubble.apply(binding.phraseText, style)
    }

    private fun updatePositionIndicator() {
        binding.positionIndicator.text = getString(
            R.string.current_position,
            currentPosition,
            totalPhrases
        )
        binding.positionIndicator.contentDescription = getString(
            R.string.current_position,
            currentPosition,
            totalPhrases
        )
    }

    private fun updateButtonStates() {
        binding.moveUpButton.isEnabled = currentPosition > 1
        binding.moveDownButton.isEnabled = currentPosition < totalPhrases

        binding.moveUpButton.alpha = if (binding.moveUpButton.isEnabled) 1.0f else 0.5f
        binding.moveDownButton.alpha = if (binding.moveDownButton.isEnabled) 1.0f else 0.5f
    }

    private fun announcePositionChange() {
        binding.positionIndicator.announceForAccessibility(
            getString(R.string.current_position, currentPosition, totalPhrases)
        )
    }

    private fun setupPositionPicker() {
        val dialog = binding.positionPickerDialog

        // Position buttons 1-9
        val positionButtons = listOf(
            dialog.position1, dialog.position2, dialog.position3,
            dialog.position4, dialog.position5, dialog.position6,
            dialog.position7, dialog.position8, dialog.position9
        )

        positionButtons.forEachIndexed { index, button ->
            button.action = {
                selectPosition(index + 1)
            }
        }

        // 10+ button shows extended picker (or just selects position 10)
        dialog.position10Plus.action = {
            // For simplicity, we'll cycle through 10, 11, 12... on repeated taps
            val nextPos = if (selectedPosition >= 10) selectedPosition + 1 else 10
            if (nextPos <= totalPhrases) {
                selectPosition(nextPos)
            }
        }

        dialog.positionPickerCancel.action = {
            hidePositionPicker()
        }

        dialog.positionPickerConfirm.action = {
            if (selectedPosition in 1..totalPhrases && selectedPosition != currentPosition) {
                viewLifecycleOwner.lifecycleScope.launch {
                    phrasesUseCase.movePhraseToPosition(
                        category.categoryId,
                        phrase.phraseId,
                        selectedPosition - 1 // Convert to 0-indexed
                    )
                    hidePositionPicker()
                    loadPhrasePosition()
                    announcePositionChange()
                }
            }
        }

        dialog.positionPickerContainer.setOnClickListener {
            hidePositionPicker()
        }
    }

    private fun showPositionPicker() {
        selectedPosition = currentPosition
        
        binding.positionPickerDialog.positionPickerInstruction.text = getString(
            R.string.enter_position,
            totalPhrases
        )
        binding.positionPickerDialog.selectedPositionText.text = selectedPosition.toString()
        
        // Update button visibility based on total phrases
        updatePositionButtonVisibility()
        
        binding.positionPickerDialog.positionPickerContainer.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hidePositionPicker() {
        binding.positionPickerDialog.positionPickerContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun selectPosition(position: Int) {
        if (position in 1..totalPhrases) {
            selectedPosition = position
            binding.positionPickerDialog.selectedPositionText.text = position.toString()
            binding.positionPickerDialog.selectedPositionText.announceForAccessibility(
                "Position $position selected"
            )
        }
    }

    private fun updatePositionButtonVisibility() {
        val dialog = binding.positionPickerDialog
        val buttons = listOf(
            dialog.position1, dialog.position2, dialog.position3,
            dialog.position4, dialog.position5, dialog.position6,
            dialog.position7, dialog.position8, dialog.position9,
            dialog.position10Plus
        )

        buttons.forEachIndexed { index, button ->
            if (index < 9) {
                button.isVisible = index < totalPhrases
                button.isEnabled = index + 1 != currentPosition
                button.alpha = if (button.isEnabled) 1.0f else 0.5f
            } else {
                // 10+ button
                button.isVisible = totalPhrases > 9
                button.isEnabled = totalPhrases > 9
            }
        }
    }

    private fun setupDeleteConfirmation() {
        binding.deleteConfirmation.dialogTitle.setText(R.string.are_you_sure)
        binding.deleteConfirmation.dialogMessage.setText(R.string.delete_warning)
        
        binding.deleteConfirmation.dialogPositiveButton.apply {
            setText(R.string.delete)
            action = {
                viewLifecycleOwner.lifecycleScope.launch {
                    phrasesUseCase.deletePhrase(phrase.phraseId)
                    findNavController().popBackStack()
                }
            }
        }

        binding.deleteConfirmation.dialogNegativeButton.apply {
            setText(R.string.cancel)
            action = {
                hideDeleteConfirmation()
            }
        }
    }

    private fun showDeleteConfirmation() {
        binding.deleteConfirmation.root.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hideDeleteConfirmation() {
        binding.deleteConfirmation.root.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun setMainButtonsEnabled(enabled: Boolean) {
        binding.apply {
            backButton.isEnabled = enabled
            editTextButton.isEnabled = enabled
            editStyleButton.isEnabled = enabled
            moveUpButton.isEnabled = enabled && currentPosition > 1
            moveDownButton.isEnabled = enabled && currentPosition < totalPhrases
            moveToPositionButton.isEnabled = enabled
            deleteButton.isEnabled = enabled
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}

