package com.safety.accountability

import java.util.Properties
import javax.mail.Authenticator
import javax.mail.PasswordAuthentication
import javax.mail.Session
import javax.mail.Transport
import javax.mail.internet.InternetAddress
import javax.mail.internet.MimeMessage

class EmailReporter(
    private val host: String, private val port: Int,
    private val username: String, private val appPassword: String, private val from: String,
) : Reporter {
    override fun send(to: String, email: AlertEmail) {
        val props = Properties().apply {
            put("mail.smtp.auth", "true")
            put("mail.smtp.starttls.enable", "true")
            put("mail.smtp.host", host)
            put("mail.smtp.port", port.toString())
        }
        val session = Session.getInstance(props, object : Authenticator() {
            override fun getPasswordAuthentication() = PasswordAuthentication(username, appPassword)
        })
        val fromAddress = InternetAddress(from)
        val toAddress = InternetAddress(to)
        val msg = MimeMessage(session).apply {
            setFrom(fromAddress)
            addRecipient(javax.mail.Message.RecipientType.TO, toAddress)
            subject = email.subject
            setText(email.body)
        }
        Transport.send(msg)
    }
}
