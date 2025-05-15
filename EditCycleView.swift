import SwiftUI

struct EditCycleView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    let cycle: Cycle // The cycle to edit
    @Environment(\.isInsideNavigationView) var isInsideNavigationView
    
    init(appData: AppData, cycle: Cycle) {
        self.appData = appData
        self.cycle = cycle
        self._cycleNumber = State(initialValue: cycle.number)
        self._startDate = State(initialValue: cycle.startDate)
        self._foodChallengeDate = State(initialValue: cycle.foodChallengeDate)
        self._patientName = State(initialValue: cycle.patientName)
    }
    
    var body: some View {
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
                        showingImagePicker = true
                    }
                    .padding(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical)
            }
            
            Section {
                HStack {
                    Text("Cycle Number")
                    InfoButton(text: "The cycle number helps track different cycles of dosing. It corresponds to the upcoming visit number.")
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
        .navigationTitle("Edit Cycle \(cycle.number)")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    let updatedCycle = Cycle(
                        id: cycle.id, // Use the original cycle's ID
                        number: cycleNumber,
                        patientName: patientName.isEmpty ? "Unnamed" : patientName,
                        startDate: startDate,
                        foodChallengeDate: foodChallengeDate
                    )
                    appData.addCycle(updatedCycle) // Updates existing cycle
                    
                    // Save profile image if changed
                    if let profileImage = profileImage {
                        appData.saveProfileImage(profileImage, forCycleId: cycle.id)
                    }
                    
                    dismiss()
                }
            }
        }
        .onAppear {
            // Load existing profile image
            profileImage = appData.loadProfileImage(forCycleId: cycle.id)
            if isInsideNavigationView {
                print("EditCycleView is correctly inside a NavigationView")
            } else {
                print("Warning: EditCycleView is not inside a NavigationView")
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $profileImage)
        }
    }
}

struct EditCycleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditCycleView(
                appData: AppData(),
                cycle: Cycle(id: UUID(), number: 1, patientName: "Test Patient", startDate: Date(), foodChallengeDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())!)
            )
            .environment(\.isInsideNavigationView, true)
        }
    }
}
