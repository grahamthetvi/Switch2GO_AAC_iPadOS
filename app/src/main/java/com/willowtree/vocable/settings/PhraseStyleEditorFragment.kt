package com.willowtree.vocable.settings

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.navigation.fragment.navArgs
import com.willowtree.vocable.BaseFragment
import com.willowtree.vocable.BindingInflater
import com.willowtree.vocable.IPhrasesUseCase
import com.willowtree.vocable.R
import com.willowtree.vocable.databinding.FragmentPhraseStyleEditorBinding
import com.willowtree.vocable.presets.Phrase
import com.willowtree.vocable.room.PhraseStyle
import com.willowtree.vocable.utils.ILocalizedResourceUtility
import com.willowtree.vocable.utils.PhraseTextBubble
import kotlinx.coroutines.launch
import org.koin.android.ext.android.inject

class PhraseStyleEditorFragment : BaseFragment<FragmentPhraseStyleEditorBinding>() {

    override val bindingInflater: BindingInflater<FragmentPhraseStyleEditorBinding> =
        FragmentPhraseStyleEditorBinding::inflate

    private val args: PhraseStyleEditorFragmentArgs by navArgs()
    private val phrasesUseCase: IPhrasesUseCase by inject()
    private val localizedResourceUtility: ILocalizedResourceUtility by inject()

    private lateinit var phrase: Phrase
    private var currentStyle: PhraseStyle = PhraseStyle.DEFAULT

    // Track which color property is being edited
    private enum class ColorTarget { BACKGROUND, TEXT, BORDER }
    private var colorTarget: ColorTarget = ColorTarget.BACKGROUND

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        phrase = args.phrase
        currentStyle = phrase.style ?: PhraseStyle.DEFAULT

        setupUI()
        updatePreview()
    }

    private fun setupUI() {
        // Set preview text
        binding.previewButton.text = localizedResourceUtility.getTextFromPhrase(phrase)

        // Back button
        binding.backButton.action = {
            findNavController().popBackStack()
        }

        // Background color button
        binding.backgroundColorButton.action = {
            colorTarget = ColorTarget.BACKGROUND
            showColorPicker()
        }

        // Text color button
        binding.textColorButton.action = {
            colorTarget = ColorTarget.TEXT
            showColorPicker()
        }

        // Text size button
        binding.textSizeButton.action = {
            showSizePicker()
        }

        // Bold toggle
        binding.boldSwitch.text = getString(R.string.text_bold)
        binding.boldSwitch.isChecked = currentStyle.isBold
        binding.boldSwitch.action = {
            val newValue = !binding.boldSwitch.isChecked
            binding.boldSwitch.isChecked = newValue
            currentStyle = currentStyle.copy(isBold = newValue)
            saveAndUpdatePreview()
        }

        // Border color button
        binding.borderColorButton.action = {
            colorTarget = ColorTarget.BORDER
            showColorPicker()
        }

        // Reset style button
        binding.resetStyleButton.action = {
            currentStyle = PhraseStyle.DEFAULT
            binding.boldSwitch.isChecked = false
            saveAndUpdatePreview()
        }

        setupColorPicker()
        setupSizePicker()
    }

    private fun setupColorPicker() {
        val dialog = binding.colorPickerDialog

        // Color option click handlers
        mapOf(
            dialog.colorOptionRed to "red",
            dialog.colorOptionBlue to "blue",
            dialog.colorOptionGreen to "green",
            dialog.colorOptionOrange to "orange",
            dialog.colorOptionPurple to "purple",
            dialog.colorOptionCyan to "cyan",
            dialog.colorOptionPink to "pink",
            dialog.colorOptionYellow to "yellow",
            dialog.colorOptionTeal to "teal",
            dialog.colorOptionBrown to "brown",
            dialog.colorOptionLime to "lime",
            dialog.colorOptionIndigo to "indigo",
            dialog.colorOptionAmber to "amber",
            dialog.colorOptionDeepPurple to "deep_purple",
            dialog.colorOptionGrey to "grey",
            dialog.colorOptionBlack to "black",
            dialog.colorOptionWhite to "white",
            dialog.colorOptionLightGray to "light_gray",
            dialog.colorOptionDarkGray to "dark_gray"
        ).forEach { (view, colorName) ->
            view.contentDescription = getString(
                R.string.color_option_description,
                formatColorName(colorName)
            )
        }

        dialog.colorOptionRed.setOnClickListener { selectColor(0xFFE53935.toInt()) }
        dialog.colorOptionBlue.setOnClickListener { selectColor(0xFF1E88E5.toInt()) }
        dialog.colorOptionGreen.setOnClickListener { selectColor(0xFF43A047.toInt()) }
        dialog.colorOptionOrange.setOnClickListener { selectColor(0xFFFB8C00.toInt()) }
        dialog.colorOptionPurple.setOnClickListener { selectColor(0xFF8E24AA.toInt()) }
        dialog.colorOptionCyan.setOnClickListener { selectColor(0xFF00ACC1.toInt()) }
        dialog.colorOptionPink.setOnClickListener { selectColor(0xFFF06292.toInt()) }
        dialog.colorOptionYellow.setOnClickListener { selectColor(0xFFFFEE58.toInt()) }
        dialog.colorOptionTeal.setOnClickListener { selectColor(0xFF26A69A.toInt()) }
        dialog.colorOptionBrown.setOnClickListener { selectColor(0xFF795548.toInt()) }
        dialog.colorOptionLime.setOnClickListener { selectColor(0xFFCDDC39.toInt()) }
        dialog.colorOptionIndigo.setOnClickListener { selectColor(0xFF3F51B5.toInt()) }
        dialog.colorOptionAmber.setOnClickListener { selectColor(0xFFFFC107.toInt()) }
        dialog.colorOptionDeepPurple.setOnClickListener { selectColor(0xFF673AB7.toInt()) }
        dialog.colorOptionGrey.setOnClickListener { selectColor(0xFF78909C.toInt()) }
        dialog.colorOptionBlack.setOnClickListener { selectColor(0xFF000000.toInt()) }
        dialog.colorOptionWhite.setOnClickListener { selectColor(0xFFFFFFFF.toInt()) }
        dialog.colorOptionLightGray.setOnClickListener { selectColor(0xFFD9D9D9.toInt()) }
        dialog.colorOptionDarkGray.setOnClickListener { selectColor(0xFF4A4A4A.toInt()) }

        dialog.colorPickerCancel.action = {
            hideColorPicker()
        }

        dialog.colorPickerContainer.setOnClickListener {
            hideColorPicker()
        }
    }

    private fun setupSizePicker() {
        val dialog = binding.sizePickerDialog

        dialog.sizeOptionSmall.action = { selectSize(12f) }
        dialog.sizeOptionMediumSmall.action = { selectSize(16f) }
        dialog.sizeOptionMedium.action = { selectSize(18f) }
        dialog.sizeOptionMediumLarge.action = { selectSize(22f) }
        dialog.sizeOptionLarge.action = { selectSize(26f) }
        dialog.sizeOptionExtraLarge.action = { selectSize(32f) }
        dialog.sizeOptionHuge.action = { selectSize(40f) }

        dialog.sizePickerCancel.action = {
            hideSizePicker()
        }

        dialog.sizePickerContainer.setOnClickListener {
            hideSizePicker()
        }
    }

    private fun showColorPicker() {
        val title = when (colorTarget) {
            ColorTarget.BACKGROUND -> getString(R.string.background_color)
            ColorTarget.TEXT -> getString(R.string.text_color)
            ColorTarget.BORDER -> getString(R.string.border_color)
        }
        binding.colorPickerDialog.colorPickerTitle.text = title
        binding.colorPickerDialog.colorPickerContainer.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hideColorPicker() {
        binding.colorPickerDialog.colorPickerContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun selectColor(color: Int) {
        currentStyle = when (colorTarget) {
            ColorTarget.BACKGROUND -> currentStyle.copy(backgroundColor = color)
            ColorTarget.TEXT -> currentStyle.copy(textColor = color)
            ColorTarget.BORDER -> currentStyle.copy(borderColor = color, borderWidthDp = 4f)
        }
        hideColorPicker()
        saveAndUpdatePreview()
    }

    private fun showSizePicker() {
        binding.sizePickerDialog.sizePickerContainer.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hideSizePicker() {
        binding.sizePickerDialog.sizePickerContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun selectSize(size: Float) {
        currentStyle = currentStyle.copy(textSizeSp = size)
        hideSizePicker()
        saveAndUpdatePreview()
    }

    private fun saveAndUpdatePreview() {
        viewLifecycleOwner.lifecycleScope.launch {
            // Save to null if default, otherwise save the style
            val styleToSave = if (currentStyle == PhraseStyle.DEFAULT) null else currentStyle
            phrasesUseCase.updatePhraseStyle(phrase.phraseId, styleToSave)
            updatePreview()
        }
    }

    private fun updatePreview() {
        val style = currentStyle

        // Update background
        val backgroundColor = style.effectiveBackgroundColor()
        val cornerRadius = 16f * resources.displayMetrics.density

        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = cornerRadius
            setColor(backgroundColor)
        }
        binding.previewButton.background = drawable

        // Update text color
        binding.previewButton.setTextColor(style.effectiveTextColor())

        // Update text size
        binding.previewButton.textSize = style.effectiveTextSize()

        // Update bold
        binding.previewButton.setTypeface(
            null,
            if (style.isBold) Typeface.BOLD else Typeface.NORMAL
        )

        PhraseTextBubble.apply(binding.previewButton, style)

        // Update button labels to show current values
        updateButtonLabels()
    }

    private fun updateButtonLabels() {
        binding.backgroundColorButton.text = getString(R.string.background_color)
        binding.textColorButton.text = getString(R.string.text_color)
        
        val sizeLabel = when (currentStyle.textSizeSp) {
            12f -> getString(R.string.size_small)
            16f -> getString(R.string.size_medium_small)
            22f -> getString(R.string.size_medium_large)
            26f -> getString(R.string.size_large)
            32f -> getString(R.string.size_extra_large)
            40f -> getString(R.string.size_huge)
            else -> getString(R.string.size_medium)
        }
        binding.textSizeButton.text = "${getString(R.string.text_size)}: $sizeLabel"
        
        binding.borderColorButton.text = getString(R.string.border_color)
    }

    private fun formatColorName(colorName: String): String {
        return colorName.replace('_', ' ')
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
    }

    private fun setMainButtonsEnabled(enabled: Boolean) {
        binding.apply {
            backButton.isEnabled = enabled
            backgroundColorButton.isEnabled = enabled
            textColorButton.isEnabled = enabled
            textSizeButton.isEnabled = enabled
            boldSwitch.isEnabled = enabled
            borderColorButton.isEnabled = enabled
            resetStyleButton.isEnabled = enabled
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}

