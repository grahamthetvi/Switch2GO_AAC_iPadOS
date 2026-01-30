package com.switch2go.aac.utils.locale

import java.util.Locale

class JavaLocaleProvider : LocaleProvider {
    override fun getDefaultLocaleString(): String =
        Locale.getDefault().toString()
}