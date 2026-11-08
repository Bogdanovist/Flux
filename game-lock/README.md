# Game Lock

A personal Android app that blocks every game on the phone until a morning check-in is
done, and bans games for a set number of days for each lifestyle goal missed since the last
check-in. Sideloaded onto one phone, never distributed.

The design doc is the Claude Doc "Game Lock: Design Doc"
(https://claude.ai/artifact/UEurZdF43P2Bn36YyjYv3B).

## Layout

- `core/` — the check-in and ban rules as plain Kotlin, in a Gradle build of its own, so
  its tests run without a device or the Android SDK.
- `app/` — the Android app. It stores what the `core` functions return (Room), blocks games
  through an Accessibility Service, puts a PIN in front of the pages that turn that service
  off, and posts a 07:00 reminder while the check-in is due.

## Test the rules

```bash
./gradlew -p core test
```

## Build and install

Needs the Android SDK (`ANDROID_HOME`, or `sdk.dir` in `local.properties`).

```bash
./gradlew :app:assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

After the first install, write down the PIN the app shows once, allow notifications, then
turn on Game Lock under Settings → Accessibility → Installed apps.
