package com.switch2connect.aac.utility

import com.switch2connect.aac.utils.DateProvider

class FakeDateProvider : DateProvider {

    var time = 0L

    override fun currentTimeMillis(): Long {
        return time
    }
}