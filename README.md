<p align="center">
  <img src="assets/icons/logo.png" alt="Aniwhere Logo" width="120" height="120">
</p>

<h1 align="center">Aniwhere</h1>

<p align="center">
  <em>Watch and read anime, manga, anywhere.</em>
</p>

<p align="center">
  <a href="https://github.com/yourusername/aniwhere/releases">
    <img src="https://img.shields.io/github/v/release/yourusername/aniwhere?style=flat-square" alt="Release">
  </a>
  <a href="https://github.com/yourusername/aniwhere/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yourusername/aniwhere?style=flat-square" alt="License">
  </a>
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter" alt="Flutter">
  </a>
  <a href="https://dart.dev">
    <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart" alt="Dart">
  </a>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#building">Building</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## ✨ Features

- 📚 **Multi-Source Support** — Read manga, manhwa, manhua, and novels from various sources
- 🎬 **Anime Streaming** — Watch anime with HLS/MP4 support and custom player controls
- 📱 **Cross-Platform** — Available on Android, iOS, Windows, Linux, and macOS
- 🔌 **Extension System** — Add custom sources via JavaScript extensions
- 📊 **Tracker Integration** — Sync progress with MyAnimeList, AniList, and Kitsu
- 🌙 **Dark Theme** — Beautiful dark-first design with purple accent
- 💾 **Offline Reading** — Download chapters for offline access
- 🔄 **Backup & Restore** — Export and import your library

## 📱 Screenshots

<p align="center">
  <img src="assets/screenshots/library.png" width="200" alt="Library">
  <img src="assets/screenshots/browse.png" width="200" alt="Browse">
  <img src="assets/screenshots/reader.png" width="200" alt="Reader">
  <img src="assets/screenshots/player.png" width="200" alt="Player">
</p>

## 📥 Installation

### Android
Download the latest APK from the [Releases](https://github.com/yourusername/aniwhere/releases) page.

### iOS
*Coming soon* — TestFlight beta available for early testers.

### Windows
Download the latest MSIX installer from [Releases](https://github.com/yourusername/aniwhere/releases).

### Linux
```bash
# AppImage
chmod +x Aniwhere-*.AppImage
./Aniwhere-*.AppImage

# Or build from source (see below)
```

### macOS
Download the DMG from [Releases](https://github.com/yourusername/aniwhere/releases).

## 🔧 Building from Source

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)
- [Dart SDK](https://dart.dev/get-dart) (3.x or later)

#### Platform-specific requirements:

**Linux:**
```bash
sudo apt install libmpv-dev libgtk-3-dev
```

**Windows:**
- Visual Studio 2022 with C++ desktop development workload

**macOS:**
- Xcode 14 or later

### Build Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/aniwhere.git
cd aniwhere

# Install dependencies
flutter pub get

# Generate code (Isar models)
flutter pub run build_runner build

# Run in debug mode
flutter run

# Build for release
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows
flutter build linux        # Linux
flutter build macos        # macOS
```

## 🏗️ Project Structure

```
aniwhere/
├── lib/
│   ├── main.dart              # App entry point
│   ├── core/                  # Core utilities
│   │   ├── constants/         # App constants
│   │   ├── theme/             # Theme configuration
│   │   ├── router/            # Navigation (go_router)
│   │   └── utils/             # Riverpod providers
│   ├── data/                  # Data layer
│   │   ├── models/            # Isar database models
│   │   ├── sources/           # Data sources
│   │   └── repositories/      # Repository pattern
│   ├── features/              # Feature modules
│   │   ├── library/           # Library management
│   │   ├── browse/            # Source browsing
│   │   ├── reader/            # Manga/novel reader
│   │   ├── player/            # Video player
│   │   ├── tracker/           # External trackers
│   │   ├── search/            # Global search
│   │   └── settings/          # App settings
│   └── ui/                    # Shared UI components
│       ├── widgets/           # Reusable widgets
│       └── screens/           # Common screens
├── extensions/                # JS extension storage
├── assets/                    # Static assets
└── test/                      # Unit & widget tests
```

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| State Management | Riverpod |
| Navigation | go_router |
| Local Database | Isar |
| Video Player | media_kit |
| HTTP Client | Dio |
| Extensions | flutter_js |

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This application does not host any content. It is a reader/player that connects to publicly available sources. The developers are not responsible for any content accessed through the app.

## 💜 Acknowledgments

- [Flutter](https://flutter.dev) — UI framework
- [Riverpod](https://riverpod.dev) — State management
- [Isar](https://isar.dev) — Local database
- [media_kit](https://github.com/media-kit/media-kit) — Video playback
- [MangaDex](https://mangadex.org) — Manga source API

---

<p align="center">
  Made with 💜 by the Aniwhere Team
</p>
