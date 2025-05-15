import SwiftUI
import StoreKit
import FirebaseDatabaseInternal
import RevenueCat

struct SubscriptionManagementView: View {
    @ObservedObject var appData: AppData
    @StateObject private var storeManager = StoreManager()
    @State private var selectedPackage: Package?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showingConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    private var currentPlan: SubscriptionPlan {
        if let plan = appData.currentUser?.subscriptionPlan {
            return SubscriptionPlan(productID: plan)
        }
        return .none
    }
    
    private var currentRoomCount: Int {
        return appData.currentUser?.ownedRooms?.count ?? 0
    }
    
    private var roomLimit: Int {
        return appData.currentUser?.roomLimit ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Subscription Management")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Manage your room subscription plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Current subscription info
                VStack(spacing: 12) {
                    Text("Current Plan")
                        .font(.headline)
                    
                    VStack(alignment: .center, spacing: 8) {
                        Text(currentPlan.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if currentPlan != .none {
                            HStack {
                                Text("Rooms: \(currentRoomCount)/\(roomLimit)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(currentRoomCount >= roomLimit ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                    )
                                    .foregroundColor(currentRoomCount >= roomLimit ? .orange : .green)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Available Plans
                VStack(alignment: .leading, spacing: 15) {
                    Text("Available Plans")
                        .font(.headline)
                        .padding(.leading)
                    
                    if storeManager.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading available plans...")
                            Spacer()
                        }
                        .padding()
                    } else if storeManager.offerings?.current?.availablePackages.isEmpty ?? true {
                        Text("No subscription plans available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let packages = storeManager.offerings?.current?.availablePackages {
                        ForEach(packages, id: \.identifier) { package in
                            let productId = package.storeProduct.productIdentifier
                            let isCurrentPlan = productId == currentPlan.rawValue
                            let roomCount = storeManager.getRoomLimitForProduct(productId)
                            
                            Button(action: {
                                self.selectedPackage = package
                                self.showingConfirmation = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(roomCount) Room\(roomCount > 1 ? "s" : "") Plan")
                                            .font(.headline)
                                        
                                        Text(package.localizedPriceString)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isCurrentPlan {
                                        Text("Current")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    } else if currentRoomCount > roomCount {
                                        Text("Need to remove \(currentRoomCount - roomCount) room\(currentRoomCount - roomCount > 1 ? "s" : "")")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(8)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isCurrentPlan ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                                )
                            }
                            .disabled(isCurrentPlan || isProcessing)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        storeManager.restorePurchases { success, error in
                            if !success, let error = error {
                                self.errorMessage = error
                                self.showError = true
                            }
                        }
                    }) {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    
                    Button(action: {
                        storeManager.manageSubscriptions()
                    }) {
                        Label("Manage in App Store", systemImage: "creditcard")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingConfirmation) {
            guard let package = selectedPackage else {
                return Alert(title: Text("Error"), message: Text("No package selected"), dismissButton: .default(Text("OK")))
            }
            
            let productId = package.storeProduct.productIdentifier
            let roomCount = storeManager.getRoomLimitForProduct(productId)
            
            if currentRoomCount > roomCount {
                // Warning about room reduction
                return Alert(
                    title: Text("Remove Rooms Required"),
                    message: Text("To downgrade to this plan, you need to remove \(currentRoomCount - roomCount) room(s) first."),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                // Normal confirmation
                return Alert(
                    title: Text("Confirm Subscription"),
                    message: Text("Do you want to subscribe to the \(roomCount) Room Plan for \(package.localizedPriceString) per month?"),
                    primaryButton: .default(Text("Subscribe")) {
                        purchasePackage(package)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            storeManager.requestProducts()
            loadUserSubscriptionStatus()
        }
    }
    
    private func purchasePackage(_ package: Package) {
        isProcessing = true
        print("Purchasing \(package.identifier)...")
        storeManager.buyProduct(package) { success, error in
            isProcessing = false
            if success {
                print("Purchase successful for \(package.identifier)")
                loadUserSubscriptionStatus()
                
                // Post notification about subscription change
                NotificationCenter.default.post(
                    name: Notification.Name("SubscriptionUpdated"),
                    object: nil,
                    userInfo: ["productId": package.storeProduct.productIdentifier]
                )
            } else if let error = error {
                print("Purchase failed: \(error)")
                errorMessage = error
                showError = true
            }
        }
    }
    
    private func loadUserSubscriptionStatus() {
        let dbRef = Database.database().reference()
        
        guard let user = appData.currentUser else {
            return
        }
        
        // Use direct string instead of checking optionality
        let userId = user.id.uuidString
        
        dbRef.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if let userData = snapshot.value as? [String: Any] {
                var updatedUser = user
                updatedUser.subscriptionPlan = userData["subscriptionPlan"] as? String
                updatedUser.roomLimit = userData["roomLimit"] as? Int ?? 0
                
                DispatchQueue.main.async {
                    self.appData.currentUser = updatedUser
                }
            }
        }
    }
}
