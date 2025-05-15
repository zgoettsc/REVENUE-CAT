import SwiftUI
import FirebaseDatabase

struct InvitationCodeView: View {
    @ObservedObject var appData: AppData
    @State private var invitationCode: String = ""
    @State private var name: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter your invitation details")) {
                    TextField("Invitation Code", text: $invitationCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                    
                    TextField("Your Name", text: $name)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: validateInvitation) {
                        if isValidating {
                            ProgressView()
                        } else {
                            Text("Join Room")
                        }
                    }
                    .disabled(invitationCode.isEmpty || name.isEmpty || isValidating)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Join with Invitation")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
    }
    
    func validateInvitation() {
        let dbRef = Database.database().reference()
        isValidating = true
        errorMessage = nil
        
        print("Starting invitation validation for code: \(invitationCode)")
        
        dbRef.child("invitations").child(invitationCode).observeSingleEvent(of: .value) { snapshot in
            if let invitation = snapshot.value as? [String: Any],
               let status = invitation["status"] as? String,
               (status == "invited" || status == "sent"),
               let roomId = invitation["roomId"] as? String {
                
                print("Valid invitation found. Status: \(status), RoomId: \(roomId)")
                
                // Verify room exists
                dbRef.child("rooms").child(roomId).observeSingleEvent(of: .value) { roomSnapshot in
                    guard roomSnapshot.exists() else {
                        print("Room \(roomId) does not exist")
                        self.errorMessage = "The room associated with this invitation no longer exists."
                        self.isValidating = false
                        return
                    }
                    
                    // Create a new user
                    let userId = UUID()
                    let newUser = User(
                        id: userId,
                        name: self.name,
                        isAdmin: invitation["isAdmin"] as? Bool ?? false
                    )
                    
                    print("Created new user: \(userId.uuidString), name: \(self.name)")
                    
                    // Save all operations to complete after Firebase updates
                    let completionOperations = {
                        print("Firebase operations completed, updating app state")
                        
                        // Set the current user
                        self.appData.currentUser = newUser
                        UserDefaults.standard.set(userId.uuidString, forKey: "currentUserId")
                        
                        // Explicitly clear roomCode to prevent accidental room creation
                        self.appData.roomCode = nil
                        UserDefaults.standard.removeObject(forKey: "roomCode")
                        
                        // Set the currentRoomId
                        UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                        self.appData.currentRoomId = roomId
                        
                        print("App state updated: currentUser=\(userId.uuidString), currentRoomId=\(roomId)")
                        
                        // Dismiss and proceed to app
                        DispatchQueue.main.async {
                            self.dismiss()
                        }
                    }
                    
                    // Add user to system
                    dbRef.child("users").child(userId.uuidString).setValue(newUser.toDictionary()) { error, _ in
                        if let error = error {
                            print("Error adding user: \(error.localizedDescription)")
                            self.errorMessage = "Error creating user account. Please try again."
                            self.isValidating = false
                            return
                        }
                        
                        print("User added to database successfully")
                        
                        // Grant room access
                        dbRef.child("users").child(userId.uuidString).child("roomAccess").child(roomId).setValue(true) { error, _ in
                            if let error = error {
                                print("Error setting room access: \(error.localizedDescription)")
                                self.errorMessage = "Error granting room access. Please try again."
                                self.isValidating = false
                                return
                            }
                            
                            print("Room access granted successfully")
                            
                            // Mark invitation as used
                            dbRef.child("invitations").child(self.invitationCode).updateChildValues([
                                "status": "accepted",
                                "acceptedBy": userId.uuidString
                            ]) { error, _ in
                                if let error = error {
                                    print("Error updating invitation status: \(error.localizedDescription)")
                                    // Continue anyway - this isn't critical
                                }
                                
                                print("Invitation marked as accepted")
                                
                                // Run completion operations
                                completionOperations()
                            }
                        }
                    }
                }
            } else {
                print("Invalid invitation. Snapshot exists: \(snapshot.exists()), Key: \(snapshot.key)")
                if let value = snapshot.value {
                    print("Value type: \(type(of: value))")
                }
                
                self.errorMessage = "Invalid or expired invitation code."
                self.isValidating = false
            }
        } withCancel: { error in
            print("Error validating invitation: \(error.localizedDescription)")
            self.errorMessage = "Error connecting to the server. Please try again."
            self.isValidating = false
        }
    }
}
