package gamelock.core

/** A manual decision on one app, which outranks the category the app declares. */
enum class AppOverride { Include, Exclude }

/** Whether the blocker treats an app as a game. */
fun isBlockable(declaresGame: Boolean, override: AppOverride?): Boolean = when (override) {
    AppOverride.Include -> true
    AppOverride.Exclude -> false
    null -> declaresGame
}
