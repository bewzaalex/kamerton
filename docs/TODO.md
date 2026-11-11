# Kamerton — TODO

Mockups: [mockups/index.html](mockups/index.html) (open in a browser; v3 "C2" is the implemented layout)

## Done: v2 single screen (layout C2)

- [x] One screen, no Listen / Reference toggle; the mic is always listening
- [x] Side panel for every instrument: headstock, or string buttons for violin family, mandolin, banjo
- [x] "Auto-detect string" switch centered under the strings
- [x] Start over status button "↺ 2 of 6 tuned" in the Strings header, green when all are tuned
- [x] Reference tone controls in the side panel, disabled while auto-detect is on; Space plays / stops
- [x] Speaker badge on the playing string; "Playing D4 on …" in the status bar
- [x] A4 next to the tuning menu; small equal-width Needle / Strobe / Bar buttons centered under the display
- [x] Level meter in dB with peak hold, color zones and noise gate marker

## Open questions

- [ ] What should the tuner show while a reference tone plays through speakers (the mic hears it)?
      Currently: keeps listening. Options: freeze the display / label it as "reference".

## Later

- [ ] **Live noise gate adjustment while tuning**: drag the gate marker on the level meter
      (and mouse wheel / arrow keys on it), show the value in a tooltip while dragging,
      apply immediately and save to settings. Must be keyboard and screen reader accessible.
- [ ] Compact always-on-top mini tuner window (needs its own mockup first)
- [ ] Share tunings as files (import / export)

## Polish / ideas

- [ ] Remember window size and position
- [ ] Translations (`.po` files via KI18n)
- [ ] Real-instrument testing on low strings (bass B0, cello C2) and adjusting the pitch smoothing
