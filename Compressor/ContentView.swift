//
//  ContentView.swift
//  Compressor
//
//  Created by Youssef Keram on 5/29/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AudioToolbox


// MARK: - Supported Formats

enum CompressionFormat: String, CaseIterable, Identifiable, Codable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    var id: String { self.rawValue }
    var fileExtension: String {
        switch self {
            case .jpeg: return "jpg"
            case .png: return "png"
            case .heic: return "heic"
        }
    }
    var allowsQuality: Bool {
        self != .png
    }
}

struct ImageFile: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var format: String
    var fileSize: Int
    var width: Int
    var height: Int
    var originalPath: String?
    var compressedPath: String?
    var compressedSize: Int?
    var compressedFormat: CompressionFormat?
    
    var image: UIImage? {
        if let path = originalPath {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
    var compressedImage: UIImage? {
        if let path = compressedPath {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, fileName, format, fileSize, width, height, originalPath, compressedPath, compressedSize, compressedFormat
    }
}

// MARK: - Persistent History Store

class CompressionHistoryStore: ObservableObject {
    @Published var history: [ImageFile] = []
    static let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CompressedHistory")
    static let metaFile = folder.appendingPathComponent("history.json")
    
    init() {
        load()
    }
    
    func add(_ imageFile: ImageFile) {
        objectWillChange.send()
        history.insert(imageFile, at: 0)
        save()
    }
    func remove(_ imageFile: ImageFile) {
        objectWillChange.send()
        if let idx = history.firstIndex(of: imageFile) {
            if let opath = imageFile.originalPath {
                try? FileManager.default.removeItem(atPath: opath)
            }
            if let cpath = imageFile.compressedPath {
                try? FileManager.default.removeItem(atPath: cpath)
            }
            history.remove(at: idx)
            save()
        }
    }
    func clear() {
        objectWillChange.send()
        for img in history {
            if let opath = img.originalPath {
                try? FileManager.default.removeItem(atPath: opath)
            }
            if let cpath = img.compressedPath {
                try? FileManager.default.removeItem(atPath: cpath)
            }
        }
        history.removeAll()
        save()
    }
    func save() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: Self.metaFile)
        } catch {}
    }
    func load() {
        do {
            let data = try Data(contentsOf: Self.metaFile)
            history = try JSONDecoder().decode([ImageFile].self, from: data)
        } catch {
            history = []
        }
    }
}

// MARK: - Helpers

func saveImageFile(data: Data, name: String) -> String {
    let dir = CompressionHistoryStore.folder
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let fileURL = dir.appendingPathComponent(name)
    try? data.write(to: fileURL)
    return fileURL.path
}
// MARK: - Main App and TabView

struct MainTabView: View {
    @StateObject private var historyStore = CompressionHistoryStore()
    var body: some View {
        TabView {
            CompressView()
                .environmentObject(historyStore)
                .tabItem { Label("Compress", systemImage: "arrow.down.circle") }
            HistoryView()
                .environmentObject(historyStore)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .accentColor(.blue)
    }
}

// MARK: - About Tab

struct AboutView: View {
    var body: some View {
        let year = Calendar.current.component(.year, from: Date())
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Text("Compressor")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Image(uiImage: getAppIcon() ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(28)
                    .shadow(radius: 8)
                
                Text("Version 1.0.0")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: reviewApp) {
                    Label("Review This App", systemImage: "star.fill")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                }
                .padding(.top, 12)
            }
            Spacer()
            Text("© 2025 Youssef Ahmed. All rights reserved.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    func getAppIcon() -> UIImage? {
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    
    func reviewApp() {
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}




// MARK: - Compress Tab

struct CompressView: View {
    @EnvironmentObject var historyStore: CompressionHistoryStore
    @State private var imageFiles: [ImageFile] = []
    @State private var showPicker = false
    @State private var isCompressing = false
    @State private var compressionQuality: Double = 0.7
    @State private var selectedFormat: CompressionFormat = .jpeg
    @State private var progress: Double = 0.0

    // Advanced options:
    @State private var resizeMode: ResizeMode = .none
    @State private var resizeValue: Double = 100.0
    @State private var removeMetadata = false

    // Estimated size
    @State private var estimatedSize: Int? = nil

    @State private var showSaveResult = false
    @State private var saveResultMessage = ""
    @State private var showShareSheet = false
    @State private var shareItem: Any?
    @State private var showClearedToast = false

    var hasUncompressedImages: Bool {
        imageFiles.contains { $0.compressedPath == nil }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if imageFiles.isEmpty {
                        VStack(spacing: 18) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .opacity(0.2)
                                .transition(.opacity)
                            Text("No images selected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .animation(.easeInOut, value: imageFiles)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(imageFiles) { img in
                                    ImageCardView(
                                        img: img,
                                        onShareOriginal: { if let uiimg = img.image { share(item: uiimg) } },
                                        onSaveOriginal: { if let path = img.originalPath { saveImageToPhotos(path: path) } },
                                        onShareCompressed: { if let cimg = img.compressedImage { share(item: cimg) } },
                                        onSaveCompressed: { if let path = img.compressedPath { saveImageToPhotos(path: path) } }
                                    )
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.top, 8)
                        }
                        .animation(.spring(), value: imageFiles)
                    }
                }
                
                // --- Toast Overlay ---
                if showClearedToast {
                    HStack {
                        Spacer()
                        Text("Cleared!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 22)
                            .background(.ultraThinMaterial)
                            .background(Color.green.opacity(0.92))
                            .cornerRadius(18)
                            .shadow(radius: 12)
                        Spacer()
                    }
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }

                // Bottom floating VStack for options & buttons
                VStack(spacing: 0) {
                    if hasUncompressedImages && !imageFiles.isEmpty {
                        GroupBox {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("Format")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Picker("", selection: $selectedFormat) {
                                        ForEach(CompressionFormat.allCases) { fmt in
                                            Text(fmt.rawValue).tag(fmt)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)
                                }
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Quality: \(Int(compressionQuality * 100))%")
                                        Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.01)
                                            .disabled(isCompressing || !selectedFormat.allowsQuality)
                                    }
                                    Stepper("Step: \(Int(compressionQuality * 100))%", value: Binding(
                                        get: { Int(compressionQuality * 100) },
                                        set: { compressionQuality = Double($0)/100 }
                                    ), in: 10...100, step: 1)
                                    .disabled(isCompressing || !selectedFormat.allowsQuality)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Resize")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Picker("Resize Mode", selection: $resizeMode) {
                                            ForEach(ResizeMode.allCases) { mode in
                                                Text(mode.rawValue).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 210)
                                    }
                                    if resizeMode != .none {
                                        HStack {
                                            if resizeMode == .percent {
                                                Slider(value: $resizeValue, in: 10...100, step: 1)
                                                Text("\(Int(resizeValue))%")
                                            } else {
                                                Slider(value: $resizeValue, in: 50...3000, step: 1)
                                                Text("\(Int(resizeValue)) px")
                                            }
                                        }
                                    }
                                }
                                Toggle(isOn: $removeMetadata) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.slash")
                                        Text("Remove Metadata (EXIF)")
                                    }
                                }
                                .toggleStyle(.switch)
                                .padding(.top, 2)

                                if let estimatedSize = estimatedSize {
                                    Text("Estimated size: \(formatBytes(estimatedSize))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }

                                if !selectedFormat.allowsQuality {
                                    Text("\(selectedFormat.rawValue) is lossless.")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: hasUncompressedImages)
                    }

                    // Button Bar (always at the very bottom)
                    VStack(spacing: 10) {
                        Divider()
                        HStack(spacing: 10) {
                            ActionButton(
                                label: "Gallery",
                                systemImage: "photo",
                                color: .accentColor,
                                action: { withAnimation { showPicker = true } }
                            )
                            ActionButton(
                                label: isCompressing ? "\(Int(progress * 100))%" : "Compress",
                                systemImage: isCompressing ? "arrow.down.circle" : "arrow.down.circle.fill",
                                color: isCompressing ? .gray : .blue,
                                action: { withAnimation { compressAllImages() } },
                                isLoading: isCompressing,
                                isDisabled: imageFiles.isEmpty || isCompressing || !hasUncompressedImages
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(radius: 6)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle("Compressor")
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $showPicker) {
                PhotoPicker { uiimages in
                    if let image = uiimages.first {
                        let fileName = UUID().uuidString + ".jpg"
                        if let data = image.jpegData(compressionQuality: 1.0) {
                            let origPath = saveImageFile(data: data, name: fileName)
                            let imgFile = ImageFile(
                                id: UUID(),
                                fileName: fileName,
                                format: "jpeg",
                                fileSize: data.count,
                                width: Int(image.size.width),
                                height: Int(image.size.height),
                                originalPath: origPath,
                                compressedPath: nil,
                                compressedSize: nil,
                                compressedFormat: nil
                            )
                            withAnimation { imageFiles = [imgFile] }
                        }
                    }
                }
            }
            .alert(isPresented: $showSaveResult) {
                Alert(title: Text("Result"), message: Text(saveResultMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showShareSheet) {
                if let item = shareItem {
                    ShareSheet(activityItems: [item])
                }
            }
            // TRIGGER ESTIMATION WHENEVER ANY OPTION CHANGES
            .onChange(of: compressionQuality) { _ in estimateOutputSize() }
            .onChange(of: selectedFormat) { _ in estimateOutputSize() }
            .onChange(of: resizeMode) { _ in estimateOutputSize() }
            .onChange(of: resizeValue) { _ in estimateOutputSize() }
            .onChange(of: removeMetadata) { _ in estimateOutputSize() }
            .onChange(of: imageFiles) { _ in estimateOutputSize() }
        }
    }

    func share(item: Any) {
        shareItem = item
        showShareSheet = true
    }
    func saveImageToPhotos(path: String) {
        if let image = UIImage(contentsOfFile: path) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            saveResultMessage = "Image saved to Photos."
        } else {
            saveResultMessage = "Failed to load image."
        }
        showSaveResult = true
    }

    func compressAllImages() {
        isCompressing = true
        progress = 0.0
        let group = DispatchGroup()
        for (idx, file) in imageFiles.enumerated() {
            group.enter()
            compressImage(
                imgFile: file,
                format: selectedFormat,
                quality: compressionQuality,
                resizeMode: resizeMode,
                resizeValue: resizeValue,
                removeMetadata: removeMetadata
            ) { compressedPath, compressedSize in
                DispatchQueue.main.async {
                    imageFiles[idx].compressedPath = compressedPath
                    imageFiles[idx].compressedSize = compressedSize
                    imageFiles[idx].compressedFormat = selectedFormat
                    if let compressedPath = compressedPath, let compressedSize = compressedSize {
                        var hist = imageFiles[idx]
                        hist.compressedPath = compressedPath
                        hist.compressedSize = compressedSize
                        hist.compressedFormat = selectedFormat
                        historyStore.add(hist)
                    }
                    withAnimation(.easeInOut) {
                        progress = Double(idx + 1) / Double(imageFiles.count)
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            withAnimation(.easeInOut) {
                isCompressing = false
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                       playSystemSound()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            }
        }
    }

    // Advanced compressImage with resizing and metadata stripping
    func compressImage(
        imgFile: ImageFile,
        format: CompressionFormat,
        quality: Double,
        resizeMode: ResizeMode,
        resizeValue: Double,
        removeMetadata: Bool,
        completion: @escaping (String?, Int?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let origPath = imgFile.originalPath, var image = UIImage(contentsOfFile: origPath) else {
                completion(nil, nil)
                return
            }
            // --- Resize if needed ---
            if resizeMode != .none {
                let newSize: CGSize
                switch resizeMode {
                case .none:
                    newSize = image.size
                case .percent:
                    newSize = CGSize(width: image.size.width * resizeValue / 100,
                                     height: image.size.height * resizeValue / 100)
                case .width:
                    newSize = CGSize(width: resizeValue, height: image.size.height * (resizeValue / image.size.width))
                case .height:
                    newSize = CGSize(width: image.size.width * (resizeValue / image.size.height), height: resizeValue)
                }
                UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                image = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            }

            // --- Prepare compression ---
            var data: Data?
            var ext = format.fileExtension
            switch format {
                case .jpeg:
                    data = image.jpegData(compressionQuality: quality)
                case .png:
                    data = image.pngData()
                case .heic:
                    if #available(iOS 11.0, *), let cgimg = image.cgImage {
                        let cfdata = NSMutableData()
                        if let dest = CGImageDestinationCreateWithData(cfdata, AVFileType.heic as CFString, 1, nil) {
                            let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
                            CGImageDestinationAddImage(dest, cgimg, props as CFDictionary)
                            if CGImageDestinationFinalize(dest) {
                                data = cfdata as Data
                            }
                        }
                    }
            }
            // --- Remove metadata if requested ---
            if removeMetadata, let data = data, let source = CGImageSourceCreateWithData(data as CFData, nil) {
                let uti = CGImageSourceGetType(source)!
                let cfdata = NSMutableData()
                if let dest = CGImageDestinationCreateWithData(cfdata, uti, 1, nil) {
                    CGImageDestinationAddImageFromSource(dest, source, 0, nil) // no metadata
                    if CGImageDestinationFinalize(dest) {
                        completion(saveImageFile(data: cfdata as Data, name: UUID().uuidString + "." + ext), cfdata.length)
                        return
                    }
                }
            }
            if let data = data {
                let compressedFileName = UUID().uuidString + "." + ext
                let compressedPath = saveImageFile(data: data, name: compressedFileName)
                completion(compressedPath, data.count)
            } else {
                completion(nil, nil)
            }
        }
    }

    // Estimate output size in memory
    func estimateOutputSize() {
        guard let imgFile = imageFiles.first,
              var image = UIImage(contentsOfFile: imgFile.originalPath ?? "") else {
            estimatedSize = nil
            return
        }

        // Resize
        if resizeMode != .none {
            let newSize: CGSize
            switch resizeMode {
            case .none:
                newSize = image.size
            case .percent:
                newSize = CGSize(width: image.size.width * resizeValue / 100,
                                 height: image.size.height * resizeValue / 100)
            case .width:
                newSize = CGSize(width: resizeValue, height: image.size.height * (resizeValue / image.size.width))
            case .height:
                newSize = CGSize(width: image.size.width * (resizeValue / image.size.height), height: resizeValue)
            }
            UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            image = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }

        // Compression
        var data: Data?
        switch selectedFormat {
            case .jpeg:
                data = image.jpegData(compressionQuality: compressionQuality)
            case .png:
                data = image.pngData()
            case .heic:
                if #available(iOS 11.0, *), let cgimg = image.cgImage {
                    let cfdata = NSMutableData()
                    if let dest = CGImageDestinationCreateWithData(cfdata, AVFileType.heic as CFString, 1, nil) {
                        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
                        CGImageDestinationAddImage(dest, cgimg, props as CFDictionary)
                        if CGImageDestinationFinalize(dest) {
                            data = cfdata as Data
                        }
                    }
                }
        }
        // Remove metadata (simulate, only Data length)
        if removeMetadata, let data = data, let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let uti = CGImageSourceGetType(source)!
            let cfdata = NSMutableData()
            if let dest = CGImageDestinationCreateWithData(cfdata, uti, 1, nil) {
                CGImageDestinationAddImageFromSource(dest, source, 0, nil)
                if CGImageDestinationFinalize(dest) {
                    estimatedSize = cfdata.length
                    return
                }
            }
        }
        if let data = data {
            estimatedSize = data.count
        } else {
            estimatedSize = nil
        }
    }
}

// Resize mode enum
enum ResizeMode: String, CaseIterable, Identifiable {
    case none = "No Resize"
    case percent = "By %"
    case width = "By Width"
    case height = "By Height"
    var id: String { self.rawValue }
}

func formatBytes(_ bytes: Int) -> String {
    let kb = Double(bytes) / 1024.0
    if kb < 1024 { return String(format: "%.1f KB", kb) }
    let mb = kb / 1024.0
    return String(format: "%.2f MB", mb)
}

func playSystemSound() {
    AudioServicesPlaySystemSound(1324) // 1057 is Mail Sent, or try 1001 for SMS Sent, 1113 for Tink
}




// MARK: - Action Button (Animated)

struct ActionButton: View {
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label)
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .font(.headline)
            .foregroundColor(isDisabled ? .gray : color)
            .frame(maxWidth: .infinity)
            .padding(10)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
        }
        .background(.thinMaterial)
        .cornerRadius(12)
        .disabled(isDisabled)
    }
}

// MARK: - Image Card View (Animated)

struct ImageCardView: View {
    let img: ImageFile
    let onShareOriginal: ()->Void
    let onSaveOriginal: ()->Void
    let onShareCompressed: ()->Void
    let onSaveCompressed: ()->Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                if let image = img.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 2)
                        .transition(.scale)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(img.fileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    FormatBadge(format: img.format)
                    Text("Size: \(formatBytes(img.fileSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Dim: \(img.width)x\(img.height)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            // ...rest unchanged...

            if let cpath = img.compressedPath,
               let csize = img.compressedSize,
               let cfmt = img.compressedFormat,
               let cimg = img.compressedImage {
                Divider()
                HStack {
                    Image(uiImage: cimg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .cornerRadius(8)
                        .transition(.scale)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compressed (\(cfmt.rawValue))")
                            .font(.subheadline.bold())
                        Text("Size: \(formatBytes(csize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            HStack(spacing: 16) {
                Menu("Original...") {
                    Button("Share", action: onShareOriginal)
                    Button("Save to Photos", action: onSaveOriginal)
                }
                .menuStyle(.borderlessButton)
                if img.compressedPath != nil {
                    Menu("Compressed...") {
                        Button("Share", action: onShareCompressed)
                        Button("Save to Photos", action: onSaveCompressed)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(radius: 2)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
// MARK: - History Tab (with Animation)

struct HistoryView: View {
    @EnvironmentObject var historyStore: CompressionHistoryStore
    @State private var showShareSheet = false
    @State private var shareItem: Any?

    var body: some View {
        NavigationView {
            if historyStore.history.filter({ $0.compressedPath != nil }).isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .opacity(0.18)
                        .transition(.opacity)
                    Text("No history yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .navigationTitle("History")
                .animation(.easeInOut, value: historyStore.history)
            } else {
                List {
                    ForEach(historyStore.history.filter { $0.compressedPath != nil }) { img in
                        HistoryCardView(img: img,
                            onShareOriginal: { if let uiimg = img.image { share(item: uiimg) } },
                            onShareCompressed: { if let cimg = img.compressedImage { share(item: cimg) } },
                            onDelete: { withAnimation { historyStore.remove(img) } }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("History")
                .animation(.spring(), value: historyStore.history)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") { withAnimation { historyStore.clear() } }
                            .foregroundColor(.red)
                            .disabled(historyStore.history.isEmpty)
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let item = shareItem {
                        ShareSheet(activityItems: [item])
                    }
                }
            }
        }
    }
    func share(item: Any) {
        shareItem = item
        showShareSheet = true
    }
}

// MARK: - History Card View (Animated)

struct HistoryCardView: View {
    let img: ImageFile
    let onShareOriginal: ()->Void
    let onShareCompressed: ()->Void
    let onDelete: ()->Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                if let image = img.compressedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 1)
                        .transition(.scale)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(img.fileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let fmt = img.compressedFormat {
                        Text("Format: \(fmt.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let compressedSize = img.compressedSize {
                        Text("Size: \(formatBytes(compressedSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Dim: \(img.width)x\(img.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Button("Share Original", action: onShareOriginal)
                    Button("Share Compressed", action: onShareCompressed)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .padding(.horizontal, 2)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
        .shadow(radius: 1)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Pickers

struct PhotoPicker: UIViewControllerRepresentable {
    let completion: ([UIImage])->Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .any(of: [.images])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            var images: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let uiimg = obj as? UIImage { images.append(uiimg) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.completion(images)
            }
        }
    }
}


// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - FORMAT BADGE

struct FormatBadge: View {
    let format: String
    var color: Color {
        switch format.lowercased() {
            case "jpeg", "jpg": return .orange
            case "png": return .blue
            case "heic", "heif": return .green
            case "gif": return .purple
            default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .font(.system(size: 13, weight: .bold))
            Text(format.uppercased())
                .font(.caption).bold()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.18))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}






