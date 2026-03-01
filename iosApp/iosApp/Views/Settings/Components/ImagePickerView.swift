import SwiftUI
import PhotosUI

/// Image/emoji picker with 14 built-in symbols + custom options
struct ImagePickerView: View {
    let selectedImage: String?
    let onImageSelected: (String?) -> Void
    let onCancel: () -> Void
    
    @State private var showingPhotoPicker = false
    @State private var showingEmojiKeyboard = false
    @State private var showingWikimediaSearch = false
    @State private var showingComingSoonAlert = false
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
                            title: "Search Wikimedia Images",
                            icon: "globe",
                            color: .green
                        ) {
                            showingComingSoonAlert = true
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
            .alert("Coming Soon", isPresented: $showingComingSoonAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Wikimedia image search will be available in a future update. For now, you can use custom images from your photo library or choose an emoji.")
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        // Save to documents directory
                        if let imageUrl = saveImageToDocuments(data: data) {
                            onImageSelected(imageUrl.absoluteString)
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
    
    private func saveImageToDocuments(data: Data) -> URL? {
        // Validate the data can be converted to UIImage first
        guard let image = UIImage(data: data) else {
            print("ImagePickerView: Invalid image data, cannot create UIImage")
            return nil
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Determine format and save with appropriate extension
        let isTransparent = image.hasAlpha()
        let fileName = "custom_image_\(UUID().uuidString).\(isTransparent ? "png" : "jpg")"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        print("ImagePickerView: Saving image to: \(fileURL.path)")
        print("ImagePickerView: Image size: \(image.size), has alpha: \(isTransparent)")
        
        // Convert to appropriate format
        let imageData: Data?
        if isTransparent {
            imageData = image.pngData()
        } else {
            imageData = image.jpegData(compressionQuality: 0.85)
        }
        
        guard let finalData = imageData else {
            print("ImagePickerView: Failed to convert image to final format")
            return nil
        }
        
        do {
            try finalData.write(to: fileURL)
            
            // Verify the file was written
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("ImagePickerView: File saved successfully, size: \(fileSize) bytes")
            }
            
            return fileURL
        } catch {
            print("ImagePickerView: Error saving image: \(error.localizedDescription)")
            return nil
        }
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
