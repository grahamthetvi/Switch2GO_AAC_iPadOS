import SwiftUI
import PhotosUI

/// Image/emoji picker with 14 built-in symbols + custom options
struct ImagePickerView: View {
    @Environment(\.openURL) private var openURL

    let selectedImage: String?
    let onImageSelected: (String?) -> Void
    let onCancel: () -> Void
    
    @State private var showingPhotoPicker = false
    @State private var showingEmojiKeyboard = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Special Options
                    VStack(spacing: 12) {
                        specialButton(
                            title: "None",
                            icon: "slash.circle",
                            color: .gray
                        ) {
                            onImageSelected(nil)
                        }
                        
                        specialButton(
                            title: "Use Emoji",
                            icon: "face.smiling",
                            color: .orange
                        ) {
                            showingEmojiKeyboard = true
                        }
                        
                        specialButton(
                            title: "Add Custom Image",
                            icon: "photo.on.rectangle.angled",
                            color: .blue
                        ) {
                            showingPhotoPicker = true
                        }

                        specialButton(
                            title: "Open Image Tool",
                            icon: "globe",
                            color: .green
                        ) {
                            openImageTool()
                        }
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showingEmojiKeyboard) {
                EmojiKeyboardView(
                    onEmojiSelected: { emoji in
                        onImageSelected("emoji:\(emoji)")
                        showingEmojiKeyboard = false
                    },
                    onCancel: {
                        showingEmojiKeyboard = false
                    }
                )
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let relativeRef = saveImageToDocuments(data: data) {
                            onImageSelected(relativeRef)
                        }
                    }
                }
            }
        }
    }
    
    private func specialButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if title == "None" && selectedImage == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func openImageTool() {
        guard let url = URL(string: "https://switch2goaac.org/index.html#image-tool") else { return }
        openURL(url)
    }
    
    /// Saves image under Documents/Images/ and returns a relative ref.
    private func saveImageToDocuments(data: Data) -> String? {
        guard let image = UIImage(data: data) else {
            DebugLog.error("Invalid image data, cannot create UIImage", tag: "ImagePickerView")
            return nil
        }

        let isTransparent = image.hasAlpha()
        let imageData: Data?
        if isTransparent {
            imageData = image.pngData()
        } else {
            imageData = image.jpegData(compressionQuality: 0.85)
        }

        guard let finalData = imageData else {
            DebugLog.error("Failed to convert image to final format", tag: "ImagePickerView")
            return nil
        }

        let ext = isTransparent ? "png" : "jpg"
        guard let relativeRef = MediaStorage.saveImage(data: finalData, preferredExtension: ext) else {
            return nil
        }
        DebugLog.info("Image saved as relative ref: \(relativeRef)", tag: "ImagePickerView")
        return relativeRef
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func hasAlpha() -> Bool {
        guard let cgImage = self.cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first || 
               alphaInfo == .last || 
               alphaInfo == .premultipliedFirst || 
               alphaInfo == .premultipliedLast
    }
}

#Preview {
    ImagePickerView(
        selectedImage: nil,
        onImageSelected: { _ in },
        onCancel: {}
    )
}
