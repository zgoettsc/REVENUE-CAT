import SwiftUI
import FirebaseDatabase

struct RoomEntryView: View {
    let roomId: String
    let roomName: String
    let appData: AppData
    @State private var profileImage: UIImage? = nil
    @State private var cycleNumber: Int = 0
    @State private var week: Int = 0
    @State private var day: Int = 0
    @State private var showingLeaveAlert = false
    @State private var showingDeleteAlert = false
    @State private var leaveErrorMessage: String?
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(roomName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if cycleNumber > 0 {
                    Text("Cycle \(cycleNumber) • Week \(week) • Day \(day)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let errorMessage = leaveErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // More options menu button
            Button(action: {
                showingActionSheet = true
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 0)
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Room Options"),
                    message: Text("Choose an action for this room"),
                    buttons: [
                        .destructive(Text("Leave Room")) {
                            showingLeaveAlert = true
                        },
                        .destructive(Text("Delete Room")) {
                            showingDeleteAlert = true
                        },
                        .cancel()
                    ]
                )
            }
            .alert("Leave Room", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    appData.leaveRoom(roomId: roomId) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                leaveErrorMessage = nil
                                // Post notification to refresh ManageRoomsView
                                NotificationCenter.default.post(name: Notification.Name("RoomLeft"), object: nil)
                            } else {
                                leaveErrorMessage = error ?? "Failed to leave room"
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to leave \(roomName)?")
            }
            .alert("Delete Room", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteRoom()
                }
            } message: {
                Text("Are you sure you want to permanently delete \(roomName) and all its data? This action cannot be undone.")
            }
        }
        .onAppear {
            loadProfileImage()
            loadCycleDetails()
        }
    }
    
    private func deleteRoom() {
        appData.deleteRoom(roomId: roomId) { success, error in
            DispatchQueue.main.async {
                if success {
                    leaveErrorMessage = nil
                    // Post notification to refresh ManageRoomsView
                    NotificationCenter.default.post(name: Notification.Name("RoomDeleted"), object: nil)
                } else {
                    leaveErrorMessage = error ?? "Failed to delete room"
                }
            }
        }
    }
    
    private func loadProfileImage() {
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).child("cycles").observeSingleEvent(of: .value) { snapshot in
            if let cycles = snapshot.value as? [String: [String: Any]] {
                var latestCycleId: String? = nil
                var latestStartDate: Date? = nil
                
                for (cycleId, cycleData) in cycles {
                    if let startDateStr = cycleData["startDate"] as? String,
                       let startDate = ISO8601DateFormatter().date(from: startDateStr) {
                        if latestStartDate == nil || startDate > latestStartDate! {
                            latestStartDate = startDate
                            latestCycleId = cycleId
                        }
                    }
                }
                
                if let cycleId = latestCycleId, let uuid = UUID(uuidString: cycleId) {
                    self.profileImage = appData.loadProfileImage(forCycleId: uuid)
                }
            }
        }
    }
    
    private func loadCycleDetails() {
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).child("cycles").observeSingleEvent(of: .value) { snapshot in
            if let cycles = snapshot.value as? [String: [String: Any]] {
                var latestCycle: [String: Any]? = nil
                var latestStartDate: Date? = nil
                
                for (_, cycleData) in cycles {
                    if let startDateStr = cycleData["startDate"] as? String,
                       let startDate = ISO8601DateFormatter().date(from: startDateStr) {
                        if latestStartDate == nil || startDate > latestStartDate! {
                            latestStartDate = startDate
                            latestCycle = cycleData
                        }
                    }
                }
                
                if let cycleData = latestCycle,
                   let cycleNumber = cycleData["number"] as? Int,
                   let startDateStr = cycleData["startDate"] as? String,
                   let startDate = ISO8601DateFormatter().date(from: startDateStr) {
                    self.cycleNumber = cycleNumber
                    
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let cycleStartDay = calendar.startOfDay(for: startDate)
                    let daysSinceStart = calendar.dateComponents([.day], from: cycleStartDay, to: today).day ?? 0
                    
                    let days = max(1, daysSinceStart + 1)
                    self.week = max(1, (days - 1) / 7 + 1)
                    self.day = max(1, (days - 1) % 7 + 1)
                } else {
                    self.cycleNumber = 1
                    self.week = 1
                    self.day = 1
                }
            } else {
                self.cycleNumber = 1
                self.week = 1
                self.day = 1
            }
        }
    }
}
