import SwiftUI

struct TreatmentFoodTimerView: View {
    @ObservedObject var appData: AppData
    @Environment(\.isInsideNavigationView) var isInsideNavigationView
    
    init(appData: AppData) {
        self.appData = appData
    }
    
    var body: some View {
        Form {
            Section(header: Text("Treatment Food Timer Notification")) {
                Toggle("Enable Notification", isOn: Binding(
                    get: { appData.currentUser?.treatmentFoodTimerEnabled ?? false },
                    set: { newValue in
                        appData.setTreatmentFoodTimerEnabled(newValue)
                        if !newValue {
                            cancelAllTreatmentTimers()
                        }
                    }
                ))
                
                Text("When enabled, a notification will alert the user 15 minutes after a treatment food is logged. The Home tab will always display the remaining timer duration.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Treatment Food Timer")
        .onAppear {
            if isInsideNavigationView {
                print("TreatmentFoodTimerView is correctly inside a NavigationView")
            } else {
                print("Warning: TreatmentFoodTimerView is not inside a NavigationView")
            }
        }
    }
    
    func cancelAllTreatmentTimers() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
