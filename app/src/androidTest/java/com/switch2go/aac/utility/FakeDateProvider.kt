package com.switch2go.aac.utility

import com.switch2go.aac.utils.DateProvider

class FakeDateProvider : DateProvider {

    var time = 0L

    override fun currentTimeMillis(): Long {
        return time
    }
}