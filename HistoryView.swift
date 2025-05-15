import SwiftUI

struct HistoryView: View {
    @ObservedObject var appData: AppData
    @State private var editingEntry: DisplayLogEntry?
    @State private var newTimestamp: Date = Date()
    @State private var showingDeleteConfirmation = false
    @State private var selectedFilter: LogFilter = .all
    @State private var showingDateRangePicker = false
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingAddLogSheet = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Filter buttons layout
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ForEach([LogFilter.all, .today, .thisWeek], id: \.self) { filter in
                                filterButton(filter)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)

                        HStack {
                            filterButton(.customDates)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                    }

                    // Grouped entries
                    ForEach(filteredGroupedLogEntries(), id: \.date) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sectionTitle(for: group.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(group.entries) { entry in
                                entryCard(for: entry)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        if appData.currentUser?.isAdmin ?? false || entry.userId == appData.currentUser?.id {
                                            editingEntry = entry
                                            newTimestamp = entry.timestamp
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            
            // Add a floating action button at the bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddLogSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("History")
        // Edit log sheet
        .sheet(item: $editingEntry, onDismiss: {
            editingEntry = nil
            appData.objectWillChange.send()
        }) { entry in
            NavigationView {
                Form {
                    DatePicker("Edit Timestamp",
                               selection: $newTimestamp,
                               displayedComponents: [.date, .hourAndMinute])
                }
                .navigationTitle("Edit Log Time")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingEntry = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            updateLogTimestamp(entry: entry, newTime: newTimestamp)
                            editingEntry = nil
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .alert("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                deleteLogEntry(entry: entry)
                                editingEntry = nil
                                appData.objectWillChange.send()
                            }
                        } message: {
                            Text("Are you sure you want to delete the log for \(entry.itemName) at \(entry.timestamp, style: .date) \(entry.timestamp, style: .time)?")
                        }
                    }
                }
            }
        }
        // Custom Date Range Sheet
        .sheet(isPresented: $showingDateRangePicker) {
            NavigationView {
                Form {
                    Section(header: Text("Start Date")) {
                        DatePicker("From", selection: $customStartDate, displayedComponents: [.date])
                    }
                    Section(header: Text("End Date")) {
                        DatePicker("To", selection: $customEndDate, in: customStartDate..., displayedComponents: [.date])
                    }
                }
                .navigationTitle("Custom Dates")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingDateRangePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            selectedFilter = .customDates
                            showingDateRangePicker = false
                        }
                    }
                }
            }
        }
        // Add Log Sheet
        .sheet(isPresented: $showingAddLogSheet) {
            AddLogEntryView(appData: appData, onDismiss: {
                showingAddLogSheet = false
            })
        }
    }

    // MARK: - Helper Views

    private func filterButton(_ filter: LogFilter) -> some View {
        Button(action: {
            if filter == .customDates {
                showingDateRangePicker = true
            } else {
                selectedFilter = filter
            }
        }) {
            HStack {
                if filter == .customDates {
                    Image(systemName: "calendar")
                    Text("\(formattedDateRange())")
                } else {
                    Text(filter.rawValue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedFilter == filter ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(selectedFilter == filter ? .white : .primary)
            .cornerRadius(20)
        }
    }

    private func formattedDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM d"

        let from = shortFormatter.string(from: customStartDate)
        let to = shortFormatter.string(from: customEndDate)

        return "\(from) – \(to)"
    }

    private func entryCard(for entry: DisplayLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(entry.category.iconColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: entry.category.icon)
                        .foregroundColor(entry.category.iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                // Combined item name and dose on the same line
                HStack(spacing: 4) {
                    Text(entry.itemName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let doseDisplay = entry.doseDisplay, !doseDisplay.isEmpty {
                        Text("- \(doseDisplay)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }

                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(entry.userName)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if appData.currentUser?.isAdmin ?? false || entry.userId == appData.currentUser?.id {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                    Image(systemName: "trash")
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    // MARK: - Data Structs and Logic

    private enum LogFilter: String, CaseIterable {
        case all = "All Items"
        case today = "Today"
        case thisWeek = "This Week"
        case customDates = "Custom Dates"
    }

    private struct DisplayLogEntry: Identifiable {
        let id = UUID()
        let cycleId: UUID
        let itemId: UUID
        let itemName: String
        let category: Category
        let timestamp: Date
        let userId: UUID
        let userName: String
        
        // Added properties for dose and unit
        let dose: Double?
        let unit: String?
        let weeklyDoses: [Int: WeeklyDoseData]?
        let doseDisplay: String?
    }

    private struct LogGroup: Identifiable {
        let date: Date
        let entries: [DisplayLogEntry]
        var id: Date { date }
    }

    private func filteredGroupedLogEntries() -> [LogGroup] {
        let allGroups = groupedLogEntries()
        let calendar = Calendar.current

        switch selectedFilter {
        case .all:
            return allGroups
        case .today:
            return allGroups.filter { calendar.isDateInToday($0.date) }
        case .thisWeek:
            return allGroups.filter {
                calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
            }
        case .customDates:
            return allGroups.filter { group in
                group.date >= calendar.startOfDay(for: customStartDate) &&
                group.date <= calendar.endOfDay(for: customEndDate)
            }
        }
    }

    // Modify the groupedLogEntries function in HistoryView to include dose and unit info
    private func groupedLogEntries() -> [LogGroup] {
        let calendar = Calendar.current
        var entries: [DisplayLogEntry] = []
        var processedEntryKeys = Set<String>() // Track processed entries to avoid duplicates

        for (cycleId, itemsLog) in appData.consumptionLog {
            guard let cycleItems = appData.cycleItems[cycleId] else { continue }
            for (itemId, logs) in itemsLog {
                if let item = cycleItems.first(where: { $0.id == itemId }) {
                    // Sort logs by date to ensure consistent processing order
                    let sortedLogs = logs.sorted { $0.date > $1.date }
                    
                    for log in sortedLogs {
                        if let user = appData.users.first(where: { $0.id == log.userId }) {
                            // Create a unique key for this entry to detect duplicates
                            let dayStart = calendar.startOfDay(for: log.date)
                            let entryKey = "\(cycleId)-\(itemId)-\(dayStart.timeIntervalSince1970)"
                            
                            // Calculate the week number for the log date if needed
                            let week = getWeekNumber(for: log.date, cycleStartDate: appData.cycles.first(where: { $0.id == cycleId })?.startDate)
                            
                            // Format dose display text
                            let doseDisplay = formatDoseDisplay(item: item, weekNumber: week)
                            
                            // Only add this entry if we haven't processed an identical one
                            if !processedEntryKeys.contains(entryKey) {
                                entries.append(DisplayLogEntry(
                                    cycleId: cycleId,
                                    itemId: itemId,
                                    itemName: item.name,
                                    category: item.category,
                                    timestamp: log.date,
                                    userId: log.userId,
                                    userName: user.name,
                                    dose: item.dose,
                                    unit: item.unit,
                                    weeklyDoses: item.weeklyDoses,
                                    doseDisplay: doseDisplay
                                ))
                                processedEntryKeys.insert(entryKey)
                            }
                        }
                    }
                }
            }
        }

        entries.sort { $0.timestamp > $1.timestamp }

        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }

        return grouped.map { LogGroup(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    // Helper function to get the week number for a date
    private func getWeekNumber(for date: Date, cycleStartDate: Date?) -> Int? {
        guard let startDate = cycleStartDate else { return nil }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
        return (daysSinceStart / 7) + 1
    }
    
    // Helper function to format dose with proper fraction display
    // Helper function to format dose display text
    private func formatDoseDisplay(item: Item, weekNumber: Int?) -> String {
        // For treatment items with weekly doses
        if item.category == .treatment, let unit = item.unit, let weekNumber = weekNumber, let weeklyDoses = item.weeklyDoses {
            if let weeklyDoseData = weeklyDoses[weekNumber] {
                return formatDoseValue(dose: weeklyDoseData.dose, unit: weeklyDoseData.unit, week: weekNumber)
            } else if let firstWeek = weeklyDoses.keys.min(), let firstDoseData = weeklyDoses[firstWeek] {
                return formatDoseValue(dose: firstDoseData.dose, unit: firstDoseData.unit, week: firstWeek)
            }
        }
        
        // For regular items with fixed dose
        if let dose = item.dose, let unit = item.unit {
            return formatDoseValue(dose: dose, unit: unit)
        }
        
        return ""
    }
    
    // Helper function to format dose values with fractions
    // Helper function to format dose values with fractions
    private func formatDoseValue(dose: Double, unit: String, week: Int? = nil) -> String {
        let doseText: String
        
        if dose == 1.0 {
            doseText = "1 \(unit)"
        } else if let fraction = Fraction.fractionForDecimal(dose) {
            doseText = "\(fraction.displayString) \(unit)"
        } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
            doseText = "\(String(format: "%d", Int(dose))) \(unit)"
        } else {
            doseText = "\(String(format: "%.1f", dose)) \(unit)"
        }
        
        if let week = week {
            return "\(doseText) (Week \(week))"
        }
        
        return doseText
    }

    private func updateLogTimestamp(entry: DisplayLogEntry, newTime: Date) {
        guard var itemLogs = appData.consumptionLog[entry.cycleId]?[entry.itemId] else { return }

        if let index = itemLogs.firstIndex(where: { $0.date == entry.timestamp && $0.userId == entry.userId }) {
            let originalLog = itemLogs[index]
            appData.removeIndividualConsumption(itemId: entry.itemId, cycleId: entry.cycleId, date: originalLog.date)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                itemLogs.remove(at: index)
                itemLogs.append(LogEntry(date: newTime, userId: entry.userId))
                self.appData.setConsumptionLog(itemId: entry.itemId, cycleId: entry.cycleId, entries: itemLogs)
            }
        } else {
            itemLogs.append(LogEntry(date: newTime, userId: entry.userId))
            appData.setConsumptionLog(itemId: entry.itemId, cycleId: entry.cycleId, entries: itemLogs)
        }
    }

    private func deleteLogEntry(entry: DisplayLogEntry) {
        if var itemLogs = appData.consumptionLog[entry.cycleId]?[entry.itemId] {
            itemLogs.removeAll { $0.date == entry.timestamp && $0.userId == entry.userId }
            // Use the improved individual consumption removal
            appData.removeIndividualConsumption(itemId: entry.itemId, cycleId: entry.cycleId, date: entry.timestamp)
        }
    }
}

// MARK: - Add Log Entry View
// New view for adding multiple log entries at once
struct AddLogEntryView: View {
    @ObservedObject var appData: AppData
    @State private var selectedItemIds: Set<UUID> = []
    @State private var selectedDate = Date()
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Log Time")) {
                    DatePicker("Time", selection: $selectedDate)
                }
                
                // Display items grouped by category
                ForEach(Category.allCases, id: \.self) { category in
                    let categoryItems = itemsForCategory(category)
                    if !categoryItems.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(categoryItems) { item in
                                HistoryLogSelectionRow(
                                    title: itemDisplayText(item: item),
                                    isSelected: selectedItemIds.contains(item.id)
                                ) {
                                    toggleItemSelection(item.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Log Entries")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLogEntries()
                        onDismiss()
                    }
                    .disabled(selectedItemIds.isEmpty)
                }
            }
        }
    }
    
    private func toggleItemSelection(_ itemId: UUID) {
        if selectedItemIds.contains(itemId) {
            selectedItemIds.remove(itemId)
        } else {
            selectedItemIds.insert(itemId)
        }
    }
    
    private func itemsForCategory(_ category: Category) -> [Item] {
        guard let cycleId = appData.currentCycleId() else { return [] }
        return appData.cycleItems[cycleId]?.filter { $0.category == category } ?? []
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
        } else if item.category == .treatment, let unit = item.unit {
            let currentWeek = currentWeekNumber()
            if let weeklyDoses = item.weeklyDoses, let weeklyDoseData = weeklyDoses[currentWeek] {
                let dose = weeklyDoseData.dose
                let unit = weeklyDoseData.unit
                
                if dose == 1.0 {
                    return "\(item.name) - 1 \(unit) (Week \(currentWeek))"
                } else if let fraction = Fraction.fractionForDecimal(dose) {
                    return "\(item.name) - \(fraction.displayString) \(unit) (Week \(currentWeek))"
                } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(item.name) - \(String(format: "%d", Int(dose))) \(unit) (Week \(currentWeek))"
                }
                return "\(item.name) - \(String(format: "%.1f", dose)) \(unit) (Week \(currentWeek))"
            } else if let weeklyDoses = item.weeklyDoses, let firstWeek = weeklyDoses.keys.min(), let firstDoseData = weeklyDoses[firstWeek] {
                let dose = firstDoseData.dose
                let unit = firstDoseData.unit
                
                if dose == 1.0 {
                    return "\(item.name) - 1 \(unit) (Week \(firstWeek))"
                } else if let fraction = Fraction.fractionForDecimal(dose) {
                    return "\(item.name) - \(fraction.displayString) \(unit) (Week \(firstWeek))"
                } else if dose.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(item.name) - \(String(format: "%d", Int(dose))) \(unit) (Week \(firstWeek))"
                }
                return "\(item.name) - \(String(format: "%.1f", dose)) \(unit) (Week \(firstWeek))"
            }
        }
        return item.name
    }
    
    private func currentWeekNumber() -> Int {
        guard let cycleId = appData.currentCycleId(),
              let cycle = appData.cycles.first(where: { $0.id == cycleId }) else { return 1 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return (daysSinceStart / 7) + 1
    }
    
    private func saveLogEntries() {
        guard let cycleId = appData.currentCycleId() else { return }
        
        // Directly log individual items, never entire groups
        for itemId in selectedItemIds {
            // Check if this item is part of any group
            let isPartOfGroup = appData.groupedItems[cycleId]?.contains { group in
                group.itemIds.contains(itemId)
            } ?? false
            
            if isPartOfGroup {
                // For items in groups, use our special individual logging method
                appData.logIndividualConsumption(itemId: itemId, cycleId: cycleId, date: selectedDate)
            } else {
                // For standalone items, can use the regular method
                appData.logConsumption(itemId: itemId, cycleId: cycleId, date: selectedDate)
            }
        }
    }
}

// MARK: - HistoryLogSelectionRow Component (renamed to avoid conflicts)
struct HistoryLogSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Calendar Extension
extension Calendar {
    func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfDay(for: date))!
    }
}
