import SwiftUI

struct FilterOptionsView: View {
    @ObservedObject var appData: AppData
    @Binding var selectedFilter: ReactionsView.FilterOption
    @Binding var dateSort: ReactionsView.DateSortOption
    @Binding var selectedItemId: UUID?
    @Binding var selectedSymptom: SymptomType?
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("FILTER TYPE")) {
                Picker("Filter By", selection: $selectedFilter) {
                    ForEach(ReactionsView.FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Date filter options
            if selectedFilter == .date {
                Section(header: Text("DATE SORTING")) {
                    DateFilterRow(title: "Newest First", isSelected: dateSort == .descending) {
                        dateSort = .descending
                    }
                    
                    DateFilterRow(title: "Oldest First", isSelected: dateSort == .ascending) {
                        dateSort = .ascending
                    }
                    
                    DateFilterRow(title: "Custom Date Range", isSelected: dateSort == .customRange) {
                        dateSort = .customRange
                    }
                    
                    if dateSort == .customRange {
                        DatePicker("From", selection: $customStartDate, displayedComponents: [.date])
                        DatePicker("To", selection: $customEndDate, in: customStartDate..., displayedComponents: [.date])
                    }
                }
            }
            
            // Item filter options
            if selectedFilter == .item {
                Section(header: Text("FILTER BY ITEM")) {
                    FilterRow(title: "All Items", isSelected: selectedItemId == nil) {
                        selectedItemId = nil
                    }
                    
                    if let cycleId = appData.currentCycleId() {
                        let items = getItemsWithReactions(cycleId: cycleId)
                        
                        ForEach(items) { item in
                            FilterRow(title: item.name, isSelected: selectedItemId == item.id) {
                                selectedItemId = item.id
                            }
                        }
                    }
                }
            }
            
            // Symptom filter options
            if selectedFilter == .symptom {
                Section(header: Text("FILTER BY SYMPTOM")) {
                    FilterRow(title: "All Symptoms", isSelected: selectedSymptom == nil) {
                        selectedSymptom = nil
                    }
                    
                    if let cycleId = appData.currentCycleId() {
                        let symptoms = getSymptomsWithReactions(cycleId: cycleId)
                        
                        ForEach(symptoms, id: \.self) { symptom in
                            FilterRow(title: symptom.rawValue, isSelected: selectedSymptom == symptom) {
                                selectedSymptom = symptom
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Apply Filter")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .navigationTitle("Filter Options")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // Get all items that have associated reactions
    func getItemsWithReactions(cycleId: UUID) -> [Item] {
        let reactions = appData.reactions[cycleId] ?? []
        let itemIds = Set(reactions.compactMap { $0.itemId })
        let allItems = appData.cycleItems[cycleId] ?? []
        
        return allItems.filter { itemIds.contains($0.id) }.sorted { $0.name < $1.name }
    }
    
    // Get all symptoms that have been logged in reactions
    func getSymptomsWithReactions(cycleId: UUID) -> [SymptomType] {
        let reactions = appData.reactions[cycleId] ?? []
        var symptoms = Set<SymptomType>()
        
        for reaction in reactions {
            for symptom in reaction.symptoms {
                symptoms.insert(symptom)
            }
        }
        
        return Array(symptoms).sorted { $0.rawValue < $1.rawValue }
    }
}

// Helper view for filter rows
struct FilterRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

// Helper view for date filter rows
struct DateFilterRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
