//
//  AccountManagementView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 5/5/25.
//


import SwiftUI
import FirebaseAuth

struct AccountManagementView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditNameSheet = false
    @State private var editedName = ""
    @State private var showingDeleteAccountAlert = false
    @State private var showingAccountErrorAlert = false
    @State private var accountErrorMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("ACCOUNT INFORMATION")) {
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
            
            Section(header: Text("ACCOUNT ACTIONS")) {
                Button(action: {
                    // Clear app state first
                    appData.currentRoomId = nil
                    appData.currentUser = nil
                    UserDefaults.standard.removeObject(forKey: "currentRoomId")
                    UserDefaults.standard.removeObject(forKey: "currentUserId")
                    
                    // Now sign out of Firebase Auth
                    authViewModel.signOut()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Section(header: Text("DANGER ZONE")) {
                Button(action: {
                    showingDeleteAccountAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Delete My Account")
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text("Deleting your account will permanently remove all your data and cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Account Management")
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
        .alert(isPresented: $showingDeleteAccountAlert) {
            Alert(
                title: Text("Delete Account"),
                message: Text("This will permanently delete your account and all your data. This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    // Call delete account method
                    authViewModel.deleteAccount { success, error in
                        if success {
                            // Clear local state
                            appData.currentRoomId = nil
                            appData.currentUser = nil
                            UserDefaults.standard.removeObject(forKey: "currentRoomId")
                            UserDefaults.standard.removeObject(forKey: "currentUserId")
                            
                            // Post notification to update UI
                            NotificationCenter.default.post(name: Notification.Name("UserDidSignOut"), object: nil)
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            // Show error
                            accountErrorMessage = error ?? "Failed to delete account"
                            showingAccountErrorAlert = true
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Error", isPresented: $showingAccountErrorAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(accountErrorMessage)
        })
    }
}