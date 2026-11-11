# Kamerton — TODO

Mockups: [mockups/index.html](mockups/index.html) (open in a browser; v3 "C2" plus v4 "E" is the implemented layout)

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

- [ ] Compact always-on-top mini tuner window (needs its own mockup first)
- [ ] Share tunings as files (import / export)

## Polish / ideas

- [ ] Remember window size and position
- [ ] Translations (`.po` files via KI18n)
- [ ] Real-instrument testing on low strings (bass B0, cello C2) and adjusting the pitch smoothing
