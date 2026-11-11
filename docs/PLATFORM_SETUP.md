# Android services and release configuration

The actual Poing AdMob and Godot Play Games plugin scripts and Android libraries are included. Missing services preserve local play. This repository does not include signing keys, production IDs or backend credentials.

## AdMob

`project.godot` → `[admob] general/android/app_id` is the operative manifest setting. It contains Google's sample app ID `ca-app-pub-3940256099942544~3347511713`. The similarly named value in `platform/config.json` is documentation/configuration context; changing JSON alone does not change the Android manifest.

`platform/config.json` starts with `admob.test_mode=true` and blank production unit mappings. Debug builds always select Google sample banner, interstitial and rewarded units from `platform/services.gd`. For a configured release, update the manifest app ID, set `test_mode=false`, and fill `banner_unit_id`, `interstitial_unit_id`, `rewarded_unit_id`. Keep sample IDs for development validation.

Banner: reserved bottom area on home and results only. Interstitial: each third banked ride at the stopped transition. Rewarded: after failure, one optional earned two-heart continue with three seconds of protection. The full-screen request, native display and consent/privacy form states block gameplay. After interruption, the player explicitly resumes. Unsupported or unavailable ads never grant rewards. Duplicate earned callbacks cannot repeat a continue. If storage fails during earning, the pre-continue state is restored and an in-memory retry is retained; a process kill while storage is unavailable cannot guarantee retention.

Consent uses the plugin's UMP update/form flow. Requests remain paused unless consent is obtained or not required. The owner must configure the actual audience, consent messages, region testing, privacy policy and Data safety disclosures. The current under-age-of-consent flag is false; this does not choose a target audience or replace store questionnaires.

## Play Games

Set the Android export option `godot_play_game_services/game_id` and `platform/config.json` → `play_games.game_id` to the same real numeric project ID, then enable `play_games.enabled`. Fill the 20 achievement and 3 leaderboard IDs using `marketing/achievement-metadata.json`. All current mappings are blank and disabled. Configure package `com.ethannyakabuski.poplinepark`, the release/test signing fingerprints, linked application, testers and published backend resources in the owner's consoles.

The adapter journals earned local unlocks and scores, retries unavailable connections, and only acknowledges native success. Local saves are device/browser-local; cloud save and cross-device migration are not implemented. Sign-in, account changes, cancellation and real remote submission need owner backend testing.

## Local plugin patches

- AdMob setting registration keeps the sample Android app ID explicit in project settings instead of hiding it as an initial default. Existing no-auto-install iOS editor behavior is preserved; Android/Web are the targets.
- Play Games exporter omits APP_ID metadata when its ID is blank, avoiding a missing string-resource reference in intentionally disabled builds. With a configured ID it generates the resource and metadata normally.

Keep upstream MIT notices and review these small patches when updating plugins.

## Release work owned by the publisher

Supply release signing outside the repository; create a release AAB; verify exact production mapping and consent behavior on physical devices; complete store contact, policy, content rating, target audience and Data safety; review copy/art/screenshots; run human difficulty, accessibility, battery/thermal, background/Back and real ad closure checks. No Play publication is performed by this project workflow.
