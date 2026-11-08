package gamelock.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import gamelock.app.ui.MainActivity
import gamelock.app.ui.PinGateActivity
import gamelock.app.ui.Screen
import gamelock.core.LockState
import gamelock.core.isBlockable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Blocks a game when it comes to the foreground while a check-in is due or a ban runs.
 * Also puts the PIN gate in front of the pages that turn the blocker off. The game test reads the app's declared category on each event, so a game installed later
 * is covered with no rescan.
 */
class LockAccessibilityService : AccessibilityService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val app get() = application as GameLockApp

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        if (pkg in GUARDED_PACKAGES) {
            if (app.pinGate.isSet && !app.pinGate.isOpen && showsGuardedPage(pkg)) {
                startActivity(Intent(this, PinGateActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            return
        }
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val declaresGame = declaresGame(packageManager, pkg)
        scope.launch {
            if (!isBlockable(declaresGame, app.repository.overrideFor(pkg))) return@launch
            when (app.repository.lockStateNow()) {
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

    /**
     * True when the window shows this app's Accessibility page, its App info page, or an
     * uninstall prompt for it. Matches on the English labels the One UI pages show.
     */
    private fun showsGuardedPage(pkg: String): Boolean {
        val root = rootInActiveWindow ?: return false
        if (!root.hasText(getString(R.string.app_name))) return false
        if (pkg in INSTALLER_PACKAGES) return true
        return root.hasText(getString(R.string.accessibility_description)) ||
            root.hasText("Force stop") ||
            root.hasText("Uninstall")
    }

    private fun AccessibilityNodeInfo.hasText(text: String): Boolean =
        findAccessibilityNodeInfosByText(text).isNotEmpty()

    private companion object {
        val INSTALLER_PACKAGES = setOf("com.google.android.packageinstaller", "com.android.packageinstaller")

        /** Settings apps and installers whose pages can turn the blocker off. */
        val GUARDED_PACKAGES = setOf("com.android.settings", "com.samsung.accessibility") + INSTALLER_PACKAGES
    }
}

/** Whether the app declares itself a game, by category or by the legacy flag. */
fun declaresGame(pm: PackageManager, pkg: String): Boolean {
    val info = try {
        pm.getApplicationInfo(pkg, 0)
    } catch (e: PackageManager.NameNotFoundException) {
        return false
    }
    @Suppress("DEPRECATION") // Older games set only the legacy flag.
    val legacyFlag = info.flags and ApplicationInfo.FLAG_IS_GAME != 0
    return info.category == ApplicationInfo.CATEGORY_GAME || legacyFlag
}
