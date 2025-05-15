//
//  NewCycleSetupView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//


import SwiftUI

struct NewCycleSetupView: View {
    @ObservedObject var appData: AppData
    let previousCycle: Cycle
    @State private var currentStep = 0
    @Environment(\.dismiss) var dismiss
    
    // New cycle properties
    @State private var newCycle: Cycle
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var profileImage: UIImage?
    
    let steps = ["Cycle Details", "Edit Items", "Group Items", "Reminders", "Treatment Timer"]
    
    init(appData: AppData, previousCycle: Cycle) {
        self.appData = appData
        self.previousCycle = previousCycle
        
        // Create new cycle with incremented number
        let newCycleId = UUID()
        let tempNewCycle = Cycle(
            id: newCycleId,
            number: previousCycle.number + 1,
            patientName: previousCycle.patientName,
            startDate: Date(),
            foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!
        )
        
        self._newCycle = State(initialValue: tempNewCycle)
        self._cycleNumber = State(initialValue: tempNewCycle.number)
        self._startDate = State(initialValue: tempNewCycle.startDate)
        self._foodChallengeDate = State(initialValue: tempNewCycle.foodChallengeDate)
        self._patientName = State(initialValue: tempNewCycle.patientName)
        
        // Copy profile image
        self._profileImage = State(initialValue: appData.loadProfileImage(forCycleId: previousCycle.id))
        DispatchQueue.main.async {
                if let dbRef = appData.valueForDBRef() {
                    // Forcibly remove all groupedItems
                    dbRef.child("cycles").child(newCycleId.uuidString).child("groupedItems").removeValue()
                }
                // Clear in memory too
                appData.groupedItems[newCycleId] = []
            }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                HStack(spacing: 0) {
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
                                .font(.caption)
                                .foregroundColor(index <= currentStep ? .primary : .gray)
                        }
                        
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                
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
                                            // Photo change handling
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
                        // Copy items step
                        EditItemsView(appData: appData, cycleId: newCycle.id)
                            .onAppear {
                                copyItems()
                            }
                            .environment(\.isInsideNavigationView, true)
                    } else if currentStep == 2 {
                        EditGroupedItemsView(appData: appData, cycleId: newCycle.id)
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
                                id: newCycle.id,
                                number: cycleNumber,
                                patientName: patientName.isEmpty ? "Unnamed" : patientName,
                                startDate: startDate,
                                foodChallengeDate: foodChallengeDate
                            )
                            appData.addCycle(updatedCycle)
                            
                            // Save profile image if available
                            if let profileImage = profileImage {
                                appData.saveProfileImage(profileImage, forCycleId: newCycle.id)
                            }
                            
                            // Update local cycle state
                            newCycle = updatedCycle
                            
                            // Move to next step
                            currentStep += 1
                        } else if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            // Finish setup - make sure UI refreshes
                            DispatchQueue.main.async {
                                appData.objectWillChange.send()
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
            .onAppear {
                        // Clear grouped items immediately when the view appears
                        appData.clearGroupedItems(forCycleId: newCycle.id)
                        appData.groupedItems[newCycle.id] = []
                        
                        // Also ensure it's empty in Firebase
                        if let dbRef = appData.valueForDBRef() {
                            dbRef.child("cycles").child(newCycle.id.uuidString).child("groupedItems").setValue([:])
                            print("Explicitly cleared groupedItems in Firebase for cycle \(newCycle.id)")
                        }
                    }
            .navigationTitle("New Cycle Setup: Step \(currentStep + 1)")
            .navigationBarItems(trailing: Button("Skip All") {
                // Make sure to save the cycle before skipping
                if currentStep == 0 {
                    let updatedCycle = Cycle(
                        id: newCycle.id,
                        number: cycleNumber,
                        patientName: patientName.isEmpty ? "Unnamed" : patientName,
                        startDate: startDate,
                        foodChallengeDate: foodChallengeDate
                    )
                    appData.addCycle(updatedCycle)
                    
                    if let profileImage = profileImage {
                        appData.saveProfileImage(profileImage, forCycleId: newCycle.id)
                    }
                }
                dismiss()
            })
        }
    }
    
    // Function to copy items from previous cycle to new cycle
    private func copyItems() {
        // Get items from previous cycle
        if let prevItems = appData.cycleItems[previousCycle.id] {
            // Create copied items with new IDs
            let newItems = prevItems.map { oldItem in
                let newItemId = UUID()
                return Item(
                    id: newItemId,
                    name: oldItem.name,
                    category: oldItem.category,
                    dose: oldItem.dose,
                    unit: oldItem.unit,
                    weeklyDoses: oldItem.weeklyDoses,
                    order: oldItem.order
                )
            }
            
            // Add to new cycle
            appData.cycleItems[newCycle.id] = newItems
            
            // Extra aggressive grouped items clearing
            appData.clearGroupedItems(forCycleId: newCycle.id)
            appData.groupedItems[newCycle.id] = []
            
            // Direct Firebase access to ensure groups are cleared
            if let dbRef = appData.valueForDBRef() {
                dbRef.child("cycles").child(newCycle.id.uuidString).child("groupedItems").setValue([:])
            }
            
            print("Copied \(newItems.count) items to new cycle, forcibly cleared all grouped items")
        }
    }
}
