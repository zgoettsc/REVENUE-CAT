//
//  AccountSettingsView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/20/25.
//


import SwiftUI
import FirebaseAuth

struct AccountSettingsView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingEditNameSheet = false
    @State private var editedName = ""
    
    var body: some View {
        Form {
            Section(header: Text("ACCOUNT INFO")) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(appData.currentUser?.name ?? authViewModel.currentUser?.displayName ?? "Not set")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editedName = appData.currentUser?.name ?? authViewModel.currentUser?.displayName ?? ""
                    showingEditNameSheet = true
                }
                
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authViewModel.currentUser?.email ?? "Not set")
                        .foregroundColor(.gray)
                }
            }
            
            Section {
                Button("Sign Out") {
                    NotificationCenter.default.post(name: Notification.Name("UserDidSignOut"), object: nil)
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Account Settings")
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