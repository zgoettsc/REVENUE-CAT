//
//  NotificationsView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/14/25.
//


import SwiftUI

struct NotificationsView: View {
    @ObservedObject var appData: AppData
    
    var body: some View {
        List {
            NavigationLink(destination: RemindersView(appData: appData)) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                    Text("Dose Reminders")
                        .font(.headline)
                }
            }
            
            NavigationLink(destination: TreatmentFoodTimerView(appData: appData)) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.purple)
                    Text("Treatment Food Timer")
                        .font(.headline)
                }
            }
        }
        .navigationTitle("Notifications")
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationsView(appData: AppData())
        }
    }
}