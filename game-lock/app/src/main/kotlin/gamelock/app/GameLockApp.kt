package gamelock.app

import android.app.Application
import gamelock.app.data.GameLockDatabase
import gamelock.app.data.GameLockRepository
import gamelock.app.reminder.Reminder

class GameLockApp : Application() {
    val repository: GameLockRepository by lazy { GameLockRepository(GameLockDatabase.open(this)) }
    val pinGate: PinGate by lazy { PinGate(this) }

    override fun onCreate() {
        super.onCreate()
        Reminder.createChannel(this)
        Reminder.scheduleNext(this)
    }
}
