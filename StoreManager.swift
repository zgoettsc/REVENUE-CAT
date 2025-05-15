import StoreKit
import FirebaseFunctions
import FirebaseAuth
import FirebaseDatabase
import SwiftUI
import RevenueCat

// Define subscription plans - keep this enum as it's used throughout your app
enum SubscriptionPlan: String {
    case none = "none"
    case plan1Room = "com.zthreesolutions.tolerancetracker.room01"
    case plan2Rooms = "com.zthreesolutions.tolerancetracker.room02"
    case plan3Rooms = "com.zthreesolutions.tolerancetracker.room03"
    case plan4Rooms = "com.zthreesolutions.tolerancetracker.room04"
    case plan5Rooms = "com.zthreesolutions.tolerancetracker.room05"
    
    init(productID: String) {
        switch productID {
        case "com.zthreesolutions.tolerancetracker.room01": self = .plan1Room
        case "com.zthreesolutions.tolerancetracker.room02": self = .plan2Rooms
        case "com.zthreesolutions.tolerancetracker.room03": self = .plan3Rooms
        case "com.zthreesolutions.tolerancetracker.room04": self = .plan4Rooms
        case "com.zthreesolutions.tolerancetracker.room05": self = .plan5Rooms
        default: self = .none
        }
    }
    
    var roomLimit: Int {
        switch self {
        case .none: return 0
        case .plan1Room: return 1
        case .plan2Rooms: return 2
        case .plan3Rooms: return 3
        case .plan4Rooms: return 4
        case .plan5Rooms: return 5
        }
    }
    
    var displayName: String {
        switch self {
        case .none: return "No Subscription"
        case .plan1Room: return "1 Room Plan"
        case .plan2Rooms: return "2 Room Plan"
        case .plan3Rooms: return "3 Room Plan"
        case .plan4Rooms: return "4 Room Plan"
        case .plan5Rooms: return "5 Room Plan"
        }
    }
}

class StoreManager: NSObject, ObservableObject {
    @Published var offerings: Offerings?
    @Published var currentSubscriptionPlan: SubscriptionPlan = .none
    @Published var isLoading = false
    
    override init() {
        super.init()
        
        // Configure RevenueCat - put this in a more central place if not already configured
        if Purchases.isConfigured == false {
            Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
        }
        
        requestProducts()
        updateSubscriptionStatus()
    }
    
    // Maps product IDs to room limits
    func getRoomLimitForProduct(_ productID: String) -> Int {
        return SubscriptionPlan(productID: productID).roomLimit
    }
    
    func requestProducts() {
        isLoading = true
        
        Purchases.shared.getOfferings { [weak self] offerings, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching offerings: \(error.localizedDescription)")
                    return
                }
                
                guard let offerings = offerings else {
                    print("No offerings found")
                    return
                }
                
                self?.offerings = offerings
                print("Found offerings: \(offerings.all.keys.joined(separator: ", "))")
            }
        }
    }
    
    func buyProduct(_ package: Package, completion: @escaping (Bool, String?) -> Void = { _, _ in }) {
        print("Initiating purchase for package: \(package.identifier)")
        self.isLoading = true
        
        Purchases.shared.purchase(package: package) { [weak self] transaction, purchaserInfo, error, userCancelled in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if userCancelled {
                    completion(false, "Purchase cancelled")
                    return
                }
                
                if let error = error {
                    print("Purchase failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let purchaserInfo = purchaserInfo {
                    print("Purchase successful")
                    self?.processSubscriptionChange(purchaserInfo: purchaserInfo)
                    completion(true, nil)
                } else {
                    completion(false, "Unknown error occurred")
                }
            }
        }
    }
    
    func restorePurchases(completion: @escaping (Bool, String?) -> Void = { _, _ in }) {
        print("Restoring purchases")
        self.isLoading = true
        
        Purchases.shared.restorePurchases { [weak self] purchaserInfo, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Restore failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let purchaserInfo = purchaserInfo {
                    print("Restore successful")
                    self?.processSubscriptionChange(purchaserInfo: purchaserInfo)
                    completion(true, nil)
                } else {
                    completion(false, "Unknown error occurred")
                }
            }
        }
    }
    
    func manageSubscriptions() {
        print("Opening subscription management")
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] purchaserInfo, error in
            if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
                return
            }
            
            if let purchaserInfo = purchaserInfo {
                self?.processSubscriptionChange(purchaserInfo: purchaserInfo)
            }
        }
    }
    
    private func processSubscriptionChange(purchaserInfo: CustomerInfo) {
        // Get the active entitlements
        let activeEntitlements = purchaserInfo.entitlements.active.keys
        print("Active entitlements: \(activeEntitlements)")
        
        // Map to your subscription plan
        var newPlan: SubscriptionPlan = .none
        var roomLimit = 0
        
        // This mapping needs to match your entitlements in RevenueCat dashboard
        if activeEntitlements.contains("1_entitlement") {
            newPlan = .plan1Room
            roomLimit = 1
        } else if activeEntitlements.contains("2_entitlement") {
            newPlan = .plan2Rooms
            roomLimit = 2
        } else if activeEntitlements.contains("3_entitlement") {
            newPlan = .plan3Rooms
            roomLimit = 3
        } else if activeEntitlements.contains("4_entitlement") {
            newPlan = .plan4Rooms
            roomLimit = 4
        } else if activeEntitlements.contains("5_entitlement") {
            newPlan = .plan5Rooms
            roomLimit = 5
        }
        
        self.currentSubscriptionPlan = newPlan
        
        // Update Firebase Database
        if let userId = Auth.auth().currentUser?.uid {
            let database = Database.database().reference()
            database.child("users").queryOrdered(byChild: "authId").queryEqual(toValue: userId).observeSingleEvent(of: .value) { snapshot in
                if snapshot.exists(), let userData = snapshot.value as? [String: [String: Any]], let userKey = userData.keys.first {
                    database.child("users").child(userKey).updateChildValues([
                        "subscriptionPlan": newPlan.rawValue,
                        "roomLimit": roomLimit
                    ]) { error, _ in
                        if let error = error {
                            print("Error updating user subscription: \(error)")
                        } else {
                            print("Successfully updated user subscription to \(newPlan.rawValue) with limit \(roomLimit)")
                            NotificationCenter.default.post(
                                name: Notification.Name("SubscriptionUpdated"),
                                object: nil,
                                userInfo: ["plan": newPlan.rawValue, "limit": roomLimit]
                            )
                        }
                    }
                } else {
                    print("User not found in database")
                }
            }
        } else {
            print("No authenticated user")
        }
    }
}
