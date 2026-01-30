package com.switch2go.aac

import com.switch2go.aac.utils.UUIDProvider

class FakeUUIDProvider : UUIDProvider {

    private var _uuid = 1

    override fun randomUUIDString(): String {
        return _uuid++.toString()
    }
}