package com.switch2go.aac.customviews

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.Switch2GOSwitchLayoutBinding

class Switch2GOSwitch @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : Switch2GOConstraintLayout(context, attrs, defStyle){
    var binding: Switch2GOSwitchLayoutBinding
    var isChecked: Boolean
        set(value) {
            binding.toggleSwitch.isChecked = value
        }
        get() = binding.toggleSwitch.isChecked

    var text: String = ""
        set(value) {
            binding.toggleTitle.text = value
        }

    init{
        binding = Switch2GOSwitchLayoutBinding.inflate(LayoutInflater.from(context), this)
        binding.root.setBackgroundResource(R.drawable.settings_group_background)
    }

}