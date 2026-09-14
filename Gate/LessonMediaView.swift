import CryptoKit
import SwiftUI
import UIKit

/// Small persistent cache for the explicitly attributed media in the bundled catalog.
private actor LessonMediaCache {
    static let shared = LessonMediaCache()
    private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GateLessonMedia", isDirectory: true)

    func data(for address: String) async throws -> Data {
        guard let url = URL(string: address), url.scheme == "https" else { throw URLError(.badURL) }
        let key = SHA256.hash(data: Data(address.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = folder.appendingPathComponent(key)
        if let cached = try? Data(contentsOf: file) { return cached }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              http.mimeType?.hasPrefix("image/") == true, data.count <= 12_000_000 else {
            throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        trimCache()
        return data
    }

    private func trimCache() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        let entries = files.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 < $1.1 }
        var total = entries.reduce(0) { $0 + $1.2 }
        for (url, _, bytes) in entries where total > 64_000_000 {
            try? FileManager.default.removeItem(at: url); total -= bytes
        }
    }
}

struct LessonMediaView: View {
    let media: LessonPhoto
    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0
    @State private var enlarged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image {
                Button { enlarged = true } label: {
                    Image(uiImage: image).resizable().scaledToFit()
                        .padding(8).frame(maxWidth: .infinity)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityLabel((media.alt ?? media.caption) + ". Bild vergrössern")
                Label("Antippen & vergrössern", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption).foregroundStyle(.secondary)
            } else if failed {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Bild gerade nicht erreichbar", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                    Text(media.alt ?? media.caption).font(.subheadline).foregroundStyle(.secondary)
                    Button("Erneut laden") { attempt += 1 }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(GateDesign.paper).clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ProgressView("Abbildung laden …").frame(maxWidth: .infinity).frame(height: 150)
            }
            Text(media.caption).font(.subheadline).lineSpacing(3)
            credits
        }
        .task(id: media.url + ":\(attempt)") {
            failed = false
            do {
                let data = try await LessonMediaCache.shared.data(for: media.url)
                try Task.checkCancellation()
                guard let decoded = UIImage(data: data) else { failed = true; return }
                image = decoded
            } catch is CancellationError { }
            catch {
                if !Task.isCancelled { failed = true }
            }
        }
        .sheet(isPresented: $enlarged) {
            NavigationStack {
                VStack(spacing: 0) {
                    if let image { ZoomableLessonImage(image: image).accessibilityLabel(media.alt ?? media.caption) }
                    ScrollView { VStack(alignment: .leading, spacing: 12) {
                        Text(media.caption).font(.subheadline)
                        credits
                    }.padding(20) }.frame(maxHeight: 190)
                }.background(GateDesign.paper).navigationTitle("Abbildung").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { enlarged = false } } }
            }.tint(GateDesign.accent)
        }
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = URL(string: media.sourceURL) {
                Link(media.credit + " ↗", destination: url).font(.caption).frame(minHeight: 44, alignment: .leading)
            }
            if let label = media.license, let address = media.licenseURL, let url = URL(string: address) {
                Link(label, destination: url).font(.caption).frame(minHeight: 44, alignment: .leading)
            }
        }.foregroundStyle(GateDesign.accent)
    }
}

private struct ZoomableLessonImage: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> ImageZoomView { ImageZoomView(image: image) }
    func updateUIView(_ view: ImageZoomView, context: Context) {}
}

private final class ImageZoomView: UIScrollView, UIScrollViewDelegate {
    private let picture: UIImageView
    private var previousSize = CGSize.zero
    init(image: UIImage) {
        picture = UIImageView(image: image)
        super.init(frame: .zero)
        picture.frame = CGRect(origin: .zero, size: image.size)
        picture.backgroundColor = .white
        addSubview(picture); delegate = self
        contentSize = image.size
        showsVerticalScrollIndicator = false; showsHorizontalScrollIndicator = false
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom))
        doubleTap.numberOfTapsRequired = 2; addGestureRecognizer(doubleTap)
    }
    required init?(coder: NSCoder) { fatalError("Use init(image:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != previousSize, bounds.width > 0, bounds.height > 0 {
            previousSize = bounds.size
            let size = picture.image?.size ?? CGSize(width: 1, height: 1)
            let fit = min(bounds.width / max(1, size.width), bounds.height / max(1, size.height))
            minimumZoomScale = fit; maximumZoomScale = max(1, fit * 5); zoomScale = fit
        }
        contentInset = UIEdgeInsets(top: max(0, (bounds.height - contentSize.height) / 2),
                                   left: max(0, (bounds.width - contentSize.width) / 2), bottom: 0, right: 0)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { picture }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { setNeedsLayout() }
    @objc private func toggleZoom() {
        setZoomScale(zoomScale > minimumZoomScale * 1.1 ? minimumZoomScale : min(maximumZoomScale, minimumZoomScale * 2.5),
                     animated: !UIAccessibility.isReduceMotionEnabled)
    }
}
