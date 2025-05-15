import SwiftUI

struct EditReactionView: View {
    @ObservedObject var appData: AppData
    let reaction: Reaction
    @State private var reactionType: ReactionType
    @State private var selectedDate: Date
    @State private var selectedItemId: UUID?
    @State private var selectedSymptoms: Set<SymptomType> = []
    @State private var otherSymptom: String = ""
    @State private var descriptionText: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    enum ReactionType {
        case toItem
        case unknown
    }
    
    init(appData: AppData, reaction: Reaction) {
        self.appData = appData
        self.reaction = reaction
        
        // Initialize state variables with reaction data
        _reactionType = State(initialValue: reaction.itemId != nil ? .toItem : .unknown)
        _selectedDate = State(initialValue: reaction.date)
        _selectedItemId = State(initialValue: reaction.itemId)
        _selectedSymptoms = State(initialValue: Set(reaction.symptoms))
        _otherSymptom = State(initialValue: reaction.otherSymptom ?? "")
        _descriptionText = State(initialValue: reaction.description)
    }
    
    var body: some View {
        Form {
            Section(header: Text("REACTION TYPE")) {
                Picker("Reaction Type", selection: $reactionType) {
                    Text("Reaction to an Item").tag(ReactionType.toItem)
                    Text("Unknown Cause").tag(ReactionType.unknown)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("DATE")) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
            }
            
            if reactionType == .toItem {
                Section(header: Text("ITEM")) {
                    if let cycleId = appData.currentCycleId() {
                        let itemsLoggedOnDay = getItemsLoggedOnDate(cycleId: cycleId, date: selectedDate)
                        
                        if itemsLoggedOnDay.isEmpty {
                            Text("No items logged on selected date")
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Select Item", selection: $selectedItemId) {
                                Text("Select an item").tag(nil as UUID?)
                                ForEach(itemsLoggedOnDay, id: \.id) { item in
                                    Text(item.name).tag(item.id as UUID?)
                                }
                            }
                        }
                    } else {
                        Text("No active cycle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("SYMPTOMS")) {
                ForEach(SymptomType.allCases.filter { $0 != .other }, id: \.self) { symptom in
                    Button(action: {
                        toggleSymptom(symptom)
                    }) {
                        HStack {
                            Text(symptom.rawValue)
                            Spacer()
                            if selectedSymptoms.contains(symptom) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Button(action: {
                    toggleSymptom(.other)
                }) {
                    HStack {
                        Text(SymptomType.other.rawValue)
                        Spacer()
                        if selectedSymptoms.contains(.other) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
                
                if selectedSymptoms.contains(.other) {
                    TextField("Specify other symptom", text: $otherSymptom)
                }
            }
            
            Section(header: Text("DESCRIPTION")) {
                TextEditor(text: $descriptionText)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(action: saveReaction) {
                    Text("Update Reaction")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(isUpdateEnabled ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isUpdateEnabled)
            }
        }
        .navigationTitle("Edit Reaction")
        .navigationBarItems(trailing: Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        })
    }
    
    var isUpdateEnabled: Bool {
        if reactionType == .toItem && selectedItemId == nil {
            return false
        }
        if selectedSymptoms.isEmpty {
            return false
        }
        if selectedSymptoms.contains(.other) && otherSymptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }
    
    func toggleSymptom(_ symptom: SymptomType) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }
    
    func getItemsLoggedOnDate(cycleId: UUID, date: Date) -> [Item] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let allItems = appData.cycleItems[cycleId] ?? []
        let loggedItemIds = Set(appData.consumptionLog[cycleId]?.compactMap { itemId, logs in
            logs.contains { log in
                log.date >= startOfDay && log.date < endOfDay
            } ? itemId : nil
        } ?? [])
        
        return allItems.filter { loggedItemIds.contains($0.id) }
    }
    
    func saveReaction() {
        guard let cycleId = appData.currentCycleId(), let userId = appData.currentUser?.id else {
            return
        }
        
        let updatedReaction = Reaction(
            id: reaction.id,
            date: selectedDate,
            itemId: reactionType == .toItem ? selectedItemId : nil,
            symptoms: Array(selectedSymptoms),
            otherSymptom: selectedSymptoms.contains(.other) ? otherSymptom : nil,
            description: descriptionText,
            userId: userId
        )
        
        appData.addReaction(updatedReaction, toCycleId: cycleId) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
