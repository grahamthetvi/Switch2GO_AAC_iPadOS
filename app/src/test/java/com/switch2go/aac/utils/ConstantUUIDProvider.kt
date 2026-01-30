package com.switch2go.aac.utils

class ConstantUUIDProvider : UUIDProvider {

    var _uuid = "1"

    override fun randomUUIDString(): String = _uuid
}