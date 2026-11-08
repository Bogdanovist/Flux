package gamelock.core

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class RulesTest {
    private val sydney = ZoneId.of("Australia/Sydney")
    private val sleep = Goal(id = 1, name = "In bed by 23:00", penaltyDays = 2)
    private val steps = Goal(id = 2, name = "10k steps", penaltyDays = 1)
    private val goals = listOf(sleep, steps)

    private fun at(text: String): Instant = LocalDateTime.parse(text).atZone(sydney).toInstant()

    private fun checkIn(history: List<CheckIn>, missed: Set<Long>, now: String): CheckIn =
        submitCheckIn(history, goals, missed, at(now), sydney)

    @Test
    fun `check-in day turns over at 04 00 local time`() {
        assertEquals(LocalDate.parse("2026-11-08"), checkInDay(at("2026-11-09T03:59"), sydney))
        assertEquals(LocalDate.parse("2026-11-09"), checkInDay(at("2026-11-09T04:00"), sydney))
    }

    @Test
    fun `first run has a check-in due at once`() {
        assertEquals(
            LockState.CheckInDue(LocalDate.parse("2026-11-08")),
            lockState(emptyList(), at("2026-11-08T21:00"), sydney),
        )
    }

    @Test
    fun `next check-in falls due at 04 00 and not before`() {
        val history = listOf(checkIn(emptyList(), emptySet(), "2026-11-08T07:00"))
        assertEquals(LockState.Unlocked, lockState(history, at("2026-11-09T03:59"), sydney))
        assertEquals(
            LockState.CheckInDue(LocalDate.parse("2026-11-09")),
            lockState(history, at("2026-11-09T04:00"), sydney),
        )
    }

    @Test
    fun `a missed goal bans from submission for its penalty days`() {
        val record = checkIn(emptyList(), setOf(sleep.id), "2026-11-08T07:15")
        assertEquals(mapOf(sleep.id to 2), record.penalties)
        assertEquals(at("2026-11-10T07:15"), record.banEnd)
        assertEquals(LockState.Banned(at("2026-11-10T07:15")), lockState(listOf(record), at("2026-11-08T07:16"), sydney))
    }

    @Test
    fun `a check-in that is due blocks before a running ban`() {
        val record = checkIn(emptyList(), setOf(sleep.id), "2026-11-08T07:15")
        assertEquals(
            LockState.CheckInDue(LocalDate.parse("2026-11-09")),
            lockState(listOf(record), at("2026-11-09T04:00"), sydney),
        )
    }

    @Test
    fun `games unlock when the ban ends`() {
        val first = checkIn(emptyList(), setOf(steps.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), emptySet(), "2026-11-09T05:00")
        val history = listOf(first, second)
        assertEquals(LockState.Banned(at("2026-11-09T07:00")), lockState(history, at("2026-11-09T06:59"), sydney))
        assertEquals(LockState.Unlocked, lockState(history, at("2026-11-09T07:00"), sydney))
    }

    @Test
    fun `penalties stack on a running ban`() {
        val first = checkIn(emptyList(), setOf(sleep.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), setOf(sleep.id, steps.id), "2026-11-09T08:00")
        // Ban ran to the 10th at 07:00; three more days on top of that.
        assertEquals(at("2026-11-13T07:00"), second.banEnd)
    }

    @Test
    fun `penalties after a ban ends start from submission`() {
        val first = checkIn(emptyList(), setOf(steps.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), setOf(steps.id), "2026-11-10T09:00")
        assertEquals(at("2026-11-11T09:00"), second.banEnd)
    }

    @Test
    fun `a clean check-in leaves a running ban unchanged`() {
        val first = checkIn(emptyList(), setOf(sleep.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), emptySet(), "2026-11-09T07:00")
        assertEquals(first.banEnd, second.banEnd)
        assertEquals(LockState.Banned(first.banEnd), lockState(listOf(first, second), at("2026-11-09T07:01"), sydney))
    }

    @Test
    fun `ban days are calendar days across a daylight-saving change`() {
        // Sydney clocks go forward at 02:00 on 2026-10-04, so that day has 23 hours.
        val record = checkIn(emptyList(), setOf(steps.id), "2026-10-03T07:00")
        assertEquals(at("2026-10-04T07:00"), record.banEnd)
    }

    @Test
    fun `a second check-in on the same day is refused`() {
        val first = checkIn(emptyList(), emptySet(), "2026-11-08T07:00")
        assertFailsWith<IllegalArgumentException> { checkIn(listOf(first), emptySet(), "2026-11-08T20:00") }
    }

    @Test
    fun `an unknown goal id is refused`() {
        assertFailsWith<IllegalArgumentException> { checkIn(emptyList(), setOf(99), "2026-11-08T07:00") }
    }

    @Test
    fun `goals missed anywhere in the running ban are locked`() {
        val first = checkIn(emptyList(), setOf(sleep.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), setOf(steps.id), "2026-11-09T07:00")
        val history = listOf(first, second)
        assertEquals(setOf(sleep.id, steps.id), lockedGoalIds(history, at("2026-11-09T07:01")))
        assertEquals(emptySet(), lockedGoalIds(history, second.banEnd))
    }

    @Test
    fun `goals from an ended ban are not locked by a new ban`() {
        val first = checkIn(emptyList(), setOf(steps.id), "2026-11-08T07:00")
        val second = checkIn(listOf(first), setOf(sleep.id), "2026-11-10T07:00")
        assertEquals(setOf(sleep.id), lockedGoalIds(listOf(first, second), at("2026-11-10T07:01")))
    }

    @Test
    fun `no goals are locked while unbanned`() {
        val record = checkIn(emptyList(), emptySet(), "2026-11-08T07:00")
        assertEquals(emptySet(), lockedGoalIds(listOf(record), at("2026-11-08T07:01")))
    }

    @Test
    fun `a clock set before the last check-in blocks games`() {
        val record = checkIn(emptyList(), emptySet(), "2026-11-08T07:00")
        assertEquals(
            LockState.ClockBehind(record.submittedAt),
            lockState(listOf(record), at("2026-11-08T06:59"), sydney),
        )
    }

    @Test
    fun `a check-in is refused while the clock reads before the last one`() {
        val record = checkIn(emptyList(), emptySet(), "2026-11-08T07:00")
        assertFailsWith<IllegalArgumentException> { checkIn(listOf(record), emptySet(), "2026-11-05T07:00") }
    }

    @Test
    fun `goal penalty must be at least one day`() {
        assertFailsWith<IllegalArgumentException> { Goal(id = 3, name = "x", penaltyDays = 0) }
    }
}
