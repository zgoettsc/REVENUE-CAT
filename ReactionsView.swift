import SwiftUI

struct ReactionsView: View {
    @ObservedObject var appData: AppData
    @State private var showingAddReactionSheet = false
    @State private var editingReaction: Reaction?
    @State private var selectedFilter: FilterOption = .date
    @State private var dateSort: DateSortOption = .descending
    @State private var showingFilterSheet = false
    @State private var selectedItemId: UUID?
    @State private var selectedSymptom: SymptomType?
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var forceRefreshID = UUID()
    
    enum FilterOption: String, CaseIterable {
        case date = "Date"
        case item = "Item"
        case symptom = "Symptom"
    }
    
    enum DateSortOption: String {
        case ascending = "Oldest First"
        case descending = "Newest First"
        case customRange = "Custom Range"
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Filter buttons layout
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            filterButton(option)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                }
                
                // Current filter display
                HStack {
                    Text(currentFilterDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isFilterActive() {
                        Button(action: {
                            clearFilters()
                        }) {
                            Text("Clear Filter")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                        Button(action: {
                            showingFilterSheet = true
                        }) {
                            Text("Change")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                   }
                   .padding(.horizontal)
                
                // Reactions list
                if let cycleId = appData.currentCycleId() {
                    let reactions = filteredReactions(cycleId: cycleId)
                    
                    if reactions.isEmpty {
                        VStack {
                            Spacer()
                            Text("No reactions match current filter")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Change filter or tap + to add a reaction")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(reactions) { reaction in
                                ReactionsListItem(reaction: reaction, appData: appData, cycleId: cycleId)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingReaction = reaction
                                    }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let reaction = reactions[index]
                                    appData.removeReaction(reaction.id, fromCycleId: cycleId)
                                }
                            }
                        }
                    }
                } else {
                    Text("No active cycle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            }
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddReactionSheet = true
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
        .navigationTitle("Reactions")
        .sheet(isPresented: $showingAddReactionSheet) {
            NavigationView {
                AddReactionView(appData: appData)
            }
        }
        .sheet(item: $editingReaction) { reaction in
            NavigationView {
                EditReactionView(appData: appData, reaction: reaction)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationView {
                FilterOptionsView(
                    appData: appData,
                    selectedFilter: $selectedFilter,
                    dateSort: $dateSort,
                    selectedItemId: $selectedItemId,
                    selectedSymptom: $selectedSymptom,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DataRefreshed"))) { _ in
            self.forceRefreshID = UUID()
        }
        .onAppear {
            // Force refresh reactions data when view appears
            print("ReactionsView appeared, refreshing data")
            
            // Make sure we're seeing all the latest data from Firebase
            if let cycleId = appData.currentCycleId() {
                if appData.reactions[cycleId] == nil {
                    // If we don't have any reactions data, initialize it
                    appData.reactions[cycleId] = []
                }
            }
            
            // Set a delay to ensure data is loaded and UI is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.forceRefreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ReactionsUpdated"))) { _ in
            print("ReactionsView received ReactionsUpdated notification")
            DispatchQueue.main.async {
                self.forceRefreshID = UUID()
            }
        }
    }
    
    // Current filter description
    private func currentFilterDescription() -> String {
        switch selectedFilter {
        case .date:
            switch dateSort {
            case .ascending:
                return "Showing oldest reactions first"
            case .descending:
                return "Showing newest reactions first"
            case .customRange:
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return "Date range: \(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
            }
        case .item:
            if let itemId = selectedItemId, let cycleId = appData.currentCycleId() {
                let itemName = appData.cycleItems[cycleId]?.first(where: { $0.id == itemId })?.name ?? "Unknown item"
                return "Filtered by item: \(itemName)"
            } else {
                return "Showing all items"
            }
        case .symptom:
            if let symptom = selectedSymptom {
                return "Filtered by symptom: \(symptom.rawValue)"
            } else {
                return "Showing all symptoms"
            }
        }
    }
    
    // Filter button styled like in HistoryView
    private func filterButton(_ filter: FilterOption) -> some View {
        Button(action: {
            selectedFilter = filter
            showingFilterSheet = true
        }) {
            Text(filter.rawValue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedFilter == filter ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(selectedFilter == filter ? .white : .primary)
                .cornerRadius(20)
        }
    }
    
    private func isFilterActive() -> Bool {
        switch selectedFilter {
        case .date:
            return dateSort != .descending // Default is newest first
        case .item:
            return selectedItemId != nil
        case .symptom:
            return selectedSymptom != nil
        }
    }

    private func clearFilters() {
        selectedFilter = .date
        dateSort = .descending
        selectedItemId = nil
        selectedSymptom = nil
        customStartDate = Calendar.current.date(byAdding : .day, value: -7, to: Date()) ?? Date()
        customEndDate = Date()
    }
    
    func filteredReactions(cycleId: UUID) -> [Reaction] {
        // Make sure we have the latest reactions
        let allReactions = appData.reactions[cycleId] ?? []
        print("ReactionsView: Found \(allReactions.count) reactions for cycle \(cycleId)")
        
        var filtered = allReactions
        
        // Apply filters based on selected options
        switch selectedFilter {
        case .date:
            switch dateSort {
            case .ascending:
                filtered = filtered.sorted { $0.date < $1.date }
            case .descending:
                filtered = filtered.sorted { $0.date > $1.date }
            case .customRange:
                let calendar = Calendar.current
                let startDay = calendar.startOfDay(for: customStartDate)
                let endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!
                
                filtered = filtered.filter { reaction in
                    reaction.date >= startDay && reaction.date < endDay
                }
                filtered = filtered.sorted { $0.date > $1.date }
            }
        case .item:
            if let itemId = selectedItemId {
                filtered = filtered.filter { $0.itemId == itemId }
            }
            filtered = filtered.sorted { $0.date > $1.date }
        case .symptom:
            if let symptom = selectedSymptom {
                filtered = filtered.filter { $0.symptoms.contains(symptom) }
            }
            filtered = filtered.sorted { $0.date > $1.date }
        }
        
        return filtered
    }
}

struct ReactionsListItem: View {
    let reaction: Reaction
    let appData: AppData
    let cycleId: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(getFormattedDate())
                        .font(.headline)
                    
                    if let itemId = reaction.itemId, let item = appData.cycleItems[cycleId]?.first(where: { $0.id == itemId }) {
                        Text("Reaction to: ")
                            .font(.subheadline)
                            .foregroundColor(.secondary) +
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(getCategoryColor(for: item.category))
                    } else {
                        Text("Unknown cause")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Severity indicator (using number of symptoms)
                ZStack {
                    Circle()
                        .fill(getSeverityColor())
                        .frame(width: 30, height: 30)
                    Text("\(reaction.symptoms.count)")
                        .foregroundColor(.white)
                        .font(.caption)
                        .bold()
                }
            }
            
            // Symptoms
            HStack {
                Text("Symptoms:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(reaction.symptoms, id: \.self) { symptom in
                            Text(symptom.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        if let otherSymptom = reaction.otherSymptom, !otherSymptom.isEmpty {
                            Text(otherSymptom)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            if !reaction.description.isEmpty {
                Text(reaction.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
    
    func getFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reaction.date)
    }
    
    func getSeverityColor() -> Color {
        if reaction.symptoms.contains(.anaphylaxis) {
            return .red
        } else if reaction.symptoms.count >= 3 {
            return .orange
        } else {
            return .blue
        }
    }
    
    func getCategoryColor(for category: Category) -> Color {
        switch category {
        case .medicine: return .blue
        case .maintenance: return .green
        case .treatment: return .purple
        case .recommended: return .orange
        }
    }
}
