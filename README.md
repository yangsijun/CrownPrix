# Crown Prix

A minimalist 2D top-down racing game, designed from the ground up exclusively for Apple Watch.

Steer with the Digital Crown. Race 24 real-world circuits. Climb the global leaderboard.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/crown-prix/id6758554134)

[Website](https://crownprix.sijun.dev)

## Features

- **Digital Crown Steering** -- Turn the crown to steer. Intuitive analog control built for the wrist.
- **24 Real-World Circuits** -- Every track from the current F1 calendar, faithfully recreated from SVG data.
- **Sector Timing** -- Three sectors per track with purple (personal best) sector indicators.
- **Game Center Leaderboards** -- Global rankings for every circuit. See where you stand.
- **iOS Companion App** -- Browse leaderboards, view rankings, and jump into races from your iPhone.
- **Haptic Feedback** -- Feel the track through your wrist with native watchOS haptics.

## How It Works

The game runs entirely on Apple Watch. Tracks are parsed from SVG path data at load time, sampled into a dense polyline, and rendered as a continuous road with collision boundaries. A lightweight physics engine handles acceleration, steering curves, and wall collisions. The Digital Crown provides proportional analog input for steering.

### Architecture

```
Watch App
├── Game/          # SpriteKit scene, car physics, camera, collision, lap & sector detection
├── Pipeline/      # SVG parsing → polyline sampling → track preprocessing
├── Input/         # Digital Crown input handler
├── Config/        # Game tuning parameters
├── Systems/       # Game Center, WatchConnectivity, haptics, persistence
├── UI/            # SwiftUI views (home, track select, race, results, leaderboard)
├── HUD/           # In-race heads-up display
├── Models/        # Track metadata, race results, sector data
└── Data/          # Track registry (24 circuits)

iOS Companion App
├── Views/         # Track list, leaderboard, about sheet
├── Models/        # Shared track metadata, time formatting
├── GameCenterManager
└── PhoneConnectivityManager
```

### Sync

Race times and leaderboard data sync between Watch and iPhone via WatchConnectivity, with automatic fallback from `sendMessage` to `transferUserInfo` for reliability.

## Tracks

| | Circuit | Country |
|---|---|---|
| :australia: | Albert Park Circuit | Australia |
| :cn: | Shanghai International Circuit | China |
| :jp: | Suzuka International Racing Course | Japan |
| :bahrain: | Bahrain International Circuit | Bahrain |
| :saudi_arabia: | Jeddah Corniche Circuit | Saudi Arabia |
| :us: | Miami International Autodrome | USA |
| :canada: | Circuit Gilles Villeneuve | Canada |
| :monaco: | Circuit de Monaco | Monaco |
| :es: | Circuit de Barcelona-Catalunya | Spain |
| :austria: | Red Bull Ring | Austria |
| :gb: | Silverstone Circuit | UK |
| :belgium: | Circuit de Spa-Francorchamps | Belgium |
| :hungary: | Hungaroring | Hungary |
| :netherlands: | Circuit Zandvoort | Netherlands |
| :it: | Autodromo Nazionale Monza | Italy |
| :es: | Circuito de Madring | Spain |
| :azerbaijan: | Baku City Circuit | Azerbaijan |
| :singapore: | Marina Bay Street Circuit | Singapore |
| :us: | Circuit of the Americas | USA |
| :mexico: | Autodromo Hermanos Rodriguez | Mexico |
| :brazil: | Autodromo Jose Carlos Pace | Brazil |
| :us: | Las Vegas Strip Circuit | USA |
| :qatar: | Losail International Circuit | Qatar |
| :united_arab_emirates: | Yas Marina Circuit | UAE |

## Requirements

- watchOS 10.0+
- iOS 17.0+
- Xcode 16.0+

## Author

**Yang Sijun** -- [sijun.dev](https://sijun.dev)

- [GitHub](https://github.com/yangsijun)
- [LinkedIn](https://linkedin.com/in/yangsijun)

## License

All rights reserved.
