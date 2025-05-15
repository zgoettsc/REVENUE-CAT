import SwiftUI
import MessageUI

// Message Compose View Helper - moved to a separate file to avoid duplication
struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    @Binding var isShowing: Bool
    var completion: (MessageComposeResult) -> Void
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposeView
        
        init(_ parent: MessageComposeView) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            parent.isShowing = false
            parent.completion(result)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        if !MFMessageComposeViewController.canSendText() {
            // SMS services are not available
            let alert = UIAlertController(
                title: "SMS Not Available",
                message: "Your device cannot send text messages.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            return alert
        }
        
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
