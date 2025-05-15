//
//  ManageRoomsAndSubscriptionsView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 5/10/25.
//


import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct ManageRoomsAndSubscriptionsView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var availableRooms: [String: (String, Bool)] = [:] // [roomId: (name, isOwned)]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingJoinRoom = false
    @State private var showingCreateRoom = false
    @State private var showingSubscriptionView = false
    @State private var currentRoomName: String = "Loading..."
    @State private var isSwitching = false
    @State private var roomToDelete: String? = nil
    @State private var roomToLeave: String? = nil
    @State private var showingDeleteAlert = false
    @State private var showingLeaveAlert = false
    @State private var showingLimitReachedAlert = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    
    private var subscriptionPlan: SubscriptionPlan {
        if let plan = appData.currentUser?.subscriptionPlan {
            return SubscriptionPlan(productID: plan)
        }
        return .none
    }
    
    private var roomLimit: Int {
        return appData.currentUser?.roomLimit ?? 0
    }
    
    private var ownedRoomCount: Int {
        return appData.currentUser?.ownedRooms?.count ?? 0
    }
    
    private var canCreateRoom: Bool {
        return ownedRoomCount < roomLimit
    }
    
    // Colors that adapt to light/dark mode
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(UIColor.secondarySystemBackground)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color.primary
    }
    
    private var subtitleColor: Color {
        colorScheme == .dark ? Color.gray : Color.secondary
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text("Rooms and Subscription")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                        .padding(.top, 20)
                    
                    // Subscription Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SUBSCRIPTION STATUS")
                            .font(.headline)
                            .foregroundColor(subtitleColor)
                            .padding(.leading)
                        
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subscriptionPlan.displayName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Text("\(ownedRoomCount) of \(roomLimit) rooms in use")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingSubscriptionView = true
                                }) {
                                    Text("Manage")
                                        .font(.callout)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Progress bar
                            VStack(spacing: 4) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 10)
                                            .cornerRadius(5)
                                        
                                        Rectangle()
                                            .fill(roomLimit > 0 ? (ownedRoomCount >= roomLimit ? Color.orange : Color.blue) : Color.gray)
                                            .frame(width: roomLimit > 0 ? min(CGFloat(ownedRoomCount) / CGFloat(roomLimit) * geometry.size.width, geometry.size.width) : 0, height: 10)
                                            .cornerRadius(5)
                                    }
                                }
                                .frame(height: 10)
                            }
                        }
                        .padding()
                        .background(cardBackgroundColor)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Current Room Section
                    if let roomId = appData.currentRoomId, !roomId.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ROOMS")
                                .font(.headline)
                                .foregroundColor(subtitleColor)
                                .padding(.leading)
                            
                            let isOwned = appData.currentUser?.ownedRooms?.contains(roomId) ?? false
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(cardBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green, lineWidth: 2) // Thin green border
                                    )
                                
                                VStack(spacing: 4) {
                                    RoomEntryView(roomId: roomId, roomName: currentRoomName, appData: appData)
                                        .padding()
                                        .background(Color.clear) // Ensure RoomEntryView doesn't override background
                                        .cornerRadius(10)
                                    
                                    // Status indicators
                                    HStack {
                                        Text(isOwned ? "Owner" : "Invited")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(isOwned ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                                            .foregroundColor(isOwned ? .blue : .orange)
                                            .cornerRadius(8)
                                        
                                        Spacer()
                                        
                                        Text("Active")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // For the OTHER ROOMS section:
                    ForEach(Array(availableRooms.keys.sorted()), id: \.self) { roomId in
                        if roomId != appData.currentRoomId {
                            let roomInfo = availableRooms[roomId]!
                            let roomName = roomInfo.0
                            let isOwned = roomInfo.1
                            
                            VStack(spacing: 4) {
                                RoomEntryView(roomId: roomId, roomName: roomName, appData: appData)
                                    .padding()
                                    .background(cardBackgroundColor)
                                    .cornerRadius(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        switchToRoom(roomId: roomId)
                                    }
                                
                                // Status indicators
                                HStack {
                                    Text(isOwned ? "Owner" : "Invited")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isOwned ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                                        .foregroundColor(isOwned ? .blue : .orange)
                                        .cornerRadius(8)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                            .background(cardBackgroundColor)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            if canCreateRoom {
                                showingCreateRoom = true
                            } else {
                                if roomLimit <= 0 {
                                    // No subscription - show subscription view
                                    showingSubscriptionView = true
                                } else {
                                    // Has subscription but reached limit
                                    showingLimitReachedAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(canCreateRoom ? .white : .gray)
                                Text("Create New Room")
                                    .font(.headline)
                                    .foregroundColor(canCreateRoom ? .white : .gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreateRoom ? Color.blue : Color.gray.opacity(0.3))
                            .cornerRadius(15)
                        }
                        .disabled(false) // Don't disable the button, handle the subscription check in the action
                        .padding(.horizontal)
                        
                        Button(action: {
                            showingJoinRoom = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(textColor)
                                Text("Join Room with Invite Code")
                                    .font(.headline)
                                    .foregroundColor(textColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(cardBackgroundColor)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                    // Footer Links
                    HStack {
                        Spacer()
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://www.zthreesolutions.com/privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Terms of Service") {
                            if let url = URL(string: "https://www.zthreesolutions.com/termsofuse") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    
                }
            }
            
            if isSwitching {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                    Text("Switching Room...")
                        .foregroundColor(.white)
                        .padding(.top, 10)
                }
                .padding(20)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(10)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentRoomName()
            loadAvailableRooms()
            loadUserSubscriptionStatus()
        }
        .sheet(isPresented: $showingJoinRoom) {
            JoinRoomView(appData: appData)
                .onDisappear {
                    loadAvailableRooms()
                }
        }
        .sheet(isPresented: $showingCreateRoom) {
            CreateRoomView(appData: appData)
                .environmentObject(authViewModel)
                .onDisappear {
                    loadAvailableRooms()
                }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            NavigationView {
                SubscriptionManagementView(appData: appData)
                    .navigationBarItems(trailing: Button("Done") {
                        showingSubscriptionView = false
                    })
            }
            .onDisappear {
                loadUserSubscriptionStatus()
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Room"),
                message: Text("Are you sure you want to delete this room?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let roomId = roomToDelete {
                        deleteRoom(roomId: roomId)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showingLeaveAlert) {
            Alert(
                title: Text("Leave Room"),
                message: Text("Are you sure you want to leave this room? You will no longer have access to the room data."),
                primaryButton: .destructive(Text("Leave")) {
                    if let roomId = roomToLeave {
                        leaveRoom(roomId: roomId)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showingLimitReachedAlert) {
            Alert(
                title: Text("Room Limit Reached"),
                message: Text("You have reached the maximum number of rooms allowed in your current subscription plan. Please upgrade your subscription to create more rooms."),
                primaryButton: .default(Text("Upgrade")) {
                    showingSubscriptionView = true
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SubscriptionUpdated"))) { _ in
            loadUserSubscriptionStatus()
            loadAvailableRooms()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RoomLeft"))) { _ in
            loadAvailableRooms()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RoomDeleted"))) { _ in
            loadAvailableRooms()
            loadUserSubscriptionStatus()
        }
    }
    
    private func loadCurrentRoomName() {
        guard let roomId = appData.currentRoomId else {
            currentRoomName = "No room selected"
            return
        }
        
        loadRoomName(roomId: roomId) { name in
            if let name = name {
                self.currentRoomName = name
            } else {
                self.currentRoomName = "Room \(roomId.prefix(6))"
            }
        }
    }
    
    private func loadRoomName(roomId: String, completion: @escaping (String?) -> Void) {
        let dbRef = Database.database().reference()
        dbRef.child("rooms").child(roomId).observeSingleEvent(of: .value) { snapshot, _ in
            if let roomData = snapshot.value as? [String: Any] {
                if let cycles = roomData["cycles"] as? [String: [String: Any]] {
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
                    
                    if let latestCycle = latestCycle,
                       let patientName = latestCycle["patientName"] as? String,
                       !patientName.isEmpty && patientName != "Unnamed" {
                        completion("\(patientName)'s Program")
                        return
                    }
                    
                    for (_, cycleData) in cycles {
                        if let patientName = cycleData["patientName"] as? String,
                           !patientName.isEmpty && patientName != "Unnamed" {
                            completion("\(patientName)'s Program")
                            return
                        }
                    }
                }
                
                if let roomName = roomData["name"] as? String {
                    completion(roomName)
                    return
                }
            }
            completion("Unknown Program")
        }
    }
    
    private func loadAvailableRooms() {
        guard let user = appData.currentUser else {
            errorMessage = "User not found"
            isLoading = false
            return
        }
        
        let userId = user.id.uuidString
        isLoading = true
        
        let dbRef = Database.database().reference()
        var rooms: [String: (String, Bool)] = [:]
        var userOwnedRooms = user.ownedRooms ?? []
        let dispatchGroup = DispatchGroup()
        
        // Debugging
        print("Loading rooms for user: \(userId)")
        print("User has \(userOwnedRooms.count) owned rooms")
        
        // First load room access information
        dispatchGroup.enter()
        dbRef.child("users").child(userId).child("roomAccess").observeSingleEvent(of: .value) { snapshot, _ in
            if let roomAccess = snapshot.value as? [String: Any] {
                print("Found \(roomAccess.count) rooms in roomAccess")
                for (roomId, _) in roomAccess {
                    dispatchGroup.enter()
                    self.loadRoomName(roomId: roomId) { roomName in
                        let isOwned = userOwnedRooms.contains(roomId)
                        rooms[roomId] = (roomName ?? "Room \(roomId.prefix(6))", isOwned)
                        print("Added room: \(roomId) with name: \(roomName ?? "unknown")")
                        dispatchGroup.leave()
                    }
                }
            } else {
                print("No roomAccess found for user")
            }
            dispatchGroup.leave()
        }
        
        // Also check rooms that have the user in their users list
        dispatchGroup.enter()
        dbRef.child("rooms").observeSingleEvent(of: .value) { snapshot, _ in
            if let allRooms = snapshot.value as? [String: [String: Any]] {
                print("Found \(allRooms.count) total rooms in database")
                for (roomId, roomData) in allRooms {
                    if let roomUsers = roomData["users"] as? [String: [String: Any]],
                       roomUsers[userId] != nil {
                        dispatchGroup.enter()
                        self.loadRoomName(roomId: roomId) { roomName in
                            let isOwned = userOwnedRooms.contains(roomId)
                            rooms[roomId] = (roomName ?? "Room \(roomId.prefix(6))", isOwned)
                            print("Added room from users list: \(roomId)")
                            dispatchGroup.leave()
                        }
                    }
                }
            } else {
                print("No rooms found in database")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            print("Found total of \(rooms.count) rooms for user")
            self.availableRooms = rooms
            self.isLoading = false
        }
    }
    
    func loadUserSubscriptionStatus() {
        let dbRef = Database.database().reference()
        
        guard let user = appData.currentUser else {
            return
        }
        
        let userId = user.id.uuidString
        
        // Use direct string instead of checking optionality
        dbRef.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if let userData = snapshot.value as? [String: Any] {
                var updatedUser = user
                updatedUser.subscriptionPlan = userData["subscriptionPlan"] as? String
                updatedUser.roomLimit = userData["roomLimit"] as? Int ?? 0
                updatedUser.ownedRooms = userData["ownedRooms"] as? [String]
                
                DispatchQueue.main.async {
                    self.appData.currentUser = updatedUser
                    self.loadAvailableRooms()
                }
            }
        }
    }
    
    private func switchToRoom(roomId: String) {
        isSwitching = true
        
        appData.switchToRoom(roomId: roomId)
        
        // Allow some time for the switch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSwitching = false
            loadCurrentRoomName()
            loadAvailableRooms()
            
            // If in settings, dismiss this view and navigate to home
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: Notification.Name("NavigateToHomeTab"), object: nil)
                self.dismiss()
            }
        }
    }
    
    private func leaveRoom(roomId: String) {
        appData.leaveRoom(roomId: roomId) { success, error in
            if success {
                loadAvailableRooms()
                loadUserSubscriptionStatus()
            } else if let error = error {
                errorMessage = error
            }
        }
    }
    
    private func deleteRoom(roomId: String) {
        // First check if this is a room the user owns
        guard let ownedRooms = appData.currentUser?.ownedRooms,
              ownedRooms.contains(roomId) else {
            errorMessage = "You can only delete rooms you have created"
            return
        }
        
        // Delete the room
        appData.deleteRoom(roomId: roomId) { success, error in
            if success {
                loadAvailableRooms()
                loadUserSubscriptionStatus()
            } else if let error = error {
                errorMessage = error
            }
        }
    }
}
