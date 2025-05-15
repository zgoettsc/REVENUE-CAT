// In TIPsApp.swift, replace the entire file content
import SwiftUI
import FirebaseCore
import UserNotifications
import FirebaseAuth
import FirebaseStorage
import RevenueCat

// Define AppDelegate class before referencing it
class AppDelegate: NSObject, UIApplicationDelegate {
    static let shared = AppDelegate()
    var appData: AppData! // Injected from TIPsApp
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("App did finish launching")
        appData.logToFile("App did finish launching")
        
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        application.registerForRemoteNotifications()
        
        // Load local timer state immediately
        appData.loadTimerState()
        
        // If we have a valid local timer, notify UI
        if let timer = appData.treatmentTimer, timer.isActive, timer.endTime > Date() {
            print("Found active timer on launch: \(timer.id), remaining: \(timer.endTime.timeIntervalSinceNow)s")
            appData.logToFile("Found active timer on launch: \(timer.id), remaining: \(timer.endTime.timeIntervalSinceNow)s")
            NotificationCenter.default.post(
                name: Notification.Name("ActiveTimerFound"),
                object: timer
            )
        }
        
        // Check Firebase after a delay
        if let roomId = appData.currentRoomId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Checking Firebase for timers on launch")
                self.appData.logToFile("Checking Firebase for timers on launch")
                self.appData.checkForActiveTimers()
            }
        }
        
        return true
    }
    
    // Add remote notifications handling
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        appData.logToFile("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
        appData.logToFile("Failed to register for remote notifications: \(error)")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("App will terminate")
        appData.logToFile("App will terminate")
        
        // Save timer state
        appData.saveTimerState()
        
        // Save to UserDefaults as backup
        if let timer = appData.treatmentTimer, timer.isActive, timer.endTime > Date() {
            let state = TimerState(timer: timer)
            if let data = try? JSONEncoder().encode(state) {
                UserDefaults.standard.set(data, forKey: "treatmentTimerState")
                UserDefaults.standard.synchronize()
                print("Saved timer to UserDefaults on termination")
                appData.logToFile("Saved timer to UserDefaults on termination")
            }
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App did enter background")
        appData.logToFile("App did enter background")
        
        // Save timer state
        appData.saveTimerState()
        
        // Save to UserDefaults as backup
        if let timer = appData.treatmentTimer, timer.isActive, timer.endTime > Date() {
            let state = TimerState(timer: timer)
            if let data = try? JSONEncoder().encode(state) {
                UserDefaults.standard.set(data, forKey: "treatmentTimerState")
                UserDefaults.standard.synchronize()
                print("Saved timer to UserDefaults on background")
                appData.logToFile("Saved timer to UserDefaults on background")
            }
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("App did become active")
        appData.logToFile("App did become active")
        
        // Clear badges when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        // Load local timer state
        appData.loadTimerState()
        
        // If we have a valid local timer, notify UI
        if let timer = appData.treatmentTimer, timer.isActive, timer.endTime > Date() {
            print("Found active timer on activation: \(timer.id), remaining: \(timer.endTime.timeIntervalSinceNow)s")
            appData.logToFile("Found active timer on activation: \(timer.id), remaining: \(timer.endTime.timeIntervalSinceNow)s")
            NotificationCenter.default.post(
                name: Notification.Name("ActiveTimerFound"),
                object: timer
            )
        }
        
        // Check Firebase after a delay
        if let roomId = appData.currentRoomId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Checking Firebase for timers on activation")
                self.appData.logToFile("Checking Firebase for timers on activation")
                self.appData.checkForActiveTimers()
            }
        }
    }
    
    // NotificationDelegate class
    class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        static let shared = NotificationDelegate()
        
        // Method to handle notification responses
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            guard let appData = AppDelegate.shared.appData else {
                print("NotificationDelegate: Missing appData")
                completionHandler()
                return
            }
            
            // Extract roomId from notification userInfo
            guard let roomId = response.notification.request.content.userInfo["roomId"] as? String else {
                print("NotificationDelegate: No roomId in notification")
                completionHandler()
                return
            }
            
            print("Handling notification for room: \(roomId)")
            appData.logToFile("Handling notification for room: \(roomId)")
            
            // Reset badge count
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().setBadgeCount(0)
            
            // Handle treatment timer notifications
            if response.notification.request.identifier.contains("treatment_timer_") {
                switch response.actionIdentifier {
                case "SNOOZE":
                    appData.snoozeTreatmentTimer(duration: 300, roomId: roomId)
                    print("Snoozed timer for room \(roomId)")
                    appData.logToFile("Snoozed timer for room \(roomId)")
                case "GO_TO_ROOM":
                    appData.stopTreatmentTimer(clearRoom: true, roomId: roomId)
                    print("Dismissed timer and switching to room \(roomId)")
                    appData.logToFile("Dismissed timer and switching to room \(roomId)")
                    
                    // Switch to the room
                    DispatchQueue.main.async {
                        appData.switchToRoom(roomId: roomId)
                    }
                case UNNotificationDefaultActionIdentifier:
                    // Default action when tapping notification
                    appData.stopTreatmentTimer(clearRoom: true, roomId: roomId)
                    print("Dismissed timer for room \(roomId) via default action")
                    appData.logToFile("Dismissed timer for room \(roomId) via default action")
                    
                    // Switch to the room when tapping notification
                    DispatchQueue.main.async {
                        appData.switchToRoom(roomId: roomId)
                    }
                default:
                    print("Unknown action: \(response.actionIdentifier) for room \(roomId)")
                    appData.logToFile("Unknown action: \(response.actionIdentifier) for room \(roomId)")
                }
            }
            // Handle reminder notifications
            else if response.notification.request.identifier.contains("reminder_") {
                switch response.actionIdentifier {
                case "DISMISS", UNNotificationDefaultActionIdentifier:
                    print("Dismissed reminder for room \(roomId)")
                    appData.logToFile("Dismissed reminder for room \(roomId)")
                    
                    // Switch to the room when tapping reminder
                    if roomId != appData.currentRoomId {
                        DispatchQueue.main.async {
                            appData.switchToRoom(roomId: roomId)
                        }
                    }
                default:
                    print("Unknown action for reminder: \(response.actionIdentifier)")
                    appData.logToFile("Unknown action for reminder: \(response.actionIdentifier)")
                }
            }
            
            completionHandler()
        }
        
        // Method to present notifications while app is in foreground
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            print("Will present notification: \(notification.request.identifier)")
            
            // For iOS 14 and above
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge, .list])
            } else {
                // For iOS 13 and below
                completionHandler([.alert, .sound, .badge])
            }
        }
        
        func scheduleSnoozeNotifications(appData: AppData) {
            guard let timer = appData.treatmentTimer else { return }
            
            let center = UNUserNotificationCenter.current()
            let baseId = timer.id
            let participantName = timer.roomName ?? appData.cycles.last?.patientName ?? "TIPs App"
            
            for i in 0..<4 {
                let content = UNMutableNotificationContent()
                content.title = "\(participantName): Time for the next treatment food"
                content.body = "Your 5-minute snooze has ended."
                content.sound = UNNotificationSound.default
                content.categoryIdentifier = "TREATMENT_TIMER"
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "treatment-timer-thread-\(baseId)"
                
                let delay = 300.0 + Double(i)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
                let request = UNNotificationRequest(identifier: "\(baseId)_repeat_\(i)", content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling snooze repeat \(i): \(error)")
                        appData.logToFile("Error scheduling snooze repeat \(i): \(error)")
                    } else {
                        print("Scheduled snooze repeat \(i) for \(participantName) in \(delay)s, id: \(request.identifier)")
                        appData.logToFile("Scheduled snooze repeat \(i) for \(participantName) in \(delay)s, id: \(request.identifier)")
                    }
                }
            }
        }
    }
    
    @main
    struct TIPsApp: App {
        @StateObject private var appData = AppData()
        @StateObject private var authViewModel = AuthViewModel()
        @Environment(\.scenePhase) private var scenePhase
        
        init() {
            FirebaseApp.configure()
            Purchases.configure(withAPIKey: "appl_xbvOWCkQEhgewsiKrzHbicOCOOd")
            setupNotifications()
            // Pass the shared appData to AppDelegate
            AppDelegate.shared.appData = appData
            UIApplication.shared.delegate = AppDelegate.shared
        }
        
        var body: some Scene {
            WindowGroup {
                ContentView(appData: appData)
                    .environmentObject(authViewModel)
                    .onChange(of: scenePhase) { newPhase in
                        switch newPhase {
                        case .active:
                            print("App became active")
                            appData.logToFile("App became active")
                        case .inactive:
                            print("App became inactive")
                            appData.logToFile("App became inactive")
                            appData.saveTimerState()
                        case .background:
                            print("App moved to background")
                            appData.logToFile("App moved to background")
                            appData.saveTimerState()
                        @unknown default:
                            print("Unknown scene phase")
                            appData.logToFile("Unknown scene phase")
                        }
                    }
            }
        }
        
        func setupNotifications() {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Error requesting notification permission: \(error)")
                } else {
                    print("Notification permission \(granted ? "granted" : "denied")")
                }
            }
            
            let goToRoomAction = UNNotificationAction(identifier: "GO_TO_ROOM", title: "Go to Room", options: [.foreground])
            let snoozeAction = UNNotificationAction(identifier: "SNOOZE", title: "Snooze for 5 min", options: [.foreground])
            
            let treatmentCategory = UNNotificationCategory(
                identifier: "TREATMENT_TIMER",
                actions: [goToRoomAction, snoozeAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            
            let reminderCategory = UNNotificationCategory(
                identifier: "REMINDER_CATEGORY",
                actions: [UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [.foreground])],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([treatmentCategory, reminderCategory])
        }
    }
}
