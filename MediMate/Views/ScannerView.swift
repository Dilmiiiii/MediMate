import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct ScannerView: View {
    let onVerified: (ScannedMedicine) -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var cameraOpen = false
    @State private var processing = false
    @State private var showingReview = false
    @State private var data = ScannedMedicine()
    @State private var issue: String?
    @State private var cameraDenied = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Position the medication label within the frame.").font(.subheadline).foregroundStyle(.secondary)
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(MediTheme.pale)
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18)).padding(12)
                    } else {
                        VStack(spacing: 18) {
                            Image(systemName: "viewfinder").font(.system(size: 85)).foregroundStyle(MediTheme.green)
                            Text("Align the label here").font(.headline).foregroundStyle(MediTheme.green)
                        }
                    }
                }.frame(height: 270)
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(MediTheme.green.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8,5])))
                HStack {
                    Button { openCamera() } label: { Label("Capture Image", systemImage: "camera") }.buttonStyle(.bordered)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose from Gallery", systemImage: "photo")
                    }.buttonStyle(.bordered)
                }
                Button("Use Bundled Sample Label") {
                    image = UIImage(named: "SampleLabel")
                    if image == nil { issue = "Bundled sample label is missing." }
                }.font(.subheadline)
                if image != nil {
                    HStack {
                        Button("Retake") { image = nil; showingReview = false }.buttonStyle(.bordered)
                        Button(action: extract) {
                            HStack { if processing { ProgressView().tint(.white) }; Text("Extract Text") }
                        }.buttonStyle(PrimaryButtonStyle()).disabled(processing)
                    }
                }
                Button("Enter Details Manually") { onVerified(ScannedMedicine()) }
                    .buttonStyle(.bordered)
                Text("Please review all extracted information carefully before saving. Scanned text may contain errors.")
                    .font(.footnote).foregroundStyle(.secondary)
                if showingReview { review }
            }.padding(18)
        }
        .navigationTitle("Scan Medication").navigationBarTitleDisplayMode(.inline)
        .background(MediTheme.canvas)
        .sheet(isPresented: $cameraOpen) { CameraCaptureView(image: $image) }
        .onChange(of: selectedPhoto) { _, item in
            Task { if let bytes = try? await item?.loadTransferable(type: Data.self) { image = UIImage(data: bytes) } }
        }
        .alert("Unable to Read Label", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
            Button("OK", role: .cancel) { issue = nil }
        } message: { Text(issue ?? "Try again in better lighting or enter details manually.") }
        .alert("Camera Access Required", isPresented: $cameraDenied) {
            Button("OK", role: .cancel) { }
        } message: { Text("Enable camera access in Settings to scan labels.") }
    }
    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review Extracted Details").font(.title3.bold())
            TextField("Medicine Name", text: $data.name).textFieldStyle(.roundedBorder).focused($nameFocused)
            Button("Edit Information") { nameFocused = true }.font(.subheadline)
            TextField("Strength", text: $data.strength).textFieldStyle(.roundedBorder)
            TextField("Instructions", text: $data.instructions).textFieldStyle(.roundedBorder)
            TextField("Expiry Date (if readable)", text: $data.expiry).textFieldStyle(.roundedBorder)
            DisclosureGroup("Full recognized text") { Text(data.rawText).font(.caption).textSelection(.enabled) }
            Label("Verify Scanned Details", systemImage: "exclamationmark.shield")
                .font(.subheadline.bold()).foregroundStyle(MediTheme.amber)
            Text("Check the medicine information before saving. MediMate does not provide prescribing advice.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Confirm & Continue") {
                if data.name.trimmingCharacters(in: .whitespaces).isEmpty { issue = "Enter a valid medication name before continuing." }
                else { onVerified(data) }
            }.buttonStyle(PrimaryButtonStyle())
            Button("Scan Again") { showingReview = false; image = nil }.buttonStyle(.bordered)
        }.mediCard()
    }
    private func extract() {
        guard let image else { return }
        processing = true; showingReview = false
        Task {
            do { data = try await OCRService.recognize(image); showingReview = true }
            catch { issue = "Try again in better lighting or enter details manually. (\(error.localizedDescription))" }
            processing = false
        }
    }
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            issue = "Camera unavailable on this device. Choose a photo or the bundled sample label instead."; return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraOpen = true
        case .notDetermined:
            Task { let granted = await AVCaptureDevice.requestAccess(for: .video); cameraOpen = granted; cameraDenied = !granted }
        default: cameraDenied = true
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView
        init(parent: CameraCaptureView) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
