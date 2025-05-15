import SwiftUI

struct WeekView: View {
    @ObservedObject var appData: AppData
    @State private var currentWeekOffset: Int = 0
    @State private var currentCycleOffset = 0
    @State private var forceRefreshID = UUID()
    
    let totalWidth = UIScreen.main.bounds.width
    let itemColumnWidth: CGFloat = 130
    var dayColumnWidth: CGFloat {
        (totalWidth - itemColumnWidth) / 7
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Week View")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text("Cycle \(displayedCycleNumber())")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            HStack {
                Button(action: { withAnimation { previousWeek() } }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .padding(.horizontal, 4)
                }
                
                Spacer()
                
                Text(weekRangeText())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { withAnimation { nextWeek() } }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            
            HStack(spacing: 0) {
                Text("Items")
                    .frame(width: itemColumnWidth, alignment: .leading)
                    .padding(.leading, 12)
                ForEach(0..<7) { offset in
                    let date = dayDate(for: offset)
                    let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                    
                    // Check if this date is a cycle start or end date
                    let isStartDate = isDateCycleStart(date)
                    let isEndDate = isDateCycleEnd(date)
                    
                    VStack(spacing: 2) {
                        if hasUnknownReaction(on: date) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Text(weekDays()[offset])
                            .font(.caption2)
                            .fontWeight(.bold)
                        Text(dayNumberFormatter.string(from: date))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(width: dayColumnWidth, height: 40)
                    .background(isToday ? Color.yellow.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isStartDate ? Color.green : isEndDate ? Color.red : Color.clear, lineWidth: isStartDate || isEndDate ? 2 : 0)
                    )
                    .cornerRadius(4)
                }
            }
            Divider()
            
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(Category.allCases, id: \.self) { category in
                        HStack {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(.label))
                                .padding(.leading, 12)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(.systemGray6))
                        
                        let categoryItems = itemsForSelectedCycle().filter { $0.category == category }
                        if categoryItems.isEmpty {
                            Text("No items added")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.leading)
                                .padding(.bottom, 6)
                        } else {
                            ForEach(categoryItems) { item in
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.caption)
                                            .foregroundColor(category == .recommended && weeklyDoseCount(for: item) >= 3 ? .green : .primary)
                                        if let doseText = itemDisplayText(item: item).components(separatedBy: " - ").last {
                                            Text(doseText)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: itemColumnWidth, alignment: .leading)
                                    .padding(.leading, 12)
                                    
                                    ForEach(0..<7) { dayOffset in
                                        let date = dayDate(for: dayOffset)
                                        let isLogged = isItemLogged(item: item, on: date)
                                        let hasReaction = hasReaction(for: item, on: date)
                                        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                                        let isStartDate = isDateCycleStart(date)
                                        let isEndDate = isDateCycleEnd(date)
                                        
                                        if hasReaction {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 14, weight: .bold))
                                                .frame(width: dayColumnWidth, height: 36)
                                                .background(isToday ? Color.yellow.opacity(0.2) : Color.clear)
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(isStartDate ? Color.green : isEndDate ? Color.red : Color.gray.opacity(0.2), lineWidth: isStartDate || isEndDate ? 2 : 0.2)
                                                )
                                        } else {
                                            Image(systemName: isLogged ? "checkmark" : "")
                                                .foregroundColor(isLogged ? .green : .clear)
                                                .font(.system(size: 14, weight: .bold))
                                                .frame(width: dayColumnWidth, height: 36)
                                                .background(isToday ? Color.yellow.opacity(0.2) : Color.clear)
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(isStartDate ? Color.green : isEndDate ? Color.red : Color.gray.opacity(0.2), lineWidth: isStartDate || isEndDate ? 2 : 0.2)
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.yellow.opacity(0.4))
                                    .frame(width: 12, height: 12)
                                Text("Current Day")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }

                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                                Text("Cycle Start")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                                Text("Food Challenge")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Logged Item")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("Reaction")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding(.bottom, 12)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation {
                        if value.translation.width < -50 {
                            nextWeek()
                        } else if value.translation.width > 50 {
                            previousWeek()
                        }
                    }
                }
        )
        .onAppear {
            initializeWeekView()
            appData.globalRefresh()
            
            // Add second refresh after a delay to ensure all data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.forceRefreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DataRefreshed"))) { _ in
            self.forceRefreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ReactionsUpdated"))) { _ in
            print("WeekView received ReactionsUpdated notification")
            DispatchQueue.main.async {
                self.forceRefreshID = UUID()
            }
        }
    }
    
    // Check if there's a reaction for a specific item on a specific date
    private func hasReaction(for item: Item, on date: Date) -> Bool {
        guard let cycleId = appData.currentCycleId() else { return false }
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let dateEnd = calendar.date(byAdding: .day, value: 1, to: dateStart)!
        
        let reactions = appData.reactions[cycleId] ?? []
        return reactions.contains { reaction in
            reaction.itemId == item.id &&
            reaction.date >= dateStart &&
            reaction.date < dateEnd
        }
    }
    
    // Check if there's an unknown reaction on a specific day
    private func hasUnknownReaction(on date: Date) -> Bool {
        guard let cycleId = appData.currentCycleId() else { return false }
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let dateEnd = calendar.date(byAdding: .day, value: 1, to: dateStart)!
        
        let reactions = appData.reactions[cycleId] ?? []
        return reactions.contains { reaction in
            reaction.itemId == nil &&
            reaction.date >= dateStart &&
            reaction.date < dateEnd
        }
    }
    
    private func forceRefreshItems() {
        guard let cycleId = appData.currentCycleId() else { return }
        
        // Print debug information
        print("Forcing refresh of items for cycle: \(cycleId)")
        print("Current consumption log before refresh: \(appData.consumptionLog[cycleId] ?? [:])")
        
        // Instead of directly accessing appData.dbRef, call a public method
        appData.refreshItemsFromFirebase(forCycleId: cycleId) { success in
            if success {
                print("Successfully refreshed items from Firebase")
                
                // Also refresh consumption log data
                if let dbRef = self.appData.valueForDBRef() {
                    dbRef.child("consumptionLog").child(cycleId.uuidString).observeSingleEvent(of: .value) { snapshot in
                        print("Consumption log data received: \(snapshot.exists())")
                        
                        DispatchQueue.main.async {
                            self.appData.objectWillChange.send()
                            // Use forceRefreshID to update the UI
                            self.forceRefreshID = UUID()
                            print("Forced UI update after consumption log refresh")
                        }
                    }
                }
            } else {
                print("Failed to refresh items from Firebase")
            }
        }
    }
    
    private let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    // New method to check if a date is a cycle start date
    private func isDateCycleStart(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        for cycle in appData.cycles {
            let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
            if calendar.isDate(normalizedDate, inSameDayAs: cycleStartDay) {
                return true
            }
        }
        
        return false
    }
    
    // New method to check if a date is a cycle end date (food challenge date)
    private func isDateCycleEnd(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        for cycle in appData.cycles {
            let foodChallengeDay = calendar.startOfDay(for: cycle.foodChallengeDate)
            if calendar.isDate(normalizedDate, inSameDayAs: foodChallengeDay) {
                return true
            }
        }
        
        return false
    }
    
    // Initialize the week view based on the current date
    private func initializeWeekView() {
        // Find which logical cycle we're in
        let (index, _) = effectiveCycleForDate(Date())
        currentCycleOffset = index - (appData.cycles.count - 1)
        
        // Calculate week offset from cycle start
        if let cycle = selectedCycle() {
            let calendar = Calendar.current
            let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
            let today = calendar.startOfDay(for: Date())
            
            let daysSinceStart = calendar.dateComponents([.day], from: cycleStartDay, to: today).day ?? 0
            currentWeekOffset = max(0, daysSinceStart / 7)
        }
    }
    
    // Returns the effective cycle index and ID for a given date
    // This is the core logic change - a "cycle" now spans from its start date
    // to the start date of the next cycle (or indefinitely if it's the last cycle)
    private func effectiveCycleForDate(_ date: Date) -> (index: Int, id: UUID?) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Sort cycles by start date
        let sortedCycles = appData.cycles.sorted { $0.startDate < $1.startDate }
        
        // Debug output
        print("Finding cycle for date: \(normalizedDate), available cycles: \(sortedCycles.count)")
        
        // First try exact day-based match
        for i in 0..<sortedCycles.count {
            let cycle = sortedCycles[i]
            let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
            let cycleEndDay = calendar.startOfDay(for: cycle.foodChallengeDate)
            
            if normalizedDate >= cycleStartDay && normalizedDate <= cycleEndDay {
                print("Found exact cycle match: \(cycle.id)")
                return (i, cycle.id)
            }
        }
        
        // If not found in exact range, try the extended logic
        for i in 0..<sortedCycles.count {
            let cycle = sortedCycles[i]
            let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
            
            // If this is the last cycle, it extends indefinitely
            if i == sortedCycles.count - 1 {
                if normalizedDate >= cycleStartDay {
                    print("Using last cycle: \(cycle.id)")
                    return (i, cycle.id)
                }
            } else {
                // Otherwise, it extends until the start of the next cycle
                let nextCycle = sortedCycles[i + 1]
                let nextCycleStartDay = calendar.startOfDay(for: nextCycle.startDate)
                
                if normalizedDate >= cycleStartDay && normalizedDate < nextCycleStartDay {
                    print("Using cycle ending before next: \(cycle.id)")
                    return (i, cycle.id)
                }
            }
        }
        
        // If the date is before any cycle, use the first cycle
        if let firstCycle = sortedCycles.first, normalizedDate < calendar.startOfDay(for: firstCycle.startDate) {
            print("Using first cycle (date before any cycle): \(firstCycle.id)")
            return (0, firstCycle.id)
        }
        
        // Fallback to the last cycle
        if let lastCycle = sortedCycles.last {
            print("Fallback to last cycle: \(lastCycle.id)")
            return (sortedCycles.count - 1, lastCycle.id)
        }
        
        print("No cycles found at all")
        return (0, nil)
    }
    
    func refreshWeekViewData() {
        print("Refreshing WeekView data")
        
        // Force reload consumption log data from AppData
        if let cycleId = appData.currentCycleId() {
            appData.loadRoomData(roomId: appData.currentRoomId ?? "")
            
            // Force UI update via the appData object instead
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appData.objectWillChange.send()
                // Use forceRefreshID to force UI update
                if #available(iOS 15.0, *) {
                    // For iOS 15+, we can use withAnimation to make it smoother
                    withAnimation {
                        // Generate a new UUID to force view update
                        self.forceRefreshID = UUID()
                    }
                } else {
                    // For earlier iOS versions
                    self.forceRefreshID = UUID()
                }
            }
        }
    }
    
    func weekStartDate() -> Date {
        guard let cycle = selectedCycle() else { return Date() }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: currentWeekOffset * 7, to: calendar.startOfDay(for: cycle.startDate)) ?? Date()
    }
    
    func dayDate(for offset: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: offset, to: weekStartDate()) ?? Date()
    }
    
    func weekDays() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStartDate()) ?? Date()
            return formatter.string(from: date)
        }
    }
    
    func displayedCycleNumber() -> Int {
        guard !appData.cycles.isEmpty else { return 0 }
        let index = max(0, min(appData.cycles.count - 1, appData.cycles.count - 1 + currentCycleOffset))
        return appData.cycles[index].number
    }
    
    func selectedCycle() -> Cycle? {
        guard !appData.cycles.isEmpty else { return nil }
        let index = max(0, min(appData.cycles.count - 1, appData.cycles.count - 1 + currentCycleOffset))
        return appData.cycles[index]
    }
    
    func itemsForSelectedCycle() -> [Item] {
        guard let cycle = selectedCycle() else { return [] }
        return (appData.cycleItems[cycle.id] ?? []).sorted { $0.order < $1.order }
    }
    
    func isItemLogged(item: Item, on date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check all cycles to be sure
        for (cycleId, itemsLog) in appData.consumptionLog {
            if let itemLogs = itemsLog[item.id] {
                for log in itemLogs {
                    if calendar.isDate(log.date, inSameDayAs: normalizedDate) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    func weeklyDoseCount(for item: Item) -> Int {
        let weekStart = weekStartDate()
        let calendar = Calendar.current
        
        var count = 0
        for dayOffset in 0..<7 {
            let currentDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            
            // Find which cycle this specific day belongs to
            let (_, cycleId) = effectiveCycleForDate(currentDate)
            
            if let id = cycleId {
                let logs = appData.consumptionLog[id]?[item.id] ?? []
                let dayLogs = logs.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
                count += dayLogs.count
            }
        }
        
        return count
    }
    
    
    
    private func itemDisplayText(item: Item) -> String {
        appData.itemDisplayText(item: item, week: displayedWeekNumber())
    }
    
    func weekRangeText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStartDate())
        let end = formatter.string(from: Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate()) ?? Date())
        let year = Calendar.current.component(.year, from: weekStartDate())
        return "\(start) - \(end), \(year)"
    }
    
    func displayedWeekNumber() -> Int {
        return currentWeekOffset + 1
    }
    
    // Calculate the effective end date of a cycle (which is the start date of the next cycle or indefinite)
    private func effectiveEndDateForCycle(_ cycle: Cycle) -> Date? {
        let sortedCycles = appData.cycles.sorted { $0.startDate < $1.startDate }
        if let index = sortedCycles.firstIndex(where: { $0.id == cycle.id }) {
            if index < sortedCycles.count - 1 {
                return sortedCycles[index + 1].startDate
            }
        }
        // If it's the last cycle or not found, return nil (no end date)
        return nil
    }
    
    func previousWeek() {
        if currentWeekOffset > 0 {
            currentWeekOffset -= 1
        } else {
            // We're at the first week of this cycle
            // Check if we need to move to a previous cycle
            if currentCycleOffset > -maxCyclesBefore() {
                currentCycleOffset -= 1
                
                // Calculate how many weeks are in the previous cycle
                if let cycle = selectedCycle() {
                    let calendar = Calendar.current
                    let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
                    let cycleEndDay: Date
                    
                    if let effectiveEndDate = effectiveEndDateForCycle(cycle) {
                        // Use the day before the next cycle starts
                        cycleEndDay = calendar.date(byAdding: .day, value: -1, to: effectiveEndDate) ?? cycle.foodChallengeDate
                    } else {
                        // If no effective end date (last cycle), use today
                        cycleEndDay = Date()
                    }
                    
                    let days = calendar.dateComponents([.day], from: cycleStartDay, to: cycleEndDay).day ?? 0
                    currentWeekOffset = max(0, days / 7)
                }
            }
        }
    }
    
    func nextWeek() {
        let maxWeeks = maxWeeksBefore()
        
        if currentWeekOffset < maxWeeks {
            currentWeekOffset += 1
        } else {
            // We're at the last week of this cycle
            // Check if we need to move to the next cycle
            if currentCycleOffset < 0 {
                currentCycleOffset += 1
                currentWeekOffset = 0
            }
        }
    }
    
    func maxWeeksBefore() -> Int {
        guard let cycle = selectedCycle() else { return 0 }
        let calendar = Calendar.current
        
        let cycleStartDay = calendar.startOfDay(for: cycle.startDate)
        
        // Always use the food challenge date for calculating the maximum number of weeks
        // This ensures we can scroll forward to see the food challenge date
        let cycleEndDay = calendar.startOfDay(for: cycle.foodChallengeDate)
        
        let days = calendar.dateComponents([.day], from: cycleStartDay, to: cycleEndDay).day ?? 0
        return max(0, days / 7)
    }
    
    func maxCyclesBefore() -> Int {
        return appData.cycles.count - 1
    }
}
