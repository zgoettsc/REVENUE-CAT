//
//  FirstCyclePopupView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//

import SwiftUI

struct FirstCyclePopupView: View {
    @ObservedObject var appData: AppData
    @Binding var isPresented: Bool
    let cycle: Cycle
    let onDismiss: () -> Void
    @State private var showingCycleSetup = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Set Up Your First Cycle")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Would you like to set up your first cycle and add items now?")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Later") {
                        // Ensure the cycle is added before dismissing
                        appData.addCycle(cycle)
                        print("Added cycle with 'Later' option: \(cycle.id)")
                        isPresented = false
                        onDismiss()
                    }
                    .padding()
                    .frame(width: 120)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    Button("Set Up Now") {
                        // Add the cycle first, then show setup
                        appData.addCycle(cycle)
                        print("Added cycle with 'Set Up Now' option: \(cycle.id)")
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
            CycleSetupView(appData: appData, cycle: cycle)
                .onDisappear {
                    // Refresh the UI after setup
                    DispatchQueue.main.async {
                        appData.objectWillChange.send()
                    }
                    isPresented = false
                    onDismiss()
                }
        }
        .onAppear {
            print("FirstCyclePopupView appeared with cycle: \(cycle.id), name: \(cycle.patientName)")
        }
    }
}
