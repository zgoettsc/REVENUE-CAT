import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct JoinRoomView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var invitationCode: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter invitation code")) {
                    TextField("Invitation Code", text: $invitationCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
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
                    .disabled(invitationCode.isEmpty || isValidating)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Join Room")
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
               (status == "invited" || status == "sent" || status == "created"),
               let roomId = invitation["roomId"] as? String,
               let phoneNumber = invitation["phoneNumber"] as? String,
               phoneNumber.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil || phoneNumber.isEmpty {
                // Proceed with existing logic
                
                print("Valid invitation found. Status: \(status), RoomId: \(roomId)")
                
                dbRef.child("rooms").child(roomId).observeSingleEvent(of: .value) { roomSnapshot in
                    guard roomSnapshot.exists() else {
                        print("Room \(roomId) does not exist")
                        self.errorMessage = "The room associated with this invitation no longer exists."
                        self.isValidating = false
                        return
                    }
                    
                    if let firebaseUser = Auth.auth().currentUser {
                        let authUserId = firebaseUser.uid
                        dbRef.child("auth_mapping").child(authUserId).observeSingleEvent(of: .value) { authMapSnapshot in
                            if let userIdString = authMapSnapshot.value as? String {
                                let joinedAt = ISO8601DateFormatter().string(from: Date())
                                
                                // Update room access with new format
                                let roomAccessData: [String: Any] = [
                                    "isActive": true,
                                    "joinedAt": joinedAt
                                ]
                                
                                // Mark all other rooms as inactive
                                dbRef.child("users").child(userIdString).child("roomAccess").observeSingleEvent(of: .value) { roomAccessSnapshot in
                                    var updatedRoomAccess: [String: [String: Any]] = [:]
                                    
                                    if let existingAccess = roomAccessSnapshot.value as? [String: Any] {
                                        for (existingRoomId, accessData) in existingAccess {
                                            var newAccess: [String: Any]
                                            
                                            if let accessDict = accessData as? [String: Any] {
                                                newAccess = accessDict
                                            } else if accessData as? Bool == true {
                                                newAccess = [
                                                    "joinedAt": joinedAt,
                                                    "isActive": false
                                                ]
                                            } else {
                                                continue
                                            }
                                            
                                            newAccess["isActive"] = false
                                            updatedRoomAccess[existingRoomId] = newAccess
                                        }
                                    }
                                    
                                    // Add current room as active
                                    updatedRoomAccess[roomId] = roomAccessData
                                    
                                    dbRef.child("users").child(userIdString).child("roomAccess").setValue(updatedRoomAccess) { error, _ in
                                        if let error = error {
                                            self.errorMessage = "Error granting room access: \(error.localizedDescription)"
                                            self.isValidating = false
                                            return
                                        }
                                        
                                        // Add user to room's users collection
                                        dbRef.child("rooms").child(roomId).child("users").child(userIdString).setValue([
                                            "id": userIdString,
                                            "name": firebaseUser.displayName ?? "User",
                                            "isAdmin": invitation["isAdmin"] as? Bool ?? false,
                                            "joinedAt": joinedAt
                                        ])
                                        
                                        // Mark invitation as accepted
                                        dbRef.child("invitations").child(self.invitationCode).updateChildValues([
                                            "status": "accepted",
                                            "acceptedBy": userIdString
                                        ])
                                        
                                        appData.currentRoomId = roomId
                                        UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                                        
                                        DispatchQueue.main.async {
                                            // Notify the app that the user is now in a new room
                                            NotificationCenter.default.post(name: Notification.Name("RoomJoined"), object: nil, userInfo: ["roomId": roomId])
                                            self.dismiss()
                                        }
                                    }
                                }
                            } else {
                                let userId = UUID()
                                let userIdString = userId.uuidString
                                let joinedAt = ISO8601DateFormatter().string(from: Date())
                                let isAdmin = invitation["isAdmin"] as? Bool ?? false
                                let newUser = User(
                                    id: userId,
                                    name: firebaseUser.displayName ?? "User",
                                    isAdmin: isAdmin
                                )
                                
                                var userDict = newUser.toDictionary()
                                userDict["authId"] = authUserId
                                dbRef.child("users").child(userIdString).setValue(userDict) { error, _ in
                                    if let error = error {
                                        self.errorMessage = "Error creating user: \(error.localizedDescription)"
                                        self.isValidating = false
                                        return
                                    }
                                    
                                    // Create auth mapping
                                    dbRef.child("auth_mapping").child(authUserId).setValue(userIdString)
                                    
                                    // Set room access with new format
                                    dbRef.child("users").child(userIdString).child("roomAccess").child(roomId).setValue([
                                        "joinedAt": joinedAt,
                                        "isActive": true
                                    ]) { error, _ in
                                        if let error = error {
                                            self.errorMessage = "Error granting room access: \(error.localizedDescription)"
                                            self.isValidating = false
                                            return
                                        }
                                        
                                        // Add user to room's users collection
                                        dbRef.child("rooms").child(roomId).child("users").child(userIdString).setValue([
                                            "id": userIdString,
                                            "name": newUser.name,
                                            "isAdmin": isAdmin,
                                            "joinedAt": joinedAt
                                        ])
                                        
                                        // Mark invitation as accepted
                                        dbRef.child("invitations").child(self.invitationCode).updateChildValues([
                                            "status": "accepted",
                                            "acceptedBy": userIdString
                                        ])
                                        
                                        // Update app state
                                        appData.currentUser = newUser
                                        UserDefaults.standard.set(userIdString, forKey: "currentUserId")
                                        appData.currentRoomId = roomId
                                        UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                                        
                                        DispatchQueue.main.async {
                                            // Notify the app that the user is now in a new room
                                            NotificationCenter.default.post(name: Notification.Name("RoomJoined"), object: nil, userInfo: ["roomId": roomId])
                                            self.dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        self.errorMessage = "You must be signed in to join a room"
                        self.isValidating = false
                    }
                }
            } else {
                self.errorMessage = "Invalid invitation code or phone number format."
                self.isValidating = false
            }
        }
    }
}
