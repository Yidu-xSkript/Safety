package com.safety.accountability
object EnforcementState {
    @Volatile var dohUrl: String? = null
    @Volatile var witnessEmail: String? = null
    @Volatile var reporter: Reporter? = null
    @Volatile var nextDnsApiKey: String? = null      // for phone-side porn-attempt polling
    @Volatile var nextDnsProfileId: String? = null
}
