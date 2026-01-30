package com.switch2go.aac.utils

enum class Switch2GOEnvironmentType {
    PRODUCTION,
    TESTING
}


interface Switch2GOEnvironment {
    val environmentType: Switch2GOEnvironmentType
}

class Switch2GOEnvironmentImpl : Switch2GOEnvironment {
    override val environmentType: Switch2GOEnvironmentType = Switch2GOEnvironmentType.PRODUCTION
}