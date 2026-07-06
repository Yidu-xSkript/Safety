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
            // Name the transport class explicitly. On Android the provider auto-registration
            // (META-INF/javamail.providers) is often lost in APK packaging, so getTransport("smtp")
            // fails with a bare "smtp" / NoSuchProviderException. This bypasses that lookup.
            put("mail.smtp.class", "com.sun.mail.smtp.SMTPTransport")
            put("mail.transport.protocol", "smtp")
            put("mail.smtp.starttls.enable", "true")
            put("mail.smtp.starttls.required", "true")
            put("mail.smtp.host", host)
            put("mail.smtp.port", port.toString())
            // Android/JavaMail hardening: force modern TLS, trust the host cert, and bound the timeouts
            // so a handshake quirk or a stalled connection surfaces as a clear error instead of hanging.
            put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3")
            put("mail.smtp.ssl.trust", host)
            put("mail.smtp.connectiontimeout", "15000")
            put("mail.smtp.timeout", "15000")
            put("mail.smtp.writetimeout", "15000")
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
