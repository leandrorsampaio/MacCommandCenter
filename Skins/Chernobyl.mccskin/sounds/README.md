# Drop a click here

The skin names `sounds/click.wav`. Any format AVAudioPlayer reads works — `.wav`,
`.mp3`, `.aiff`, `.m4a` — just match the filename to `chrome.keySound` in `skin.json`.

If the file is missing the app falls back to a synthesised click, so a wrong path costs
the skin its sound and nothing else.

Keep it short. A key click wants to be under about 150ms, or it lags behind the press.

**Licensing:** whatever you put here ships with the skin. This repository is MIT, so a
sound under a different licence should stay with the skin rather than being committed
here, unless its terms allow redistribution.
