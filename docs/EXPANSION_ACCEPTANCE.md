# Popline Park 1.1 expansion — local acceptance

Version **1.1.0 (2)**. The results below describe the tested local acceptance candidate, based on `45624b6010de2c47661c7bdd79014fa5d76b8ced`. The expansion is prepared for publication through GitHub Actions: all three suites run in separate fresh roots, then CI builds and deploys Web. See the deployed `build.json` for the actual public Web commit. CI does not build Android; the APK/AAB hashes below identify the locally verified files. No Google Play submission has been performed.

## Implemented behavior

- Bottom action row: **OLLIE / KICKFLIP / PUSH**, in that order. Steering arrows remain above it; swipe steering and tap-to-ollie still work. Keyboard: arrows/A–D, Space, K/X, P/C, Escape.
- Rails retain the original 3-unit minimum and generate at 3, 6, 9 or 12 units. Both physics and visible GLB length use that span. Entry has 0.25-unit edge tolerance and 0.18-second recent-landing grace. Grinds last until the visible trailing endpoint instead of a fixed timer. Grounded contact costs a heart, subject to the existing hit-protection window.
- OLLIE deliberately pops off a rail. A consumed rail cannot immediately recapture or pay again. Steering off produces a continuous 0.18-second downward drop; it does not count as an obstacle ollie.
- KICKFLIP works once during a jump, with at least 0.08 seconds of flight remaining. Landing earns +75 × combo from flat or +150 × combo from an obstacle ollie. Collisions cancel pending flip credit. A low landing onto a ramp settles the old flip before its next launch.
- Clearing either the low block or small ramp/bump while airborne earns +60 × combo. Small ramps are rotated 180 degrees from the original placement.
- PUSH adds 1.3 m/s per accepted ground stroke, with a 0.22-second cooldown and a +6 m/s boost cap. Coasting sheds 0.65 m/s of boost per second. Hits remove 4 m/s of boost and impose a temporary 1.8 m/s slowdown even at ordinary cruise, recovering at 0.75 m/s per second. Speed never falls below 3.2 m/s.
- The supplied push animation plays only during an accepted push, facing forward for 0.6 seconds, then returns to the sideways standing/coasting pose. Only KICKFLIP spins the board. Airborne and grinding pushes are rejected.
- Slower moving skaters are collision hazards: none on lines 1–2, one on lines 3–5, then increasing frequency. They use the supplied Kenney skaters and boards, with a warm ground marker for readability.

## Neighborhoods and progress

The original 30 line seeds, feature kinds and center positions are preserved; the requested rail/collision/traffic changes apply to them. The campaign now contains **60 levels across six neighborhoods**:

| Lines | Neighborhood |
|---|---|
| 1–10 | Palm Promenade |
| 11–20 | Brickyard Groove |
| 21–30 | Blue Hour Pier |
| 31–40 | Sunset Courts |
| 41–50 | Pinecrest Commons |
| 51–60 | Harbor Lights |

The new neighborhoods have distinct court, pine/rock and dockside scenery plus separate material/sky palettes. Daily rides can use all six districts. Original profile version 1 remains readable; the active simulation extends to snapshot version 2. Legacy midair/grind saves migrate without resetting earned coins, XP, stars, achievements or settings. Finishing the original 30 lines opens line 31.

## Final source checks

Each suite uses its own new process user-data root under `build/expansion-tests/final4/`.

| Suite | Result |
|---|---|
| Rules, persistence and stock-gear completion of all 60 routes | **229 checks, 0 failures** |
| Expansion boundaries, input, animation and compatibility | **154 checks, 0 failures** |
| Lifecycle, full-screen service gates and reward idempotency | **30 checks, 0 failures** |

Total: **413 passing assertions**. Godot loads/type-checks the changed scripts and exports them successfully. `git diff --check` and the existing content validator also pass. Fixtures exercise application callbacks; they do not prove physical touch or native ad dismissal. The original 18 marketing images remain historical 1.0 captures; updated expansion evidence is stored separately.

Tests cover leading/trailing/late rail contact at 30/60/120Hz, all generated rail bounds, no repeat collision/recapture/payout, side-drop continuity, flat/obstacle/ramp flip awards, both bump models, push spam/caps/coasting/hits, zero-boost slowdown/recovery, NPC collisions/density, genuine old-code active snapshots, 30-to-60 progression, midflip restoration, malformed new fields, visible button order, pose transitions, key auto-repeat, multitouch ownership and focus-loss gesture cleanup. Pause, background, Back and ad/consent gates reject all three controls.

## Rendered and browser evidence

The final desktop driver completes actual lines 1, 31, 41 and 60 using the game's action handlers, with flips, pushes, rails, live traffic and saved payouts. The 59 prior unlocks are explicitly seeded test data; the completed rides and their scores are not fabricated. Runtime results: `docs/evidence/expansion/desktop-summary.json`. Frames: `marketing/screenshots/expansion/desktop/` at 540×960. These are desktop viewport captures, not physical-phone evidence.

The local Web build was played in the Chromium in-app browser. Keyboard and visible OLLIE/KICKFLIP/PUSH controls worked. Repeated key/button inputs under pause did not change the ride. Saving and fully reloading during an active flip recovered the same paused 7.9 m/s state; resuming landed the flip for 90 points plus 20 points from two collected tokens. Boost returned to 6.8 m/s cruise. The observed browser warning/error log was empty. After all gameplay edits, the final Web export was reloaded and its push/ollie/kickflip/pause sequence, frozen paused buttons and return-to-park payout passed again with no observed console warnings/errors. See `docs/evidence/expansion/web-verification.json`. The local review was visually checked and all seven images loaded.

## Android evidence

The disposable API 30 x86 emulator uses read-only/no-snapshot mode, host GPU and process-only `GLESDynamicVersion`, with no persistent security or AVD changes. Native evidence is distinct from desktop captures and physical devices.

A real APK upgrade from preserved 1.0 to the ordinary 1.1 test APK retained a synthetic old-format profile with 30 completed levels, 678 coins, 1,234 XP and active run 81 at jump=0.4. The application's actual load/achievement commit advanced sequence 7 to 8 while preserving those fields. See `docs/evidence/expansion/native-upgrade.json`.

The final installed acceptance APK completed lines 1, 31, 41 and 60 with **zero failed runtime checks and zero hits**, scoring 2,350 / 12,285 / 8,450 / 13,875. It exercised 65 landed flips, 163 pushes and 12 rails. After force-stop, the cold profile contained **four rounds, 2,144 coins and no active ride**. The paused-midflip repeated-input and durable-save checks passed. The final seeded third-round transition presented the actual test interstitial. The seeded unlocks and service counter are documented test fixtures; no human completion or natural progression is implied.

See `docs/evidence/expansion/native-summary.json`, `native-runtime.txt`, `native-cold-save.json` and `native-images.json`. Eighteen actual 1080x2022 Android game viewport captures are in `marketing/screenshots/expansion/android-emulator/`; these exclude OS/SDK overlays and are not physical-device screenshots. Sampled final-ride FPS values were 36-55 on this loaded emulator, not a performance benchmark. The final ordinary APK was separately reinstalled and launched with no acceptance driver and no observed script/native fatal errors; see `ordinary-apk-launch.json`. The acceptance APK is an automated debug probe and must not be distributed as the player app. It uses a separate test profile; the ordinary APK has no automated driving.

## Play the update

Public Web: **https://ethannyakabuski.github.io/popline-park/play/**. Review: **https://ethannyakabuski.github.io/popline-park/review/**. The local acceptance build can also be served at **http://127.0.0.1:8767/play/**. If the server has stopped, run `py -3 -m http.server 8767 --bind 127.0.0.1 --directory build/expansion-v1.1/site` from the project folder. Keyboard: arrows/A-D steer, Space ollies, K/X flips, P/C pushes, Escape pauses. The ordinary Android APK below is the player app.

## Local artifacts and identity

- `build/expansion-v1.1/android/popline-park-1.1-debug.aab` — default debug bundle.
- `build/expansion-v1.1/android/popline-park-1.1-test.apk` — ordinary installable debug app.
- `build/expansion-v1.1/android/popline-park-1.1-acceptance.apk` — debug-only automated acceptance.
- `build/expansion-v1.1/site/` — assembled local review and Web build; game is under `play/`.
- `review/index.html` — owner-facing visual expansion review.
- `docs/expansion-build-evidence.json` — exact artifact hashes, base commit and uncommitted source hashes. This is historical pre-publication candidate evidence; deployed Web identity is in `build.json`.

Android package remains `com.ethannyakabuski.poplinepark`, min API 24, target API 36, version code 2. All builds retain sample AdMob mappings and disabled blank Play Games settings. Actual bundle ELF headers verify ARM64, x86 and x86_64 counterparts. Notices and exclusion checks run against the packaged artifacts.

## Remaining limits

Physical-device touch, listening, accessibility, thermal/battery/performance and human difficulty tuning remain owner checks. Automated policies establish playable routes, not ideal difficulty. Native ad dismissal/early-close/no-earned journeys and consent-region variants are not newly certified by this update. Production services, signing and Play submission remain unconfigured/unperformed. Saves remain local; no cloud migration was added. No genuine user save or unrelated project was modified.

Final local source-tree receipt: `b289f5ba385cfd9bd52abbe56f9434e93b9aa82754826885b0aec31b3671fcee`. All final artifact SHA-256 values are in `docs/expansion-build-evidence.json`. Final tests and builds follow the last gameplay edit; only review/documentation/evidence changed afterward. The historical base commit is `45624b6010de2c47661c7bdd79014fa5d76b8ced`; use the deployment metadata for the published expansion commit.
