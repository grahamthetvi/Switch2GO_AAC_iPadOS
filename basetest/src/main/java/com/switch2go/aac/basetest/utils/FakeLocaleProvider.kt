package com.switch2go.aac.basetest.utils

import com.switch2go.aac.utils.locale.LocaleProvider

class FakeLocaleProvider : LocaleProvider {
    override fun getDefaultLocaleString(): String = "en_US"
}
