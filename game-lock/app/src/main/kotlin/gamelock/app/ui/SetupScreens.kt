package gamelock.app.ui

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import gamelock.app.data.GameLockRepository
import gamelock.app.declaresGame
import gamelock.core.AppOverride
import gamelock.core.generatePin
import gamelock.core.isBlockable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.compose.runtime.rememberCoroutineScope

/**
 * Shows the new PIN once. Only its hash is stored, and only after the user confirms, so a PIN
 * that was never written down is never stored.
 */
@Composable
fun PinSetupScreen(onSaved: (String) -> Unit) {
    val pin = rememberSaveable { generatePin() }
    var written by remember { mutableStateOf(false) }

    Text("Your PIN", style = MaterialTheme.typography.headlineMedium)
    Text("The PIN is needed to turn Game Lock off or uninstall it. It does not end a ban.")
    Text(pin, style = MaterialTheme.typography.displayMedium, fontFamily = FontFamily.Monospace)
    Text("Write it down and keep it away from the phone. It will not be shown again.")
    Row(verticalAlignment = Alignment.CenterVertically) {
        Checkbox(checked = written, onCheckedChange = { written = it })
        Text("I have written it down")
    }
    Button(enabled = written, onClick = { onSaved(pin) }) { Text("Continue") }
}

private data class InstalledApp(val packageName: String, val label: String, val declaresGame: Boolean)

/** Every launchable app, with a switch that blocks it or not. Blocked apps come first. */
@Composable
fun GamesScreen(repository: GameLockRepository, onNavigate: (Screen) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val overrides by repository.overrides.collectAsState(initial = emptyMap())
    var apps by remember { mutableStateOf<List<InstalledApp>?>(null) }
    LaunchedEffect(Unit) { apps = withContext(Dispatchers.IO) { launchableApps(context) } }

    Text("Games", style = MaterialTheme.typography.headlineMedium)
    Text("Apps that declare themselves games are blocked. Switch any app to change that.")
    val loaded = apps ?: return
    loaded
        .sortedByDescending { isBlockable(it.declaresGame, overrides[it.packageName]) }
        .forEach { app ->
            val override = overrides[app.packageName]
            val blocked = isBlockable(app.declaresGame, override)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(app.label, style = MaterialTheme.typography.titleMedium)
                    Text(
                        when (override) {
                            AppOverride.Include -> "Added by hand"
                            AppOverride.Exclude -> "Removed by hand"
                            null -> if (app.declaresGame) "Declares itself a game" else "Not a game"
                        },
                    )
                }
                Switch(
                    checked = blocked,
                    onCheckedChange = { block ->
                        val next = when {
                            block == app.declaresGame -> null
                            block -> AppOverride.Include
                            else -> AppOverride.Exclude
                        }
                        scope.launch { repository.setOverride(app.packageName, next) }
                    },
                )
            }
        }
    OutlinedButton(onClick = { onNavigate(Screen.Home) }) { Text("Back") }
}

private fun launchableApps(context: Context): List<InstalledApp> {
    val pm = context.packageManager
    val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    return pm.queryIntentActivities(launcher, PackageManager.ResolveInfoFlags.of(0))
        .map { it.activityInfo.applicationInfo }
        .distinctBy { it.packageName }
        .filter { it.packageName != context.packageName }
        .map { InstalledApp(it.packageName, pm.getApplicationLabel(it).toString(), declaresGame(pm, it.packageName)) }
        .sortedBy { it.label.lowercase() }
}
