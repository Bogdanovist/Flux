package gamelock.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import gamelock.app.ui.MainActivity
import gamelock.app.ui.Screen
import gamelock.core.LockState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Blocks a game when it comes to the foreground while a check-in is due or a ban runs.
 * The game test reads the installed app's category on each event, so a game installed
 * later is covered with no rescan.
 */
class LockAccessibilityService : AccessibilityService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName || !isGame(packageManager, pkg)) return

        val repository = (application as GameLockApp).repository
        scope.launch {
            when (val state = repository.lockStateNow()) {
                is LockState.CheckInDue -> open(Screen.CheckIn)
                is LockState.Banned -> {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    open(Screen.Blocked)
                }
                LockState.Unlocked -> Unit
            }
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun open(screen: Screen) {
        startActivity(MainActivity.intent(this, screen).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

fun isGame(pm: PackageManager, pkg: String): Boolean {
    val info = try {
        pm.getApplicationInfo(pkg, 0)
    } catch (e: PackageManager.NameNotFoundException) {
        return false
    }
    @Suppress("DEPRECATION") // Older games set only the legacy flag.
    val legacyFlag = info.flags and ApplicationInfo.FLAG_IS_GAME != 0
    return info.category == ApplicationInfo.CATEGORY_GAME || legacyFlag
}
