# Game Lock

A personal Android app that blocks every game on the phone until a morning check-in is
done, and bans games for a set number of days for each lifestyle goal missed the day before.
Sideloaded onto one phone, never distributed.

The design doc is the Claude Doc "Game Lock: Design Doc"
(https://claude.ai/artifact/UEurZdF43P2Bn36YyjYv3B).

## Layout

- `core/` — the check-in and ban rules as plain Kotlin with no Android dependency, so the
  JVM tests prove them without a device or the Android SDK. The app module calls these
  functions and stores what they return.

## Test

```bash
./gradlew :core:test
```
