package gamelock.app.ui

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import gamelock.app.GameLockApp

enum class Screen { Home, Goals, CheckIn, Blocked }

class MainActivity : ComponentActivity() {
    private var screen by mutableStateOf(Screen.Home)

    private val askNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        screen = intent.screen()
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
        val repository = (application as GameLockApp).repository
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                GameLockUi(repository, screen, onNavigate = { screen = it })
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        screen = intent.screen()
    }

    companion object {
        private const val EXTRA_SCREEN = "screen"

        fun intent(context: Context, screen: Screen): Intent =
            Intent(context, MainActivity::class.java).putExtra(EXTRA_SCREEN, screen.name)

        private fun Intent.screen(): Screen =
            getStringExtra(EXTRA_SCREEN)?.let { Screen.valueOf(it) } ?: Screen.Home
    }
}
