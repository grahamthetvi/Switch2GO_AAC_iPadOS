package com.switch2connect.aac.basetest.utils

import com.switch2connect.aac.utils.locale.LocaleProvider

class FakeLocaleProvider : LocaleProvider {
    override fun getDefaultLocaleString(): String = "en_US"
}
