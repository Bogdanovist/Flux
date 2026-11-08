package gamelock.app

import android.content.Context
import android.os.SystemClock
import gamelock.core.PinHash
import gamelock.core.hashPin
import gamelock.core.verifyPin
import java.util.Base64

/**
 * Guards the pages that turn the blocker off. Holds the PIN's salted hash, and the short
 * window after a correct PIN in which those pages stay open.
 */
class PinGate(context: Context) {
    private val prefs = context.getSharedPreferences("pin", Context.MODE_PRIVATE)

    /** Elapsed-realtime millis until which the guarded pages stay open; survives no restart. */
    @Volatile
    private var openUntil = 0L

    val isSet: Boolean get() = prefs.contains(KEY_HASH)

    /** Stores [pin] as a salted hash. Called once, after the user has written the PIN down. */
    fun set(pin: String) {
        check(!isSet) { "The PIN is already set" }
        val stored = hashPin(pin)
        val encoder = Base64.getEncoder()
        prefs.edit()
            .putString(KEY_SALT, encoder.encodeToString(stored.salt))
            .putString(KEY_HASH, encoder.encodeToString(stored.hash))
            .apply()
    }

    /** True and opens the guarded pages for [OPEN_FOR_MS] when [pin] is right. */
    fun unlock(pin: String): Boolean {
        val stored = stored() ?: return false
        if (!verifyPin(pin, stored)) return false
        openUntil = SystemClock.elapsedRealtime() + OPEN_FOR_MS
        return true
    }

    val isOpen: Boolean get() = SystemClock.elapsedRealtime() < openUntil

    private fun stored(): PinHash? {
        val decoder = Base64.getDecoder()
        val salt = prefs.getString(KEY_SALT, null) ?: return null
        val hash = prefs.getString(KEY_HASH, null) ?: return null
        return PinHash(decoder.decode(salt), decoder.decode(hash))
    }

    private companion object {
        const val KEY_SALT = "salt"
        const val KEY_HASH = "hash"
        const val OPEN_FOR_MS = 5 * 60 * 1000L
    }
}
