# Acceptance — Popline Park 1.0.0 (1)

This is a complete first-pass game and publishing package for review, with test-configured Android services. Production service configuration and physical-device/human acceptance remain open. Nothing has been submitted to Google Play.

## Exact artifacts

`build/android/popline-park-debug.aab` is the default Android bundle. `popline-park-test.apk` is the ordinary installable debug app. `popline-park-acceptance.apk` is a **separate debug-only automated acceptance build** with the `acceptance` feature; do not distribute it to players. `build/site/play/` contains the single-threaded Web export; `build/site/` includes the landing page, review and publishing package.

SHA-256, sizes, runtime source-file hashes and source commit are recorded in [build-evidence.json](build-evidence.json). Later documentation-only commits do not imply a different tested binary. The repository's CI run and deployed `build.json` identify the actual remote Web source commit. Local build outputs and genuine test profiles are intentionally not committed.

Engine: Godot **4.5.1.stable.official.f62fdbde1**, Compatibility. Android package `com.ethannyakabuski.poplinepark`, min API 24, target API 36. The built test APK manifest was inspected with Android `aapt`; its compile SDK is 35 and target SDK is 36. Actual native ELF headers include ARM64, x86 and x86_64; every x86 library has its matching x86_64 counterpart. The AdMob manifest app ID is Google's sample ID, not a copied production mapping.

## Passing source checks

- **152 rules/persistence assertions, zero failures.** All 30 campaign routes finish with the baseline stock-gear dodge/grind policy. Daily seeds/claims, seven-day gifts, backward-clock denial, gear limits, rewards, duplicate payouts, schema/field corruption, validated backup recovery and storage failure are covered. This automated policy demonstrates feasibility; it is not a human difficulty rating.
- **26 UI/lifecycle assertions, zero failures.** Repeated controls under pause, background and Back, all full-screen-ad state gates, explicit resume, mode switching, district restoration, failed-save earned entitlement retry, duplicate callback denial and unavailable-ad no-reward behavior.
- Content validation: store copy limits, 20 achievements, 3 boards, paired 512px/128px icons, 512px app icon, 1024×500 feature image, 18 required capture dimensions and notices.

The callback fixtures deliberately exercise application logic. They are not evidence that a native SDK awarded or dismissed an ad.

## Actual rendered and native runs

The real desktop runtime completed a fresh-profile ride at each profile: 1,155 points, four rails, 102 coins and 85 XP. Six implemented views per phone/7-inch/10-inch profile plus extra district previews were captured and visually checked. See [SCREENSHOTS.md](SCREENSHOTS.md) for precise provenance. Lighting, model orientation and cross-platform glyph issues were found and corrected during this pass.

Android used the installed **Pixel_3a_API_30_x86** AVD, temporary `-read-only -no-snapshot-load -no-snapshot-save` mode, 1536MB RAM, two cores, host GPU, and process-only `-feature GLESDynamicVersion`. The existing persistent AVD and genuine user saves were not modified. The emulator reports GLES 3.0 using the NVIDIA RTX A400 translator. No historical readiness claim is substituted for the current app run.

The ordinary APK installed and launched successfully. The final native acceptance APK completed and saved a ride: score 1,155, four rails, 102 coins, one banked round; cold-reading its profile recovered that progress. A sampled result frame reported 47fps in this emulator, which is not a device performance guarantee. The real AdMob singleton initialized, the banner reported a native height of 137px with 152 reference units reserved, and the native rewarded unit became available. Play Games stayed intentionally disabled with blank backend mappings. Native viewport images exclude Android SDK overlays and system bars.

The driver then followed actual obstacle lanes until failure and requested the real sample rewarded unit. Native callbacks recorded **rewarded_presented** and **rewarded_earned**. After force-stopping the process, its saved active run still had `continued=true`, `hearts=2`, `done=false`: the genuine earned continue was durable. A separate disposable emulator fixture seeded a prior round count of two; one real completed ride then produced **interstitial_presented** at the third-round transition. This proves the native presentation path, not three freshly played rounds or dismissal. Filtered excerpts and the cold-save check are under `docs/evidence/`; no ad creative, account data or full device log is published.

## Browser acceptance

The Web export was opened in the connected Chromium in-app browser. An actual ride accepted steering and ollie input; Escape paused it. The save-and-return action and a full reload recovered the paused ride at **50 points and five tokens**. Unsupported font symbols were found on that first browser pass and replaced by portable controls/Kenney heart textures. Web uses local saves and platform-unavailable messages, without fake ad rewards. Browser persistence remains subject to the user's site-storage settings.

## Open acceptance and publisher configuration

- Physical phone/tablet touch ergonomics, sound listening, thermal/battery/performance, accessibility and human difficulty assessment remain unverified.
- Native interstitial/rewarded dismissal, early-close/no-earned user journeys and consent-region variations require hands-on validation. One genuine native earned-and-persisted path passes; application pause and duplicate-reward gates also pass fixtures.
- Supply production AdMob/PGS IDs, release signing/fingerprints, backend resources, test accounts, policy/support/contact URLs and store questionnaires. Validate account switching and real remote achievement/leaderboard submission afterward.
- Saves are local, with a validated backup; cloud save/migration is not implemented. If storage fails while an ad reward is earned, an in-memory retry is retained, but killing the process while storage remains unavailable cannot guarantee that entitlement.

See [PLATFORM_SETUP.md](PLATFORM_SETUP.md) for exact configuration fields and [BUG_LOG.md](BUG_LOG.md) for the iteration history.
