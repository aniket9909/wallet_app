package com.aniket.ewallet

import android.telephony.SmsMessage
import android.util.Log
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets

/**
 * Extracts readable text from normal text SMS and binary/data SMS PDUs.
 */
object SmsPayloadDecoder {
    private const val TAG = "SmsPayloadDecoder"

    fun extractText(smsMessage: SmsMessage?): String {
        if (smsMessage == null) return ""

        val body = smsMessage.messageBody?.trim().orEmpty()
        if (body.isNotEmpty()) return body

        val display = try {
            smsMessage.displayMessageBody?.trim().orEmpty()
        } catch (_: Exception) {
            ""
        }
        if (display.isNotEmpty()) return display

        val userData = try {
            smsMessage.userData
        } catch (_: Exception) {
            null
        } ?: return ""

        if (userData.isEmpty()) return ""

        val decoded = decodeUserData(userData)
        Log.d(TAG, "Decoded data SMS (${userData.size} bytes): ${decoded.take(120)}")
        return decoded
    }

    private fun decodeUserData(bytes: ByteArray): String {
        // Prefer encodings that produce printable bank-alert text.
        val candidates = listOf(
            decode(bytes, StandardCharsets.UTF_8),
            decode(bytes, Charset.forName("UTF-16")),
            decode(bytes, Charset.forName("UTF-16BE")),
            decode(bytes, Charset.forName("UTF-16LE")),
            decode(bytes, StandardCharsets.ISO_8859_1),
            decodeGsm7BitLoose(bytes),
        )

        val best = candidates
            .filter { it.isNotBlank() }
            .maxByOrNull { scoreReadable(it) }
            ?: ""

        return best.trim()
    }

    private fun decode(bytes: ByteArray, charset: Charset): String {
        return try {
            String(bytes, charset).trim()
        } catch (_: Exception) {
            ""
        }
    }

    /** Best-effort GSM-7 unpack for short binary payloads. */
    private fun decodeGsm7BitLoose(bytes: ByteArray): String {
        return try {
            val out = StringBuilder()
            var carry = 0
            var carryBits = 0
            for (b in bytes) {
                val value = b.toInt() and 0xFF
                val septet = ((value shl carryBits) or carry) and 0x7F
                out.append(gsm7ToChar(septet))
                carry = value shr (7 - carryBits)
                carryBits++
                if (carryBits == 7) {
                    out.append(gsm7ToChar(carry and 0x7F))
                    carry = 0
                    carryBits = 0
                }
            }
            out.toString().trim()
        } catch (_: Exception) {
            ""
        }
    }

    private fun gsm7ToChar(code: Int): Char {
        // Basic GSM 7-bit default alphabet (partial; enough for bank keywords/amounts).
        val table = "@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ ÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
            "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
        return if (code in table.indices) table[code] else ' '
    }

    private fun scoreReadable(text: String): Int {
        if (text.isEmpty()) return -1
        var score = 0
        for (c in text) {
            when {
                c.isLetterOrDigit() -> score += 2
                c == ' ' || c == '.' || c == ',' || c == '/' || c == ':' || c == '-' -> score += 1
                c == '₹' -> score += 3
                c < ' ' && c != '\n' && c != '\r' && c != '\t' -> score -= 4
                else -> score += 0
            }
        }
        val lower = text.lowercase()
        if (lower.contains("inr") || lower.contains("rs") || text.contains('₹')) score += 20
        if (lower.contains("credit") || lower.contains("debit") ||
            lower.contains("credited") || lower.contains("debited")
        ) {
            score += 25
        }
        return score
    }
}
