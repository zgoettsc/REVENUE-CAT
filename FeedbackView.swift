//
//  FeedbackView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//


import SwiftUI
import MessageUI

struct FeedbackView: View {
    @State private var feedbackText: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingMailSheet = false
    @State private var showingMailError = false
    @State private var showingSuccessAlert = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Your Feedback")) {
                TextField("What would you like to tell us? Please be specific if describing an issue.", text: $feedbackText, axis: .vertical)
                    .lineLimit(5...10)
            }
            
            Section(header: Text("Add a Screenshot")) {
                HStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } else {
                        Text("No image selected")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Text(selectedImage == nil ? "Add Image" : "Change")
                    }
                }
            }
            
            Section {
                Button(action: {
                    if MFMailComposeViewController.canSendMail() {
                        showingMailSheet = true
                    } else {
                        showingMailError = true
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Submit Feedback")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(feedbackText.isEmpty)
            }
        }
        .navigationTitle("Send Feedback")
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingMailSheet) {
            MailComposeView(
                feedbackText: feedbackText,
                selectedImage: selectedImage,
                onDismiss: { result in
                    if result == .sent {
                        showingSuccessAlert = true
                    }
                }
            )
        }
        .alert("Email Not Available", isPresented: $showingMailError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device is not configured to send emails. Please check your email settings.")
        }
        .alert("Thank You!", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { 
                dismiss()
            }
        } message: {
            Text("Your feedback has been sent. We appreciate your input!")
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    var feedbackText: String
    var selectedImage: UIImage?
    var onDismiss: (MFMailComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject("Tolerance Tracker Feedback")
        vc.setToRecipients(["zack@tolerancetracker.com"]) // Replace with your email
        vc.setMessageBody(feedbackText, isHTML: false)
        
        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
            vc.addAttachmentData(imageData, mimeType: "image/jpeg", fileName: "screenshot.jpg")
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            parent.onDismiss(result)
        }
    }
}
