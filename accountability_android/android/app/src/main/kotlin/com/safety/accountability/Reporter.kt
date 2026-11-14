package com.safety.accountability

// The backend seam: TelegramReporter posts to the witness's Telegram channel.
interface Reporter {
    fun send(email: AlertEmail)
}
