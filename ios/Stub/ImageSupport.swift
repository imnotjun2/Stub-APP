import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct StubImage: View {
    @EnvironmentObject private var store: ArchiveStore

    let reference: MediaReference
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = platformImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ContentUnavailableView(
                    "Image unavailable",
                    systemImage: "photo.badge.exclamationmark"
                )
            }
        }
        .accessibilityHidden(platformImage == nil)
    }

    private var platformImage: Image? {
        let url: URL?
        switch reference.location {
        case .bundled:
            let parts = reference.value.split(separator: ".", maxSplits: 1).map(String.init)
            url = Bundle.main.url(
                forResource: parts.first,
                withExtension: parts.count > 1 ? parts[1] : nil
            )
        case .stored:
            url = store.storedURL(for: reference)
        }
        guard let url else { return nil }

        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

struct DraftImage: View {
    let data: Data
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = platformImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(28)
            }
        }
    }

    private var platformImage: Image? {
        #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
        NSImage(data: data).map(Image.init(nsImage:))
        #else
        nil
        #endif
    }
}

enum ImageCodec {
    static func prepareForStorage(_ data: Data, maxDimension: CGFloat = 2600) -> Data {
        #if canImport(UIKit)
        guard let source = UIImage(data: data) else { return data }
        let longest = max(source.size.width, source.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.84) ?? data
        #else
        return data
        #endif
    }
}

#if canImport(UIKit)
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (Data) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                onImage(ImageCodec.prepareForStorage(data))
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif
