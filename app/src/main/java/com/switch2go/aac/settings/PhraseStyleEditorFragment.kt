package com.switch2go.aac.settings

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.navigation.fragment.navArgs
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.IPhrasesUseCase
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentPhraseStyleEditorBinding
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.room.PhraseStyle
import com.switch2go.aac.utils.ILocalizedResourceUtility
import com.switch2go.aac.utils.PhraseTextBubble
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
    
    companion object {
        private const val DEFAULT_BORDER_WIDTH_DP = 6f
        private const val BORDER_WIDTH_NONE_DP = 0f
        private const val BORDER_WIDTH_THIN_DP = 6f
        private const val BORDER_WIDTH_MEDIUM_DP = 10f
        private const val BORDER_WIDTH_THICK_DP = 14f
        private const val BORDER_WIDTH_XL_DP = 20f
        private const val BORDER_WIDTH_XXL_DP = 28f
    }

    // Track which color property is being edited
    private enum class ColorTarget { BACKGROUND, TEXT, BORDER }
    private var colorTarget: ColorTarget = ColorTarget.BACKGROUND
    
    private val imagePickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            requireContext().contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            selectImage(uri.toString())
        }
    }

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
            showColorPicker(ColorTarget.BACKGROUND)
        }

        // Text color button
        binding.textColorButton.action = {
            showColorPicker(ColorTarget.TEXT)
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
            showColorPicker(ColorTarget.BORDER)
        }
        
        // Border thickness button
        binding.borderWidthButton.action = {
            showBorderWidthPicker()
        }

        // Image button
        binding.imageButton.action = {
            showImagePicker()
        }

        // Reset style button
        binding.resetStyleButton.action = {
            currentStyle = PhraseStyle.DEFAULT
            binding.boldSwitch.isChecked = false
            saveAndUpdatePreview()
        }

        setupColorPicker()
        setupSizePicker()
        setupBorderWidthPicker()
        setupImagePicker()
        setupEmojiKeyboard()
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

    private fun setupImagePicker() {
        val dialog = binding.imagePickerDialog

        // Add image option
        dialog.imageOptionAddImage.action = {
            hideImagePicker()
            imagePickerLauncher.launch(arrayOf("image/*"))
        }

        // Emoji keyboard option
        dialog.imageOptionEmojiKeyboard.action = {
            hideImagePicker()
            showEmojiKeyboard()
        }

        // None option - clear image
        dialog.imageOptionNone.action = { selectImage(null) }
        
        // Image options - map to drawable resource names
        dialog.imageOptionHappy.setOnClickListener { selectImage("ic_symbol_happy") }
        dialog.imageOptionSad.setOnClickListener { selectImage("ic_symbol_sad") }
        dialog.imageOptionYes.setOnClickListener { selectImage("ic_symbol_yes") }
        dialog.imageOptionNo.setOnClickListener { selectImage("ic_symbol_no") }
        dialog.imageOptionHelp.setOnClickListener { selectImage("ic_symbol_help") }
        dialog.imageOptionFood.setOnClickListener { selectImage("ic_symbol_food") }
        dialog.imageOptionDrink.setOnClickListener { selectImage("ic_symbol_drink") }
        dialog.imageOptionPain.setOnClickListener { selectImage("ic_symbol_pain") }
        dialog.imageOptionBathroom.setOnClickListener { selectImage("ic_symbol_bathroom") }
        dialog.imageOptionSleep.setOnClickListener { selectImage("ic_symbol_sleep") }
        dialog.imageOptionLove.setOnClickListener { selectImage("ic_symbol_love") }
        dialog.imageOptionHome.setOnClickListener { selectImage("ic_symbol_home") }
        dialog.imageOptionPerson.setOnClickListener { selectImage("ic_symbol_person") }
        dialog.imageOptionQuestion.setOnClickListener { selectImage("ic_symbol_question") }
        
        dialog.imagePickerCancel.action = {
            hideImagePicker()
        }

        dialog.imagePickerContainer.setOnClickListener {
            hideImagePicker()
        }
    }

    private fun setupEmojiKeyboard() {
        val dialog = binding.emojiKeyboardDialog
        
        dialog.emojiKeyboardConfirm.action = {
            val emojiText = dialog.emojiInput.text?.toString()?.trim().orEmpty()
            if (emojiText.isNotEmpty()) {
                selectImage("${PhraseStyle.EMOJI_PREFIX}$emojiText")
            } else {
                hideEmojiKeyboard()
            }
        }
        
        dialog.emojiKeyboardCancel.action = {
            hideEmojiKeyboard()
        }
        
        dialog.emojiKeyboardContainer.setOnClickListener {
            hideEmojiKeyboard()
        }
    }

    private fun showEmojiKeyboard() {
        val dialog = binding.emojiKeyboardDialog
        dialog.emojiInput.setText("")
        dialog.emojiKeyboardContainer.isVisible = true
        setMainButtonsEnabled(false)
        dialog.emojiInput.requestFocus()
        val imm = requireContext().getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showSoftInput(dialog.emojiInput, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun hideEmojiKeyboard() {
        val dialog = binding.emojiKeyboardDialog
        val imm = requireContext().getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(dialog.emojiInput.windowToken, 0)
        dialog.emojiKeyboardContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun showImagePicker() {
        binding.imagePickerDialog.imagePickerContainer.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hideImagePicker() {
        binding.imagePickerDialog.imagePickerContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun selectImage(imageRef: String?) {
        currentStyle = currentStyle.copy(imageRef = imageRef)
        hideImagePicker()
        hideEmojiKeyboard()
        saveAndUpdatePreview()
    }

    private fun showColorPicker(target: ColorTarget) {
        colorTarget = target
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
            ColorTarget.BORDER -> {
                val width = currentStyle.borderWidthDp ?: DEFAULT_BORDER_WIDTH_DP
                val normalizedWidth = if (width <= 0f) DEFAULT_BORDER_WIDTH_DP else width
                currentStyle.copy(borderColor = color, borderWidthDp = normalizedWidth)
            }
        }
        hideColorPicker()
        saveAndUpdatePreview()
    }

    private fun setupBorderWidthPicker() {
        val dialog = binding.borderWidthPickerDialog
        
        dialog.borderWidthOptionNone.action = { selectBorderWidth(BORDER_WIDTH_NONE_DP) }
        dialog.borderWidthOptionThin.action = { selectBorderWidth(BORDER_WIDTH_THIN_DP) }
        dialog.borderWidthOptionMedium.action = { selectBorderWidth(BORDER_WIDTH_MEDIUM_DP) }
        dialog.borderWidthOptionThick.action = { selectBorderWidth(BORDER_WIDTH_THICK_DP) }
        dialog.borderWidthOptionXl.action = { selectBorderWidth(BORDER_WIDTH_XL_DP) }
        dialog.borderWidthOptionXxl.action = { selectBorderWidth(BORDER_WIDTH_XXL_DP) }
        
        dialog.borderWidthPickerCancel.action = {
            hideBorderWidthPicker()
        }
        
        dialog.borderWidthPickerContainer.setOnClickListener {
            hideBorderWidthPicker()
        }
    }

    private fun showBorderWidthPicker() {
        binding.borderWidthPickerDialog.borderWidthPickerContainer.isVisible = true
        setMainButtonsEnabled(false)
    }

    private fun hideBorderWidthPicker() {
        binding.borderWidthPickerDialog.borderWidthPickerContainer.isVisible = false
        setMainButtonsEnabled(true)
    }

    private fun selectBorderWidth(widthDp: Float) {
        currentStyle = currentStyle.copy(borderWidthDp = widthDp)
        hideBorderWidthPicker()
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
        
        val borderWidthLabel = when (currentStyle.borderWidthDp) {
            BORDER_WIDTH_NONE_DP -> getString(R.string.border_thickness_none)
            BORDER_WIDTH_THIN_DP -> getString(R.string.border_thickness_thin)
            BORDER_WIDTH_MEDIUM_DP -> getString(R.string.border_thickness_medium)
            BORDER_WIDTH_THICK_DP -> getString(R.string.border_thickness_thick)
            BORDER_WIDTH_XL_DP -> getString(R.string.border_thickness_xl)
            BORDER_WIDTH_XXL_DP -> getString(R.string.border_thickness_xxl)
            null -> getString(R.string.border_thickness_none)
            else -> getString(R.string.border_thickness_custom, currentStyle.borderWidthDp?.toInt() ?: 0)
        }
        binding.borderWidthButton.text = "${getString(R.string.border_thickness)}: $borderWidthLabel"
        
        // Update image button label
        val emoji = PhraseStyle.extractEmoji(currentStyle.imageRef)
        val imageLabel = when {
            emoji != null -> getString(R.string.image_emoji, emoji)
            currentStyle.imageRef.isNullOrBlank() -> getString(R.string.none)
            currentStyle.imageRef?.startsWith("content://") == true ||
                currentStyle.imageRef?.startsWith("file://") == true ->
                getString(R.string.image_custom)
            else -> when (currentStyle.imageRef) {
            "ic_symbol_happy" -> getString(R.string.image_happy)
            "ic_symbol_sad" -> getString(R.string.image_sad)
            "ic_symbol_yes" -> getString(R.string.image_yes)
            "ic_symbol_no" -> getString(R.string.image_no)
            "ic_symbol_help" -> getString(R.string.image_help)
            "ic_symbol_food" -> getString(R.string.image_food)
            "ic_symbol_drink" -> getString(R.string.image_drink)
            "ic_symbol_pain" -> getString(R.string.image_pain)
            "ic_symbol_bathroom" -> getString(R.string.image_bathroom)
            "ic_symbol_sleep" -> getString(R.string.image_sleep)
            "ic_symbol_love" -> getString(R.string.image_love)
            "ic_symbol_home" -> getString(R.string.image_home)
            "ic_symbol_person" -> getString(R.string.image_person)
            "ic_symbol_question" -> getString(R.string.image_question)
            else -> currentStyle.imageRef ?: getString(R.string.none)
            }
        }
        binding.imageButton.text = "${getString(R.string.phrase_image)}: $imageLabel"
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
            borderWidthButton.isEnabled = enabled
            imageButton.isEnabled = enabled
            resetStyleButton.isEnabled = enabled
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}

