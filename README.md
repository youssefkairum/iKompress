# Compressor (iKompress)

![Platform](https://img.shields.io/badge/Platform-iOS-blue.svg)
![Language](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Interface](https://img.shields.io/badge/UI-SwiftUI-purple.svg)

**Compressor** is a modern, privacy-focused iOS application built with SwiftUI that allows users to compress, resize, and convert images efficiently. Featuring a beautiful "glassmorphic" design, it offers advanced controls over image quality and metadata while maintaining a history of your compressed files.

## ✨ Key Features

### 🖼 Image Compression & Conversion
* **Multiple Formats:** Support for **JPEG**, **PNG**, and **HEIC**.
* **Smart Compression:** Adjustable quality slider (0.1 - 1.0) for lossy formats.
* **Lossless Support:** Intelligent handling for PNG files.
* **Size Estimation:** Real-time calculation of the estimated output file size before compression.

### 📏 Advanced Resizing
* **No Resize:** Keep original dimensions.
* **Percentage:** Scale images down by a specific percentage.
* **Custom Dimensions:** Resize by specific **Width** or **Height** (maintaining aspect ratio).

### 🔒 Privacy & Metadata
* **Metadata Stripping:** Optional toggle to remove **EXIF data** (location, camera details) for privacy.
* **Local Processing:** All compression happens on-device; images never leave your phone.

### 📝 History & Analytics
* **Persistent History:** Automatically saves compressed images to a local "CompressedHistory" folder.
* **Storage Stats:** Visual dashboard tracking total files compressed and storage space saved.
* **Management:** Share, Save to Photos, or Delete files directly from the history tab.

### 💰 Support the Dev (Tip Jar)
* **StoreKit 2 Integration:** Built-in "Tip Jar" allowing users to support development via In-App Purchases.
* **Animations:** Playful interactions and animations upon successful support.

---

## 🛠 Tech Stack

* **Language:** Swift 5
* **UI Framework:** SwiftUI
* **Architecture:** MVVM (Model-View-ViewModel)
* **Persistence:** `FileManager` (Documents Directory) + `JSONEncoder`/`Codable`
* **Concurrency:** Grand Central Dispatch (GCD) & `async/await`
* **Dependencies:**
    * [SDWebImage](https://github.com/SDWebImage/SDWebImage)
    * [SDWebImageWebPCoder](https://github.com/SDWebImage/SDWebImageWebPCoder) (WebP support integration)

---

## 📂 Project Structure

```text
Compressor/
├── App/
│   ├── CompressorApp.swift    # App Entry Point & StoreKit Transaction Listener
│   └── Assets.xcassets        # App Icons and Colors
├── Views/
│   ├── ContentView.swift      # Main Logic & UI Components
│   ├── MainTabView.swift      # Tab Navigation (Compress, History, About)
│   ├── CompressView.swift     # Core Compression UI & Logic
│   ├── HistoryView.swift      # History List & Statistics
│   └── AboutView.swift        # App Info & Tip Jar
└── Logic/
    ├── CompressionHistoryStore.swift # Persistence Layer
    └── ImageFile.swift               # Data Model
