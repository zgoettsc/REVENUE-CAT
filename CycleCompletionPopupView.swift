//
//  CycleCompletionPopupView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//


import SwiftUI

struct CycleCompletionPopupView: View {
    @ObservedObject var appData: AppData
    @Binding var isPresented: Bool
    let previousCycle: Cycle
    @State private var showingCycleSetup = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Cycle \(previousCycle.number) Completed!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your food challenge date has passed. Would you like to start a new cycle?")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Later") {
                        isPresented = false
                    }
                    .padding()
                    .frame(width: 120)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    Button("Start New Cycle") {
                        // Create a new cycle with incremented number
                        let newCycleId = UUID()
                        let newCycle = Cycle(
                            id: newCycleId,
                            number: previousCycle.number + 1,
                            patientName: previousCycle.patientName,
                            startDate: Date(),
                            foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!
                        )
                        
                        // Force delete ALL grouped items for this new cycle
                        appData.nukeAllGroupedItems(forCycleId: newCycleId)
                        
                        // Also nuke groups from the previous cycle since we don't need them anymore
                        appData.nukeAllGroupedItems(forCycleId: previousCycle.id)
                        
                        // Copy profile image
                        if let profileImage = appData.loadProfileImage(forCycleId: previousCycle.id) {
                            appData.saveProfileImage(profileImage, forCycleId: newCycleId)
                        }
                        
                        // Start cycle setup with the new cycle
                        UserDefaults.standard.set(newCycleId.uuidString, forKey: "newCycleId")
                        showingCycleSetup = true
                    }
                    .padding()
                    .frame(width: 120)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(30)
        }
        .fullScreenCover(isPresented: $showingCycleSetup) {
            NewCycleSetupView(appData: appData, previousCycle: previousCycle)
                .onDisappear {
                    isPresented = false
                }
        }
    }
}
