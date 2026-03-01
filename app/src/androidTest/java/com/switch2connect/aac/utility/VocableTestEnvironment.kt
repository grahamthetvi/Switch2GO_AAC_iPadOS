package com.switch2connect.aac.utility

import com.switch2connect.aac.utils.VocableEnvironment
import com.switch2connect.aac.utils.VocableEnvironmentType

class VocableTestEnvironment: VocableEnvironment {
    override val environmentType = VocableEnvironmentType.TESTING
}