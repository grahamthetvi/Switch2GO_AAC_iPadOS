package com.switch2connect.aac

import com.switch2connect.aac.utils.UUIDProvider

class FakeUUIDProvider : UUIDProvider {

    private var _uuid = 1

    override fun randomUUIDString(): String {
        return _uuid++.toString()
    }
}