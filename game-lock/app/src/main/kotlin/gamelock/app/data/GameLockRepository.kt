package gamelock.app.data

import androidx.room.withTransaction
import gamelock.core.AppOverride
import gamelock.core.CheckIn
import gamelock.core.Goal
import gamelock.core.LockState
import gamelock.core.lockState
import gamelock.core.lockedGoalIds
import gamelock.core.submitCheckIn
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** Stores what the rules in gamelock.core compute. Holds no rules of its own. */
class GameLockRepository(private val db: GameLockDatabase) {
    private val dao = db.dao()

    val goals: Flow<List<Goal>> = dao.goals().map { rows -> rows.map { it.toGoal() } }

    val history: Flow<List<CheckIn>> = dao.history().map { rows -> rows.map { it.toCheckIn() } }

    /** Manual include and exclude decisions, keyed by package name. */
    val overrides: Flow<Map<String, AppOverride>> =
        dao.overrides().map { rows -> rows.associate { it.packageName to it.mode } }

    suspend fun overrideFor(packageName: String): AppOverride? = dao.overrideFor(packageName)

    /** Sets the manual decision for [packageName]; null returns the app to its declared category. */
    suspend fun setOverride(packageName: String, override: AppOverride?) {
        if (override == null) dao.deleteOverride(packageName) else dao.upsertOverride(GameOverrideEntity(packageName, override))
    }

    suspend fun lockStateNow(now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): LockState =
        lockState(historyNow(), now, zone)

    suspend fun addGoal(name: String, penaltyDays: Int) {
        val goal = Goal(id = 0, name = name.trim(), penaltyDays = penaltyDays)
        dao.insertGoal(GoalEntity(name = goal.name, penaltyDays = goal.penaltyDays))
    }

    suspend fun updateGoal(goal: Goal) = db.withTransaction {
        checkUnlocked(goal.id)
        dao.updateGoal(GoalEntity(id = goal.id, name = goal.name.trim(), penaltyDays = goal.penaltyDays))
    }

    suspend fun deleteGoal(id: Long) = db.withTransaction {
        checkUnlocked(id)
        dao.deleteGoal(id)
    }

    /** The check-in that [submit] would store, for the summary shown before confirmation. */
    suspend fun preview(missedGoalIds: Set<Long>, now: Instant = Instant.now()): CheckIn =
        submitCheckIn(historyNow(), goalsNow(), missedGoalIds, now, ZoneId.systemDefault())

    suspend fun submit(missedGoalIds: Set<Long>, now: Instant = Instant.now()): CheckIn = db.withTransaction {
        val record = submitCheckIn(historyNow(), goalsNow(), missedGoalIds, now, ZoneId.systemDefault())
        val day = record.day.toString()
        dao.insertCheckIn(CheckInEntity(day, record.submittedAt.toEpochMilli(), record.banEnd.toEpochMilli()))
        dao.insertMissed(record.penalties.map { (goalId, days) -> MissedGoalEntity(day, goalId, days) })
        record
    }

    private suspend fun checkUnlocked(goalId: Long) {
        check(goalId !in lockedGoalIds(historyNow(), Instant.now())) {
            "Goal $goalId contributes to the running ban"
        }
    }

    private suspend fun goalsNow(): List<Goal> = dao.goalsNow().map { it.toGoal() }

    private suspend fun historyNow(): List<CheckIn> = dao.historyNow().map { it.toCheckIn() }
}

private fun GoalEntity.toGoal() = Goal(id = id, name = name, penaltyDays = penaltyDays)

private fun CheckInWithMissed.toCheckIn() = CheckIn(
    day = LocalDate.parse(checkIn.day),
    submittedAt = Instant.ofEpochMilli(checkIn.submittedAtMs),
    penalties = missed.associate { it.goalId to it.penaltyDays },
    banEnd = Instant.ofEpochMilli(checkIn.banEndMs),
)
