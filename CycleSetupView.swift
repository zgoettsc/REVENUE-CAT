//
//  CycleSetupView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//


import SwiftUI

struct CycleSetupView: View {
    @ObservedObject var appData: AppData
    @State var cycle: Cycle // Change to @State so we can update it
    @State private var currentStep = 0
    @Environment(\.dismiss) var dismiss
    
    // Track the edited values
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var profileImage: UIImage?
    
    let steps = ["Cycle Details", "Edit Items", "Group Items", "Reminders", "Treatment Timer"]
    
    init(appData: AppData, cycle: Cycle) {
        self.appData = appData
        self._cycle = State(initialValue: cycle)
        self._cycleNumber = State(initialValue: cycle.number)
        self._startDate = State(initialValue: cycle.startDate)
        self._foodChallengeDate = State(initialValue: cycle.foodChallengeDate)
        self._patientName = State(initialValue: cycle.patientName)
        // Load profile image
        self._profileImage = State(initialValue: appData.loadProfileImage(forCycleId: cycle.id))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                HStack(spacing: 4) { // Reduced spacing to give more room for text
                    ForEach(0..<steps.count, id: \.self) { index in
                        VStack {
                            Circle()
                                .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text("\(index + 1)")
                                        .foregroundColor(.white)
                                )
                            
                            Text(steps[index])
                                .font(.caption2) // Smaller font size for better fit
                                .minimumScaleFactor(0.6) // Allow text to shrink more if needed
                                .lineLimit(1) // Force single line
                                .foregroundColor(index <= currentStep ? .primary : .gray)
                                .fixedSize(horizontal: true, vertical: false) // Prevent wrapping
                        }
                        .frame(maxWidth: .infinity) // Distribute space evenly
                    }
                }
                .padding(.horizontal)
                
                // Current step view
                ZStack {
                    if currentStep == 0 {
                        // First step: Edit cycle details
                        VStack {
                            Form {
                                Section(header: Text("Participant Picture")) {
                                    HStack {
                                        if let profileImage = profileImage {
                                            Image(uiImage: profileImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Button("Change Photo") {
                                            // Handle photo change
                                        }
                                        .padding(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical)
                                }
                                
                                Section {
                                    HStack {
                                        Text("Cycle Number")
                                        Spacer()
                                        Picker("", selection: $cycleNumber) {
                                            ForEach(1...25, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                }
                                TextField("Participant Name", text: $patientName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                DatePicker("Cycle Dosing Start Date", selection: $startDate, displayedComponents: .date)
                                DatePicker("Food Challenge Date", selection: $foodChallengeDate, displayedComponents: .date)
                            }
                        }
                    } else if currentStep == 1 {
                        EditItemsView(appData: appData, cycleId: cycle.id)
                            .environment(\.isInsideNavigationView, true)
                    } else if currentStep == 2 {
                        EditGroupedItemsView(appData: appData, cycleId: cycle.id)
                            .environment(\.isInsideNavigationView, true)
                    } else if currentStep == 3 {
                        RemindersView(appData: appData)
                            .environment(\.isInsideNavigationView, true)
                    } else if currentStep == 4 {
                        TreatmentFoodTimerView(appData: appData)
                            .environment(\.isInsideNavigationView, true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                        .padding()
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == steps.count - 1 ? "Finish" : "Next") {
                        if currentStep == 0 {
                            // Save cycle details before moving to next step
                            let updatedCycle = Cycle(
                                id: cycle.id,
                                number: cycleNumber,
                                patientName: patientName.isEmpty ? "Unnamed" : patientName,
                                startDate: startDate,
                                foodChallengeDate: foodChallengeDate
                            )
                            appData.addCycle(updatedCycle)
                            
                            // Save profile image if available
                            if let profileImage = profileImage {
                                appData.saveProfileImage(profileImage, forCycleId: cycle.id)
                            }
                            
                            // Update local cycle state
                            cycle = updatedCycle
                            
                            print("Saved updated cycle: \(updatedCycle.patientName), start: \(updatedCycle.startDate), end: \(updatedCycle.foodChallengeDate)")
                            
                            // Move to next step
                            currentStep += 1
                        } else if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            // Finish setup - make sure UI refreshes
                            DispatchQueue.main.async {
                                appData.objectWillChange.send()
                                
                                // Navigate to home tab after setup is complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: Notification.Name("NavigateToHomeTab"), object: nil)
                                }
                            }
                            dismiss()
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Cycle Setup")
            .navigationBarItems(trailing: Button("Skip All") {
                // Make sure to save the cycle before skipping
                if currentStep == 0 {
                    let updatedCycle = Cycle(
                        id: cycle.id,
                        number: cycleNumber,
                        patientName: patientName.isEmpty ? "Unnamed" : patientName,
                        startDate: startDate,
                        foodChallengeDate: foodChallengeDate
                    )
                    appData.addCycle(updatedCycle)
                    
                    if let profileImage = profileImage {
                        appData.saveProfileImage(profileImage, forCycleId: cycle.id)
                    }
                }
                // Navigate to home tab after skipping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("NavigateToHomeTab"), object: nil)
                }
                dismiss()
            })
        }
    }
}
