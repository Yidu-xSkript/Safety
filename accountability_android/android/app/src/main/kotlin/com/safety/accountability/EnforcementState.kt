package com.safety.accountability
object EnforcementState {
    @Volatile var dohUrl: String? = null
    @Volatile var witnessEmail: String? = null
    @Volatile var reporter: Reporter? = null
}
