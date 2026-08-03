# Android build JDK

Local Android builds pin **JDK 21** (an LTS release). This document records why
and how to set it up, so the next Android-Studio-driven JDK bump does not
require rediscovering the problem.

## Symptom

`flutter build apk --debug`, `flutter run`, and `scripts/dev-run.sh --android`
fail early with a Gradle error whose message is just a JDK version string:

```
FAILURE: Build failed with an exception.
* What went wrong:
25.0.2
java.lang.IllegalArgumentException: 25.0.2
	at org.jetbrains.kotlin.com.intellij.util.lang.JavaVersion.parse(...)
```

## Cause

Flutter runs Gradle with the JDK it resolves in this order: the JDK bundled
with the latest Android Studio (its JBR), then `JAVA_HOME`, then `java` on
`PATH`. The Android Studio JBR is therefore used by default, and recent Android
Studio releases bundle **JDK 25**; the Homebrew `openjdk` formula is now on
**JDK 26**. Setting `JAVA_HOME` alone does **not** help, because the bundled JBR
takes precedence over it — only `flutter config --jdk-dir` overrides the JBR.

The pinned Android toolchain cannot run on JDK 25/26:

- Kotlin Gradle plugin `JavaVersion.parse()` throws on any JDK 25+ version
  string ([KT-83610][]).
- Gradle's own compatibility matrix requires **Gradle 9.1.0+ for JDK 25** and
  **9.4.0+ for JDK 26** ([Gradle compatibility][]); this project pins Gradle
  8.14.

## Why not just upgrade to support JDK 25/26

Making the toolchain accept JDK 25/26 means moving to Gradle 9.x, which forces
Android Gradle Plugin (AGP) 9.x (AGP 8.x does not support Gradle 9). That path
is currently blocked for this app:

- AGP 9.0 removed support for *applying* the Kotlin Gradle Plugin
  (`org.jetbrains.kotlin.android`, which this project uses), and Flutter's
  official guidance is to **not** upgrade to AGP 9 yet
  ([Flutter built-in Kotlin migration][], [flutter/flutter#181383][]).
- Firebase's Flutter plugins are not yet AGP 9 compatible
  ([firebase/flutterfire#17987][]), and this app depends on them.
- The pinned Flutter (3.38.3, 2025-11) predates AGP 9.0 stable (2026-01).

So local builds stay within the **JDK 17–21** range that Flutter and AGP 8.x
support.

## Setup

Install a JDK 21 and point Flutter at it (a one-time, per-machine setting):

```sh
brew install openjdk@21
flutter config --jdk-dir="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
```

Homebrew's `openjdk@21` is a standard OpenJDK build and is equivalent to any
other JDK 21 (including Android Studio's JBR) for command-line Gradle builds;
installing it through Android Studio is not required. Note that `openjdk@21` is
keg-only and is not registered with `/usr/libexec/java_home`, so the JDK home
must be referenced by its explicit path as above.

`scripts/dev-run.sh --android` performs this automatically: if Flutter has no
`--jdk-dir` set (or it points at a JDK newer than 21), the script finds a
JDK 17/21 and configures it, or tells you to `brew install openjdk@21` if none
is present.

## Verify

```sh
cd peppercheck_flutter
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Pass `--flavor dev`; without a flavor, Gradle builds every flavor and Flutter
reports a misleading "failed to produce an .apk file" even though the build
succeeded.

## Trade-off and revisit trigger

This pin must be revisited whenever the default JDK changes — a new machine, or
an Android Studio update that moves the bundled JBR again — because Flutter will
fall back to the (too-new) JBR until `--jdk-dir` is set. Revisit the underlying
constraint when Flutter and the Firebase Flutter plugins support AGP 9 /
built-in Kotlin; at that point the toolchain can move to Gradle 9.x + AGP 9.x
and use the bundled JDK directly.

## References

- [KT-83610][] — `JavaVersion.parse()` fails on Java 25
- [Gradle compatibility][] — JDK ↔ Gradle version matrix
- [Flutter built-in Kotlin migration][]
- [flutter/flutter#181383][] — Flutter plugins should support AGP 9.0
- [firebase/flutterfire#17987][] — Firebase Flutter plugins AGP 9 incompatibility
- Tracking issue: [#484][]

[KT-83610]: https://youtrack.jetbrains.com/issue/KT-83610
[Gradle compatibility]: https://docs.gradle.org/current/userguide/compatibility.html
[Flutter built-in Kotlin migration]: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
[flutter/flutter#181383]: https://github.com/flutter/flutter/issues/181383
[firebase/flutterfire#17987]: https://github.com/firebase/flutterfire/issues/17987
[#484]: https://github.com/cloveclovedev/peppercheck/issues/484
