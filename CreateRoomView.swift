import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct CreateRoomView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var participantName: String = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isCreatingRoom = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Participant Details")) {
                    TextField("Participant Name", text: $participantName)

                    HStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.secondary)
                        }

                        Button("Choose Photo") {
                            showingImagePicker = true
                        }
                        .padding(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: {
                        createRoom()
                    }) {
                        if isCreatingRoom {
                            ProgressView()
                        } else {
                            Text("Create Room")
                        }
                    }
                    .disabled(participantName.isEmpty || isCreatingRoom)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Create New Room")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $profileImage)
            }
        }
    }

    func createRoom() {
        guard !participantName.isEmpty, let user = appData.currentUser else {
            errorMessage = "Participant name or user missing"
            return
        }
        
        guard let userId = appData.currentUser?.id.uuidString else {
            errorMessage = "User ID missing"
            return
        }
        
        // Check room limit based on subscription plan
        let roomLimit = user.roomLimit
        let currentRoomCount = user.ownedRooms?.count ?? 0
        
        if roomLimit <= 0 {
            errorMessage = "You need an active subscription to create a room."
            return
        }
        
        if currentRoomCount >= roomLimit {
            errorMessage = "You've reached your room limit (\(roomLimit)). Please upgrade your subscription."
            return
        }
        
        isCreatingRoom = true
        
        // Create a new room ID
        let dbRef = Database.database().reference()
        let newRoomRef = dbRef.child("rooms").childByAutoId()
        guard let roomId = newRoomRef.key else {
            errorMessage = "Failed to generate room ID"
            isCreatingRoom = false
            return
        }
        
        // Create the room data
        let roomData: [String: Any] = [
            "users": [
                userId: [
                    "id": userId,
                    "name": user.name,
                    "isAdmin": true,
                    "joinedAt": ISO8601DateFormatter().string(from: Date())
                ]
            ],
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Save the room
        newRoomRef.setValue(roomData) { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create room: \(error.localizedDescription)"
                    self.isCreatingRoom = false
                }
                return
            }
            
            // Update user's room access
            let userRoomAccessRef = dbRef.child("users").child(userId).child("roomAccess").child(roomId)
            userRoomAccessRef.setValue([
                "joinedAt": ISO8601DateFormatter().string(from: Date()),
                "isActive": true
            ])
            
            // Update user's owned rooms
            var ownedRooms = user.ownedRooms ?? []
            ownedRooms.append(roomId)
            dbRef.child("users").child(userId).child("ownedRooms").setValue(ownedRooms)
            
            // Create the initial cycle
            let cycleId = UUID()
            let cycle = Cycle(
                id: cycleId,
                number: 1,
                patientName: self.participantName,
                startDate: Date(),
                foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!
            )
            
            // Save the cycle
            dbRef.child("rooms").child(roomId).child("cycles").child(cycleId.uuidString).setValue(cycle.toDictionary())
            
            // Update local state
            DispatchQueue.main.async {
                // Update user with new owned room
                if var updatedUser = self.appData.currentUser {
                    updatedUser.ownedRooms = ownedRooms
                    self.appData.currentUser = updatedUser
                }
                
                // Save participant info for cycle creation
                UserDefaults.standard.set(self.participantName, forKey: "pendingParticipantName")
                if let profileImage = self.profileImage, let imageData = profileImage.jpegData(compressionQuality: 0.7) {
                    UserDefaults.standard.set(imageData, forKey: "pendingProfileImage")
                }
                
                // Upload profile image
                if let profileImage = self.profileImage {
                    self.appData.saveProfileImage(profileImage, forCycleId: cycleId)
                    self.appData.uploadProfileImage(profileImage, forCycleId: cycleId) { _ in }
                }
                
                // Set current room and cycle
                self.appData.currentRoomId = roomId
                UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                UserDefaults.standard.set(true, forKey: "showFirstCyclePopup")
                UserDefaults.standard.set(cycleId.uuidString, forKey: "newCycleId")
                
                // Update app data
                self.appData.cycles = [cycle]
                
                // Notify of room creation
                NotificationCenter.default.post(
                    name: Notification.Name("RoomCreated"),
                    object: nil,
                    userInfo: ["roomId": roomId, "cycle": cycle]
                )
                
                // Reset state and dismiss
                self.isCreatingRoom = false
                self.dismiss()
                
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToHomeTab"),
                    object: nil
                )
                self.dismiss()
            }
        }
    }
}
