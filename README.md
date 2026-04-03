<div align="center">

```
░█████╗░███╗░░██╗██╗░██╗░░░██╗░██╗░░██╗███████╗██████╗░███████╗
██╔══██╗████╗░██║██║░██║░░░██║░██║░░██║██╔════╝██╔══██╗██╔════╝
███████║██╔██╗██║██║░╚██╗░██╔╝░███████║█████╗░░██████╔╝█████╗░░
██╔══██║██║╚████║██║░░╚████╔╝░░██╔══██║██╔══╝░░██╔══██╗██╔══╝░░
██║░░██║██║░╚███║██║░░░╚██╔╝░░░██║░░██║███████╗██║░░██║███████╗
╚═╝░░╚═╝╚═╝░░╚══╝╚═╝░░░░╚═╝░░░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚══════╝
```

### `watch it. read it. aniwhere.`

<br>

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

![License](https://img.shields.io/github/license/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED)
![Stars](https://img.shields.io/github/stars/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED)
![Issues](https://img.shields.io/github/issues/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED)
![Last Commit](https://img.shields.io/github/last-commit/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED)

</div>

---

<br>

## ◈ what is this?

**Aniwhere** is an open-source, cross-platform Flutter app for people who refuse to be tied down to one platform, one app, or one source.

Watch anime. Read manga. Devour webtoons. Binge light novels.  
On your phone, your desktop, your old laptop, your anything.

Built from scratch by **[HUNTERZEN](https://github.com/HUNTERZEN)** — not a fork, not a clone. *A thing of its own.*

<br>

---

## ◈ the feature wall

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   📖  Manga · Webtoon · Comic · Novel reader                │
│   🎬  Anime & movie streaming via extensions                │
│   🔌  JS-based extension system — add any source            │
│   📚  Library with categories & progress tracking           │
│   🔄  Tracker sync — MAL · AniList · Kitsu                  │
│   📥  Offline reading & local file support                  │
│   🎨  Configurable reader — direction, zoom, bg             │
│   🌑  Dark-first UI — because eyes deserve respect          │
│   💾  Backup & restore your entire library                  │
│   🖥️  Runs on Android · iOS · Windows · Linux · macOS       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

<br>

---

## ◈ built with

| Layer | Tech |
|---|---|
| Framework | Flutter 3.x + Dart 3 |
| State | Riverpod |
| Database | Isar |
| Networking | Dio |
| Video | media\_kit |
| Extensions | flutter\_js (QuickJS engine) |
| Navigation | go\_router |
| Image Cache | cached\_network\_image |
| Auth | OAuth2 (MAL / AniList / Kitsu) |

<br>

---

## ◈ getting started

> Make sure you have Flutter 3.19+ installed.

```bash
# 1. clone it
git clone https://github.com/HUNTERZEN/aniwhere.git
cd aniwhere

# 2. get dependencies
flutter pub get

# 3. run it
flutter run

# 4. build release (Android)
flutter build apk --release
```

<br>

---

## ◈ project layout

```
aniwhere/
 ├── lib/
 │    ├── core/          → theme, router, constants
 │    ├── data/          → models, sources, repositories
 │    ├── features/      → library, browse, reader, player,
 │    │                    tracker, search, settings
 │    └── ui/            → shared widgets & screens
 ├── extensions/         → JS source extensions
 ├── assets/             → icons, fonts
 └── test/
```

<br>

---

## ◈ extension system

Aniwhere runs a lightweight **JavaScript engine** at runtime.  
Sources are `.js` files — drop them in, enable them, done.  
No rebuilds. No updates needed from me.

```
extensions/
 ├── mangadex.js
 ├── gogoanime.js
 └── your-source-here.js   ← yes, you can write your own
```

> Want to write an extension? See [`/docs/extensions.md`](./docs/extensions.md) *(coming soon)*

<br>

---

## ◈ screenshots

> *Coming once the UI is cooked. Stay tuned.*

<br>

---

## ◈ roadmap

- [x] Project scaffold & architecture
- [x] Theme system (dark-first, purple accent)
- [ ] Browse screen + MangaDex source
- [ ] Manga reader (paged + vertical)
- [ ] Anime player (HLS/m3u8)
- [ ] Library with progress tracking
- [ ] MAL / AniList / Kitsu tracker sync
- [ ] Extension manager UI
- [ ] Backup & restore
- [ ] iOS & desktop builds

<br>

---

## ◈ contributing

Got a fix? A feature idea? A source extension?  
PRs are open. Issues are welcome. No ego here.

```bash
# fork → branch → commit → PR
git checkout -b feat/your-idea
```

Please keep code clean and typed. Dart null safety is non-negotiable.

<br>

---

## ◈ legal note

Aniwhere does **not** host, store, or distribute any copyrighted content.  
It is a client interface — like a browser — that connects to third-party sources via user-installed extensions.  
*You are responsible for how you use it.*

<br>

---

## ◈ license

```
MIT License — do what you want, keep the credit.
Copyright (c) 2025 HUNTERZEN
```

<br>

---

<div align="center">

made with obsession by **[HUNTERZEN](https://github.com/HUNTERZEN)**

*if it helped you — drop a ⭐. it costs nothing.*

</div>
