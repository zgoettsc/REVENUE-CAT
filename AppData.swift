import Foundation
import SwiftUI
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth

class AppData: ObservableObject {
    @Published var cycles: [Cycle] = []
    @Published var cycleItems: [UUID: [Item]] = [:]
    @Published var groupedItems: [UUID: [GroupedItem]] = [:]
    @Published var units: [Unit] = []
    @Published var consumptionLog: [UUID: [UUID: [LogEntry]]] = [:]
    @Published var lastResetDate: Date?
    @Published var users: [User] = []
    @Published var currentUser: User? {
        didSet { saveCurrentUserSettings() }
    }
    @Published var treatmentTimer: TreatmentTimer? {
        didSet {
            saveTimerState()
        }
    }
    private var lastSaveTime: Date?
    @Published var categoryCollapsed: [String: Bool] = [:]
    @Published var groupCollapsed: [UUID: Bool] = [:] // Keyed by group ID
    @Published var roomCode: String? {
        didSet {
            if let roomCode = roomCode {
                UserDefaults.standard.set(roomCode, forKey: "roomCode")
                // Log warning for legacy use
                print("WARNING: Using deprecated roomCode property with value: \(roomCode)")
                logToFile("WARNING: Using deprecated roomCode property with value: \(roomCode)")
                // Do NOT create a new room or set dbRef
                // Instead, treat this as an attempt to join an existing room
                // Assume roomCode might be a legacy invitation code
                let dbRef = Database.database().reference()
                dbRef.child("invitations").child(roomCode).observeSingleEvent(of: .value) { snapshot in
                    if let invitation = snapshot.value as? [String: Any],
                       let roomId = invitation["roomId"] as? String {
                        print("Found invitation with roomId: \(roomId) for legacy roomCode: \(roomCode)")
                        // Set currentRoomId instead
                        self.currentRoomId = roomId
                    } else {
                        print("No valid invitation found for roomCode: \(roomCode)")
                        self.syncError = "Invalid or expired invitation code."
                        self.isLoading = false
                    }
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "roomCode")
                // Do not clear dbRef here; let currentRoomId handle it
            }
        }
    }
    @Published var syncError: String?
    @Published var isLoading: Bool = true
    @Published var currentRoomId: String? {
        didSet {
            if let roomId = currentRoomId {
                print("Setting currentRoomId to: \(roomId)")
                UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                
                // Clear roomCode to avoid confusion
                self.roomCode = nil
                UserDefaults.standard.removeObject(forKey: "roomCode")
                
                // Reset state but preserve timer
                resetStateForNewRoom()
                
                // Load room data and restore timer
                loadRoomData(roomId: roomId)
            } else {
                print("Clearing currentRoomId")
                UserDefaults.standard.removeObject(forKey: "currentRoomId")
                // Do not clear timer state here
                print("Preserving timer state during room switch")
                self.logToFile("Preserving timer state during room switch")
            }
        }
    }
    @Published var activeTimers: [String: TreatmentTimer] = [:] // Keyed by roomId
    @Published var reactions: [UUID: [Reaction]] = [:]  // Key is cycleId
    
    func addReaction(_ reaction: Reaction, toCycleId cycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == cycleId }) else {
            completion(false)
            return
        }
        
        let reactionRef = dbRef.child("cycles").child(cycleId.uuidString).child("reactions").child(reaction.id.uuidString)
        
        // First update local state immediately for better UI responsiveness
        DispatchQueue.main.async {
            if var cycleReactions = self.reactions[cycleId] {
                if let index = cycleReactions.firstIndex(where: { $0.id == reaction.id }) {
                    cycleReactions[index] = reaction
                } else {
                    cycleReactions.append(reaction)
                }
                self.reactions[cycleId] = cycleReactions
            } else {
                self.reactions[cycleId] = [reaction]
            }
            self.objectWillChange.send()
        }
        
        // Then update Firebase
        reactionRef.setValue(reaction.toDictionary()) { error, _ in
            if let error = error {
                print("Error adding reaction \(reaction.id) to Firebase: \(error)")
                self.logToFile("Error adding reaction \(reaction.id) to Firebase: \(error)")
                
                // Revert local state if Firebase update fails
                DispatchQueue.main.async {
                    if var cycleReactions = self.reactions[cycleId] {
                        cycleReactions.removeAll { $0.id == reaction.id }
                        if !cycleReactions.isEmpty {
                            self.reactions[cycleId] = cycleReactions
                        } else {
                            self.reactions.removeValue(forKey: cycleId)
                        }
                        self.objectWillChange.send()
                    }
                }
                
                completion(false)
            } else {
                DispatchQueue.main.async {
                    // Firebase observer will handle the update
                    print("Successfully added reaction \(reaction.id) to Firebase")
                    self.saveCachedData()
                    completion(true)
                }
            }
        }
    }
    
    func removeReaction(_ reactionId: UUID, fromCycleId cycleId: UUID) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == cycleId }) else { return }
        
        // First update local state immediately for better UI responsiveness
        DispatchQueue.main.async {
            if var cycleReactions = self.reactions[cycleId] {
                cycleReactions.removeAll { $0.id == reactionId }
                self.reactions[cycleId] = cycleReactions
                self.objectWillChange.send()
            }
        }
        
        // Then update Firebase
        dbRef.child("cycles").child(cycleId.uuidString).child("reactions").child(reactionId.uuidString).removeValue { error, _ in
            if let error = error {
                print("Error removing reaction \(reactionId) from Firebase: \(error)")
                self.logToFile("Error removing reaction \(reactionId) from Firebase: \(error)")
            } else {
                print("Successfully removed reaction \(reactionId) from Firebase")
                self.saveCachedData()
            }
        }
    }
    
    func uploadProfileImage(_ image: UIImage, forCycleId cycleId: UUID, completion: @escaping (Bool) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let imagePath = "profileImages/\(cycleId.uuidString).jpg"
        let imageRef = storageRef.child(imagePath)
        
        // Upload the image
        let uploadTask = imageRef.putData(imageData, metadata: nil) { metadata, error in
            if error != nil {
                print("Error uploading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            // Get download URL
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    completion(false)
                    return
                }
                
                // Save URL reference to database
                if let dbRef = self.dbRef {
                    dbRef.child("cycles").child(cycleId.uuidString).child("profileImageURL").setValue(downloadURL) { error, _ in
                        if let error = error {
                            print("Error saving image URL: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            // Still save locally for offline access
                            self.saveProfileImage(image, forCycleId: cycleId)
                            completion(true)
                        }
                    }
                } else {
                    // Save locally if Firebase not available
                    self.saveProfileImage(image, forCycleId: cycleId)
                    completion(false)
                }
            }
        }
        
        uploadTask.resume()
    }

    func downloadProfileImage(forCycleId cycleId: UUID, completion: @escaping (UIImage?) -> Void) {
        // First try to get from local cache
        if let localImage = loadProfileImage(forCycleId: cycleId) {
            completion(localImage)
            return
        }
        
        // If not in cache, try Firebase
        if let dbRef = dbRef {
            dbRef.child("cycles").child(cycleId.uuidString).child("profileImageURL").observeSingleEvent(of: .value) { snapshot in
                guard let urlString = snapshot.value as? String,
                      let url = URL(string: urlString) else {
                    completion(nil)
                    return
                }
                
                // Download image from URL
                URLSession.shared.dataTask(with: url) { data, response, error in
                    guard let data = data, error == nil,
                          let image = UIImage(data: data) else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }
                    
                    // Save to local cache and return
                    self.saveProfileImage(image, forCycleId: cycleId)
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }.resume()
            }
        } else {
            completion(nil)
        }
    }
    
    // Add this method to the AppData class
    func clearGroupedItems(forCycleId cycleId: UUID) {
        // Clear in memory
        groupedItems[cycleId] = []
        
        // Clear in Firebase
        if let dbRef = dbRef {
            dbRef.child("cycles").child(cycleId.uuidString).child("groupedItems").setValue([:])
            print("Cleared grouped items for cycle \(cycleId) in Firebase")
        } else {
            print("No database reference available, only cleared grouped items in memory")
        }
    }
    
    private var dataRefreshObservers: [UUID: () -> Void] = [:]

    func addDataRefreshObserver(id: UUID, handler: @escaping () -> Void) {
        dataRefreshObservers[id] = handler
    }

    func removeDataRefreshObserver(id: UUID) {
        dataRefreshObservers.removeValue(forKey: id)
    }

    func notifyDataRefreshObservers() {
        DispatchQueue.main.async {
            for handler in self.dataRefreshObservers.values {
                handler()
            }
        }
    }
    
    // Add to AppData class
    func createUserFromAuth(authUser: AuthUser, isAdmin: Bool = false) -> User {
        let userId = UUID()
        let user = User(
            id: userId,
            name: authUser.displayName ?? "User",
            isAdmin: isAdmin,
            remindersEnabled: [:],
            reminderTimes: [:],
            treatmentFoodTimerEnabled: true,
            treatmentTimerDuration: 900
        )
        
        addUser(user)
        currentUser = user
        UserDefaults.standard.set(userId.uuidString, forKey: "currentUserId")
        return user
    }


    func linkUserToFirebaseAuth(user: User, authId: String) {
        guard let dbRef = dbRef else { return }
        
        // Create a mapping between Firebase Auth UID and our app's UUID
        dbRef.child("auth_mapping").child(authId).setValue(user.id.uuidString)
        
        // Add Firebase Auth ID to user record
        dbRef.child("users").child(user.id.uuidString).child("authId").setValue(authId)
    }

    func getUserByAuthId(authId: String, completion: @escaping (User?) -> Void) {
        guard let dbRef = dbRef else {
            completion(nil)
            return
        }
        
        // Look up the user UUID from auth mapping
        dbRef.child("auth_mapping").child(authId).observeSingleEvent(of: .value) { snapshot in
            guard let userIdString = snapshot.value as? String,
                  let userId = UUID(uuidString: userIdString) else {
                completion(nil)
                return
            }
            
            // Get the user data
            dbRef.child("users").child(userIdString).observeSingleEvent(of: .value) { userSnapshot in
                guard let userData = userSnapshot.value as? [String: Any],
                      let user = User(dictionary: userData) else {
                    completion(nil)
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentUser = user
                    UserDefaults.standard.set(userIdString, forKey: "currentUserId")
                    completion(user)
                }
            }
        }
    }
    
    // Function to start a new treatment timer
    func startTreatmentTimer(duration: TimeInterval = 900, roomId: String? = nil) {
        let targetRoomId = roomId ?? currentRoomId
        guard let roomId = targetRoomId else {
            print("No room ID provided, cannot start timer")
            self.logToFile("No room ID provided, cannot start timer")
            return
        }
        
        stopTreatmentTimer(roomId: roomId)
        
        let unloggedItems = getUnloggedTreatmentItems()
        if unloggedItems.isEmpty {
            print("No unlogged treatment items for room \(roomId), not starting timer")
            self.logToFile("No unlogged treatment items for room \(roomId), not starting timer")
            return
        }
        
        let participantName = cycles.first(where: { $0.id == currentCycleId() })?.patientName ?? "Unknown"
        let endTime = Date().addingTimeInterval(duration)
        let timerId = "treatment_timer_\(UUID().uuidString)"
        
        let notificationIds = scheduleNotifications(timerId: timerId, endTime: endTime, duration: duration, participantName: participantName, roomId: roomId)
        
        let newTimer = TreatmentTimer(
            id: timerId,
            isActive: true,
            endTime: endTime,
            associatedItemIds: unloggedItems.map { $0.id },
            notificationIds: notificationIds,
            roomName: participantName
        )
        
        activeTimers[roomId] = newTimer
        if roomId == currentRoomId {
            treatmentTimer = newTimer
            treatmentTimerId = timerId
            saveTimerState()
        }
        
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).child("treatmentTimer").setValue(newTimer.toDictionary()) { error, _ in
            if let error = error {
                print("Failed to save timer to Firebase for room \(roomId): \(error)")
                self.logToFile("Failed to save timer to Firebase for room \(roomId): \(error)")
            } else {
                print("Saved timer to Firebase for room \(roomId)")
                self.logToFile("Saved timer to Firebase for room \(roomId)")
            }
        }
    }
    // Get unlogged treatment items
    private func getUnloggedTreatmentItems() -> [Item] {
        guard let cycleId = currentCycleId() else { return [] }
        
        let treatmentItems = (cycleItems[cycleId] ?? []).filter { $0.category == .treatment }
        
        // If there are no treatment items at all, return empty array
        if treatmentItems.isEmpty {
            return []
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        return treatmentItems.filter { item in
            let logs = consumptionLog[cycleId]?[item.id] ?? []
            return !logs.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
        }
    }
    
    func leaveRoom(roomId: String, completion: @escaping (Bool, String?) -> Void) {
        // Get direct reference to the main database
        let mainDbRef = Database.database().reference()
        
        guard let userId = currentUser?.id.uuidString else {
            completion(false, "User ID not available")
            return
        }
        
        // First check if we still have access to the room
        mainDbRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                // Create an empty room access node if it doesn't exist
                mainDbRef.child("users").child(userId).child("roomAccess").setValue([:]) { error, _ in
                    if let error = error {
                        completion(false, "Error creating roomAccess: \(error.localizedDescription)")
                    } else {
                        // Try again after creating the node
                        self.leaveRoom(roomId: roomId, completion: completion)
                    }
                }
                return
            }
            
            let accessibleRooms = snapshot.children.compactMap { ($0 as? DataSnapshot)?.key }
            
            // Remove room access
            mainDbRef.child("users").child(userId).child("roomAccess").child(roomId).removeValue { error, _ in
                if let error = error {
                    completion(false, "Error leaving room: \(error.localizedDescription)")
                    return
                }
                
                // Remove user from room's users
                mainDbRef.child("rooms").child(roomId).child("users").child(userId).removeValue { error, _ in
                    if let error = error {
                        completion(false, "Error updating room users: \(error.localizedDescription)")
                        return
                    }
                    
                    // If leaving the active room, handle room switch
                    if roomId == self.currentRoomId {
                        if let nextRoomId = accessibleRooms.first(where: { $0 != roomId }) {
                            // Switch to another room
                            self.currentRoomId = nextRoomId
                            UserDefaults.standard.set(nextRoomId, forKey: "currentRoomId")
                        } else {
                            // No other rooms, clear currentRoomId
                            self.currentRoomId = nil
                            UserDefaults.standard.removeObject(forKey: "currentRoomId")
                        }
                    }
                    
                    // Post notification to refresh
                    NotificationCenter.default.post(name: Notification.Name("RoomLeft"), object: nil)
                    completion(true, nil)
                }
            }
        }
    }
    // Function to stop the treatment timer
    func stopTreatmentTimer(clearRoom: Bool = false, roomId: String? = nil) {
        print("AppData: Stopping treatment timer, clearRoom: \(clearRoom), roomId: \(roomId ?? "all")")
        self.logToFile("AppData: Stopping treatment timer, clearRoom: \(clearRoom), roomId: \(roomId ?? "all")")
        
        if let specificRoomId = roomId {
            // Stop timer for a specific room
            if let timer = activeTimers[specificRoomId], timer.isActive {
                if let notificationIds = timer.notificationIds, !notificationIds.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
                    print("Canceled notifications for room \(specificRoomId): \(notificationIds)")
                    self.logToFile("Canceled notifications for room \(specificRoomId): \(notificationIds)")
                }
                
                if clearRoom {
                    let dbRef = Database.database().reference()
                    dbRef.child("rooms").child(specificRoomId).child("treatmentTimer").removeValue { error, _ in
                        if let error = error {
                            print("Failed to remove timer from Firebase for room \(specificRoomId): \(error)")
                            self.logToFile("Failed to remove timer from Firebase for room \(specificRoomId): \(error)")
                        } else {
                            print("Successfully removed timer from Firebase for room \(specificRoomId)")
                            self.logToFile("Successfully removed timer from Firebase for room \(specificRoomId)")
                        }
                    }
                    activeTimers.removeValue(forKey: specificRoomId)
                    if specificRoomId == currentRoomId {
                        treatmentTimer = nil
                        treatmentTimerId = nil
                        saveTimerState()
                    }
                }
            }
        } else {
            // Stop all timers
            for (roomId, timer) in activeTimers where timer.isActive {
                if let notificationIds = timer.notificationIds, !notificationIds.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
                    print("Canceled notifications for room \(roomId): \(notificationIds)")
                    self.logToFile("Canceled notifications for room \(roomId): \(notificationIds)")
                }
                
                if clearRoom {
                    let dbRef = Database.database().reference()
                    dbRef.child("rooms").child(roomId).child("treatmentTimer").removeValue { error, _ in
                        if let error = error {
                            print("Failed to remove timer from Firebase for room \(roomId): \(error)")
                            self.logToFile("Failed to remove timer from Firebase for room \(roomId): \(error)")
                        } else {
                            print("Successfully removed timer from Firebase for room \(roomId)")
                            self.logToFile("Successfully removed timer from Firebase for room \(roomId)")
                        }
                    }
                }
            }
            
            if clearRoom {
                activeTimers.removeAll()
                treatmentTimer = nil
                treatmentTimerId = nil
                saveTimerState()
            }
        }
    }
    
    // In AppData.swift, add this method to check for active timers on initialization
    func checkForActiveTimers() {
        guard let userId = currentUser?.id.uuidString else {
            print("Cannot check for active timers: no user ID")
            self.logToFile("Cannot check for active timers: no user ID")
            return
        }

        let dbRef = Database.database().reference()
        dbRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot in
            guard let roomAccess = snapshot.value as? [String: Any] else {
                print("No accessible rooms found for user \(userId)")
                self.logToFile("No accessible rooms found for user \(userId)")
                return
            }

            var newActiveTimers: [String: TreatmentTimer] = [:]
            let group = DispatchGroup()

            for (roomId, _) in roomAccess {
                group.enter()
                dbRef.child("rooms").child(roomId).child("treatmentTimer").observeSingleEvent(of: .value) { timerSnapshot in
                    defer { group.leave() }
                    if let timerDict = timerSnapshot.value as? [String: Any],
                       let timerObj = TreatmentTimer.fromDictionary(timerDict),
                       timerObj.isActive && timerObj.endTime > Date() {
                        print("Found valid timer in room \(roomId): \(timerObj.id), ending at \(timerObj.endTime)")
                        self.logToFile("Found valid timer in room \(roomId): \(timerObj.id), ending at \(timerObj.endTime)")
                        newActiveTimers[roomId] = timerObj

                        // If this is the current room, set as primary timer
                        if roomId == self.currentRoomId {
                            DispatchQueue.main.async {
                                self.treatmentTimer = timerObj
                                self.treatmentTimerId = timerObj.id
                                self.saveTimerState()
                                NotificationCenter.default.post(
                                    name: Notification.Name("ActiveTimerFound"),
                                    object: timerObj
                                )
                            }
                        }
                    }
                } withCancel: { error in
                    print("Failed to fetch timer for room \(roomId): \(error)")
                    self.logToFile("Failed to fetch timer for room \(roomId): \(error)")
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.activeTimers = newActiveTimers
                print("Updated active timers: \(newActiveTimers.keys)")
                self.logToFile("Updated active timers: \(newActiveTimers.keys)")

                // Reschedule notifications for all active timers
                self.rescheduleAllNotifications()
            }
        }
    }
    
    func setupTimerObservation() {
        if let roomId = currentRoomId {
            let dbRef = Database.database().reference()
            dbRef.child("rooms").child(roomId).child("treatmentTimer").observe(.value) { snapshot in
                if let timerDict = snapshot.value as? [String: Any],
                   let timerObj = TreatmentTimer.fromDictionary(timerDict),
                   timerObj.isActive && timerObj.endTime > Date() {
                    
                    DispatchQueue.main.async {
                        // Only update if timer is newer or we don't have one
                        if self.treatmentTimer == nil ||
                           self.treatmentTimer!.endTime < timerObj.endTime {
                            self.treatmentTimer = timerObj
                            self.treatmentTimerId = timerObj.id
                            
                            // Notify the UI
                            NotificationCenter.default.post(
                                name: Notification.Name("ActiveTimerFound"),
                                object: timerObj
                            )
                        }
                    }
                }
            }
        }
    }
    
    func switchToRoom(roomId: String) {
        // Clear badge when switching rooms
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        guard let userId = currentUser?.id.uuidString else { return }
        print("Switching to room: \(roomId) from current room: \(currentRoomId ?? "none")")
        logToFile("Switching to room: \(roomId) from current room: \(currentRoomId ?? "none")")
        
        let dbRef = Database.database().reference()
        
        dbRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot in
            guard let roomAccess = snapshot.value as? [String: Any] else {
                print("No room access data found")
                self.logToFile("No room access data found")
                return
            }
            
            if roomAccess[roomId] == nil {
                print("You no longer have access to this room")
                self.logToFile("You no longer have access to this room")
                return
            }
            
            var updatedRoomAccess: [String: [String: Any]] = [:]
            let joinedAt = ISO8601DateFormatter().string(from: Date())
            
            for (existingRoomId, accessData) in roomAccess {
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
                
                newAccess["isActive"] = existingRoomId == roomId
                updatedRoomAccess[existingRoomId] = newAccess
            }
            
            dbRef.child("users").child(userId).child("roomAccess").setValue(updatedRoomAccess) { error, _ in
                if let error = error {
                    print("Error switching rooms: \(error.localizedDescription)")
                    self.logToFile("Error switching rooms: \(error.localizedDescription)")
                    return
                }
                
                // Save current timer state before switching
                self.saveTimerState()
                
                // Store current room ID to switch back later if needed
                let oldRoomId = self.currentRoomId
                self.currentRoomId = nil
                
                // Clear current state to avoid conflicts
                self.cycles = []
                self.cycleItems = [:]
                self.groupedItems = [:]
                self.consumptionLog = [:]
                
                DispatchQueue.main.async {
                    // Set new room ID and save to UserDefaults
                    self.currentRoomId = roomId
                    UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                    
                    // Notify that we've joined a new room
                    NotificationCenter.default.post(
                        name: Notification.Name("RoomJoined"),
                        object: nil,
                        userInfo: ["oldRoomId": oldRoomId ?? "", "newRoomId": roomId]
                    )
                }
            }
        }
    }
    
    // New method to reschedule notifications for all active timers
    func rescheduleAllNotifications() {
        guard let user = currentUser, user.treatmentFoodTimerEnabled else {
            print("Notifications disabled, skipping reschedule")
            logToFile("Notifications disabled, skipping reschedule")
            return
        }

        for (roomId, timer) in activeTimers {
            if timer.isActive && timer.endTime > Date() {
                let remainingTime = timer.endTime.timeIntervalSinceNow
                let participantName = timer.roomName ?? cycles.first(where: { $0.id == currentCycleId() })?.patientName ?? "TIPs App"
                let notificationIds = scheduleNotifications(timerId: timer.id, endTime: timer.endTime, duration: remainingTime, participantName: participantName, roomId: roomId)
                
                // Update timer with new notification IDs
                let updatedTimer = TreatmentTimer(
                    id: timer.id,
                    isActive: timer.isActive,
                    endTime: timer.endTime,
                    associatedItemIds: timer.associatedItemIds,
                    notificationIds: notificationIds,
                    roomName: timer.roomName
                )
                activeTimers[roomId] = updatedTimer
                
                // Update Firebase
                let dbRef = Database.database().reference().child("rooms").child(roomId)
                dbRef.child("treatmentTimer").setValue(updatedTimer.toDictionary()) { error, _ in
                    if let error = error {
                        print("Failed to update timer in room \(roomId): \(error)")
                        self.logToFile("Failed to update timer in room \(roomId): \(error)")
                    }
                }
            }
        }
    }
    
    // Function to snooze the treatment timer
    func snoozeTreatmentTimer(duration: TimeInterval = 300, roomId: String? = nil) {
        let targetRoomId = roomId ?? currentRoomId
        guard let roomId = targetRoomId, let currentTimer = activeTimers[roomId] else { return }
        
        if let notificationIds = currentTimer.notificationIds {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
        }
        
        let endTime = Date().addingTimeInterval(duration)
        let participantName = currentTimer.roomName ?? cycles.first(where: { $0.id == currentCycleId() })?.patientName ?? "TIPs App"
        let notificationIds = scheduleNotifications(timerId: currentTimer.id, endTime: endTime, duration: duration, participantName: participantName, roomId: roomId)
        
        let newTimer = TreatmentTimer(
            id: currentTimer.id,
            isActive: true,
            endTime: endTime,
            associatedItemIds: currentTimer.associatedItemIds,
            notificationIds: notificationIds,
            roomName: participantName
        )
        
        activeTimers[roomId] = newTimer
        if roomId == currentRoomId {
            treatmentTimer = newTimer
        }
        
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).child("treatmentTimer").setValue(newTimer.toDictionary()) { error, _ in
            if let error = error {
                print("Failed to update snoozed timer in Firebase for room \(roomId): \(error)")
                self.logToFile("Failed to update snoozed timer in Firebase for room \(roomId): \(error)")
            } else {
                print("Updated snoozed timer in Firebase for room \(roomId)")
                self.logToFile("Updated snoozed timer in Firebase for room \(roomId)")
            }
        }
    }
    
    private func mergeTimerStates(local: TreatmentTimer?, firebase: TreatmentTimer?) -> TreatmentTimer? {
        switch (local, firebase) {
        case (let local?, let firebase?) where local.isActive && firebase.isActive:
            return local.endTime > firebase.endTime ? local : firebase
        case (let local?, nil) where local.isActive && local.endTime > Date():
            return local
        case (nil, let firebase?) where firebase.isActive && firebase.endTime > Date():
            return firebase
        default:
            return nil
        }
    }

    // Schedule multiple notifications and return their IDs
    private func scheduleNotifications(timerId: String, endTime: Date, duration: TimeInterval, participantName: String, roomId: String) -> [String] {
        var notificationIds: [String] = []
        
        guard let isEnabled = currentUser?.treatmentFoodTimerEnabled, isEnabled else {
            print("Notifications disabled for timer \(timerId) in room \(roomId)")
            logToFile("Notifications disabled for timer \(timerId) in room \(roomId)")
            return notificationIds
        }
        
        for i in 0..<4 {
            let notificationId = "\(timerId)_room_\(roomId)_repeat_\(i)"
            notificationIds.append(notificationId)
            
            let content = UNMutableNotificationContent()
            content.title = "\(participantName): Time for next treatment food"
            content.body = "Your 15 minute treatment food timer has ended."
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "TREATMENT_TIMER"
            content.interruptionLevel = .timeSensitive
            content.threadIdentifier = "treatment-timer-thread-\(timerId)"
            content.userInfo = ["roomId": roomId, "timerId": timerId, "participantName": participantName]
            
            // Important: Set the badge number to ensure the notification shows up
            content.badge = 1
            
            let delay = max(duration, 1) + Double(i)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification \(notificationId): \(error)")
                    self.logToFile("Error scheduling notification \(notificationId): \(error)")
                } else {
                    print("Scheduled notification \(notificationId) for \(participantName) in room \(roomId) in \(delay)s")
                    self.logToFile("Scheduled notification \(notificationId) for \(participantName) in room \(roomId) in \(delay)s")
                }
            }
        }
        
        return notificationIds
    }

    // Check timer status and update UI
    func checkTimerStatus() -> TimeInterval? {
        guard let timer = treatmentTimer, timer.isActive else { return nil }
        
        let remainingTime = timer.endTime.timeIntervalSinceNow
        
        if remainingTime <= 0 {
            // Timer expired but wasn't properly cleared
            stopTreatmentTimer()
            return nil
        }
        
        return remainingTime
    }

    // Check if all treatment items are logged
    // In AppData.swift, replace the checkIfAllTreatmentItemsLogged method:
    func checkIfAllTreatmentItemsLogged() {
        guard let timer = treatmentTimer, timer.isActive,
              let associatedItemIds = timer.associatedItemIds,
              !associatedItemIds.isEmpty,
              let cycleId = currentCycleId() else {
            return
        }
        
        // Get all treatment items
        let treatmentItems = (cycleItems[cycleId] ?? []).filter { $0.category == .treatment }
        
        // If there are no treatment items, stop the timer
        if treatmentItems.isEmpty {
            stopTreatmentTimer()
            return
        }
        
        // Check if all treatment items are logged
        let today = Calendar.current.startOfDay(for: Date())
        let allLogged = treatmentItems.allSatisfy { item in
            let logs = consumptionLog[cycleId]?[item.id] ?? []
            return logs.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
        }
        
        if allLogged {
            // All items have been logged, stop the timer
            stopTreatmentTimer()
        }
    }

    func loadRoomData(roomId: String) {
        let dbRef = Database.database().reference()
        
        print("Loading room data for roomId: \(roomId)")
        self.isLoading = true
        
        // Load room data
        dbRef.child("rooms").child(roomId).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                print("ERROR: Room \(roomId) does not exist in Firebase")
                self.syncError = "Room \(roomId) not found"
                self.isLoading = false
                self.currentRoomId = nil
                UserDefaults.standard.removeObject(forKey: "currentRoomId")
                return
            }
            
            print("Room \(roomId) found in Firebase, updating references")
            self.dbRef = Database.database().reference().child("rooms").child(roomId)
            self.loadFromFirebase()
            self.isLoading = false
            
            // Trigger timer check for all rooms
            self.checkForActiveTimers()
        } withCancel: { error in
            print("Error loading room \(roomId): \(error.localizedDescription)")
            self.syncError = "Failed to load room data: \(error.localizedDescription)"
            self.isLoading = false
            self.currentRoomId = nil
            UserDefaults.standard.removeObject(forKey: "currentRoomId")
        }
    }
    
    func optimizedItemSave(_ item: Item, toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef else {
            completion(false)
            return
        }
        
        // Simplified saving that just sends this one item directly
        let itemRef = dbRef.child("cycles").child(toCycleId.uuidString).child("items").child(item.id.uuidString)
        
        // Convert item to dictionary
        let itemDict = item.toDictionary()
        
        // Save directly
        itemRef.setValue(itemDict) { error, _ in
            if let error = error {
                print("Optimized save error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Update local cache
            DispatchQueue.main.async {
                if var items = self.cycleItems[toCycleId] {
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        items[index] = item
                    } else {
                        items.append(item)
                    }
                    self.cycleItems[toCycleId] = items
                } else {
                    self.cycleItems[toCycleId] = [item]
                }
                completion(true)
            }
        }
    }
    
    func nukeAllGroupedItems(forCycleId cycleId: UUID) {
        print("NUKE: Starting complete group deletion for cycle \(cycleId)")
        
        // 1. Clear local memory
        groupedItems[cycleId] = []
        
        // 2. Get direct database reference
        guard let roomId = currentRoomId else {
            print("NUKE: No current room ID, aborting")
            return
        }
        
        let mainDbRef = Database.database().reference()
        
        // 3. Directly delete at the room level
        mainDbRef.child("rooms").child(roomId).child("cycles").child(cycleId.uuidString).child("groupedItems").removeValue { error, _ in
            if let error = error {
                print("NUKE: Failed to remove groupedItems: \(error.localizedDescription)")
            } else {
                print("NUKE: Successfully nuked all groupedItems for cycle \(cycleId)")
            }
        }
        
        // 4. Also clear any group collapse states
        mainDbRef.child("rooms").child(roomId).child("groupCollapsed").observeSingleEvent(of: .value) { snapshot in
            if let collapseStates = snapshot.value as? [String: Bool] {
                let updates = collapseStates.mapValues { _ in NSNull() }
                mainDbRef.child("rooms").child(roomId).child("groupCollapsed").updateChildValues(updates as [String: Any])
                print("NUKE: Cleared group collapse states")
            }
        }
    }
    
    private var pendingConsumptionLogUpdates: [UUID: [UUID: [LogEntry]]] = [:] // Track pending updates
    
    private var dbRef: DatabaseReference?
    private var isAddingCycle = false
    public var treatmentTimerId: String? {
        didSet { saveTimerState() }
    }
    
    func forceDeleteAllGroupedItems(forCycleId cycleId: UUID) {
        // Clear in memory
        groupedItems[cycleId] = []
        
        // Clear in Firebase with a forceful approach
        if let dbRef = dbRef {
            let groupedItemsRef = dbRef.child("cycles").child(cycleId.uuidString).child("groupedItems")
            
            // First read all groups to explicitly delete each one
            groupedItemsRef.observeSingleEvent(of: .value) { snapshot in
                if let groups = snapshot.value as? [String: Any] {
                    for (groupId, _) in groups {
                        groupedItemsRef.child(groupId).removeValue()
                    }
                }
                
                // Then clear the entire node
                groupedItemsRef.removeValue { error, _ in
                    if let error = error {
                        print("Error clearing grouped items: \(error.localizedDescription)")
                    } else {
                        print("Successfully cleared all grouped items for cycle \(cycleId)")
                    }
                }
            }
        }
    }

    // Functions to handle profile images
    func saveProfileImage(_ image: UIImage, forCycleId cycleId: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileName = "profile_\(cycleId.uuidString).jpg"
        
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) {
            try? data.write(to: url)
            UserDefaults.standard.set(fileName, forKey: "profileImage_\(cycleId.uuidString)")
        }
    }
    
    func loadProfileImage(forCycleId cycleId: UUID) -> UIImage? {
        guard let fileName = UserDefaults.standard.string(forKey: "profileImage_\(cycleId.uuidString)") else {
            return nil
        }
        
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    func deleteProfileImage(forCycleId cycleId: UUID) {
        guard let fileName = UserDefaults.standard.string(forKey: "profileImage_\(cycleId.uuidString)") else {
            return
        }
        
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.standard.removeObject(forKey: "profileImage_\(cycleId.uuidString)")
        }
    }

    
    init() {
        print("AppData initializing")
        logToFile("AppData initializing")
        
        // First check if we have a user ID and room ID
        if let userIdStr = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: userIdStr) {
            print("Found existing user ID: \(userIdStr)")
            loadCurrentUserSettings(userId: userId)
            
            // Prioritize currentRoomId over roomCode
            if let roomId = UserDefaults.standard.string(forKey: "currentRoomId") {
                print("Found existing room ID: \(roomId), loading room data")
                self.currentRoomId = roomId
                // Clear roomCode to avoid confusion
                UserDefaults.standard.removeObject(forKey: "roomCode")
            } else if let roomCode = UserDefaults.standard.string(forKey: "roomCode") {
                // Legacy support for old room code system
                print("Using legacy room code: \(roomCode)")
                self.roomCode = roomCode
            } else {
                print("No existing room found, will need setup")
            }
        } else {
            print("No existing user or room found, will need setup")
        }
        
        units = [Unit(name: "mg"), Unit(name: "g"), Unit(name: "tsp"), Unit(name: "tbsp"), Unit(name: "oz"), Unit(name: "mL"), Unit(name: "nuts"), Unit(name: "fist sized")]
        loadCachedData()
        
        // Ensure all groups start collapsed
        for (cycleId, groups) in groupedItems {
            for group in groups {
                if groupCollapsed[group.id] == nil {
                    groupCollapsed[group.id] = true
                }
            }
        }
        
        loadTimerState()
        checkAndResetIfNeeded()
        rescheduleDailyReminders()
        
        if currentRoomId != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("Delayed timer check starting")
                self.checkForActiveTimers()
            }
        }
        
        // Log timer state
        print("AppData init: Loaded treatmentTimer = \(String(describing: treatmentTimer))")
        logToFile("AppData init: Loaded treatmentTimer = \(String(describing: treatmentTimer))")
        
        if let timer = treatmentTimer {
            if timer.isActive && timer.endTime > Date() {
                print("AppData init: Active timer found, endDate = \(timer.endTime)")
                logToFile("AppData init: Active timer found, endDate = \(timer.endTime)")
            } else {
                print("AppData init: Timer expired, clearing treatmentTimer")
                logToFile("AppData init: Timer expired, clearing treatmentTimer")
                self.treatmentTimer = nil
            }
        } else {
            print("AppData init: No active timer to resume")
            logToFile("AppData init: No active timer to resume")
        }
        loadTimerState()
        if let timer = treatmentTimer, timer.isActive, timer.endTime > Date() {
            print("AppData init: Found active timer with \(timer.endTime.timeIntervalSinceNow)s remaining")
            logToFile("AppData init: Found active timer with \(timer.endTime.timeIntervalSinceNow)s remaining")
            
            // Also check UserDefaults as a backup
            if let timerData = UserDefaults.standard.data(forKey: "treatmentTimerState") {
                do {
                    let backupState = try JSONDecoder().decode(TimerState.self, from: timerData)
                    if let backupTimer = backupState.timer,
                       backupTimer.isActive && backupTimer.endTime > Date() &&
                       backupTimer.endTime > timer.endTime {
                        // Use the backup if it's newer
                        treatmentTimer = backupTimer
                        print("Using newer backup timer from UserDefaults")
                        logToFile("Using newer backup timer from UserDefaults")
                    }
                } catch {
                    print("Error decoding backup timer: \(error)")
                    logToFile("Error decoding backup timer: \(error)")
                }
            }
            
            // Notify immediately on init that we have an active timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Posting ActiveTimerFound notification from AppData init")
                self.logToFile("Posting ActiveTimerFound notification from AppData init")
                NotificationCenter.default.post(
                    name: Notification.Name("ActiveTimerFound"),
                    object: self.treatmentTimer
                )
            }
        }
        // Ensure all users have the correct treatment timer duration
        if let currentUser = currentUser, currentUser.treatmentTimerDuration != 900 {
            setTreatmentTimerDuration(900)
        }
    }
    
    func globalRefresh() {
        print("Performing global data refresh")
        self.logToFile("Performing global data refresh")
        
        guard let roomId = currentRoomId else {
            print("No current room ID, cannot refresh")
            self.isLoading = false
            NotificationCenter.default.post(name: Notification.Name("DataRefreshed"), object: nil)
            return
        }
        
        // Mark as loading
        self.isLoading = true
        
        // Get a direct reference to the database
        let dbRef = Database.database().reference()
        
        // First load cycles
        dbRef.child("rooms").child(roomId).child("cycles").observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(), let cyclesData = snapshot.value as? [String: [String: Any]] else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    NotificationCenter.default.post(name: Notification.Name("DataRefreshed"), object: nil)
                }
                return
            }
            
            var loadedCycles: [Cycle] = []
            var loadedCycleItems: [UUID: [Item]] = [:]
            var loadedConsumptionLog: [UUID: [UUID: [LogEntry]]] = [:]
            var loadedGroupedItems: [UUID: [GroupedItem]] = [:]
            var loadedReactions: [UUID: [Reaction]] = [:]
            
            let group = DispatchGroup()
            
            // Process cycles
            for (cycleId, cycleData) in cyclesData {
                guard let cycleUUID = UUID(uuidString: cycleId) else { continue }
                
                var mutableData = cycleData
                mutableData["id"] = cycleId
                if let cycle = Cycle(dictionary: mutableData) {
                    loadedCycles.append(cycle)
                    
                    // Load items for this cycle
                    group.enter()
                    dbRef.child("rooms").child(roomId).child("cycles").child(cycleId).child("items")
                        .observeSingleEvent(of: .value) { itemsSnapshot in
                            
                        defer { group.leave() }
                        
                        if let itemsData = itemsSnapshot.value as? [String: [String: Any]] {
                            let items = itemsData.compactMap { (itemId, itemData) -> Item? in
                                var mutableItem = itemData
                                mutableItem["id"] = itemId
                                return Item(dictionary: mutableItem)
                            }
                            
                            if !items.isEmpty {
                                loadedCycleItems[cycleUUID] = items
                            }
                        }
                    }
                    
                    // Load grouped items for this cycle
                    group.enter()
                    dbRef.child("rooms").child(roomId).child("cycles").child(cycleId).child("groupedItems")
                        .observeSingleEvent(of: .value) { groupsSnapshot in
                            
                        defer { group.leave() }
                        
                        if let groupsData = groupsSnapshot.value as? [String: [String: Any]] {
                            let groups = groupsData.compactMap { (groupId, groupData) -> GroupedItem? in
                                var mutableGroup = groupData
                                mutableGroup["id"] = groupId
                                return GroupedItem(dictionary: mutableGroup)
                            }
                            
                            if !groups.isEmpty {
                                loadedGroupedItems[cycleUUID] = groups
                            }
                        }
                    }
                    
                    // Load consumption log for this cycle
                    group.enter()
                    dbRef.child("rooms").child(roomId).child("consumptionLog").child(cycleId)
                        .observeSingleEvent(of: .value) { logSnapshot in
                            
                        defer { group.leave() }
                        
                        if let logData = logSnapshot.value as? [String: [[String: String]]] {
                            var cycleLog: [UUID: [LogEntry]] = [:]
                            
                            for (itemIdString, entries) in logData {
                                guard let itemId = UUID(uuidString: itemIdString) else { continue }
                                
                                let itemLogs = entries.compactMap { entry -> LogEntry? in
                                    guard
                                        let timestamp = entry["timestamp"],
                                        let dateObj = ISO8601DateFormatter().date(from: timestamp),
                                        let userIdString = entry["userId"],
                                        let userId = UUID(uuidString: userIdString)
                                    else { return nil }
                                    
                                    return LogEntry(date: dateObj, userId: userId)
                                }
                                
                                if !itemLogs.isEmpty {
                                    cycleLog[itemId] = itemLogs
                                }
                            }
                            
                            if !cycleLog.isEmpty {
                                loadedConsumptionLog[cycleUUID] = cycleLog
                            }
                        }
                    }
                    
                    // Load reactions for this cycle
                    group.enter()
                    dbRef.child("rooms").child(roomId).child("cycles").child(cycleId).child("reactions")
                        .observeSingleEvent(of: .value) { reactionsSnapshot in
                            
                        defer { group.leave() }
                        
                        if let reactionsData = reactionsSnapshot.value as? [String: [String: Any]] {
                            let reactions = reactionsData.compactMap { (reactionId, reactionData) -> Reaction? in
                                var mutableReaction = reactionData
                                mutableReaction["id"] = reactionId
                                return Reaction(dictionary: mutableReaction)
                            }
                            
                            if !reactions.isEmpty {
                                loadedReactions[cycleUUID] = reactions
                                print("Loaded \(reactions.count) reactions for cycle \(cycleId)")
                            } else {
                                // Even if empty, make sure we have an entry to clear any stale data
                                loadedReactions[cycleUUID] = []
                                print("No reactions found for cycle \(cycleId)")
                            }
                        } else {
                            // If no reactions node exists, make sure we have an empty array
                            loadedReactions[cycleUUID] = []
                            print("No reactions node found for cycle \(cycleId)")
                        }
                    }
                }
            }
            
            // When all data is loaded, update the app state
            group.notify(queue: .main) {
                self.cycles = loadedCycles.sorted { $0.startDate < $1.startDate }
                
                // Only update cycle items if we found some
                for (cycleId, items) in loadedCycleItems {
                    self.cycleItems[cycleId] = items
                }
                
                // Only update grouped items if we found some
                for (cycleId, groups) in loadedGroupedItems {
                    self.groupedItems[cycleId] = groups
                }
                
                // Only update consumption log if we found entries
                for (cycleId, logs) in loadedConsumptionLog {
                    self.consumptionLog[cycleId] = logs
                }
                
                // Always update reactions to ensure we have the latest data
                self.reactions = loadedReactions
                
                self.isLoading = false
                self.saveCachedData() // Save all data to local cache
                self.objectWillChange.send()
                
                // Notify all views
                NotificationCenter.default.post(name: Notification.Name("DataRefreshed"), object: nil)
                
                print("Global refresh complete: \(self.cycles.count) cycles, \(self.cycleItems.count) item sets, \(self.consumptionLog.count) log sets, \(self.reactions.count) reaction sets")
            }
        }
    }
    
    func refreshDataOnTabSwitch() {
        // First notify of pending refresh
        self.objectWillChange.send()
        
        // Do a quick update of the local data models
        DispatchQueue.main.async {
            // Then do a full network refresh with slight delay
            // to allow the UI to update first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.globalRefresh()
            }
        }
    }

    private func loadConsumptionLogForCycle(cycleId: UUID) {
        guard let roomId = currentRoomId else { return }
        
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).child("consumptionLog").child(cycleId.uuidString)
            .observeSingleEvent(of: .value) { snapshot in
                
            print("Consumption log for cycle \(cycleId) - exists: \(snapshot.exists())")
            
            if snapshot.exists(), let logData = snapshot.value as? [String: [[String: String]]] {
                DispatchQueue.main.async {
                    var cycleLog: [UUID: [LogEntry]] = [:]
                    
                    for (itemIdString, entries) in logData {
                        guard let itemId = UUID(uuidString: itemIdString) else { continue }
                        
                        let itemLogs = entries.compactMap { entry -> LogEntry? in
                            guard
                                let timestamp = entry["timestamp"],
                                let dateObj = ISO8601DateFormatter().date(from: timestamp),
                                let userIdString = entry["userId"],
                                let userId = UUID(uuidString: userIdString)
                            else { return nil }
                            
                            return LogEntry(date: dateObj, userId: userId)
                        }
                        
                        if !itemLogs.isEmpty {
                            cycleLog[itemId] = itemLogs
                        }
                    }
                    
                    self.consumptionLog[cycleId] = cycleLog
                    self.objectWillChange.send()
                    
                    print("Updated consumption log for cycle \(cycleId): \(cycleLog.count) items")
                }
            }
        }
    }
    
    func ensureCorrectRoomReference() {
        // If we have a currentRoomId, make sure dbRef points to the right place
        if let roomId = currentRoomId {
            print("Ensuring database reference points to room: \(roomId)")
            dbRef = Database.database().reference().child("rooms").child(roomId)
            
            // Clear roomCode to avoid confusion
            self.roomCode = nil
            UserDefaults.standard.removeObject(forKey: "roomCode")
            
            // Also update the user's roomAccess to mark this room as active
            if let userId = currentUser?.id.uuidString {
                let dbMainRef = Database.database().reference()
                
                // First get all room access
                dbMainRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot in
                    if let roomAccess = snapshot.value as? [String: Any] {
                        var updatedRoomAccess: [String: [String: Any]] = [:]
                        let joinedAt = ISO8601DateFormatter().string(from: Date())
                        
                        for (existingRoomId, accessData) in roomAccess {
                            var newAccess: [String: Any]
                            
                            // Handle both old format (boolean) and new format (dictionary)
                            if let accessDict = accessData as? [String: Any] {
                                newAccess = accessDict
                            } else if accessData as? Bool == true {
                                newAccess = [
                                    "joinedAt": joinedAt,
                                    "isActive": false
                                ]
                            } else {
                                continue // Skip invalid entries
                            }
                            
                            // Set isActive based on the selected room
                            newAccess["isActive"] = existingRoomId == roomId
                            updatedRoomAccess[existingRoomId] = newAccess
                        }
                        
                        // Update roomAccess with new format
                        dbMainRef.child("users").child(userId).child("roomAccess").setValue(updatedRoomAccess) { error, _ in
                            if let error = error {
                                print("Error updating room access format: \(error.localizedDescription)")
                            } else {
                                print("Successfully updated room access format")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func resetStateForNewRoom() {
        // Clear current data
        cycles = []
        cycleItems = [:]
        groupedItems = [:]
        consumptionLog = [:]
        categoryCollapsed = [:]
        groupCollapsed = [:]
        lastResetDate = nil
        // Do NOT clear activeTimers, treatmentTimer, or treatmentTimerId
        print("App state reset for new room, preserving timers")
        logToFile("App state reset for new room, preserving timers")
    }
    
    private func loadCachedData() {
        if let cycleData = UserDefaults.standard.data(forKey: "cachedCycles"),
           let decodedCycles = try? JSONDecoder().decode([Cycle].self, from: cycleData) {
            self.cycles = decodedCycles
        }
        if let itemsData = UserDefaults.standard.data(forKey: "cachedCycleItems"),
           let decodedItems = try? JSONDecoder().decode([UUID: [Item]].self, from: itemsData) {
            self.cycleItems = decodedItems
        }
        if let groupedItemsData = UserDefaults.standard.data(forKey: "cachedGroupedItems"),
           let decodedGroupedItems = try? JSONDecoder().decode([UUID: [GroupedItem]].self, from: groupedItemsData) {
            self.groupedItems = decodedGroupedItems
        }
        if let logData = UserDefaults.standard.data(forKey: "cachedConsumptionLog"),
           let decodedLog = try? JSONDecoder().decode([UUID: [UUID: [LogEntry]]].self, from: logData) {
            self.consumptionLog = decodedLog
        }
    }

    private func saveCachedData() {
        if let cycleData = try? JSONEncoder().encode(cycles) {
            UserDefaults.standard.set(cycleData, forKey: "cachedCycles")
        }
        if let itemsData = try? JSONEncoder().encode(cycleItems) {
            UserDefaults.standard.set(itemsData, forKey: "cachedCycleItems")
        }
        if let groupedItemsData = try? JSONEncoder().encode(groupedItems) {
            UserDefaults.standard.set(groupedItemsData, forKey: "cachedGroupedItems")
        }
        if let logData = try? JSONEncoder().encode(consumptionLog) {
            UserDefaults.standard.set(logData, forKey: "cachedConsumptionLog")
        }
        UserDefaults.standard.synchronize()
    }

    public func loadTimerState() {
        guard let url = timerStateURL() else {
            print("Failed to get timer state URL")
            self.logToFile("Failed to get timer state URL")
            return
        }
        
        do {
            // Try loading from file
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let state = try JSONDecoder().decode(TimerState.self, from: data)
                if let timer = state.timer, timer.isActive && timer.endTime > Date() {
                    self.treatmentTimer = timer
                    self.treatmentTimerId = timer.id
                    let timeRemaining = timer.endTime.timeIntervalSinceNow
                    print("Loaded valid timer from file with \(timeRemaining)s remaining")
                    self.logToFile("Loaded valid timer from file with \(timeRemaining)s remaining")
                    
                    // Post notification to update UI
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("ActiveTimerFound"),
                            object: timer
                        )
                    }
                    return
                } else {
                    print("File timer is expired or inactive, checking UserDefaults")
                    self.logToFile("File timer is expired or inactive, checking UserDefaults")
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                print("No timer state file found at \(url.path)")
                self.logToFile("No timer state file found at \(url.path)")
            }
            
            // Fallback to UserDefaults
            if let timerData = UserDefaults.standard.data(forKey: "treatmentTimerState") {
                let state = try JSONDecoder().decode(TimerState.self, from: timerData)
                if let timer = state.timer, timer.isActive && timer.endTime > Date() {
                    self.treatmentTimer = timer
                    self.treatmentTimerId = timer.id
                    let timeRemaining = timer.endTime.timeIntervalSinceNow
                    print("Loaded valid timer from UserDefaults with \(timeRemaining)s remaining")
                    self.logToFile("Loaded valid timer from UserDefaults with \(timeRemaining)s remaining")
                    
                    // Post notification to update UI
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("ActiveTimerFound"),
                            object: timer
                        )
                    }
                } else {
                    print("UserDefaults timer is expired or inactive, clearing")
                    self.logToFile("UserDefaults timer is expired or inactive, clearing")
                    UserDefaults.standard.removeObject(forKey: "treatmentTimerState")
                }
            } else {
                print("No timer state in UserDefaults")
                self.logToFile("No timer state in UserDefaults")
            }
        } catch {
            print("Failed to load timer state: \(error.localizedDescription)")
            self.logToFile("Failed to load timer state: \(error.localizedDescription)")
        }
    }

    public func saveTimerState() {
        guard let url = timerStateURL() else { return }
        
        let now = Date()
        if let last = lastSaveTime, now.timeIntervalSince(last) < 0.5 {
            print("Debounced saveTimerState: too soon since last save at \(last)")
            self.logToFile("Debounced saveTimerState: too soon since last save at \(last)")
            return
        }
        
        do {
            if let timer = treatmentTimer, timer.isActive && timer.endTime > Date() {
                let state = TimerState(timer: timer)
                let data = try JSONEncoder().encode(state)
                try data.write(to: url, options: .atomic)
                lastSaveTime = now
                
                // Also update in UserDefaults as a backup
                UserDefaults.standard.set(data, forKey: "treatmentTimerState")
                UserDefaults.standard.synchronize()
                
                print("Saved active timer state ending at \(timer.endTime), remaining: \(timer.endTime.timeIntervalSinceNow)s")
                self.logToFile("Saved active timer state ending at \(timer.endTime), remaining: \(timer.endTime.timeIntervalSinceNow)s")
            } else {
                // Clean up any existing timer files
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("Removed expired timer state file")
                    self.logToFile("Removed expired timer state file")
                }
                
                // Clear from UserDefaults as well
                UserDefaults.standard.removeObject(forKey: "treatmentTimerState")
                
                print("No active timer to save")
                self.logToFile("No active timer to save")
            }
        } catch {
            print("Failed to save timer state: \(error)")
            self.logToFile("Failed to save timer state: \(error)")
        }
    }

    private func timerStateURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("timer_state.json")
    }

    public func logToFile(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent("app_log.txt")
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try? logEntry.data(using: .utf8)?.write(to: fileURL)
            }
        }
    }

    private func loadCurrentUserSettings(userId: UUID) {
        if let data = UserDefaults.standard.data(forKey: "userSettings_\(userId.uuidString)"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
            print("Loaded current user \(userId)")
            logToFile("Loaded current user \(userId)")
        }
    }

    private func saveCurrentUserSettings() {
        guard let user = currentUser else { return }
        UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "userSettings_\(user.id.uuidString)")
        }
        saveCachedData()
    }

    public func loadFromFirebase() {
        guard let dbRef = dbRef else {
            print("ERROR: No database reference available.")
            logToFile("ERROR: No database reference available.")
            syncError = "No room code set."
            self.isLoading = false
            return
        }
        
        print("Loading data from Firebase path: \(dbRef.description())")
        
        // First check if the cycles node exists
        dbRef.child("cycles").observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                print("Creating empty cycles node")
                dbRef.child("cycles").setValue([:]) { error, ref in
                    if let error = error {
                        print("Error creating cycles node: \(error.localizedDescription)")
                        self.syncError = "Failed to initialize database structure"
                    } else {
                        print("Successfully created cycles node")
                        // Continue loading after ensuring the node exists
                        self.setupPersistentObservers()
                    }
                }
            } else {
                // Node exists, continue with regular loading
                self.setupPersistentObservers()
            }
        }
    }

    private func setupPersistentObservers() {
        guard let dbRef = dbRef else { return }
        
        // Observe cycles with a persistent listener
        dbRef.child("cycles").observe(.value) { snapshot in
            if self.isAddingCycle { return }
            var newCycles: [Cycle] = []
            
            if snapshot.exists(), let value = snapshot.value as? [String: [String: Any]] {
                print("Processing \(value.count) cycles from Firebase")
                
                for (key, dict) in value {
                    var mutableDict = dict
                    mutableDict["id"] = key
                    guard let cycle = Cycle(dictionary: mutableDict) else {
                        print("Failed to parse cycle with key: \(key)")
                        continue
                    }
                    
                    print("Parsed cycle: \(cycle.number) - \(cycle.patientName)")
                    newCycles.append(cycle)
                    
                    // Setup observers for each cycle's data
                    self.setupCycleObservers(cycleId: key, cycleUUID: cycle.id)
                }
                
                DispatchQueue.main.async {
                    self.cycles = newCycles.sorted { $0.startDate < $1.startDate }
                    self.syncError = nil
                    self.isLoading = false
                    self.saveCachedData()
                    self.objectWillChange.send()
                    
                    // Notify views that data has been updated
                    NotificationCenter.default.post(name: Notification.Name("DataRefreshed"), object: nil)
                }
            } else {
                DispatchQueue.main.async {
                    if self.cycles.isEmpty {
                        print("ERROR: No cycles found in Firebase or data is malformed: \(snapshot.key)")
                        self.syncError = "No cycles found in Firebase or data is malformed."
                    } else {
                        print("No cycles in Firebase but using cached data")
                        self.syncError = nil
                    }
                    self.isLoading = false
                }
            }
        }
        
        // Observe units
        dbRef.child("units").observe(.value) { snapshot in
            if snapshot.value != nil, let value = snapshot.value as? [String: [String: Any]] {
                let units = value.compactMap { (key, dict) -> Unit? in
                    var mutableDict = dict
                    mutableDict["id"] = key
                    return Unit(dictionary: mutableDict)
                }
                
                DispatchQueue.main.async {
                    if units.isEmpty {
                        // Ensure we always have at least the default units
                        if self.units.isEmpty {
                            self.units = [Unit(name: "mg"), Unit(name: "g"), Unit(name: "tsp"), Unit(name: "tbsp"), Unit(name: "oz"), Unit(name: "mL"), Unit(name: "nuts"), Unit(name: "fist sized")]
                        }
                    } else {
                        // Add default units if they don't exist
                        var allUnits = units
                        let defaultUnits = ["mg", "g", "tsp", "tbsp", "oz", "mL", "nuts", "fist sized"]
                        for defaultUnit in defaultUnits {
                            if !allUnits.contains(where: { $0.name == defaultUnit }) {
                                allUnits.append(Unit(name: defaultUnit))
                            }
                        }
                        self.units = allUnits
                    }
                    
                    // If we have items that reference units not in our units list, add those units
                    self.ensureItemUnitsExist()
                    
                    self.saveCachedData()
                    self.objectWillChange.send()
                }
            } else {
                // If Firebase returns no units, make sure we have at least the defaults
                DispatchQueue.main.async {
                    if self.units.isEmpty {
                        self.units = [Unit(name: "mg"), Unit(name: "g"), Unit(name: "tsp"), Unit(name: "tbsp"), Unit(name: "oz"), Unit(name: "mL"), Unit(name: "nuts"), Unit(name: "fist sized")]
                        self.saveCachedData()
                        self.objectWillChange.send()
                    }
                }
            }
        }
        
        // Observe category collapse state
        dbRef.child("categoryCollapsed").observe(.value) { snapshot in
            if snapshot.value != nil, let value = snapshot.value as? [String: Bool] {
                DispatchQueue.main.async {
                    self.categoryCollapsed = value
                }
            }
        }
        
        // Observe group collapse state
        dbRef.child("groupCollapsed").observe(.value) { snapshot in
            if snapshot.value != nil, let value = snapshot.value as? [String: Bool] {
                DispatchQueue.main.async {
                    let firebaseCollapsed = value.reduce(into: [UUID: Bool]()) { result, pair in
                        if let groupId = UUID(uuidString: pair.key) {
                            result[groupId] = pair.value
                        }
                    }
                    // Merge Firebase data, preserving local changes if they exist
                    for (groupId, isCollapsed) in firebaseCollapsed {
                        if self.groupCollapsed[groupId] == nil {
                            self.groupCollapsed[groupId] = isCollapsed
                        }
                    }
                }
            }
        }
        
        // Observe users
        dbRef.child("users").observe(.value) { snapshot in
            if snapshot.value != nil, let value = snapshot.value as? [String: [String: Any]] {
                let users = value.compactMap { (key, dict) -> User? in
                    var mutableDict = dict
                    mutableDict["id"] = key
                    return User(dictionary: mutableDict)
                }
                DispatchQueue.main.async {
                    self.users = users
                    if let userIdStr = UserDefaults.standard.string(forKey: "currentUserId"),
                       let userId = UUID(uuidString: userIdStr),
                       let updatedUser = users.first(where: { $0.id == userId }) {
                        self.currentUser = updatedUser
                        self.saveCurrentUserSettings()
                    }
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        
        // Current user observer
        if let userId = currentUser?.id.uuidString {
            dbRef.child("users").child(userId).observe(.value) { snapshot in
                if let userData = snapshot.value as? [String: Any],
                   let user = User(dictionary: userData) {
                    DispatchQueue.main.async {
                        self.currentUser = user
                        self.saveCurrentUserSettings()
                    }
                }
            }
        }
        
        // Treatment timer observer
        dbRef.child("treatmentTimer").observe(.value) { snapshot in
            print("Treatment timer update from Firebase at path \(dbRef.child("treatmentTimer").description()): \(String(describing: snapshot.value))")
            self.logToFile("Treatment timer update from Firebase at path \(dbRef.child("treatmentTimer").description()): \(String(describing: snapshot.value))")
            
            if let timerDict = snapshot.value as? [String: Any],
               let timerObj = TreatmentTimer.fromDictionary(timerDict) {
                
                print("Parsed timer object: isActive=\(timerObj.isActive), endTime=\(timerObj.endTime)")
                self.logToFile("Parsed timer object: isActive=\(timerObj.isActive), endTime=\(timerObj.endTime)")
                
                // Only update if the timer is still active and has not expired
                if timerObj.isActive && timerObj.endTime > Date() {
                    DispatchQueue.main.async {
                        self.treatmentTimer = timerObj
                        self.treatmentTimerId = timerObj.id
                        print("Updated local timer from Firebase")
                        self.logToFile("Updated local timer from Firebase")
                        
                        // Add this notification to ensure ContentView updates
                        NotificationCenter.default.post(
                            name: Notification.Name("ActiveTimerFound"),
                            object: timerObj
                        )
                    }
                } else {
                    // Timer is inactive or expired, clear it
                    DispatchQueue.main.async {
                        self.treatmentTimer = nil
                        self.treatmentTimerId = nil
                        print("Cleared local timer (inactive or expired)")
                        self.logToFile("Cleared local timer (inactive or expired)")
                    }
                    
                    // Clean up expired timer in Firebase
                    dbRef.child("treatmentTimer").removeValue()
                }
            } else {
                // No timer in Firebase, clear local timer
                DispatchQueue.main.async {
                    if self.treatmentTimer != nil {
                        self.treatmentTimer = nil
                        self.treatmentTimerId = nil
                        print("Cleared local timer (no timer in Firebase)")
                        self.logToFile("Cleared local timer (no timer in Firebase)")
                    }
                }
            }
        }
    }

    // Setup observers for a specific cycle's data
    private func setupCycleObservers(cycleId: String, cycleUUID: UUID) {
        guard let dbRef = dbRef else { return }
        
        // Observe items for this cycle
        let itemsRef = dbRef.child("cycles").child(cycleId).child("items")
        itemsRef.observe(.value) { snapshot in
            if let itemsDict = snapshot.value as? [String: [String: Any]] {
                let items = itemsDict.compactMap { (itemId, itemData) -> Item? in
                    var mutableItem = itemData
                    mutableItem["id"] = itemId
                    return Item(dictionary: mutableItem)
                }.sorted { $0.order < $1.order }
                
                DispatchQueue.main.async {
                    self.cycleItems[cycleUUID] = items
                    self.ensureItemUnitsExist()
                    self.saveCachedData()
                    self.objectWillChange.send()
                }
            } else if self.cycleItems[cycleUUID] == nil {
                DispatchQueue.main.async {
                    self.cycleItems[cycleUUID] = []
                }
            }
        }
        
        // Observe grouped items for this cycle
        let groupedItemsRef = dbRef.child("cycles").child(cycleId).child("groupedItems")
        groupedItemsRef.observe(.value) { snapshot in
            if let groupedItemsDict = snapshot.value as? [String: [String: Any]] {
                let groupedItems = groupedItemsDict.compactMap { (groupId, groupData) -> GroupedItem? in
                    var mutableGroup = groupData
                    mutableGroup["id"] = groupId
                    return GroupedItem(dictionary: mutableGroup)
                }
                
                DispatchQueue.main.async {
                    self.groupedItems[cycleUUID] = groupedItems
                    self.saveCachedData()
                    self.objectWillChange.send()
                }
            } else if self.groupedItems[cycleUUID] == nil {
                DispatchQueue.main.async {
                    self.groupedItems[cycleUUID] = []
                }
            }
        }
        
        // Observe reactions for this cycle - CRITICAL for ensuring reactions are always up to date
        let reactionsRef = dbRef.child("cycles").child(cycleId).child("reactions")
        reactionsRef.observe(.value) { snapshot in
            print("Reactions update for cycle \(cycleId): \(snapshot.exists() ? "exists" : "doesn't exist")")
            
            if let reactionsDict = snapshot.value as? [String: [String: Any]] {
                let reactions = reactionsDict.compactMap { (reactionId, reactionData) -> Reaction? in
                    var mutableReaction = reactionData
                    mutableReaction["id"] = reactionId
                    return Reaction(dictionary: mutableReaction)
                }
                
                DispatchQueue.main.async {
                    self.reactions[cycleUUID] = reactions
                    print("Updated reactions for cycle \(cycleId): \(reactions.count) reactions")
                    self.saveCachedData()
                    self.objectWillChange.send()
                    NotificationCenter.default.post(name: Notification.Name("ReactionsUpdated"), object: nil)
                }
            } else {
                // Important: if there are no reactions, we need to set an empty array to clear any stale data
                DispatchQueue.main.async {
                    self.reactions[cycleUUID] = []
                    print("Cleared reactions for cycle \(cycleId) - no reactions found")
                    self.saveCachedData()
                    self.objectWillChange.send()
                    NotificationCenter.default.post(name: Notification.Name("ReactionsUpdated"), object: nil)
                }
            }
        }
        
        // Observe consumption log for this cycle
        let logRef = dbRef.child("consumptionLog").child(cycleId)
        logRef.observe(.value) { snapshot in
            if snapshot.exists() {
                if let logData = snapshot.value as? [String: [[String: String]]] {
                    var cycleLog: [UUID: [LogEntry]] = [:]
                    
                    for (itemIdString, entries) in logData {
                        guard let itemId = UUID(uuidString: itemIdString) else { continue }
                        
                        let itemLogs = entries.compactMap { entry -> LogEntry? in
                            guard
                                let timestamp = entry["timestamp"],
                                let dateObj = ISO8601DateFormatter().date(from: timestamp),
                                let userIdString = entry["userId"],
                                let userId = UUID(uuidString: userIdString)
                            else { return nil }
                            
                            return LogEntry(date: dateObj, userId: userId)
                        }
                        
                        if !itemLogs.isEmpty {
                            cycleLog[itemId] = itemLogs
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.consumptionLog[cycleUUID] = cycleLog
                        self.saveCachedData()
                        self.objectWillChange.send()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.consumptionLog[cycleUUID] = [:]
                    self.saveCachedData()
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func observeCycles() {
        guard let dbRef = dbRef else { return }
        
        dbRef.child("cycles").observe(.value) { snapshot in
            if self.isAddingCycle { return }
            var newCycles: [Cycle] = []
            
            var newCycleItems = self.cycleItems
            var newGroupedItems = self.groupedItems
            var newReactions: [UUID: [Reaction]] = [:]
            
            print("Firebase cycles snapshot received: \(snapshot.key), childCount: \(snapshot.childrenCount)")
            self.logToFile("Firebase cycles snapshot received: \(snapshot.key), childCount: \(snapshot.childrenCount)")
            
            if snapshot.exists(), let value = snapshot.value as? [String: [String: Any]] {
                print("Processing \(value.count) cycles from Firebase")
                
                for (key, dict) in value {
                    var mutableDict = dict
                    mutableDict["id"] = key
                    guard let cycle = Cycle(dictionary: mutableDict) else {
                        print("Failed to parse cycle with key: \(key)")
                        continue
                    }
                    
                    print("Parsed cycle: \(cycle.number) - \(cycle.patientName)")
                    newCycles.append(cycle)
                    
                    if let itemsDict = dict["items"] as? [String: [String: Any]], !itemsDict.isEmpty {
                        let firebaseItems = itemsDict.compactMap { (itemKey, itemDict) -> Item? in
                            var mutableItemDict = itemDict
                            mutableItemDict["id"] = itemKey
                            return Item(dictionary: mutableItemDict)
                        }.sorted { $0.order < $1.order }
                        
                        if let localItems = newCycleItems[cycle.id] {
                            var mergedItems = localItems.map { localItem in
                                if let firebaseItem = firebaseItems.first(where: { $0.id == localItem.id }) {
                                    return Item(
                                        id: localItem.id,
                                        name: firebaseItem.name,
                                        category: firebaseItem.category,
                                        dose: firebaseItem.dose,
                                        unit: firebaseItem.unit,
                                        weeklyDoses: localItem.weeklyDoses ?? firebaseItem.weeklyDoses, // Preserve local weeklyDoses
                                        order: firebaseItem.order
                                    )
                                } else {
                                    return localItem
                                }
                            }
                            let newFirebaseItems = firebaseItems.filter { firebaseItem in
                                !mergedItems.contains(where: { mergedItem in mergedItem.id == firebaseItem.id })
                            }
                            mergedItems.append(contentsOf: newFirebaseItems)
                            newCycleItems[cycle.id] = mergedItems.sorted { $0.order < $1.order }
                        } else {
                            newCycleItems[cycle.id] = firebaseItems
                        }
                    } else if newCycleItems[cycle.id] == nil {
                        newCycleItems[cycle.id] = []
                    }
                    
                    if let groupedItemsDict = dict["groupedItems"] as? [String: [String: Any]] {
                        let firebaseGroupedItems = groupedItemsDict.compactMap { (groupKey, groupDict) -> GroupedItem? in
                            var mutableGroupDict = groupDict
                            mutableGroupDict["id"] = groupKey
                            return GroupedItem(dictionary: mutableGroupDict)
                        }
                        newGroupedItems[cycle.id] = firebaseGroupedItems
                    } else if newGroupedItems[cycle.id] == nil {
                        newGroupedItems[cycle.id] = []
                    }
                    
                    // Load reactions for this cycle
                    if let reactionsDict = dict["reactions"] as? [String: [String: Any]] {
                        let cycleReactions = reactionsDict.compactMap { (reactionKey, reactionDict) -> Reaction? in
                            var mutableReactionDict = reactionDict
                            mutableReactionDict["id"] = reactionKey
                            return Reaction(dictionary: mutableReactionDict)
                        }
                        
                        print("Found \(cycleReactions.count) reactions for cycle \(cycle.id)")
                        
                        if !cycleReactions.isEmpty {
                            newReactions[cycle.id] = cycleReactions
                        }
                    } else {
                        print("No reactions found for cycle \(cycle.id)")
                        // Make sure to clear any existing reactions for this cycle
                        newReactions[cycle.id] = []
                    }
                }
                DispatchQueue.main.async {
                    self.cycles = newCycles.sorted { $0.startDate < $1.startDate }
                    if !newCycleItems.isEmpty {
                        self.cycleItems = newCycleItems
                    }
                    if !newGroupedItems.isEmpty {
                        self.groupedItems = newGroupedItems
                    }
                    if !newReactions.isEmpty {
                        self.reactions = newReactions
                    }
                    self.saveCachedData()
                    self.syncError = nil
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    if self.cycles.isEmpty {
                        print("ERROR: No cycles found in Firebase or data is malformed: \(snapshot.key)")
                        self.syncError = "No cycles found in Firebase or data is malformed."
                    } else {
                        print("No cycles in Firebase but using cached data")
                        self.syncError = nil
                    }
                    self.isLoading = false
                }
            }
        } withCancel: { error in
            DispatchQueue.main.async {
                self.syncError = "Failed to sync cycles: \(error.localizedDescription)"
                self.isLoading = false
                print("Sync error: \(error.localizedDescription)")
                self.logToFile("Sync error: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensureItemUnitsExist() {
        var unitNames = Set(units.map { $0.name })
        
        // Scan all items in all cycles
        for (_, items) in cycleItems {
            for item in items {
                if let unitName = item.unit, !unitName.isEmpty, !unitNames.contains(unitName) {
                    // This item references a unit that doesn't exist in our units list
                    let newUnit = Unit(name: unitName)
                    units.append(newUnit)
                    unitNames.insert(unitName)
                    
                    // Save to Firebase if possible
                    if let dbRef = dbRef {
                        dbRef.child("units").child(newUnit.id.uuidString).setValue(newUnit.toDictionary())
                    }
                }
                
                // Also check weekly doses if present
                if let weeklyDoses = item.weeklyDoses, let unitName = item.unit, !unitName.isEmpty, !unitNames.contains(unitName) {
                    let newUnit = Unit(name: unitName)
                    units.append(newUnit)
                    unitNames.insert(unitName)
                    
                    // Save to Firebase if possible
                    if let dbRef = dbRef {
                        dbRef.child("units").child(newUnit.id.uuidString).setValue(newUnit.toDictionary())
                    }
                }
            }
        }
    }

    func setLastResetDate(_ date: Date) {
        guard let dbRef = dbRef else { return }
        dbRef.child("lastResetDate").setValue(ISO8601DateFormatter().string(from: date))
        lastResetDate = date
    }

    func setTreatmentTimerEnd(_ date: Date?) {
        guard let dbRef = dbRef else { return }
        if let date = date {
            dbRef.child("treatmentTimerEnd").setValue(ISO8601DateFormatter().string(from: date))
        } else {
            dbRef.child("treatmentTimerEnd").removeValue()
            self.treatmentTimerId = nil
        }
    }

    func addUnit(_ unit: Unit) {
        guard let dbRef = dbRef else { return }
        
        // Check if unit already exists with same name to avoid duplicates
        if !units.contains(where: { $0.name == unit.name }) {
            // Add to local array
            units.append(unit)
            
            // Save to Firebase
            dbRef.child("units").child(unit.id.uuidString).setValue(unit.toDictionary())
            
            // Save to cache for offline use
            saveCachedData()
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func addItem(_ item: Item, toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == toCycleId }), currentUser?.isAdmin == true else {
            completion(false)
            return
        }
        
        // Debug print to track item data
        print("Saving item to Firebase: \(item.name), weeklyDoses: \(item.weeklyDoses?.description ?? "none")")
        
        let currentItems = cycleItems[toCycleId] ?? []
        let newOrder = item.order == 0 ? currentItems.count : item.order
        let updatedItem = Item(
            id: item.id,
            name: item.name,
            category: item.category,
            dose: item.dose,
            unit: item.unit,
            weeklyDoses: item.weeklyDoses,
            order: newOrder
        )
        let itemRef = dbRef.child("cycles").child(toCycleId.uuidString).child("items").child(updatedItem.id.uuidString)
        
        // Convert weekly doses to the correct format for Firebase
        var itemDict = updatedItem.toDictionary()
        
        // If there are weekly doses, ensure they're in the right format for Firebase
        if let weeklyDoses = item.weeklyDoses, !weeklyDoses.isEmpty {
            var weeklyDosesDict: [String: [String: Any]] = [:]
            
            for (week, doseData) in weeklyDoses {
                weeklyDosesDict[String(week)] = [
                    "dose": doseData.dose,
                    "unit": doseData.unit
                ]
            }
            
            // Replace the weeklyDoses in the dictionary
            itemDict["weeklyDoses"] = weeklyDosesDict
        }
        
        // Log the exact dictionary being saved
        print("Firebase item dictionary: \(itemDict)")
        
        itemRef.setValue(itemDict) { error, _ in
            if let error = error {
                print("Error adding item \(updatedItem.id) to Firebase: \(error)")
                self.logToFile("Error adding item \(updatedItem.id) to Firebase: \(error)")
                completion(false)
            } else {
                print("Successfully saved item to Firebase: \(updatedItem.name)")
                DispatchQueue.main.async {
                    if var items = self.cycleItems[toCycleId] {
                        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                            items[index] = updatedItem
                        } else {
                            items.append(updatedItem)
                        }
                        self.cycleItems[toCycleId] = items.sorted { $0.order < $1.order }
                    } else {
                        self.cycleItems[toCycleId] = [updatedItem]
                    }
                    self.saveCachedData()
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }
    
    // Add this to the AppData class
    func refreshItemsFromFirebase(forCycleId cycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef else {
            completion(false)
            return
        }
        
        dbRef.child("cycles").child(cycleId.uuidString).child("items").observeSingleEvent(of: .value) { snapshot in
            if let items = snapshot.value as? [String: [String: Any]] {
                let refreshedItems = items.compactMap { (key, dict) -> Item? in
                    var mutableDict = dict
                    mutableDict["id"] = key
                    return Item(dictionary: mutableDict)
                }
                
                DispatchQueue.main.async {
                    self.cycleItems[cycleId] = refreshedItems
                    self.objectWillChange.send()
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }

    func saveItems(_ items: [Item], toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == toCycleId }) else {
            completion(false)
            return
        }
        let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0.toDictionary()) })
        dbRef.child("cycles").child(toCycleId.uuidString).child("items").setValue(itemsDict) { error, _ in
            if let error = error {
                print("Error saving items to Firebase: \(error)")
                self.logToFile("Error saving items to Firebase: \(error)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self.cycleItems[toCycleId] = items.sorted { $0.order < $1.order }
                    self.saveCachedData()
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }
    
    func itemDisplayText(item: Item, week: Int? = nil) -> String {
        let targetWeek = week ?? currentWeekNumber(forCycleId: currentCycleId())
        
        // For treatment items with weekly doses
        if item.category == .treatment, let weeklyDoses = item.weeklyDoses {
            // Try the target week first
            if let doseData = weeklyDoses[targetWeek] {
                let doseText = formatDose(doseData.dose)
                return "\(item.name) - \(doseText) \(doseData.unit) (Week \(targetWeek))"
            }
            
            // If target week not found, look for closest smaller week
            let availableWeeks = weeklyDoses.keys.sorted()
            let closestSmallerWeek = availableWeeks.last(where: { $0 <= targetWeek })
            
            if let week = closestSmallerWeek, let doseData = weeklyDoses[week] {
                let doseText = formatDose(doseData.dose)
                return "\(item.name) - \(doseText) \(doseData.unit) (Week \(week))"
            }
            
            // If no smaller week, try the smallest week available
            if let firstWeek = availableWeeks.first, let doseData = weeklyDoses[firstWeek] {
                let doseText = formatDose(doseData.dose)
                return "\(item.name) - \(doseText) \(doseData.unit) (Week \(firstWeek))"
            }
        }
        
        // For regular items with fixed dose
        if let dose = item.dose, let unit = item.unit {
            let doseText = formatDose(dose)
            return "\(item.name) - \(doseText) \(unit)"
        }
        
        return item.name
    }

    // Helper method to get the current week number for a cycle
    func currentWeekNumber(forCycleId cycleId: UUID?) -> Int {
        guard let cycleId = cycleId,
              let cycle = cycles.first(where: { $0.id == cycleId }) else { return 1 }
        
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return (daysSinceStart / 7) + 1
    }
    
    private func formatDose(_ dose: Double) -> String {
        if dose == 1.0 {
            return "1"
        } else if let fraction = Fraction.fractionForDecimal(dose) {
            return fraction.displayString
        } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%d", Int(dose))
        }
        return String(format: "%.1f", dose)
    }

    func removeItem(_ itemId: UUID, fromCycleId: UUID) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == fromCycleId }), currentUser?.isAdmin == true else { return }
        dbRef.child("cycles").child(fromCycleId.uuidString).child("items").child(itemId.uuidString).removeValue()
        if var items = cycleItems[fromCycleId] {
            items.removeAll { $0.id == itemId }
            cycleItems[fromCycleId] = items
            saveCachedData()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func addCycle(_ cycle: Cycle, copyItemsFromCycleId: UUID? = nil) {
        guard let dbRef = dbRef, currentUser?.isAdmin == true else { return }
        
        print("Adding cycle \(cycle.id) with number \(cycle.number)")
        
        if cycles.contains(where: { $0.id == cycle.id }) {
            print("Cycle \(cycle.id) already exists, updating")
            saveCycleToFirebase(cycle, withItems: cycleItems[cycle.id] ?? [], groupedItems: groupedItems[cycle.id] ?? [], previousCycleId: copyItemsFromCycleId)
            return
        }
        
        isAddingCycle = true
        cycles.append(cycle)
        var copiedItems: [Item] = []
        var copiedGroupedItems: [GroupedItem] = []
        
        let effectiveCopyId = copyItemsFromCycleId ?? (cycles.count > 1 ? cycles[cycles.count - 2].id : nil)
        
        if let fromCycleId = effectiveCopyId {
            dbRef.child("cycles").child(fromCycleId.uuidString).observeSingleEvent(of: .value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    if let itemsDict = dict["items"] as? [String: [String: Any]] {
                        copiedItems = itemsDict.compactMap { (itemKey, itemDict) -> Item? in
                            var mutableItemDict = itemDict
                            mutableItemDict["id"] = itemKey
                            return Item(dictionary: mutableItemDict)
                        }.map { Item(id: UUID(), name: $0.name, category: $0.category, dose: $0.dose, unit: $0.unit, weeklyDoses: $0.weeklyDoses, order: $0.order) }
                    }
                    if let groupedItemsDict = dict["groupedItems"] as? [String: [String: Any]] {
                        copiedGroupedItems = groupedItemsDict.compactMap { (groupKey, groupDict) -> GroupedItem? in
                            var mutableGroupDict = groupDict
                            mutableGroupDict["id"] = groupKey
                            return GroupedItem(dictionary: mutableGroupDict)
                        }.map { GroupedItem(id: UUID(), name: $0.name, category: $0.category, itemIds: $0.itemIds.map { _ in UUID() }) }
                    }
                }
                DispatchQueue.main.async {
                    self.cycleItems[cycle.id] = copiedItems
                    self.groupedItems[cycle.id] = copiedGroupedItems
                    self.saveCycleToFirebase(cycle, withItems: copiedItems, groupedItems: copiedGroupedItems, previousCycleId: effectiveCopyId)
                }
            } withCancel: { error in
                DispatchQueue.main.async {
                    self.cycleItems[cycle.id] = copiedItems
                    self.groupedItems[cycle.id] = copiedGroupedItems
                    self.saveCycleToFirebase(cycle, withItems: copiedItems, groupedItems: copiedGroupedItems, previousCycleId: effectiveCopyId)
                }
            }
        } else {
            cycleItems[cycle.id] = []
            groupedItems[cycle.id] = []
            saveCycleToFirebase(cycle, withItems: copiedItems, groupedItems: copiedGroupedItems, previousCycleId: effectiveCopyId)
        }
    }

    private func saveCycleToFirebase(_ cycle: Cycle, withItems items: [Item], groupedItems: [GroupedItem], previousCycleId: UUID?) {
        guard let dbRef = dbRef else { return }
        var cycleDict = cycle.toDictionary()
        let cycleRef = dbRef.child("cycles").child(cycle.id.uuidString)
        
        cycleRef.updateChildValues(cycleDict) { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    if let index = self.cycles.firstIndex(where: { $0.id == cycle.id }) {
                        self.cycles.remove(at: index)
                        self.cycleItems.removeValue(forKey: cycle.id)
                        self.groupedItems.removeValue(forKey: cycle.id)
                    }
                    self.isAddingCycle = false
                    self.objectWillChange.send()
                }
                return
            }
            
            if !items.isEmpty {
                let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0.toDictionary()) })
                cycleRef.child("items").updateChildValues(itemsDict)
            }
            
            if !groupedItems.isEmpty {
                let groupedItemsDict = Dictionary(uniqueKeysWithValues: groupedItems.map { ($0.id.uuidString, $0.toDictionary()) })
                cycleRef.child("groupedItems").updateChildValues(groupedItemsDict)
            }
            
            if let prevId = previousCycleId, let prevItems = self.cycleItems[prevId], !prevItems.isEmpty {
                let prevCycleRef = dbRef.child("cycles").child(prevId.uuidString)
                prevCycleRef.child("items").observeSingleEvent(of: .value) { snapshot in
                    if snapshot.value == nil || (snapshot.value as? [String: [String: Any]])?.isEmpty ?? true {
                        let prevItemsDict = Dictionary(uniqueKeysWithValues: prevItems.map { ($0.id.uuidString, $0.toDictionary()) })
                        prevCycleRef.child("items").updateChildValues(prevItemsDict)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if self.cycleItems[cycle.id] == nil || self.cycleItems[cycle.id]!.isEmpty {
                    self.cycleItems[cycle.id] = items
                }
                if self.groupedItems[cycle.id] == nil || self.groupedItems[cycle.id]!.isEmpty {
                    self.groupedItems[cycle.id] = groupedItems
                }
                self.saveCachedData()
                self.isAddingCycle = false
                self.objectWillChange.send()
            }
        }
    }

    func addUser(_ user: User) {
        guard let dbRef = dbRef else { return }
        print("Adding/updating user: \(user.id) with name: \(user.name)")
        
        let userRef = dbRef.child("users").child(user.id.uuidString)
        var userDict = user.toDictionary()
        // Add authId if available
        if let authId = Auth.auth().currentUser?.uid {
            userDict["authId"] = authId
        }
        userRef.setValue(userDict) { error, _ in
            if let error = error {
                print("Error adding/updating user \(user.id): \(error)")
                self.logToFile("Error adding/updating user \(user.id): \(error)")
            } else {
                print("Successfully added/updated user \(user.id) with name: \(user.name)")
            }
        }
        DispatchQueue.main.async {
            if let index = self.users.firstIndex(where: { $0.id == user.id }) {
                self.users[index] = user
            } else {
                self.users.append(user)
            }
            if self.currentUser?.id == user.id {
                self.currentUser = user
            }
            self.saveCurrentUserSettings()
        }
    }
    
    func syncRoomAccess() {
        let dbRef = Database.database().reference()
        dbRef.child("rooms").observeSingleEvent(of: .value) { snapshot in
            guard let rooms = snapshot.value as? [String: [String: Any]] else { return }
            for (roomId, roomData) in rooms {
                if let roomUsers = roomData["users"] as? [String: [String: Any]] {
                    for (userId, _) in roomUsers {
                        dbRef.child("users").child(userId).child("roomAccess").child(roomId).observeSingleEvent(of: .value) { userSnapshot in
                            if !userSnapshot.exists() {
                                let joinedAt = ISO8601DateFormatter().string(from: Date())
                                dbRef.child("users").child(userId).child("roomAccess").child(roomId).setValue([
                                    "joinedAt": joinedAt,
                                    "isActive": roomId == self.currentRoomId
                                ])
                            }
                        }
                    }
                }
            }
        }
    }
    
    func migrateRoomAccess() {
        guard let userId = currentUser?.id.uuidString else { return }
        let dbRef = Database.database().reference()
        dbRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot in
            guard let roomAccess = snapshot.value as? [String: Any] else { return }
            
            var updatedRoomAccess: [String: [String: Any]] = [:]
            let joinedAt = ISO8601DateFormatter().string(from: Date())
            
            for (roomId, accessData) in roomAccess {
                if let accessDict = accessData as? [String: Any] {
                    updatedRoomAccess[roomId] = accessDict
                } else if accessData as? Bool == true {
                    updatedRoomAccess[roomId] = [
                        "joinedAt": joinedAt,
                        "isActive": roomId == self.currentRoomId
                    ]
                }
            }
            
            dbRef.child("users").child(userId).child("roomAccess").setValue(updatedRoomAccess) { error, _ in
                if let error = error {
                    print("Error migrating roomAccess: \(error.localizedDescription)")
                } else {
                    print("Successfully migrated roomAccess for user \(userId)")
                }
            }
        }
    }

    func logConsumption(itemId: UUID, cycleId: UUID, date: Date = Date()) {
        guard let dbRef = dbRef, let userId = currentUser?.id, cycles.contains(where: { $0.id == cycleId }) else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        let logEntry = LogEntry(date: date, userId: userId)
        let today = Calendar.current.startOfDay(for: Date())

        // Fetch current Firebase state first
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot in
            var currentLogs = (snapshot.value as? [[String: String]]) ?? []
            let newEntryDict = ["timestamp": timestamp, "userId": userId.uuidString]
            
            // Remove any existing log for today to prevent duplicates
            currentLogs.removeAll { entry in
                if let logTimestamp = entry["timestamp"],
                   let logDate = formatter.date(from: logTimestamp) {
                    return Calendar.current.isDate(logDate, inSameDayAs: today)
                }
                return false
            }
            
            // Add the new entry
            currentLogs.append(newEntryDict)
            
            // Write to Firebase
            dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(currentLogs) { error, _ in
                if let error = error {
                    print("Failed to log consumption for \(itemId): \(error)")
                    self.logToFile("Failed to log consumption for \(itemId): \(error)")
                } else {
                    // Update local consumptionLog only after Firebase success
                    DispatchQueue.main.async {
                        if var cycleLog = self.consumptionLog[cycleId] {
                            var itemLogs = cycleLog[itemId] ?? []
                            // Remove today's existing logs locally
                            itemLogs.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }
                            itemLogs.append(logEntry)
                            cycleLog[itemId] = itemLogs
                            self.consumptionLog[cycleId] = cycleLog
                        } else {
                            self.consumptionLog[cycleId] = [itemId: [logEntry]]
                        }
                        // Clear pending updates for this item
                        if var cyclePending = self.pendingConsumptionLogUpdates[cycleId] {
                            cyclePending.removeValue(forKey: itemId)
                            if cyclePending.isEmpty {
                                self.pendingConsumptionLogUpdates.removeValue(forKey: cycleId)
                            } else {
                                self.pendingConsumptionLogUpdates[cycleId] = cyclePending
                            }
                        }
                        self.saveCachedData()
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }

    func removeConsumption(itemId: UUID, cycleId: UUID, date: Date) {
        guard let dbRef = dbRef else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        
        // Update local consumptionLog
        if var cycleLogs = consumptionLog[cycleId], var itemLogs = cycleLogs[itemId] {
            itemLogs.removeAll { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .second) }
            if itemLogs.isEmpty {
                cycleLogs.removeValue(forKey: itemId)
            } else {
                cycleLogs[itemId] = itemLogs
            }
            consumptionLog[cycleId] = cycleLogs.isEmpty ? nil : cycleLogs
            saveCachedData()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        // Update Firebase
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot in
            if var entries = snapshot.value as? [[String: String]] {
                entries.removeAll { $0["timestamp"] == timestamp }
                dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(entries.isEmpty ? nil : entries) { error, _ in
                    if let error = error {
                        print("Failed to remove consumption for \(itemId): \(error)")
                        self.logToFile("Failed to remove consumption for \(itemId): \(error)")
                    }
                }
            }
        }
    }

    func setConsumptionLog(itemId: UUID, cycleId: UUID, entries: [LogEntry]) {
        guard let dbRef = dbRef else { return }
        let formatter = ISO8601DateFormatter()
        let newEntries = Array(Set(entries)) // Deduplicate entries
        
        print("Setting consumption log for item \(itemId) in cycle \(cycleId) with entries: \(newEntries.map { $0.date })")
        
        // Fetch existing logs and update
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot in
            var existingEntries = (snapshot.value as? [[String: String]]) ?? []
            let newEntryDicts = newEntries.map { ["timestamp": formatter.string(from: $0.date), "userId": $0.userId.uuidString] }
            
            // Remove any existing entries not in the new list to prevent retaining old logs
            existingEntries = existingEntries.filter { existingEntry in
                guard let timestamp = existingEntry["timestamp"],
                      let date = formatter.date(from: timestamp) else { return false }
                return newEntries.contains { $0.date == date && $0.userId.uuidString == existingEntry["userId"] }
            }
            
            // Add new entries
            for newEntry in newEntryDicts {
                if !existingEntries.contains(where: { $0["timestamp"] == newEntry["timestamp"] && $0["userId"] == newEntry["userId"] }) {
                    existingEntries.append(newEntry)
                }
            }
            
            // Update local consumptionLog
            if var cycleLog = self.consumptionLog[cycleId] {
                cycleLog[itemId] = newEntries
                self.consumptionLog[cycleId] = cycleLog.isEmpty ? nil : cycleLog
            } else {
                self.consumptionLog[cycleId] = [itemId: newEntries]
            }
            if self.pendingConsumptionLogUpdates[cycleId] == nil {
                self.pendingConsumptionLogUpdates[cycleId] = [:]
            }
            self.pendingConsumptionLogUpdates[cycleId]![itemId] = newEntries
            self.saveCachedData()
            
            print("Updating Firebase with: \(existingEntries)")
            
            // Update Firebase
            dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(existingEntries.isEmpty ? nil : existingEntries) { error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to set consumption log for \(itemId): \(error)")
                        self.logToFile("Failed to set consumption log for \(itemId): \(error)")
                        self.syncError = "Failed to sync log: \(error.localizedDescription)"
                    } else {
                        if var cyclePending = self.pendingConsumptionLogUpdates[cycleId] {
                            cyclePending.removeValue(forKey: itemId)
                            if cyclePending.isEmpty {
                                self.pendingConsumptionLogUpdates.removeValue(forKey: cycleId)
                            } else {
                                self.pendingConsumptionLogUpdates[cycleId] = cyclePending
                            }
                        }
                        print("Firebase update complete, local log: \(self.consumptionLog[cycleId]?[itemId] ?? [])")
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    func setCategoryCollapsed(_ category: Category, isCollapsed: Bool) {
        guard let dbRef = dbRef else { return }
        categoryCollapsed[category.rawValue] = isCollapsed
        dbRef.child("categoryCollapsed").child(category.rawValue).setValue(isCollapsed)
    }
    
    func setGroupCollapsed(_ groupId: UUID, isCollapsed: Bool) {
        guard let dbRef = dbRef else { return }
        groupCollapsed[groupId] = isCollapsed
        dbRef.child("groupCollapsed").child(groupId.uuidString).setValue(isCollapsed)
    }

    func setReminderEnabled(_ category: Category, enabled: Bool) {
        guard var user = currentUser else { return }
        user.remindersEnabled[category] = enabled
        addUser(user)
    }

    func setReminderTime(_ category: Category, time: Date) {
        guard var user = currentUser else { return }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else { return }
        let now = Date()
        var normalizedComponents = calendar.dateComponents([.year, .month, .day], from: now)
        normalizedComponents.hour = hour
        normalizedComponents.minute = minute
        normalizedComponents.second = 0
        if let normalizedTime = calendar.date(from: normalizedComponents) {
            user.reminderTimes[category] = normalizedTime
            addUser(user)
        }
    }

    func setTreatmentFoodTimerEnabled(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.treatmentFoodTimerEnabled = enabled
        addUser(user)
    }

    func setTreatmentTimerDuration(_ duration: TimeInterval) {
        guard var user = currentUser else { return }
        user.treatmentTimerDuration = 900
        addUser(user)
    }

    func addGroupedItem(_ groupedItem: GroupedItem, toCycleId: UUID, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == toCycleId }), currentUser?.isAdmin == true else {
            completion(false)
            return
        }
        let groupRef = dbRef.child("cycles").child(toCycleId.uuidString).child("groupedItems").child(groupedItem.id.uuidString)
        groupRef.setValue(groupedItem.toDictionary()) { error, _ in
            if let error = error {
                print("Error adding grouped item \(groupedItem.id) to Firebase: \(error)")
                self.logToFile("Error adding grouped item \(groupedItem.id) to Firebase: \(error)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    var cycleGroups = self.groupedItems[toCycleId] ?? []
                    if let index = cycleGroups.firstIndex(where: { $0.id == groupedItem.id }) {
                        cycleGroups[index] = groupedItem
                    } else {
                        cycleGroups.append(groupedItem)
                    }
                    self.groupedItems[toCycleId] = cycleGroups
                    self.saveCachedData()
                    self.objectWillChange.send()
                    completion(true)
                }
            }
        }
    }

    func removeGroupedItem(_ groupId: UUID, fromCycleId: UUID) {
        guard let dbRef = dbRef, cycles.contains(where: { $0.id == fromCycleId }), currentUser?.isAdmin == true else { return }
        dbRef.child("cycles").child(fromCycleId.uuidString).child("groupedItems").child(groupId.uuidString).removeValue()
        if var groups = groupedItems[fromCycleId] {
            groups.removeAll { $0.id == groupId }
            groupedItems[fromCycleId] = groups
            saveCachedData()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func logGroupedItem(_ groupedItem: GroupedItem, cycleId: UUID, date: Date = Date()) {
        guard let dbRef = dbRef else { return }
        let today = Calendar.current.startOfDay(for: date)
        let isChecked = groupedItem.itemIds.allSatisfy { itemId in
            self.consumptionLog[cycleId]?[itemId]?.contains { Calendar.current.isDate($0.date, inSameDayAs: today) } ?? false
        }
        
        print("logGroupedItem: Group \(groupedItem.name) isChecked=\(isChecked)")
        self.logToFile("logGroupedItem: Group \(groupedItem.name) isChecked=\(isChecked)")
        
        if isChecked {
            for itemId in groupedItem.itemIds {
                if let logs = self.consumptionLog[cycleId]?[itemId], !logs.isEmpty {
                    print("Clearing all \(logs.count) logs for item \(itemId)")
                    self.logToFile("Clearing all \(logs.count) logs for item \(itemId)")
                    if var itemLogs = self.consumptionLog[cycleId] {
                        itemLogs[itemId] = []
                        if itemLogs[itemId]?.isEmpty ?? true {
                            itemLogs.removeValue(forKey: itemId)
                        }
                        self.consumptionLog[cycleId] = itemLogs.isEmpty ? nil : itemLogs
                    }
                    let path = "consumptionLog/\(cycleId.uuidString)/\(itemId.uuidString)"
                    dbRef.child(path).removeValue { error, _ in
                        if let error = error {
                            print("Failed to clear logs for \(itemId): \(error)")
                            self.logToFile("Failed to clear logs for \(itemId): \(error)")
                        } else {
                            print("Successfully cleared logs for \(itemId) in Firebase")
                            self.logToFile("Successfully cleared logs for \(itemId) in Firebase")
                        }
                    }
                }
            }
        } else {
            for itemId in groupedItem.itemIds {
                if !(self.consumptionLog[cycleId]?[itemId]?.contains { Calendar.current.isDate($0.date, inSameDayAs: today) } ?? false) {
                    print("Logging item \(itemId) for \(date)")
                    self.logToFile("Logging item \(itemId) for \(date)")
                    self.logConsumption(itemId: itemId, cycleId: cycleId, date: date)
                }
            }
        }
        self.saveCachedData()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func resetDaily() {
        let today = Calendar.current.startOfDay(for: Date())
        setLastResetDate(today)
        
        for (cycleId, itemLogs) in consumptionLog {
            var updatedItemLogs = itemLogs
            for (itemId, logs) in itemLogs {
                updatedItemLogs[itemId] = logs.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }
                if updatedItemLogs[itemId]?.isEmpty ?? false {
                    updatedItemLogs.removeValue(forKey: itemId)
                }
            }
            if let dbRef = dbRef {
                let formatter = ISO8601DateFormatter()
                let updatedLogDict = updatedItemLogs.mapValues { entries in
                    entries.map { ["timestamp": formatter.string(from: $0.date), "userId": $0.userId.uuidString] }
                }
                dbRef.child("consumptionLog").child(cycleId.uuidString).setValue(updatedLogDict.isEmpty ? nil : updatedLogDict)
            }
            consumptionLog[cycleId] = updatedItemLogs.isEmpty ? nil : updatedItemLogs
        }
        
        Category.allCases.forEach { category in
            setCategoryCollapsed(category, isCollapsed: false)
        }
        
        if let timer = treatmentTimer, timer.isActive, timer.endTime > Date() {
            print("Preserving active timer ending at: \(timer.endTime)")
            logToFile("Preserving active timer ending at: \(timer.endTime)")
        } else {
            treatmentTimer = nil
        }
        
        saveCachedData()
        saveTimerState()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func checkAndResetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if lastResetDate == nil || !Calendar.current.isDate(lastResetDate!, inSameDayAs: today) {
            resetDaily()
        }
    }

    func currentCycleId() -> UUID? {
        let today = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        
        // First check if today is within any cycle's date range
        for cycle in cycles {
            let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
            let cycleEndDay = calendar.startOfDay(for: cycle.foodChallengeDate)
            
            if todayStart >= cycleStartDay && todayStart <= cycleEndDay {
                return cycle.id
            }
        }
        
        // If we're between cycles, use the most recent cycle that has started
        return cycles.filter {
            calendar.startOfDay(for: $0.startDate) <= todayStart
        }.max(by: {
            $0.startDate < $1.startDate
        })?.id ?? cycles.last?.id
    }

    func verifyFirebaseState() {
        guard let dbRef = dbRef else { return }
        dbRef.child("cycles").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: [String: Any]] {
                print("Final Firebase cycles state: \(value)")
                self.logToFile("Final Firebase cycles state: \(value)")
            } else {
                print("Final Firebase cycles state is empty or missing")
                self.logToFile("Final Firebase cycles state is empty or missing")
            }
        }
    }

    func rescheduleDailyReminders() {
        guard let user = currentUser else { return }
        for category in Category.allCases where user.remindersEnabled[category] == true {
            if let view = UIApplication.shared.windows.first?.rootViewController?.view {
                RemindersView(appData: self).scheduleReminder(for: category)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 24 * 3600) {
            self.rescheduleDailyReminders()
        }
    }
}

struct TimerState: Codable {
    let timer: TreatmentTimer?
}

extension AppData {
    // This method logs a consumption for a specific item without triggering group logging behavior
    // Add or replace this method in your AppData extension
    func logIndividualConsumption(itemId: UUID, cycleId: UUID, date: Date = Date()) {
        guard let dbRef = dbRef, let userId = currentUser?.id, cycles.contains(where: { $0.id == cycleId }) else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        let logEntry = LogEntry(date: date, userId: userId)
        let calendar = Calendar.current
        let logDay = calendar.startOfDay(for: date)
        
        // Check if the item already has a log for this day locally
        if let existingLogs = consumptionLog[cycleId]?[itemId] {
            let existingLogForDay = existingLogs.first { calendar.isDate($0.date, inSameDayAs: logDay) }
            if existingLogForDay != nil {
                print("Item \(itemId) already has a log for \(logDay), skipping")
                return
            }
        }
        
        // Fetch current logs from Firebase
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot in
            var currentLogs = (snapshot.value as? [[String: String]]) ?? []
            
            // Deduplicate entries by day in case there are already duplicates in Firebase
            var entriesByDay = [String: [String: String]]()
            
            for entry in currentLogs {
                if let entryTimestamp = entry["timestamp"],
                   let entryDate = formatter.date(from: entryTimestamp) {
                    let dayKey = formatter.string(from: calendar.startOfDay(for: entryDate))
                    entriesByDay[dayKey] = entry
                }
            }
            
            // Check if there's already an entry for this day
            let todayKey = formatter.string(from: logDay)
            if entriesByDay[todayKey] != nil {
                print("Firebase already has an entry for \(logDay), skipping")
                return
            }
            
            // Add new entry
            let newEntryDict = ["timestamp": timestamp, "userId": userId.uuidString]
            entriesByDay[todayKey] = newEntryDict
            
            // Convert back to array
            let deduplicatedLogs = Array(entriesByDay.values)
            
            // Update Firebase
            dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(deduplicatedLogs) { error, _ in
                if let error = error {
                    print("Error logging consumption for \(itemId): \(error)")
                    self.logToFile("Error logging consumption for \(itemId): \(error)")
                } else {
                    // Update local data after Firebase success
                    DispatchQueue.main.async {
                        if var cycleLog = self.consumptionLog[cycleId] {
                            if var itemLogs = cycleLog[itemId] {
                                // Remove any existing logs for the same day before adding the new one
                                itemLogs.removeAll { calendar.isDate($0.date, inSameDayAs: logDay) }
                                itemLogs.append(logEntry)
                                cycleLog[itemId] = itemLogs
                            } else {
                                cycleLog[itemId] = [logEntry]
                            }
                            self.consumptionLog[cycleId] = cycleLog
                        } else {
                            self.consumptionLog[cycleId] = [itemId: [logEntry]]
                        }
                        
                        self.saveCachedData()
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    func deleteRoom(roomId: String, completion: @escaping (Bool, String?) -> Void) {
        let dbRef = Database.database().reference()

        // First, get all users with access to this room to update their room access
        dbRef.child("users").observeSingleEvent(of: .value) { snapshot in
            if let usersData = snapshot.value as? [String: [String: Any]] {
                for (userId, userData) in usersData {
                    if let roomAccess = userData["roomAccess"] as? [String: Any],
                       roomAccess[roomId] != nil {
                        // Remove this room from user's access
                        dbRef.child("users").child(userId).child("roomAccess").child(roomId).removeValue()
                    }
                    // Update ownedRooms for the owner
                    if userId == self.currentUser?.id.uuidString,
                       let ownedRooms = userData["ownedRooms"] as? [String] {
                        let updatedOwnedRooms = ownedRooms.filter { $0 != roomId }
                        dbRef.child("users").child(userId).child("ownedRooms").setValue(updatedOwnedRooms.isEmpty ? nil : updatedOwnedRooms)
                        DispatchQueue.main.async {
                            if var currentUser = self.currentUser {
                                currentUser.ownedRooms = updatedOwnedRooms.isEmpty ? nil : updatedOwnedRooms
                                self.currentUser = currentUser
                            }
                        }
                    }
                }

                // Now delete the room itself
                dbRef.child("rooms").child(roomId).removeValue { error, _ in
                    if let error = error {
                        print("Error deleting room: \(error.localizedDescription)")
                        completion(false, "Failed to delete room: \(error.localizedDescription)")
                    } else {
                        print("Room deleted successfully")
                        // If current room was deleted, clear it
                        if roomId == self.currentRoomId {
                            DispatchQueue.main.async {
                                self.currentRoomId = nil
                                UserDefaults.standard.removeObject(forKey: "currentRoomId")
                            }
                        }

                        NotificationCenter.default.post(name: Notification.Name("RoomDeleted"), object: nil)
                        NotificationCenter.default.post(name: Notification.Name("RoomLeft"), object: nil)
                        completion(true, nil)
                    }
                }
            } else {
                completion(false, "Could not get user list to update room access")
            }
        }
    }
    
    // This method enhances the deletion of consumption logs to ensure consistent state
    func removeIndividualConsumption(itemId: UUID, cycleId: UUID, date: Date) {
        guard let dbRef = dbRef else { return }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
        let calendar = Calendar.current
        
        // Update local consumptionLog first
        if var cycleLogs = consumptionLog[cycleId], var itemLogs = cycleLogs[itemId] {
            itemLogs.removeAll { calendar.isDate($0.date, equalTo: date, toGranularity: .second) }
            if itemLogs.isEmpty {
                cycleLogs.removeValue(forKey: itemId)
            } else {
                cycleLogs[itemId] = itemLogs
            }
            consumptionLog[cycleId] = cycleLogs.isEmpty ? nil : cycleLogs
            saveCachedData()
        }
        
        // Then update Firebase
        dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).observeSingleEvent(of: .value) { snapshot in
            if var entries = snapshot.value as? [[String: String]] {
                // Remove entries that match the date (could be multiple if there were duplicates)
                entries.removeAll { entry in
                    guard let entryTimestamp = entry["timestamp"],
                          let entryDate = formatter.date(from: entryTimestamp) else {
                        return false
                    }
                    return calendar.isDate(entryDate, equalTo: date, toGranularity: .second)
                }
                
                // Update or remove the entry in Firebase
                if entries.isEmpty {
                    dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).removeValue { error, _ in
                        if let error = error {
                            print("Error removing consumption for \(itemId): \(error)")
                            self.logToFile("Error removing consumption for \(itemId): \(error)")
                        } else {
                            print("Successfully removed all logs for item \(itemId)")
                            self.logToFile("Successfully removed all logs for item \(itemId)")
                        }
                    }
                } else {
                    dbRef.child("consumptionLog").child(cycleId.uuidString).child(itemId.uuidString).setValue(entries) { error, _ in
                        if let error = error {
                            print("Error updating consumption for \(itemId): \(error)")
                            self.logToFile("Error updating consumption for \(itemId): \(error)")
                        } else {
                            print("Successfully updated logs for item \(itemId)")
                            self.logToFile("Successfully updated logs for item \(itemId)")
                        }
                    }
                }
            }
        }
        
        // Ensure UI updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

extension AppData {
    // Method to safely access dbRef for direct Firebase operations in critical code paths
    func valueForDBRef() -> DatabaseReference? {
        return dbRef
    }
}
