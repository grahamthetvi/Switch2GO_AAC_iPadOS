package com.switch2go.aac.utils

class FakeDateProvider : DateProvider {

    var _currentTimeMillis = 0L

    override fun currentTimeMillis(): Long = _currentTimeMillis
}