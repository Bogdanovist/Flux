package gamelock.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class GamesAndPinTest {
    @Test
    fun `an override outranks the declared category`() {
        assertTrue(isBlockable(declaresGame = false, override = AppOverride.Include))
        assertFalse(isBlockable(declaresGame = true, override = AppOverride.Exclude))
    }

    @Test
    fun `with no override the declared category decides`() {
        assertTrue(isBlockable(declaresGame = true, override = null))
        assertFalse(isBlockable(declaresGame = false, override = null))
    }

    @Test
    fun `a pin has eight digits`() {
        val pin = generatePin()
        assertEquals(PIN_LENGTH, pin.length)
        assertTrue(pin.all(Char::isDigit))
    }

    @Test
    fun `only the right pin verifies`() {
        val stored = hashPin("12345678")
        assertTrue(verifyPin("12345678", stored))
        assertFalse(verifyPin("12345679", stored))
    }

    @Test
    fun `the same pin hashes differently under a new salt`() {
        assertFalse(hashPin("12345678").hash.contentEquals(hashPin("12345678").hash))
    }
}
