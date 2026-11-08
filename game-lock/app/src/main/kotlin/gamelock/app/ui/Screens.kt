package gamelock.app.ui

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import gamelock.app.LockAccessibilityService
import gamelock.app.data.GameLockRepository
import gamelock.core.CheckIn
import gamelock.core.Goal
import gamelock.core.LockState
import gamelock.core.lockState
import gamelock.core.lockedGoalIds
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun GameLockUi(repository: GameLockRepository, screen: Screen, onNavigate: (Screen) -> Unit) {
    val goals by repository.goals.collectAsState(initial = null)
    val history by repository.history.collectAsState(initial = null)
    val now = rememberNow()
    val zone = ZoneId.systemDefault()

    BackHandler(enabled = screen != Screen.Home) { onNavigate(Screen.Home) }

    Surface(Modifier.fillMaxSize()) {
        Column(
            Modifier.safeDrawingPadding().padding(16.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val loadedGoals = goals
            val loadedHistory = history
            if (loadedGoals == null || loadedHistory == null) return@Column
            val state = lockState(loadedHistory, now, zone)
            when (screen) {
                Screen.Home -> HomeScreen(state, now, onNavigate)
                Screen.Goals -> GoalsScreen(repository, loadedGoals, lockedGoalIds(loadedHistory, now), onNavigate)
                Screen.CheckIn -> CheckInScreen(repository, loadedGoals, state, onNavigate)
                Screen.Blocked -> BlockedScreen(state, now, onNavigate)
            }
        }
    }
}

@Composable
private fun HomeScreen(state: LockState, now: Instant, onNavigate: (Screen) -> Unit) {
    Text("Game Lock", style = MaterialTheme.typography.headlineMedium)
    when (state) {
        LockState.Unlocked -> Text("Unlocked", style = MaterialTheme.typography.titleLarge)
        is LockState.CheckInDue -> {
            Text("Check-in due", style = MaterialTheme.typography.titleLarge)
            Button(onClick = { onNavigate(Screen.CheckIn) }) { Text("Check in") }
        }
        is LockState.Banned -> {
            Text("Banned until ${formatInstant(state.until)}", style = MaterialTheme.typography.titleLarge)
            Text(formatRemaining(Duration.between(now, state.until)))
        }
    }
    OutlinedButton(onClick = { onNavigate(Screen.Goals) }) { Text("Goals") }
    AccessibilityStatus()
}

/** The blocker works only while its Accessibility Service is on, so Home says when it is off. */
@Composable
private fun AccessibilityStatus() {
    val context = LocalContext.current
    val now = rememberNow()
    val enabled = remember(now.epochSecond / 5) { isServiceEnabled(context) }
    if (enabled) return
    Spacer(Modifier.padding(4.dp))
    Text("The blocker is off. Turn on Game Lock in Accessibility settings.", color = MaterialTheme.colorScheme.error)
    Button(onClick = { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }) {
        Text("Open Accessibility settings")
    }
}

private fun isServiceEnabled(context: Context): Boolean {
    val ours = ComponentName(context, LockAccessibilityService::class.java).flattenToString()
    val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
    return enabled?.split(':')?.any { it.equals(ours, ignoreCase = true) } == true
}

@Composable
private fun GoalsScreen(
    repository: GameLockRepository,
    goals: List<Goal>,
    locked: Set<Long>,
    onNavigate: (Screen) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var editing by remember { mutableStateOf<Goal?>(null) }
    var name by remember { mutableStateOf("") }
    var days by remember { mutableStateOf("1") }

    Text("Goals", style = MaterialTheme.typography.headlineMedium)
    goals.forEach { goal ->
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(goal.name, style = MaterialTheme.typography.titleMedium)
                Text("${goal.penaltyDays} day${if (goal.penaltyDays == 1) "" else "s"} if missed")
                if (goal.id in locked) Text("Locked: this goal adds to the running ban.")
            }
            val unlocked = goal.id !in locked
            TextButton(enabled = unlocked, onClick = {
                editing = goal
                name = goal.name
                days = goal.penaltyDays.toString()
            }) { Text("Edit") }
            TextButton(enabled = unlocked, onClick = { scope.launch { repository.deleteGoal(goal.id) } }) {
                Text("Delete")
            }
        }
    }

    Text(if (editing == null) "Add goal" else "Edit goal", style = MaterialTheme.typography.titleMedium)
    OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, singleLine = true)
    OutlinedTextField(
        value = days,
        onValueChange = { days = it.filter(Char::isDigit) },
        label = { Text("Penalty days") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
    )
    val penalty = days.toIntOrNull()
    val valid = name.isNotBlank() && penalty != null && penalty >= 1
    Row {
        Button(enabled = valid, onClick = {
            val current = editing
            scope.launch {
                if (current == null) {
                    repository.addGoal(name, penalty!!)
                } else {
                    repository.updateGoal(current.copy(name = name, penaltyDays = penalty!!))
                }
                editing = null
                name = ""
                days = "1"
            }
        }) { Text(if (editing == null) "Add" else "Save") }
        if (editing != null) {
            Spacer(Modifier.width(8.dp))
            TextButton(onClick = { editing = null; name = ""; days = "1" }) { Text("Cancel") }
        }
    }
    OutlinedButton(onClick = { onNavigate(Screen.Home) }) { Text("Back") }
}

@Composable
private fun CheckInScreen(
    repository: GameLockRepository,
    goals: List<Goal>,
    state: LockState,
    onNavigate: (Screen) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var missed by remember { mutableStateOf(emptySet<Long>()) }
    var preview by remember { mutableStateOf<CheckIn?>(null) }

    Text("Check-in", style = MaterialTheme.typography.headlineMedium)
    if (state !is LockState.CheckInDue) {
        Text("Today's check-in is done. The next one opens at 04:00.")
        OutlinedButton(onClick = { onNavigate(Screen.Home) }) { Text("Back") }
        return
    }
    Text("Since your last check-in, did you meet each goal?")
    goals.forEach { goal ->
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(goal.name, Modifier.weight(1f))
            Text(if (goal.id in missed) "Not met" else "Met")
            Spacer(Modifier.width(8.dp))
            Switch(
                checked = goal.id !in missed,
                onCheckedChange = { met ->
                    missed = if (met) missed - goal.id else missed + goal.id
                    preview = null
                },
            )
        }
    }

    val summary = preview
    if (summary == null) {
        Button(onClick = { scope.launch { preview = repository.preview(missed) } }) { Text("Submit") }
    } else {
        Text(
            if (summary.penaltyDays == 0) "No days added." else "${summary.penaltyDays} days added.",
            style = MaterialTheme.typography.titleMedium,
        )
        if (summary.banEnd > summary.submittedAt) Text("Ban ends ${formatInstant(summary.banEnd)}.")
        Button(onClick = {
            scope.launch {
                repository.submit(missed)
                onNavigate(Screen.Home)
            }
        }) { Text("Confirm") }
        TextButton(onClick = { preview = null }) { Text("Change answers") }
    }
}

@Composable
private fun BlockedScreen(state: LockState, now: Instant, onNavigate: (Screen) -> Unit) {
    Text("Games are blocked", style = MaterialTheme.typography.headlineMedium)
    if (state is LockState.Banned) {
        Text("Ban ends ${formatInstant(state.until)}.", style = MaterialTheme.typography.titleLarge)
        Text(formatRemaining(Duration.between(now, state.until)))
    }
    Button(onClick = { onNavigate(Screen.Home) }) { Text("OK") }
}

@Composable
private fun rememberNow(): Instant {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000)
            now = Instant.now()
        }
    }
    return now
}

private val BAN_END_FORMAT = DateTimeFormatter.ofPattern("EEE d MMM, HH:mm")

private fun formatInstant(instant: Instant): String = BAN_END_FORMAT.format(instant.atZone(ZoneId.systemDefault()))

private fun formatRemaining(left: Duration): String {
    if (left.isNegative || left.isZero) return ""
    return "${left.toDays()}d ${left.toHoursPart()}h ${left.toMinutesPart()}m ${left.toSecondsPart()}s left"
}
