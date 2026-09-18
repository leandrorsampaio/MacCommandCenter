# Sounds

`click.wav` is the key click for the RBMK panel, named by `chrome.keySound` in
`skin.json`.

## Provenance

Derived from "Click Button" by **Universfield**, from Pixabay
(<https://pixabay.com/sound-effects/film-special-effects-click-button-140881/>), used
under the [Pixabay Content License](https://pixabay.com/service/license-summary/), which
permits use and modification in a product. It is redistributed here as part of the app,
not as a standalone sound.

Trimmed from 496 ms to 158 ms and summed to mono: the original carried 21 ms of silence
before the attack, which a key press reads as lag, and 380 ms of tail after it that only
mattered if you pressed twice quickly.

## Using your own

Point `chrome.keySound` at any file in this folder. Anything `AVAudioPlayer` reads works —
`.wav`, `.mp3`, `.aiff`, `.m4a`. A missing file falls back to the synthesised click, so a
wrong path costs the skin its sound and nothing else.

Keep it short. Under about 150 ms, with the attack at the very start.

Other sounds you drop here are gitignored, because their licences travel with them.
