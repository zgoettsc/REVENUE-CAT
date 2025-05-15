import SwiftUI

struct SettingsView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingRoomCodeSheet = false
    @State private var newRoomCode = ""
    @State private var showingConfirmation = false
    @State private var showingShareSheet = false
    @State private var selectedUser: User?
    @State private var showingEditNameSheet = false
    @State private var editedName = ""
    @State private var showingDeleteAccountAlert = false
    @State private var showingAccountErrorAlert = false
    @State private var accountErrorMessage = ""
    @State private var showingOnboardingTutorial = false
    
    // Helper function to calculate days until food challenge
    private var daysUntilFoodChallenge: String {
        guard let cycle = appData.cycles.first else {
            return "No cycle available"
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: cycle.foodChallengeDate)
        if let days = components.day {
            return days >= 0 ? "\(days) day\(days == 1 ? "" : "s") remaining" : "Food challenge date passed"
        }
        return "Unknown"
    }
    
    var body: some View {
        List {
            // New Food Challenge Section
            Section(header: Text("FOOD CHALLENGE")) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.purple)
                    Text("Days until Food Challenge")
                        .font(.headline)
                    Spacer()
                    Text(daysUntilFoodChallenge)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            // Plan section
            if appData.currentUser?.isAdmin ?? false {
                Section(header: Text("PLAN MANAGEMENT")) {
                    NavigationLink(destination: EditPlanView(appData: appData)) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.blue)
                            Text("Edit Plan")
                                .font(.headline)
                        }
                    }
                }
            }
            
            // Notifications section
            Section(header: Text("NOTIFICATIONS")) {
                NavigationLink(destination: NotificationsView(appData: appData)) {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.orange)
                        Text("Notifications")
                            .font(.headline)
                    }
                }
            }
            
            // OTHER SECTION
            Section(header: Text("OTHER")) {
                NavigationLink(destination: HistoryView(appData: appData)) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.green)
                        Text("History")
                            .font(.headline)
                    }
                }
                
                NavigationLink(destination: ReactionsView(appData: appData)) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Reactions")
                            .font(.headline)
                    }
                }
                
                NavigationLink(destination: ContactTIPsView()) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.indigo)
                        Text("Contact TIPs")
                            .font(.headline)
                    }
                }
                
                // Add this new NavigationLink:
                NavigationLink(destination: FeedbackView()) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Send Feedback")
                            .font(.headline)
                    }
                }
                Button(action: {
                    showingOnboardingTutorial = true
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.teal)
                        Text("App Tutorial")
                            .font(.headline)
                    }
                }
                .sheet(isPresented: $showingOnboardingTutorial) {
                    OnboardingView(isShowingOnboarding: $showingOnboardingTutorial)
                }
            }
            
            // Add this to SettingsView.swift inside the body List
            Section(header: Text("ROOMS, USERS, SUBSCRIPTIONS")) {
                NavigationLink(destination: ManageRoomsAndSubscriptionsView(appData: appData)) {
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(.teal)
                        Text("Rooms and Subscriptions")
                            .font(.headline)
                    }
                }
                if appData.currentUser?.isAdmin ?? false {
                    NavigationLink(destination:         UserManagementView(appData: appData)) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.purple)
                            Text("Invite & Manage Room Users")
                                .font(.headline)
                        }
                    }
                }
            }

            Section(header: Text("ACCOUNT")) {
                NavigationLink(destination: AccountManagementView(appData: appData)) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        Text("Account Management")
                            .font(.headline)
                    }
                }
            
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingEditNameSheet) {
            NavigationView {
                Form {
                    TextField("Your Name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .navigationTitle("Edit Your Name")
                .navigationBarItems(
                    leading: Button("Cancel") { showingEditNameSheet = false },
                    trailing: Button("Save") {
                        if let user = appData.currentUser, !editedName.isEmpty {
                            let updatedUser = User(
                                id: user.id,
                                name: editedName,
                                isAdmin: user.isAdmin,
                                remindersEnabled: user.remindersEnabled,
                                reminderTimes: user.reminderTimes,
                                treatmentFoodTimerEnabled: user.treatmentFoodTimerEnabled,
                                treatmentTimerDuration: user.treatmentTimerDuration
                            )
                            appData.addUser(updatedUser)
                            if appData.currentUser?.id == user.id {
                                appData.currentUser = updatedUser
                            }
                        }
                        showingEditNameSheet = false
                    }
                    .disabled(editedName.isEmpty)
                )
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
