import SwiftUI

struct EditItemsView: View {
    @ObservedObject var appData: AppData
    let cycleId: UUID
    @State private var addItemState: (isPresented: Bool, category: Category?)? // Tracks sheet state and category
    @State private var showingAddTreatmentFood = false
    @State private var showingEditItem: Item? = nil
    @State private var isEditing = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.isInsideNavigationView) var isInsideNavigationView
    
    // Computed binding for addItemState sheet
    private var addItemSheetBinding: Binding<Bool> {
        Binding(
            get: { addItemState?.isPresented ?? false },
            set: { newValue in
                if newValue {
                    // Maintain existing category when re-presenting
                    addItemState = addItemState ?? (isPresented: true, category: nil)
                } else {
                    addItemState = nil
                }
            }
        )
    }
    
    var body: some View {
        List {
            ForEach(Category.allCases, id: \.self) { category in
                categorySection(for: category)
            }
        }
        .navigationTitle("Edit Items")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(isEditing ? "Done" : "Edit Order") {
                    isEditing.toggle()
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .sheet(isPresented: addItemSheetBinding) {
            NavigationView {
                ItemFormView(appData: appData, cycleId: cycleId, initialCategory: addItemState?.category)
            }
        }
        .sheet(item: $showingEditItem) { item in
            NavigationView {
                ItemFormView(appData: appData, cycleId: cycleId, editingItem: item)
            }
        }
        .sheet(isPresented: $showingAddTreatmentFood) {
            NavigationView {
                ItemFormView(appData: appData, cycleId: cycleId, initialCategory: .treatment)
            }
        }
        .onAppear {
            if isInsideNavigationView {
                print("EditItemsView is correctly inside a NavigationView")
            } else {
                print("Warning: EditItemsView is not inside a NavigationView")
            }
        }
        .onDisappear {
            saveReorderedItems()
            print("EditItemsView dismissed, saved reordered items")
        }
    }
    
    private func categorySection(for category: Category) -> some View {
        CategorySectionView(
            appData: appData,
            category: category,
            items: currentItems().filter { $0.category == category },
            onAddAction: {
                print("Add button clicked for category: \(category.rawValue)")
                if category == .treatment {
                    print("Opening ItemFormView for Treatment")
                    showingAddTreatmentFood = true
                } else {
                    print("Opening ItemFormView for \(category.rawValue)")
                    addItemState = (isPresented: true, category: category)
                }
            },
            onEditAction: { item in
                print("Editing item: \(item.name) in category: \(item.category.rawValue)")
                showingEditItem = item
            },
            isEditing: isEditing,
            onMove: { source, destination in
                moveItems(from: source, to: destination, in: category)
            }
        )
    }
    
    private func itemDisplayText(item: Item) -> String {
        appData.itemDisplayText(item: item)
    }
    
    private func currentItems() -> [Item] {
        return (appData.cycleItems[cycleId] ?? []).sorted { $0.order < $1.order }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int, in category: Category) {
        guard var allItems = appData.cycleItems[cycleId]?.sorted(by: { $0.order < $1.order }) else { return }
        
        var categoryItems = allItems.filter { $0.category == category }
        let nonCategoryItems = allItems.filter { $0.category != category }
        
        categoryItems.move(fromOffsets: source, toOffset: destination)
        
        let reorderedCategoryItems = categoryItems.enumerated().map { index, item in
            Item(id: item.id, name: item.name, category: item.category, dose: item.dose, unit: item.unit, weeklyDoses: item.weeklyDoses, order: index)
        }
        
        var updatedItems = nonCategoryItems
        updatedItems.append(contentsOf: reorderedCategoryItems)
        
        appData.cycleItems[cycleId] = updatedItems.sorted { $0.order < $1.order }
        print("Reordered items locally: \(updatedItems.map { "\($0.name) - order: \($0.order)" })")
    }
    
    private func saveReorderedItems() {
        guard let items = appData.cycleItems[cycleId] else { return }
        appData.saveItems(items, toCycleId: cycleId) { success in
            if !success {
                print("Failed to save reordered items")
            }
        }
    }
}

struct CategorySectionView: View {
    @ObservedObject var appData: AppData
    let category: Category
    let items: [Item]
    let onAddAction: () -> Void
    let onEditAction: (Item) -> Void
    let isEditing: Bool
    let onMove: (IndexSet, Int) -> Void
    
    var body: some View {
        Section(header: Text(category.rawValue)) {
            if items.isEmpty {
                Text("No items added")
                    .foregroundColor(.gray)
            } else {
                ForEach(items) { item in
                    Button(action: {
                        onEditAction(item)
                    }) {
                        Text(itemDisplayText(item: item))
                            .foregroundColor(.primary)
                    }
                }
                .onMove(perform: isEditing ? onMove : nil)
            }
            Button(action: {
                print("CategorySectionView: Add button tapped for category: \(category.rawValue)")
                onAddAction()
            }) {
                Text(category == .treatment ? "Add Treatment Food" : "Add Item")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func itemDisplayText(item: Item) -> String {
        if let dose = item.dose, let unit = item.unit {
            if dose == 1.0 {
                return "\(item.name) - 1 \(unit)"
            } else if let fraction = Fraction.fractionForDecimal(dose) {
                return "\(item.name) - \(fraction.displayString) \(unit)"
            } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(item.name) - \(String(format: "%d", Int(dose))) \(unit)"
            }
            return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
        } else if item.category == .treatment, let weeklyDoses = item.weeklyDoses {
            let week = currentWeek()
            
            if let weeklyDoseData = weeklyDoses[week] {
                let dose = weeklyDoseData.dose
                let unit = weeklyDoseData.unit
                
                if dose == 1.0 {
                    return "\(item.name) - 1 \(unit)"
                } else if let fraction = Fraction.fractionForDecimal(dose) {
                    return "\(item.name) - \(fraction.displayString) \(unit)"
                } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(item.name) - \(String(format: "%d", Int(dose))) \(unit)"
                }
                return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
            } else {
                // Try to find the nearest week
                let sortedWeeks = weeklyDoses.keys.sorted()
                let closestWeek = sortedWeeks.first { $0 >= week } ?? sortedWeeks.first
                
                if let week = closestWeek, let doseData = weeklyDoses[week] {
                    let dose = doseData.dose
                    let unit = doseData.unit
                    
                    if dose == 1.0 {
                        return "\(item.name) - 1 \(unit)"
                    } else if let fraction = Fraction.fractionForDecimal(dose) {
                        return "\(item.name) - \(fraction.displayString) \(unit)"
                    } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
                        return "\(item.name) - \(String(format: "%d", Int(dose))) \(unit)"
                    }
                    return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
                }
            }
        }
        return item.name
    }
    
    private func currentWeek() -> Int {
        guard let currentCycle = appData.cycles.last else { return 1 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: currentCycle.startDate, to: Date()).day ?? 0
        return (daysSinceStart / 7) + 1
    }
}

struct EditItemsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditItemsView(appData: AppData(), cycleId: UUID())
                .environment(\.isInsideNavigationView, true)
        }
    }
}
