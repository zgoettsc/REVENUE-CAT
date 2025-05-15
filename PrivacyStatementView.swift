import SwiftUI

struct PrivacyStatementView: View {
    @Binding var isPresented: Bool
    @State private var hasScrolledToBottom = false
    @State private var scrollPosition: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Privacy Statement & User Agreement")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Effective Date: May 4, 2025")
                        .font(.subheadline)
                        .padding(.bottom, 10)
                    
                    Group {
                        Text("1. About Tolerance Tracker")
                            .font(.headline)
                        Text("Tolerance Tracker is a privately developed mobile app created by an independent developer, a parent of a participant in the Tolerance Induction Program (TIP) offered by the Food Allergy Institute. It is not affiliated with, endorsed by, or officially connected to the Food Allergy Institute or TIP. The app uses SwiftUI and Google Firebase to help users track cycle-based allergy treatment plans, including food and medicine intake, timers, reminders, and role-based permissions.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("2. Information We Collect")
                            .font(.headline)
                        Text("We collect only the data necessary for app functionality:")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("2.1 Information You Provide")
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Cycle details (e.g., cycle number, start date, patient nickname).")
                            Text("• Item details (e.g., medicine, food, doses, units).")
                            Text("• Daily intake logs (timestamps, user identifiers).")
                            Text("• Room codes for sharing access.")
                            Text("• User preferences (e.g., reminders, units).")
                            Text("• Contact info (e.g., email) if you contact us at zack@tolerancetracker.com.")
                        }
                        .padding(.leading)
                        
                        Text("Recommendation: Avoid entering sensitive data (e.g., full names, medical diagnoses, SSNs). Use nicknames or initials instead (e.g., 'MyChild').")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("2.2 Automatically Collected Information")
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Device info (e.g., device type, iOS version, Firebase ID).")
                            Text("• Anonymized usage data (e.g., feature interactions, timestamps).")
                            Text("• Anonymized crash and performance data.")
                        }
                        .padding(.leading)
                        
                        Text("2.3 No Health Data Collection")
                            .font(.subheadline)
                        Text("The app does not collect HealthKit data or protected health information (PHI) under HIPAA.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("3. How We Use Your Information")
                            .font(.headline)
                        Text("We use data solely for app functionality, including:")
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Storing/syncing cycle plans, logs, and settings via Firebase.")
                            Text("• Displaying progress, timers, and reminders.")
                            Text("• Enabling role-based permissions and room code sharing.")
                            Text("• Sending notifications based on user settings.")
                            Text("• Responding to inquiries at zack@tolerancetracker.com.")
                            Text("• Improving app performance via anonymized data.")
                        }
                        .padding(.leading)
                        Text("We do not use data for advertising or unrelated purposes.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("4. How We Share Your Information")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Google Firebase: Processes data for syncing/storage (see Firebase Privacy Policy).")
                            Text("• Legal Obligations: If required by law (e.g., court order).")
                            Text("• Room Code Sharing: Shared codes grant access to cycle plans/logs. Share only with trusted individuals.")
                        }
                        .padding(.leading)
                        Text("We do not sell or share data with other third parties.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("5. Data Storage and Security")
                            .font(.headline)
                        Text("Data is stored in a private Firebase database, encrypted in transit (HTTPS/TLS) and at rest. We use Firebase security rules and role-based permissions to protect data. However, no system is fully secure, and we cannot guarantee absolute security.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("6. Your Data Rights")
                            .font(.headline)
                        Text("You may have rights under laws like GDPR or CCPA, including:")
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Access, correct, or delete your data.")
                            Text("• Restrict processing or request a portable copy.")
                        }
                        .padding(.leading)
                        Text("Contact zack@tolerancetracker.com to exercise rights. Deletion may limit app functionality.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("7. Children’s Privacy")
                            .font(.headline)
                        Text("The app is not intended for children under 13 without parental consent (per COPPA). We do not knowingly collect data from children under 13. Parents should use nicknames, avoid sensitive health data, and supervise room code sharing. Contact us to delete any child’s data.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("8. International Data Transfers")
                            .font(.headline)
                        Text("Data may be stored on Firebase servers outside your country (e.g., U.S.). Firebase complies with frameworks like the EU-U.S. Data Privacy Framework for lawful transfers.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("9. Third-Party Services")
                            .font(.headline)
                        Text("We use only Google Firebase for storage, syncing, and notifications. Linksучка shared via the app (e.g., room codes) may lead to external platforms (e.g., App Store), which have their own privacy policies.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("10. Retention of Data")
                            .font(.headline)
                        Text("Data is retained while you use the app. Inactive cycle plans (no updates for 12 months) may be deleted. Deletion requests are processed within 30 days.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("11. Disclaimers and Limitations")
                            .font(.headline)
                        Text("The app is an organizational tool, not a medical device. It does not provide medical advice or replace professional care. The developer is not liable for incorrect data entry, missed dosages, unauthorized access via room codes, or data breaches.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("12. Changes to This Privacy Policy")
                            .font(.headline)
                        Text("We may update this policy. Significant changes will be posted on www.zthreesolutions.com and in the app. Continued use indicates acceptance.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("13. Contact Us")
                            .font(.headline)
                        Text("For questions or requests, contact:")
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Email: zack@tolerancetracker.com\nWebsite: www.zthreesolutions.com")
                            .font(.subheadline)
                    }
                    
                    Group {
                        Text("14. Compliance with Apple Guidelines")
                            .font(.headline)
                        Text("This policy complies with Apple App Store guidelines, including data disclosure, third-party roles, children’s privacy, and user rights support.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottomMarker")
                }
                .padding(.horizontal)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollViewOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scrollView")).size.height
                        )
                    }
                )
            }
            .coordinateSpace(name: "scrollView")
            .frame(maxHeight: 400)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { height in
                scrollContentHeight = height
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        scrollViewHeight = geometry.size.height
                    }
                }
            )
            .simultaneousGesture(
                DragGesture().onChanged { value in
                    let offsetY = value.translation.height
                    if offsetY < 0 {
                        // User is scrolling down
                        scrollPosition += abs(offsetY)
                        
                        // Check if user has scrolled to bottom
                        if scrollPosition >= (scrollContentHeight - scrollViewHeight - 50) {
                            DispatchQueue.main.async {
                                self.hasScrolledToBottom = true
                            }
                        }
                    }
                }
            )
            
            HStack {
                Spacer()
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasAcceptedPrivacyPolicy")
                    isPresented = false
                }) {
                    Text("I Accept")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(hasScrolledToBottom ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!hasScrolledToBottom)
                Spacer()
            }
            .padding(.horizontal)
            
            if !hasScrolledToBottom {
                Text("Please scroll to the bottom to accept")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Text("Thank you for reviewing our policy")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            // Failsafe button
            Button("Can't accept? Tap here") {
                self.hasScrolledToBottom = true
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 5)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}
