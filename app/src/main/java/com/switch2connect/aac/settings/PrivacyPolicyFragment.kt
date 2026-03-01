package com.switch2connect.aac.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.navigation.fragment.findNavController
import com.switch2connect.aac.BaseFragment
import com.switch2connect.aac.BindingInflater
import com.switch2connect.aac.databinding.FragmentPrivacyPolicyBinding

class PrivacyPolicyFragment : BaseFragment<FragmentPrivacyPolicyBinding>() {

    override val bindingInflater: BindingInflater<FragmentPrivacyPolicyBinding> = FragmentPrivacyPolicyBinding::inflate

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

        binding.privacyPolicyBackButton.action = {
            findNavController().popBackStack()
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}
