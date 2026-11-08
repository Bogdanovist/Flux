package gamelock.core

import java.time.Instant
import java.time.LocalDate

/** A binary lifestyle goal. Missing it adds [penaltyDays] to the ban. */
data class Goal(
    val id: Long,
    val name: String,
    val penaltyDays: Int,
) {
    init {
        require(name.isNotBlank()) { "Goal name must not be blank" }
        require(penaltyDays >= 1) { "Penalty days must be at least 1, was $penaltyDays" }
    }
}

/**
 * One submitted check-in; at most one exists per check-in day [day] (see [checkInDay]). It
 * records which goals the user judged missed since their last check-in. Days with no
 * check-in are never judged later.
 *
 * [penalties] maps each missed goal's id to the penalty days it carried at submission, so a
 * later edit to the goal cannot change history. [banEnd] is the ban end this check-in left in
 * place: it equals the previous ban end, or [submittedAt], when nothing was missed.
 */
data class CheckIn(
    val day: LocalDate,
    val submittedAt: Instant,
    val penalties: Map<Long, Int>,
    val banEnd: Instant,
) {
    val penaltyDays: Int get() = penalties.values.sum()
}

/** What the phone must do when a game comes to the foreground. */
sealed interface LockState {
    /** Games are allowed. */
    data object Unlocked : LockState

    /** The check-in for [day] is outstanding; games are blocked until it is submitted. */
    data class CheckInDue(val day: LocalDate) : LockState

    /** The ban runs until [until]; games are blocked. */
    data class Banned(val until: Instant) : LockState
}
