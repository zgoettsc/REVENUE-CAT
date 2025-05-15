//
//  InitialRoomsAndSubscriptionsView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 5/10/25.
//


import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct InitialRoomsAndSubscriptionsView: View {
    @ObservedObject var appData: AppData
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var availableRooms: [String: (String, Bool)] = [:] // [roomId: (name, isOwned)]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingJoinRoom = false
    @State private var showingCreateRoom = false
    @State private var showingSubscriptionView = false
    @State private var isSwitching = false
    @State private var roomToDelete: String? = nil
    @State private var roomToLeave: String? = nil
    @State private var showingDeleteAlert = false
    @State private var showingLeaveAlert = false
    @State private var showingLimitReachedAlert = false
    @State private var showingSignOutAlert = false
    @State private var showOnboarding = false
    @Environment(\.colorScheme) private var colorScheme
    
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
                    Text("Select a Room")
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
                    
                    // Available Rooms Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AVAILABLE ROOMS")
                            .font(.headline)
                            .foregroundColor(subtitleColor)
                            .padding(.leading)
                        
                        if isLoading {
                            ProgressView("Loading rooms...")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(cardBackgroundColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(cardBackgroundColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        } else if availableRooms.isEmpty {
                            Text("No rooms available")
                                .foregroundColor(subtitleColor)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(cardBackgroundColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        } else {
                            ForEach(Array(availableRooms.keys.sorted()), id: \.self) { roomId in
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
                                            // Use switchToRoom or enterRoom depending on which view
                                            enterRoom(roomId: roomId) // or enterRoom(roomId: roomId)
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
                                        
                                        // Remove the leave/delete button completely
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                }
                                .background(cardBackgroundColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
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
                        
                        // Sign Out Button
                        Button(action: {
                            showingSignOutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
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
                    Text("Entering Room...")
                        .foregroundColor(.white)
                        .padding(.top, 10)
                }
                .padding(20)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(10)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            // Check if we should show the onboarding (first-time user)
            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                // Delay slightly to allow the view to fully appear first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showOnboarding = true
                }
            }
            
            // Fetch current user data
            fetchUserData()
            // Check if we have valid auth and user data
            if let currentUser = Auth.auth().currentUser {
                print("Firebase Auth user is logged in: \(currentUser.uid)")
                
                // If we have an authId but no appData.currentUser, try to fetch user data
                if appData.currentUser == nil {
                    let dbRef = Database.database().reference()
                    dbRef.child("auth_mapping").child(currentUser.uid).observeSingleEvent(of: .value) { snapshot in
                        if let userIdString = snapshot.value as? String {
                            print("Found user mapping: \(userIdString)")
                            dbRef.child("users").child(userIdString).observeSingleEvent(of: .value) { userSnapshot in
                                if let userData = userSnapshot.value as? [String: Any],
                                   let user = User(dictionary: userData) {
                                    DispatchQueue.main.async {
                                        self.appData.currentUser = user
                                        print("Successfully retrieved user data: \(user.name)")
                                        self.loadAvailableRooms()
                                        self.loadUserSubscriptionStatus()
                                    }
                                } else {
                                    print("Failed to parse user data")
                                }
                            }
                        } else {
                            print("No user mapping found for auth ID: \(currentUser.uid)")
                        }
                    }
                } else {
                    loadAvailableRooms()
                    loadUserSubscriptionStatus()
                }
            } else {
                print("No Firebase Auth user logged in")
            }
            // Check if we have valid auth and user data
            if let currentUser = Auth.auth().currentUser {
                print("Firebase Auth user is logged in: \(currentUser.uid)")
                // Rest of your existing code...
            }
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
        .alert(isPresented: $showingSignOutAlert) {
            Alert(
                title: Text("Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    signOut()
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SubscriptionUpdated"))) { _ in
            print("Subscription updated notification received, refreshing user data")
            fetchUserData()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isShowingOnboarding: $showOnboarding)
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
    
    func loadUserSubscriptionStatus() {
        let dbRef = Database.database().reference()
        
        guard let user = appData.currentUser else {
            return
        }
        
        let userId = user.id.uuidString
        
        dbRef.child("users").child(userId).observeSingleEvent(of: .value) { snapshot, _ in
            if let userData = snapshot.value as? [String: Any] {
                var updatedUser = user
                updatedUser.subscriptionPlan = userData["subscriptionPlan"] as? String
                updatedUser.roomLimit = userData["roomLimit"] as? Int ?? 0
                
                DispatchQueue.main.async {
                    self.appData.currentUser = updatedUser
                    print("Updated user with plan: \(updatedUser.subscriptionPlan ?? "none"), limit: \(updatedUser.roomLimit)")
                }
            }
        }
    }
    
    private func enterRoom(roomId: String) {
        isSwitching = true
        
        appData.switchToRoom(roomId: roomId)
        
        // Post notification to navigate to home tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: Notification.Name("NavigateToHomeTab"), object: nil)
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

    func fetchUserData() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No Firebase Auth user logged in")
            return
        }
        
        print("Fetching user data for auth ID: \(currentUser.uid)")
        let dbRef = Database.database().reference()
        
        // First check if user mapping exists
        dbRef.child("auth_mapping").child(currentUser.uid).observeSingleEvent(of: .value) { snapshot in
            if let userIdString = snapshot.value as? String {
                print("Found user mapping: \(userIdString)")
                
                // Load user data from Firebase
                dbRef.child("users").child(userIdString).observeSingleEvent(of: .value) { userSnapshot in
                    if let userData = userSnapshot.value as? [String: Any] {
                        print("Found user data: \(userData)")
                        
                        // Create User object
                        var userDict = userData
                        userDict["id"] = userIdString
                        
                        if let user = User(dictionary: userDict) {
                            DispatchQueue.main.async {
                                self.appData.currentUser = user
                                print("Successfully loaded user: \(user.name), plan: \(user.subscriptionPlan ?? "none"), limit: \(user.roomLimit)")
                                
                                // Refresh available rooms
                                self.loadAvailableRooms()
                                self.loadUserSubscriptionStatus()
                            }
                        } else {
                            print("Failed to parse user data")
                        }
                    } else {
                        print("No user data found for ID: \(userIdString)")
                    }
                }
            } else {
                print("No user mapping found for auth ID: \(currentUser.uid)")
            }
        }
    }
    private func signOut() {
        // Sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
            
            // Clear local app state
            appData.currentUser = nil
            appData.currentRoomId = nil
            
            // Remove from UserDefaults
            UserDefaults.standard.removeObject(forKey: "currentUserId")
            UserDefaults.standard.removeObject(forKey: "currentRoomId")
            
            // Post notification about user sign out
            NotificationCenter.default.post(name: Notification.Name("UserDidSignOut"), object: nil)
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }
}
