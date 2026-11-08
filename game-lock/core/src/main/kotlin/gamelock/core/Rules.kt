package gamelock.core

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/** Local time at which each day's check-in opens. */
val CHECK_IN_OPENS: LocalTime = LocalTime.of(4, 0)

/**
 * The check-in day that [now] falls in. A check-in day runs from 04:00 local time to 04:00
 * the next morning, so 02:00 on the 9th belongs to the check-in day of the 8th.
 */
fun checkInDay(now: Instant, zone: ZoneId): LocalDate {
    val local = now.atZone(zone)
    val date = local.toLocalDate()
    return if (local.toLocalTime() < CHECK_IN_OPENS) date.minusDays(1) else date
}

/** The ban end in force after the latest check-in, or null before the first check-in. */
fun banEnd(history: List<CheckIn>): Instant? = history.maxByOrNull { it.submittedAt }?.banEnd

fun lockState(history: List<CheckIn>, now: Instant, zone: ZoneId): LockState {
    val today = checkInDay(now, zone)
    if (history.none { it.day == today }) return LockState.CheckInDue(today)
    val end = banEnd(history)
    return if (end != null && now < end) LockState.Banned(end) else LockState.Unlocked
}

/**
 * Builds the check-in for the current check-in day. The result is both the summary shown
 * before confirmation and the record to store on confirmation.
 *
 * Penalties stack: each missed goal's days are added on top of a ban still running at [now],
 * or on top of [now] when no ban runs. Days are calendar days in [zone], so a ban that starts
 * at 07:15 ends at 07:15 local time across a daylight-saving change.
 */
fun submitCheckIn(
    history: List<CheckIn>,
    goals: List<Goal>,
    missedGoalIds: Set<Long>,
    now: Instant,
    zone: ZoneId,
): CheckIn {
    val day = checkInDay(now, zone)
    require(history.none { it.day == day }) { "The check-in for $day is already submitted" }
    val goalsById = goals.associateBy { it.id }
    val unknown = missedGoalIds - goalsById.keys
    require(unknown.isEmpty()) { "Unknown goal ids: $unknown" }

    val penalties = missedGoalIds.associateWith { goalsById.getValue(it).penaltyDays }
    val runningEnd = banEnd(history)?.takeIf { it > now }
    val base = runningEnd ?: now
    val days = penalties.values.sum().toLong()
    val end = if (days == 0L) base else base.atZone(zone).plusDays(days).toInstant()
    return CheckIn(day = day, submittedAt = now, penalties = penalties, banEnd = end)
}

/**
 * Goals that cannot be edited or deleted because they contribute to the ban running at [now].
 *
 * A ban is one unbroken run of blocked time. Every check-in submitted while an earlier ban was
 * still running extends that same ban, so every goal missed in that run contributes to it.
 */
fun lockedGoalIds(history: List<CheckIn>, now: Instant): Set<Long> {
    val ordered = history.sortedBy { it.submittedAt }
    val last = ordered.lastOrNull() ?: return emptySet()
    if (now >= last.banEnd) return emptySet()

    var start = ordered.lastIndex
    while (start > 0 && ordered[start].submittedAt < ordered[start - 1].banEnd) start--
    return ordered.subList(start, ordered.size).flatMapTo(mutableSetOf()) { it.penalties.keys }
}
