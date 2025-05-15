import SwiftUI

struct EditGroupedItemsView: View {
    @ObservedObject var appData: AppData
    let cycleId: UUID
    @State private var showingAddGroup = false
    @State private var editingGroup: GroupedItem?
    @State private var isEditing = false
    @State private var groupName: String = ""
    @State private var groupCategory: Category = .maintenance
    @State private var selectedItemIds: [UUID] = []
    @Binding var step: Int?
    @Environment(\.dismiss) var dismiss
    @Environment(\.isInsideNavigationView) var isInsideNavigationView

    init(appData: AppData, cycleId: UUID, step: Binding<Int?> = .constant(nil)) {
        self.appData = appData
        self.cycleId = cycleId
        self._step = step
    }

    var body: some View {
        List {
            ForEach(Category.allCases, id: \.self) { category in
                Section(header: Text(category.rawValue)) {
                    let groups = (appData.groupedItems[cycleId] ?? []).filter { $0.category == category }

                    if groups.isEmpty {
                        Text("No grouped items")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(groups) { group in
                            Button(action: {
                                editingGroup = group
                                groupName = group.name
                                groupCategory = group.category
                                selectedItemIds = group.itemIds
                                showingAddGroup = true
                            }) {
                                HStack {
                                    Text(group.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    Button(action: {
                        showingAddGroup = true
                        editingGroup = nil
                        groupName = ""
                        groupCategory = category
                        selectedItemIds = []
                    }) {
                        Text("Add Grouped Item")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Edit Grouped Items")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(isEditing ? "Done" : "Edit Order") {
                    isEditing.toggle()
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .sheet(isPresented: $showingAddGroup) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Group Name (e.g., Muffin)", text: $groupName)
                        Picker("Category", selection: $groupCategory) {
                            ForEach(Category.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }

                    Section(header: Text("Select Items")) {
                        let categoryItems = appData.cycleItems[cycleId]?.filter { $0.category == groupCategory } ?? []
                        if categoryItems.isEmpty {
                            Text("No items in this category")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(categoryItems) { item in
                                MultipleSelectionRow(
                                    title: itemDisplayText(item: item),
                                    isSelected: selectedItemIds.contains(item.id),
                                    action: {
                                        if selectedItemIds.contains(item.id) {
                                            selectedItemIds.removeAll { $0 == item.id }
                                        } else {
                                            selectedItemIds.append(item.id)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    if editingGroup != nil {
                        Section {
                            Button("Delete Group", role: .destructive) {
                                if let groupId = editingGroup?.id {
                                    appData.removeGroupedItem(groupId, fromCycleId: cycleId)
                                }
                                showingAddGroup = false
                            }
                        }
                    }
                }
                .navigationTitle(editingGroup == nil ? "Add Group" : "Edit Group")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingAddGroup = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            let newGroup = GroupedItem(
                                id: editingGroup?.id ?? UUID(),
                                name: groupName,
                                category: groupCategory,
                                itemIds: selectedItemIds
                            )
                            appData.addGroupedItem(newGroup, toCycleId: cycleId)
                            showingAddGroup = false
                        }
                        .disabled(groupName.isEmpty || selectedItemIds.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            print("EditGroupedItemsView is \(isInsideNavigationView ? "inside" : "not inside") a NavigationView")
        }
    }

    private func itemDisplayText(item: Item) -> String {
        if let dose = item.dose, let unit = item.unit {
            return "\(item.name) - \(String(format: "%.1f", dose)) \(unit)"
        }
        return item.name
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

