package gamelock.app.ui

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import gamelock.app.GameLockApp

/**
 * Covers a page that turns the blocker off. The right PIN returns to that page and keeps it
 * open for a few minutes; cancelling goes to the home screen.
 */
class PinGateActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val gate = (application as GameLockApp).pinGate
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                var pin by remember { mutableStateOf("") }
                var wrong by remember { mutableStateOf(false) }
                BackHandler { goHome() }
                Surface(Modifier.fillMaxSize()) {
                    Column(
                        Modifier.safeDrawingPadding().padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text("PIN needed", style = MaterialTheme.typography.headlineMedium)
                        Text("This page can turn Game Lock off. Enter the PIN you wrote down at setup.")
                        OutlinedTextField(
                            value = pin,
                            onValueChange = { pin = it.filter(Char::isDigit); wrong = false },
                            label = { Text("PIN") },
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                            isError = wrong,
                        )
                        if (wrong) Text("Wrong PIN.", color = MaterialTheme.colorScheme.error)
                        Row {
                            Button(onClick = { if (gate.unlock(pin)) finish() else wrong = true }) { Text("Unlock") }
                            TextButton(onClick = { goHome() }) { Text("Cancel") }
                        }
                    }
                }
            }
        }
    }

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }
}
