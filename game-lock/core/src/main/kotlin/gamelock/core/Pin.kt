package gamelock.core

import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/** Digits in the PIN that guards turning the blocker off. */
const val PIN_LENGTH = 8

private const val SALT_BYTES = 16
private const val ITERATIONS = 120_000
private const val KEY_BITS = 256

/** The stored form of the PIN. The PIN itself is shown once and never stored. */
class PinHash(val salt: ByteArray, val hash: ByteArray)

fun generatePin(random: SecureRandom = SecureRandom()): String =
    (1..PIN_LENGTH).map { random.nextInt(10) }.joinToString("")

fun hashPin(pin: String, random: SecureRandom = SecureRandom()): PinHash {
    val salt = ByteArray(SALT_BYTES).also(random::nextBytes)
    return PinHash(salt, derive(pin, salt))
}

fun verifyPin(pin: String, stored: PinHash): Boolean =
    MessageDigest.isEqual(derive(pin, stored.salt), stored.hash)

private fun derive(pin: String, salt: ByteArray): ByteArray {
    val spec = PBEKeySpec(pin.toCharArray(), salt, ITERATIONS, KEY_BITS)
    try {
        return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
    } finally {
        spec.clearPassword()
    }
}
