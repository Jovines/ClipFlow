import SwiftUI

struct ImagePreviewView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()

                if let imagePath = item.imagePath,
                   let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath),
                   let nsImage = NSImage(data: imageData) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    scale = scale > 1.0 ? 1.0 : 2.0
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Unable to load image")
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Image Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { withAnimation { scale = max(0.5, scale - 0.25) } }) {
                            Image(systemName: "minus.magnifyingglass")
                        }

                        Button(action: { withAnimation { scale = 1.0 } }) {
                            Image(systemName: "arrow.counterclockwise")
                        }

                        Button(action: { withAnimation { scale = min(3.0, scale + 0.25) } }) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
