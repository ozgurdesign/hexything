# HexyThing

A Mac menu-bar app that reads colour codes from text on your screen.

**[Download the latest version](https://github.com/ozgurdesign/hexything/releases/latest)** · [ozgur.ca](https://ozgur.ca/projects/hexything)

Hover over a colour code anywhere (Figma, a browser, a PDF, a screenshot) to see the colour. Click to copy it. Your last 10 colours stay in the menu bar.

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
| Open the loupe | ⌃⌥⌘C or click the menu-bar icon |
| Copy and save | Click |
| Read as HSL | Hold ⌥ |
| Cancel | Esc |
| History and settings | Right-click the menu-bar icon |

Settings let you change the shortcut and turn on launch at login.

## Download

Each release has one disk image, `HexyThing-<version>.dmg`, for macOS 14 Sonoma and later, on Apple silicon and Intel.

The "Source code" links GitHub adds to every release only contain this README and the licence. The app is the `.dmg`.

## First launch

HexyThing is not notarized by Apple, so macOS asks before opening it the first time.

1. Open the disk image and drag HexyThing to Applications.
2. Open HexyThing once. macOS says it can't check the app.
3. Go to System Settings › Privacy & Security and click Open Anyway.
4. Allow Screen Recording when asked, then reopen HexyThing.

You only need to do this once.

## Privacy

HexyThing captures a small strip around the pointer to read the text. Recognition runs on your Mac with Apple's Vision framework. Nothing is sent anywhere, and nothing is collected.

## About this repository

This repository hosts releases only. The source code is not public, and issues and pull requests are turned off.

## Credits

Shortcut recording uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus, bundled under the MIT License. Its notice is in [LICENSE](LICENSE) and inside the app.

## Licence

HexyThing by [Oz Gultekin](https://ozgur.ca) is licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/). See [LICENSE](LICENSE).
