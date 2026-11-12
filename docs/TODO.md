# Kamerton — TODO

Mockups: [mockups/index.html](mockups/index.html) (open in a browser; v10 is the implemented layout)

## Done: window sizes and the headstock (v9, v10, v11 C)

- [x] Two states: every panel in full when the window has room; otherwise the Detector stays and Instrument and Noise gate shrink to one-line panels
- [x] Side column or one column, whichever gives the bigger meter; the Detector always first; scrolling only as the last resort
- [x] The small panels' buttons open the full panel in a popup window that may reach past the tuner window, closed by a click outside or Esc
- [x] Floating Noise gate shows the level on the meter's top row
- [x] Narrow Detector panel: Needle / Strobe / Bar show icons only
- [x] Les Paul style headstock (outline traced from a photo, smoothed): black face, cream binding, bell cover, chrome bushings; fixed proportions
- [x] Tuner keys are wide chrome buttons with note, string number and frequency; the chosen one tinted with the selection color, a bigger ✓ badge when tuned
- [x] Qt 6.8 or newer, for popup windows

## Done: panels and the VU meter (v5 D, v7)

- [x] No toolbar: instrument, tuning and A4 in the **Instrument** panel; display style buttons and the main menu in the **Detector** panel
- [x] **Noise gate** in its own panel under the Instrument panel, level in its heading
- [x] Needle / Strobe / Bar and Pluck / Sine / Organ as joined, equal-width buttons with drawn icons
- [x] The "x of N tuned" button keeps its normal look; a ✓ badge replaces its reset icon when every string is tuned, the reset icon is back on hover
- [x] Needle display is an analog VU meter: golden-ratio case that scales with the window, face lit like a bulb behind glass, bezel in a dark KDE color, glass glare and edge, needle shadow, a domed "In tune" LED under the glass
- [x] Under the window: Hz and target on the left, the big note in the middle, cents and what to do on the right; nothing shown twice
- [x] With no sound the needle sinks to its stop instead of the display dimming

## Done: noise gate on the level meter (v4, variant E)

- [x] "Noise gate adjust" meter in the tuner card, label and level on the meter line, dB scale, draggable gate marker; hatched zone for ignored sounds
- [x] Mouse wheel, arrow keys, Page Up/Down and double-click reset on the meter; screen reader name and value
- [x] Reset and "Set from room noise" under the meter, same size, centered (listens 2 s, gate 6 dB above the noise; feedback only on the button)
- [x] String buttons sized to the UI font; badge glyphs drawn so they read at 18 px with any icon theme
- [x] Gate limited to −70…−10 dB so the marker always stays on the meter
- [x] Status bar removed
- [x] String number and frequency on the headstock pegs; tuned and play / stop badges on the top edge of every string button
- [x] With auto-detect off, clicking a string plays its reference tone and clicking it again stops it; the panel keeps only the sound settings
- [x] Reference tones fade in (60 ms) and out (150 ms)
- [x] All colors from the KDE color scheme

## Done: v2 single screen (layout C2)

- [x] One screen, no Listen / Reference toggle; the mic is always listening
- [x] Side panel for every instrument: headstock, or string buttons for violin family, mandolin, banjo
- [x] "Auto-detect string" switch centered under the strings
- [x] Start over status button "↺ 2 of 6 tuned" in the Strings header, green when all are tuned
- [x] Reference tone controls in the side panel, disabled while auto-detect is on; Space plays / stops
- [x] Speaker badge on the playing string; "Playing D4 on …" in the status bar (both replaced in v4)
- [x] A4 next to the tuning menu; small equal-width Needle / Strobe / Bar buttons centered under the display
- [x] Level meter in dB with peak hold, color zones and noise gate marker

## Open questions

- [ ] What should the tuner show while a reference tone plays through speakers (the mic hears it)?
      Currently: keeps listening. Options: freeze the display / label it as "reference".

## Later

- [x] Compact mini tuner: the smallest window shows the meter and the small Instrument and Noise gate panels (v9, v10); "Keep Above Others" comes from the Plasma window menu
- [ ] Share tunings as files (import / export)

### Street mode: tuning in noisy places

Goal: steady readings on a street or in a loud room. Normalisation / automatic gain does not help:
it raises the noise as much as the string, and YIN ignores loudness anyway. Better input beats any
software: a clip-on piezo pickup or a guitar cable into an audio interface already works today.

Plan, in order:

- [ ] **Test bench first**: mix string recordings with street-like noise at several loudness levels and
      count how often each variant reads the right note within ±1 cent, so every step is measured.
- [ ] **Listen only where the string is**: when the target string is known, band-pass around its note
      and first overtones and narrow the YIN search range; fixed low cut below ~30 Hz (traffic, wind).
      Auto-detect can only narrow to the instrument's range; chromatic mode can't narrow.
- [ ] **React to the pluck**: start measuring on a pluck (sharp rise, smooth decay) and stay locked through
      the decay; let the gate follow the noise floor automatically, a few dB above it.
- [ ] **Learn the noise**: extend "Set from room noise" to record the noise spectrum and subtract it before
      detection. Helps with steady noise (traffic, fans, crowd murmur), not with voices or horns.
- [ ] **Noisy place option** (mockup first): longer averaging and a stricter clarity threshold, slower but steadier.
- [ ] Later, if still needed: **harmonic check**, accept a reading only when the spectrum shows the target's
      overtone series (f, 2f, 3f…) and agrees with YIN.

Not recommended: voice noise suppression (RNNoise, EasyEffects, PipeWire echo-cancel) in front of
Kamerton; it is trained on speech and can remove a sustained string tone.

### Testing

Approach: a test pyramid. Many fast unit tests for logic and DSP, fewer QML component tests, and a
manual checklist for real hardware.
- DSP is measured, not eyeballed: known-pitch signals, numeric thresholds
  (e.g. ±0.5 ¢ from 30 Hz to 1.3 kHz, ≥ 95 % correct notes at 10 dB of noise).
- Every bug gets a failing test before the fix.
- No sleeps in tests: fake clock and fake audio.
- CI must pass before a pull request merges (with branch protection on `main`).

Tools:
- Qt Test via ECM `ecm_add_tests`, run by `ctest`; data-driven `_data()` tables; `QSignalSpy`.
- Qt Quick Test (`TestCase`, offscreen) for QML components.
- qmllint, clazy, clang-tidy; AddressSanitizer + UndefinedBehaviorSanitizer and ThreadSanitizer builds
  (the real-time thread, the ring buffer, the atomics).
- `appstreamcli validate`, `desktop-file-validate`, `flatpak-builder-lint`.
- GitHub Actions: build with GCC and Clang in a recent KDE container (or the KDE Flatpak SDK),
  `ctest` with `QT_QPA_PLATFORM=offscreen`, linters, validators, a sanitizer build.
- CI saves offscreen screenshots for a human to look at; no pixel comparison (fonts and Qt versions differ).
- Later, only if needed: end-to-end UI tests with KDE's selenium-webdriver-at-spi.

Plan, in order:

- [ ] **Unit tests that need no refactoring**: note parsing and frequencies (every built-in tuning,
      `B0`, `F#3`, `Bb2`, bad input), pitch detector accuracy on synthetic signals, tone generator fades
      (timings, no clicks).
- [ ] **GitHub Actions** on every pull request, then branch protection on `main`.
- [ ] **Audio source interface**: `TunerController` gets its samples through an interface instead of
      creating the PipeWire engine itself, so tests can feed a fake source (WAV or synthetic string)
      with a fake clock. Then controller tests (auto-detect switching, tuned marks, noise gate,
      Set from room noise), and the screenshot harness moves into `tests/`.
- [ ] **Test bench with real recordings and noise**: the author's own recordings under a free license,
      mixed with street noise; this is also the first step of Street mode.
- [ ] **QML component tests** (noise gate meter: clamping, keys, double-click reset; string button states),
      plus the sanitizer and clazy builds.
- [ ] **Manual checklist before each release**: real microphone, reference tones on speakers, dragging the
      gate, light and dark themes, a wide UI font.

## Polish / ideas

- [ ] Remember window size and position
- [ ] Translations (`.po` files via KI18n)
- [ ] Real-instrument testing on low strings (bass B0, cello C2) and adjusting the pitch smoothing
