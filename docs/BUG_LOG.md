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
- Final browser settings check: advertising privacy produced no visible fallback message on Web. Settings now display platform service notices, with a regression assertion. The native acceptance driver also stops cleanly if its next scripted action is blocked by an actual full-screen ad.

Current rules pass: 152 assertions, 0 failures. UI lifecycle fixture has 27 checks, including the final privacy-message regression. Artifact-bound native/Web evidence and outstanding checks are recorded in ACCEPTANCE.md; source fixtures are not production-service evidence.


## Local 1.1 expansion iteration

- Replaced one-point rail contacts and fixed-duration grinds with matching 3Ã¢â‚¬â€œ12 unit visible intervals and distance-based exits. Grounded rail entry now damages once; used rails cannot recapture a pop-off.
- Added collision slowdown below cruise as well as loss of boost. A zero-boost hit now always costs momentum.
- Independent review caught a discontinuous upward jump when steering off a rail. Side exits now drop continuously for 0.18 seconds and cannot earn an obstacle-ollie flip bonus.
- The first expanded baseline driver lost 11 later routes because its old single-obstacle policy did not anticipate moving skaters. A swept lateral path policy reduced this to zero failures across all 60 routes; this is feasibility evidence, not a human difficulty rating.
- One new slowdown assertion initially let its short fixture finish before recovery; extending the isolated fixture corrected the test.
- The first rendered test paused when another test process interrupted focus and timed out on line 60. The debug-only driver now explicitly resumes after those interruptions; the player-facing game still requires explicit resume.
- Captures wait for a subsequent simulation/render frame so newly requested tricks are actually visible in the recorded pixels.

- First native expansion capture attempt used the wrong case for the Android feature flag, directing debug captures to a read-only resource path. Corrected to `android`; all final exports and native acceptance are rebuilt after this instrumentation fix. Player gameplay and save upgrade succeeded during that attempt, but failed captures are not accepted as final evidence.

- A late flip landing onto a ramp now settles its pending flip award before the ramp launches the next jump, instead of silently clearing it. A dedicated boundary regression covers this case.
