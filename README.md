# StreamFetcher 📥🎵

**StreamFetcher** is a lightweight and powerful Android video and song downloader built with Flutter. It allows users to effortlessly download media from YouTube URLs, direct MP4 links, and `.m3u8` stream playlists, saving them directly to public storage for smooth playback in external media players like MX Player.

---

## ✨ Features

* **YouTube Integration:** Powered by `youtube_explode_dart` to extract direct, high-quality muxed (audio + video combined) streams from YouTube links.
* **Stream & Playlist Support:** Automatically parses `.m3u8` stream manifest files to extract and download different video resolutions.
* **Background Downloads:** Utilizes `flutter_downloader` with background isolates to manage downloads reliably with live progress updates and system notifications.
* **External Player Friendly:** Saved files are stored in public directories, making them instantly accessible by players like MX Player, VLC, etc.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Core Packages:**
  * [`flutter_downloader`](https://pub.dev/packages/flutter_downloader) - For handling background downloads and notifications.
  * [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart) - For parsing and extracting streams from YouTube videos.
  * [`permission_handler`](https://pub.dev/packages/permission_handler) - For managing storage and notification permissions.
  * [`path_provider`](https://pub.dev/packages/path_provider) - For locating device storage directories.
  * [`http`](https://pub.dev/packages/http) - For fetching remote stream data.

---

## 📱 Getting Started

### Prerequisites
* Flutter SDK installed on your machine.
* Android Studio / VS Code with Flutter extensions.
* An Android device or emulator.

### Installation & Running Locally

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YourUsername/StreamFetcher.git](https://github.com/YourUsername/StreamFetcher.git)
   cd stream_fetcher_android