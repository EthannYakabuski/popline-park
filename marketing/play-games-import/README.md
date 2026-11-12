# Popline Park: Google Play Games achievement import

Import only `popline-park-achievements-google-play.zip`. The archive is flat and contains the two headerless CSVs plus the 20 unchanged 512 x 512 achievement PNGs. The mapping, settings, validation receipt and this guide stay outside the import ZIP.

## Decisions and source

- Names and achievement order come from `game/catalog.json`. Icons are copied byte-for-byte from `marketing/achievements/`.
- Every achievement is **standard**: the game checks its local threshold and `platform/services.gd` calls `unlock_achievement`. Threshold counts are not Play Games incremental steps.
- All are **Revealed**. Points are proposed balancing values, not prior Console settings. Early milestones get fewer points than long-term milestones; each value is a multiple of five and the game total remains at or below 1000. Review them before publishing.
- Default-language English only. No locale overrides are invented.
- Catalog descriptions are retained except numeric thousands separators: `1,000` and `3,000` become `1000` and `3000`. Google disallows commas in names/descriptions even when CSV quoting is possible.

## Import and connect

1. In this game's Play Games Services Achievements page, use Import achievements and select the ZIP, then save as draft. Import only into the intended game; this file is for creating achievements, not blindly re-importing definitions that already exist.
2. Review names, descriptions, points, icons, type and initial state. Type and initial state become fixed after publication.
3. Copy each generated Console achievement ID into the matching key in `platform/config.json`. Use `achievement-id-mapping-and-points.json` as the crosswalk. Blank ID fields are deliberate placeholders, not working IDs.
4. Configure matching numeric game ID, linked Android app/signing fingerprints and testers using `docs/PLATFORM_SETUP.md`. Test actual remote unlocks before publishing.

No Play Console upload, backend configuration, signing, service enablement or app release was performed by this packaging task. Existing app settings are unchanged.

## Rebuild and verify

Run `python tools/build_play_games_import.py` to rebuild, then `python tools/build_play_games_import.py --check` for read-only validation. The builder uses only the Python standard library. It checks text and CSV structure, key and icon matching, PNG dimensions/chunk CRCs, size/count/point limits, ZIP CRCs and exact source bytes. ZIP members use fixed timestamps for reproducibility.

`validation.json` records the archive size/SHA256, catalog hash and validation scope. Passing local checks does not prove Google Play Console accepted the import or real Android services work. No gameplay/runtime source changed, so no new local APK/device acceptance is claimed.

Schema: https://developer.android.com/games/pgs/integrate-achievements#zip-file-guidelines
