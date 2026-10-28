# Teleprompter changes

Branch: `codex/teleprompter-pass`; baseline and current HEAD: `38d197dbe6d24d12ab863563f1ac97c5c0ee89bb`.

No new commits could be created: the sandbox makes `.git` read-only, and `git add` returned 128 because `.git/index.lock` could not be created. All changes remain in the working tree. The two patches below are the reviewable substitutes, in dependency order. Do not apply them over this already-modified clone.

| Intended commit | Work product | Test evidence |
|---|---|---|
| `fix(teleprompter): follow the reading cursor and cancel scroll timers` | `verification/01-display-and-timing.patch`: shared measured karaoke view, safe cursor/window math, spoken-line offsets, paged glasses cues, elapsed-time coroutine timer, mark-follow cooldown, wrapped controls, launch/mic error feedback, brighter label and bounded projected surface | Combined offline Gradle suite returned 0. `PromptPlaybackTest`: 8 passed. Existing `WireCompatTest`: 9 passed. Full app Kotlin/Compose sources compiled. `git apply --reverse --check verification/01-display-and-timing.patch` returned 0. Visible behavior remains UNVERIFIED. |
| `feat(teleprompter): bundle eleven original one-tap practice scripts` | `verification/02-sample-pack-and-import.patch`: 11 original native PlayScript JSON assets, catalog entries, one-tap append to a mark, production parser access for tests, asynchronous asset loading with explicit retry/error UI | `ScriptSamplesTest`: 4 passed, exercising the production decoder on all 18 assets, serialization round trips, original-cue preservation and ordered import, demo length/topics, and rejection of malformed/unknown entries. `python3 verification/check_assets.py` returned 0. `git apply --reverse --check verification/02-sample-pack-and-import.patch` returned 0. |

The unit command was run from `android/` with Android Studio JBR 21, task-owned `GRADLE_USER_HOME=android/.gradle/t1-home` (absolute path in the child) and task-owned `TMPDIR`:

```sh
./gradlew :app:testDebugUnitTest --offline --no-daemon --max-workers=2
```

Actual result: `BUILD SUCCESSFUL in 8m 10s`, 21 tests, zero failures/errors. Logs: `verification/gradle-unit.log`, `verification/gradle-unit.exit`, `verification/test-summary.txt`; full HTML report: `android/app/build/reports/tests/testDebugUnitTest/index.html`. The cold build exceeded the few-minute target. Sandbox failures starting the Kotlin daemon were recovered by Gradle's in-process fallback. No second Gradle invocation ran concurrently.

Sample pack: stage monologue, keynote opener, film scene, fictional news read, toast, product demo, lecture, 60-second pitch, accessibility/long-word test, multi-speaker scene, and Alex's Android XR walkthrough. All text is original. The walkthrough contains 369 words and keeps readiness claims conditional; it distinguishes the projected glasses companion from the Aura headset path.

`AUDIT.md` records baseline findings, references, scope, implemented/deferred items, and sandbox deviations. `verification/MANUAL-QA.md` contains exact phone/glasses checks. Durable recovery, automatic disconnect handling, background/battery policy, speech retry/backoff, and font-size controls for glasses remain unimplemented.

Debug packaging also passed after a fresh guard admission: `./gradlew :app:assembleDebug --offline --no-daemon --max-workers=2 -Pkotlin.compiler.execution.strategy=in-process --no-watch-fs` returned 0, `BUILD SUCCESSFUL in 4m 53s`. APK entries contain all 11 samples byte-for-byte.

Understudy Android | T1 teleprompter pass | agilelens.understudy | `/Users/alex/Archives/overnight-androidxr-2026-10/out/t1-teleprompter/wt/android/app/build/outputs/apk/debug/app-debug.apk` | build 39 (0.36)

Receipt: `verification/artifact.json`. This is an assembled debug artifact, not an installed or visually accepted demo. `./gradlew --stop` returned 0 (`No Gradle daemons are running.`).
