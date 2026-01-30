package com.switch2go.aac.utils

import java.util.UUID

class RandomUUIDProvider : UUIDProvider {
    override fun randomUUIDString(): String {
        return UUID.randomUUID().toString()
    }
}