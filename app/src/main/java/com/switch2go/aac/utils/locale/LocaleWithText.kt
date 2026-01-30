package com.switch2go.aac.utils.locale

import java.util.Locale


typealias LocaleWithText = Pair<Locale, String>
fun LocaleWithText.locale() = first
fun LocaleWithText.text() = second