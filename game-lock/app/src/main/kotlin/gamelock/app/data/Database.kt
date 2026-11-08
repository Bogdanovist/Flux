package gamelock.app.data

import android.content.Context
import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Relation
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction
import androidx.room.Update
import androidx.room.Upsert
import gamelock.core.AppOverride
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "goals")
data class GoalEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    @ColumnInfo(name = "penalty_days") val penaltyDays: Int,
)

/** One row per check-in day. [day] is an ISO-8601 date, so the key enforces one check-in a day. */
@Entity(tableName = "check_ins")
data class CheckInEntity(
    @PrimaryKey val day: String,
    @ColumnInfo(name = "submitted_at_ms") val submittedAtMs: Long,
    @ColumnInfo(name = "ban_end_ms") val banEndMs: Long,
)

/**
 * One row per goal missed in a check-in. [goalId] has no foreign key to goals, because a goal
 * may be deleted once its ban ends and its history must stay.
 */
@Entity(
    tableName = "missed_goals",
    primaryKeys = ["check_in_day", "goal_id"],
    foreignKeys = [
        ForeignKey(
            entity = CheckInEntity::class,
            parentColumns = ["day"],
            childColumns = ["check_in_day"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class MissedGoalEntity(
    @ColumnInfo(name = "check_in_day") val checkInDay: String,
    @ColumnInfo(name = "goal_id") val goalId: Long,
    @ColumnInfo(name = "penalty_days") val penaltyDays: Int,
)

/** One row per app added to or removed from the game list by hand; an app is in one list at most. */
@Entity(tableName = "game_overrides")
data class GameOverrideEntity(
    @PrimaryKey @ColumnInfo(name = "package_name") val packageName: String,
    val mode: AppOverride,
)

data class CheckInWithMissed(
    @Embedded val checkIn: CheckInEntity,
    @Relation(parentColumn = "day", entityColumn = "check_in_day")
    val missed: List<MissedGoalEntity>,
)

@Dao
interface GameLockDao {
    @Query("SELECT * FROM goals ORDER BY id")
    fun goals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals ORDER BY id")
    suspend fun goalsNow(): List<GoalEntity>

    @Insert
    suspend fun insertGoal(goal: GoalEntity): Long

    @Update
    suspend fun updateGoal(goal: GoalEntity)

    @Query("DELETE FROM goals WHERE id = :id")
    suspend fun deleteGoal(id: Long)

    @Transaction
    @Query("SELECT * FROM check_ins ORDER BY submitted_at_ms")
    fun history(): Flow<List<CheckInWithMissed>>

    @Transaction
    @Query("SELECT * FROM check_ins ORDER BY submitted_at_ms")
    suspend fun historyNow(): List<CheckInWithMissed>

    @Insert
    suspend fun insertCheckIn(checkIn: CheckInEntity)

    @Insert
    suspend fun insertMissed(missed: List<MissedGoalEntity>)

    @Query("SELECT * FROM game_overrides ORDER BY package_name")
    fun overrides(): Flow<List<GameOverrideEntity>>

    @Query("SELECT mode FROM game_overrides WHERE package_name = :packageName")
    suspend fun overrideFor(packageName: String): AppOverride?

    @Upsert
    suspend fun upsertOverride(override: GameOverrideEntity)

    @Query("DELETE FROM game_overrides WHERE package_name = :packageName")
    suspend fun deleteOverride(packageName: String)
}

@Database(
    entities = [GoalEntity::class, CheckInEntity::class, MissedGoalEntity::class, GameOverrideEntity::class],
    version = 1,
    exportSchema = true,
)
abstract class GameLockDatabase : RoomDatabase() {
    abstract fun dao(): GameLockDao

    companion object {
        fun open(context: Context): GameLockDatabase =
            Room.databaseBuilder(context, GameLockDatabase::class.java, "game-lock.db").build()
    }
}
