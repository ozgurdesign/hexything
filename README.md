# HexyThing

A macOS menubar app that reads colour codes from text on your screen.

Hover over a colour code anywhere (Figma, a browser, a PDF, a screenshot) to see the colour. Click to copy it. Your last 10 colours stay in the menubar.

## Formats

| On screen | Copied as |
| --- | --- |
| `#3a7bd5`, `3A7BD5`, `#f00a` | `#3A7BD5`, `#FF0000AA` |
| `rgb(58, 123, 213)`, `hsla(210 64% 53% / 0.5)` | As written |
| `58, 123, 213`, `R 58 G 123 B 213` | `rgb(58, 123, 213)` |
| `210 64% 53%`, `H 210 S 64% L 53%` | `hsl(210, 64%, 53%)` |

Values without labels or `%` read as RGB. Hold ⌥ to read them as HSL.

## Controls

| Action | Input |
| --- | --- |
| Open the loupe | ⌃⌥⌘C or click the menubar icon |
| Copy and save | Click |
| Read as HSL | Hold ⌥ |
| Cancel | Esc |
| History and settings | Right-click the menubar icon |

Settings let you change the shortcut and turn on launch at login.

## Install

Requires macOS 14 or later.

1. Download `HexyThing.zip` from Releases and move `HexyThing.app` to Applications.
2. The app is not notarized. Right-click it and choose Open. If macOS blocks it, go to System Settings › Privacy & Security and click Open Anyway.
3. Allow Screen Recording when asked, then reopen HexyThing.

Text recognition runs on your Mac. Nothing is sent anywhere.

## Build

Requires Xcode.

```sh
./scripts/build-app.sh
```

Each ad-hoc build resets the Screen Recording permission. To keep it, create a self-signed Code Signing certificate named `HexyThing Dev` in Keychain Access › Certificate Assistant › Create a Certificate. The build script uses it automatically.

## Licence

MIT
