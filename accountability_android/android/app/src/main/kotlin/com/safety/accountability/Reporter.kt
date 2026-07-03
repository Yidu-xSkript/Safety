package com.safety.accountability

// The backend seam: v1 is EmailReporter; a future HttpReporter posts to a server instead.
interface Reporter {
    fun send(to: String, email: AlertEmail)
}
