package com.switch2connect.aac.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.navigation.fragment.findNavController
import com.switch2connect.aac.BaseFragment
import com.switch2connect.aac.BindingInflater
import com.switch2connect.aac.databinding.FragmentThirdPartyNoticesBinding

class ThirdPartyNoticesFragment : BaseFragment<FragmentThirdPartyNoticesBinding>() {

    override val bindingInflater: BindingInflater<FragmentThirdPartyNoticesBinding> =
        FragmentThirdPartyNoticesBinding::inflate

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.thirdPartyNoticesBackButton.action = {
            findNavController().popBackStack()
        }

        if (binding.thirdPartyNoticesText.text.isNullOrEmpty()) {
            val text = requireContext().assets.open("third_party_notices.txt")
                .bufferedReader()
                .use { it.readText() }
            binding.thirdPartyNoticesText.text = text
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}
