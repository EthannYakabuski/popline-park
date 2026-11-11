# Iteration record

- Initial import: two untyped pointer deltas and two inferred payout integers failed GDScript parsing. Explicit types fixed the errors.
- First rules fixture: 91 checks, 21 failures. Cold-load comparison compared integer versus JSON floating-point representations; normalized semantic comparison now passes. Twenty later-route failures exposed an overly simplistic jump-everything test strategy. A stock-gear dodge-and-grind policy now finishes all 30 routes. This is automated feasibility evidence, not a human difficulty assessment.
- Corrupt JSON initially emitted engine errors during expected recovery. Explicit JSON parser error handling now recovers quietly from the validated backup.
- Static review: malformed active-run fields could reach typed game state; complete snapshot validation now rejects invalid types, ranges and event dictionaries. Negative/fractional counters are rejected.
- Static review: pause controls could still steer/jump; all gameplay button actions now share the pause and fullscreen-ad gate. Restoring a ride reapplies its district. An explicit end-and-bank action was added.
- Earned continue storage failure: a failed commit now restores the full pre-revive state and retains an in-memory earned retry. It never claims durable retention if storage itself is unavailable.
- First genuine viewport captures: scene was overexposed. Ambient sky contribution was removed, materials/lighting were balanced, a far shore was added and all three district palettes were re-captured and inspected.
- Geometry review: the supplied board and rails have their long axis on Z. Rolling geometry now follows travel; the board turns only for the boardslide pose, and the rider's local-X foot separation is aligned with the board.
- First Android build: blank Play Games configuration emitted metadata referencing a missing string. The exporter now omits that metadata when disabled, while retaining actual native libraries and configured-ID behavior.
- Browser play: default font lacked menu/play/heart glyphs. Controls use portable text and hearts use a licensed Kenney texture. Final profile captures were regenerated.
- Additional corrupt-save cases: schema objects/arrays and fractional metrics are rejected without conversion errors; an impossible generator distance cannot cause a huge catch-up loop.

Current rules pass: 152 assertions, 0 failures. UI lifecycle fixture: 26 checks, 0 failures. Artifact-bound native/Web evidence and outstanding checks are recorded in ACCEPTANCE.md; source fixtures are not production-service evidence.
