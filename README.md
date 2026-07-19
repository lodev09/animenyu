# AniMenyu

A sleek macOS menu bar app for tracking your currently airing anime on [AniList](https://anilist.co).

## Features

- 🍥 Lives in your menu bar — no Dock icon
- 📺 Shows your watching list for the current season with cover art
- ⏳ Live countdown to each next episode
- 🔴 Accent bar when you're behind on episodes
- ➕ One click on the card's bottom bar to bump your progress
- 🔗 Click a card for details and a link to its AniList page
- 🔐 Sign in with AniList via OAuth — token stored in your Keychain

## Requirements

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

```sh
xcodegen generate
open AniMenyu.xcodeproj
```

Then build and run (⌘R).

To regenerate the app and menu bar icons:

```sh
swift scripts/generate_icons.swift
```

## License

[MIT](LICENSE) © [Jovanni Lo](https://github.com/lodev09)
