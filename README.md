<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=7C3AED&height=200&section=header&text=ANIWHERE&fontSize=80&fontColor=ffffff&fontAlignY=38&desc=watch%20it.%20read%20it.%20aniwhere.&descAlignY=58&descSize=18&descColor=d8b4fe" width="100%"/>

<br/>

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

<br/>

[![License](https://img.shields.io/github/license/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED&labelColor=0d0d0d)](LICENSE)
[![Stars](https://img.shields.io/github/stars/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED&labelColor=0d0d0d)](https://github.com/HUNTERZEN/aniwhere/stargazers)
[![Issues](https://img.shields.io/github/issues/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED&labelColor=0d0d0d)](https://github.com/HUNTERZEN/aniwhere/issues)
[![Last Commit](https://img.shields.io/github/last-commit/HUNTERZEN/aniwhere?style=flat-square&color=7C3AED&labelColor=0d0d0d)](https://github.com/HUNTERZEN/aniwhere/commits)

</div>

<br/>

---

## ◈ what is this?

**Aniwhere** is a free, open-source Flutter app for people who refuse to be tied down to one platform, one app, or one source.

Watch anime. Read manga. Devour webtoons. Binge light novels.  
On your phone, your desktop, your old laptop — your anything.

> Built from scratch by **[HUNTERZEN](https://github.com/HUNTERZEN)** — not a fork, not a clone. *A thing of its own.*

<br/>

---

## ◈ the feature wall

| 　 | Feature |
|:---:|:---|
| 📖 | Manga · Webtoon · Comic · Light Novel reader |
| 🎬 | Anime & movie streaming via extensions |
| 🔌 | JS-based extension system — add any source |
| 📚 | Library with categories & read progress tracking |
| 🔄 | Tracker sync — MyAnimeList · AniList · Kitsu |
| 📥 | Offline reading & local file support |
| 🎨 | Configurable reader — direction, zoom, background |
| 🌑 | Dark-first UI with deep purple accent |
| 💾 | Backup & restore your entire library |
| 🖥️ | Android · iOS · Windows · Linux · macOS |

<br/>

---

## ◈ built with

| Layer | Tech |
|:---|:---|
| Framework | Flutter 3.x + Dart 3 (null safety) |
| State Management | Riverpod |
| Local Database | Isar |
| Networking | Dio |
| Video Playback | media\_kit |
| Extension Engine | flutter\_js (QuickJS) |
| Navigation | go\_router |
| Image Caching | cached\_network\_image |
| Tracker Auth | OAuth2 — MAL · AniList · Kitsu |

<br/>

---

## ◈ getting started

> Requires Flutter 3.19+

```bash
# clone
git clone https://github.com/HUNTERZEN/aniwhere.git
cd aniwhere

# install deps
flutter pub get

# run
flutter run

# build (Android)
flutter build apk --release
```

<br/>

---

## ◈ project structure

```
aniwhere/
├── lib/
│   ├── core/          # theme, router, constants
│   ├── data/          # models, sources, repositories
│   ├── features/      # library · browse · reader
│   │                  # player · tracker · search · settings
│   └── ui/            # shared widgets & screens
├── extensions/        # JS source extensions
├── assets/            # icons, fonts
└── test/
```

<br/>

---

## ◈ extension system

Sources are `.js` files powered by a lightweight **QuickJS engine** at runtime.  
No rebuilds. No app updates. Drop a file, enable it, done.

```
extensions/
├── mangadex.js
├── gogoanime.js
└── your-source.js    ← write your own
```

> Docs for writing extensions → [`/docs/extensions.md`](./docs/extensions.md) *(coming soon)*

<br/>

---

## ◈ roadmap

| Status | Task |
|:---:|:---|
| ✅ | Project scaffold & clean architecture |
| ✅ | Theme system — dark-first, `#7C3AED` purple accent |
| ✅ | Video player screen with custom controls |
| ✅ | Browse screen + MangaDex built-in source |
| ✅ | Manga reader — paged & vertical scroll |
| ✅ | Library with progress tracking |
| ✅ | MAL / AniList / Kitsu tracker sync |
| ✅ | Extension manager UI |
| 🔲 | Backup & restore |
| 🔲 | iOS & desktop builds |

<br/>

---

## ◈ contributing

PRs are welcome. Issues are welcome. No ego here.

```bash
git checkout -b feat/your-idea
# → commit → push → open PR
```

Keep code clean, typed, and null-safe. That's it.

<br/>

---

## ◈ disclaimer

Aniwhere does **not** host, store, or distribute any copyrighted content.  
It is a client — like a browser — that connects to third-party sources via user-installed extensions.  
*You are responsible for what you do with it.*

<br/>

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=7C3AED&height=120&section=footer" width="100%"/>

**made with obsession by [HUNTERZEN](https://github.com/HUNTERZEN)**

*if it helped — drop a ⭐. it costs nothing.*

</div>
