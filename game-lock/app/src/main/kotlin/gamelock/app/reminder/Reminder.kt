package gamelock.app.reminder

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import gamelock.app.GameLockApp
import gamelock.app.R
import gamelock.app.ui.MainActivity
import gamelock.app.ui.Screen
import gamelock.core.LockState
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** A daily on-device reminder at 07:00 local time, posted only while the check-in is due. */
object Reminder {
    val AT: LocalTime = LocalTime.of(7, 0)
    private const val CHANNEL = "check-in-reminder"
    private const val NOTIFICATION_ID = 1

    // An inexact alarm needs no special permission; a few minutes late is fine for a reminder.
    private const val WINDOW_MS = 10 * 60 * 1000L

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL,
            context.getString(R.string.reminder_channel),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun scheduleNext(context: Context, now: ZonedDateTime = ZonedDateTime.now(ZoneId.systemDefault())) {
        val today = now.with(AT)
        val next = if (now < today) today else today.plusDays(1)
        val alarm = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        context.getSystemService(AlarmManager::class.java)
            .setWindow(AlarmManager.RTC_WAKEUP, next.toInstant().toEpochMilli(), WINDOW_MS, alarm)
    }

    fun post(context: Context) {
        if (context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            MainActivity.intent(context, Screen.CheckIn),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = android.app.Notification.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle(context.getString(R.string.reminder_title))
            .setContentText(context.getString(R.string.reminder_text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminder.scheduleNext(context)
        val pending = goAsync()
        val repository = (context.applicationContext as GameLockApp).repository
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (repository.lockStateNow() is LockState.CheckInDue) Reminder.post(context)
            } finally {
                pending.finish()
            }
        }
    }
}

/** Alarms do not survive a restart, so the next reminder is set again at boot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminder.scheduleNext(context)
    }
}
