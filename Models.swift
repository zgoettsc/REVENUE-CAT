import Foundation

struct LogEntry: Equatable, Codable, Hashable, Identifiable {
    let id = UUID() // Local identifier, not used for uniqueness in Set
    let date: Date
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case date = "timestamp"
        case userId
        // 'id' is not included in CodingKeys since it's not stored in Firebase
    }
    
    init(date: Date, userId: UUID) {
        self.date = date
        self.userId = userId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .date)
        guard let decodedDate = ISO8601DateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        self.date = decodedDate
        self.userId = try container.decode(UUID.self, forKey: .userId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let dateString = ISO8601DateFormatter().string(from: date)
        try container.encode(dateString, forKey: .date)
        try container.encode(userId, forKey: .userId)
    }
    
    // Hashable conformance: Ignore id, use only date and userId
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        return lhs.date == rhs.date && lhs.userId == rhs.userId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(userId)
    }
}

// Cycle conforms to Equatable and Codable
struct Cycle: Equatable, Codable {
    let id: UUID
    let number: Int
    let patientName: String
    let startDate: Date
    let foodChallengeDate: Date
    
    init(id: UUID = UUID(), number: Int, patientName: String, startDate: Date, foodChallengeDate: Date) {
        self.id = id
        self.number = number
        self.patientName = patientName
        self.startDate = startDate
        self.foodChallengeDate = foodChallengeDate
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let number = dictionary["number"] as? Int,
              let patientName = dictionary["patientName"] as? String,
              let startDateStr = dictionary["startDate"] as? String,
              let startDate = ISO8601DateFormatter().date(from: startDateStr),
              let foodChallengeDateStr = dictionary["foodChallengeDate"] as? String,
              let foodChallengeDate = ISO8601DateFormatter().date(from: foodChallengeDateStr) else { return nil }
        self.id = id
        self.number = number
        self.patientName = patientName
        self.startDate = startDate
        self.foodChallengeDate = foodChallengeDate
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "number": number,
            "patientName": patientName,
            "startDate": ISO8601DateFormatter().string(from: startDate),
            "foodChallengeDate": ISO8601DateFormatter().string(from: foodChallengeDate)
        ]
    }
    
    static func == (lhs: Cycle, rhs: Cycle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.number == rhs.number &&
               lhs.patientName == rhs.patientName &&
               lhs.startDate == rhs.startDate &&
               lhs.foodChallengeDate == rhs.foodChallengeDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, number, patientName, startDate, foodChallengeDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(Int.self, forKey: .number)
        patientName = try container.decode(String.self, forKey: .patientName)
        let startDateString = try container.decode(String.self, forKey: .startDate)
        guard let decodedStartDate = ISO8601DateFormatter().date(from: startDateString) else {
            throw DecodingError.dataCorruptedError(forKey: .startDate, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        startDate = decodedStartDate
        let foodChallengeDateString = try container.decode(String.self, forKey: .foodChallengeDate)
        guard let decodedFoodChallengeDate = ISO8601DateFormatter().date(from: foodChallengeDateString) else {
            throw DecodingError.dataCorruptedError(forKey: .foodChallengeDate, in: container, debugDescription: "Invalid ISO8601 date string")
        }
        foodChallengeDate = decodedFoodChallengeDate
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(patientName, forKey: .patientName)
        try container.encode(ISO8601DateFormatter().string(from: startDate), forKey: .startDate)
        try container.encode(ISO8601DateFormatter().string(from: foodChallengeDate), forKey: .foodChallengeDate)
    }
}

struct WeeklyDoseData: Codable, Equatable {
    let dose: Double
    let unit: String
    
    static func == (lhs: WeeklyDoseData, rhs: WeeklyDoseData) -> Bool {
        return lhs.dose == rhs.dose && lhs.unit == rhs.unit
    }
}

// Item conforms to Identifiable and Codable
struct Item: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: Category
    let dose: Double?
    let unit: String?
    let weeklyDoses: [Int: WeeklyDoseData]?
    let order: Int
    
    init(id: UUID = UUID(), name: String, category: Category, dose: Double? = nil, unit: String? = nil,
         weeklyDoses: [Int: WeeklyDoseData]? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.dose = dose
        self.unit = unit
        self.weeklyDoses = weeklyDoses
        self.order = order
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String,
              let categoryStr = dictionary["category"] as? String,
              let category = Category(rawValue: categoryStr) else {
            print("Failed to parse item: missing id, name, or category in \(dictionary)")
            return nil
        }
        self.id = id
        self.name = name
        self.category = category
        self.dose = dictionary["dose"] as? Double
        self.unit = dictionary["unit"] as? String
        
        // Enhanced weekly doses parsing
        var parsedDoses: [Int: WeeklyDoseData] = [:]
        
        if let weeklyDosesDict = dictionary["weeklyDoses"] as? [String: Any] {
            for (weekKey, value) in weeklyDosesDict {
                guard let weekNum = Int(weekKey) else {
                    print("Invalid week key: \(weekKey) in weeklyDoses")
                    continue
                }
                if let doseDataDict = value as? [String: Any],
                   let doseValue = doseDataDict["dose"] as? Double,
                   let unitValue = doseDataDict["unit"] as? String {
                    parsedDoses[weekNum] = WeeklyDoseData(dose: doseValue, unit: unitValue)
                } else if let doseValue = value as? Double {
                    // Legacy format with just dose, use item unit as fallback
                    parsedDoses[weekNum] = WeeklyDoseData(dose: doseValue, unit: self.unit ?? "")
                    print("Parsed legacy weekly dose for week \(weekNum): \(doseValue)")
                } else {
                    print("Failed to parse weekly dose for week \(weekKey): \(value)")
                }
            }
        } else if let weeklyDosesArray = dictionary["weeklyDoses"] as? [Any] {
            for (index, value) in weeklyDosesArray.enumerated() {
                if let doseDataDict = value as? [String: Any],
                   let doseValue = doseDataDict["dose"] as? Double,
                   let unitValue = doseDataDict["unit"] as? String {
                    parsedDoses[index] = WeeklyDoseData(dose: doseValue, unit: unitValue)
                } else if let doseValue = value as? Double {
                    // Simple number in array
                    parsedDoses[index] = WeeklyDoseData(dose: doseValue, unit: self.unit ?? "")
                } else if value is NSNull || value == nil {
                    // Skip null values in array
                    continue
                }
            }
        }
        
        self.weeklyDoses = parsedDoses.isEmpty ? nil : parsedDoses
        self.order = dictionary["order"] as? Int ?? 0
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "category": category.rawValue,
            "order": order
        ]
        if let dose = dose { dict["dose"] = dose }
        if let unit = unit { dict["unit"] = unit }
        
        if let weeklyDoses = weeklyDoses {
            var weeklyDosesDict: [String: [String: Any]] = [:]
            for (week, doseData) in weeklyDoses {
                weeklyDosesDict[String(week)] = [
                    "dose": doseData.dose,
                    "unit": doseData.unit
                ]
            }
            dict["weeklyDoses"] = weeklyDosesDict
            print("Serialized weeklyDoses: \(weeklyDosesDict)")
        }
        
        return dict
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, dose, unit, weeklyDoses, order
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let categoryString = try container.decode(String.self, forKey: .category)
        guard let decodedCategory = Category(rawValue: categoryString) else {
            throw DecodingError.dataCorruptedError(forKey: .category, in: container, debugDescription: "Invalid category value")
        }
        category = decodedCategory
        dose = try container.decodeIfPresent(Double.self, forKey: .dose)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        
        // Decode the weekly doses
        if let weeklyDosesDict = try container.decodeIfPresent([String: [String: String]].self, forKey: .weeklyDoses) {
            var decodedWeeklyDoses: [Int: WeeklyDoseData] = [:]
            for (weekStr, doseData) in weeklyDosesDict {
                if let week = Int(weekStr),
                   let doseStr = doseData["dose"],
                   let dose = Double(doseStr),
                   let unit = doseData["unit"] {
                    decodedWeeklyDoses[week] = WeeklyDoseData(dose: dose, unit: unit)
                }
            }
            weeklyDoses = decodedWeeklyDoses.isEmpty ? nil : decodedWeeklyDoses
        } else {
            weeklyDoses = nil
        }
        
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category.rawValue, forKey: .category)
        try container.encodeIfPresent(dose, forKey: .dose)
        try container.encodeIfPresent(unit, forKey: .unit)
        
        if let weeklyDoses = weeklyDoses {
            var encodedWeeklyDoses: [String: [String: String]] = [:]
            for (week, doseData) in weeklyDoses {
                encodedWeeklyDoses[String(week)] = [
                    "dose": String(doseData.dose),
                    "unit": doseData.unit
                ]
            }
            try container.encode(encodedWeeklyDoses, forKey: .weeklyDoses)
        }
        
        try container.encode(order, forKey: .order)
    }
}

// Unit conforms to Hashable, Identifiable, and Codable
struct Unit: Hashable, Identifiable, Codable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String else { return nil }
        self.id = id
        self.name = name
    }
    
    func toDictionary() -> [String: Any] {
        ["id": id.uuidString, "name": name]
    }
    
    static func == (lhs: Unit, rhs: Unit) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

// User conforms to Identifiable, Equatable, and Codable
// User conforms to Identifiable, Equatable, and Codable
struct User: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    var isAdmin: Bool
    let authId: String?
    var remindersEnabled: [Category: Bool]
    var reminderTimes: [Category: Date]
    var treatmentFoodTimerEnabled: Bool
    var treatmentTimerDuration: TimeInterval
    var ownedRooms: [String]? // Optional array for rooms owned by the user
    var subscriptionPlan: String? // Stores the product ID of the current subscription
    var roomLimit: Int // Maximum number of rooms allowed

    init(id: UUID = UUID(), name: String, isAdmin: Bool = false, authId: String? = nil,
         remindersEnabled: [Category: Bool] = [:], reminderTimes: [Category: Date] = [:],
         treatmentFoodTimerEnabled: Bool = false, treatmentTimerDuration: TimeInterval = 900,
         ownedRooms: [String]? = nil, subscriptionPlan: String? = nil, roomLimit: Int = 0) {
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
        self.authId = authId
        self.remindersEnabled = remindersEnabled
        self.reminderTimes = reminderTimes
        self.treatmentFoodTimerEnabled = treatmentFoodTimerEnabled
        self.treatmentTimerDuration = treatmentTimerDuration
        self.ownedRooms = ownedRooms
        self.subscriptionPlan = subscriptionPlan
        self.roomLimit = roomLimit
    }

    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String,
              let isAdmin = dictionary["isAdmin"] as? Bool else { return nil }
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
        self.authId = dictionary["authId"] as? String
        self.ownedRooms = dictionary["ownedRooms"] as? [String]
        self.subscriptionPlan = dictionary["subscriptionPlan"] as? String
        self.roomLimit = dictionary["roomLimit"] as? Int ?? 0

        if let remindersEnabledDict = dictionary["remindersEnabled"] as? [String: Bool] {
            self.remindersEnabled = remindersEnabledDict.reduce(into: [Category: Bool]()) { result, pair in
                if let category = Category(rawValue: pair.key) {
                    result[category] = pair.value
                }
            }
        } else {
            self.remindersEnabled = [:]
        }

        if let reminderTimesDict = dictionary["reminderTimes"] as? [String: String] {
            self.reminderTimes = reminderTimesDict.reduce(into: [Category: Date]()) { result, pair in
                if let category = Category(rawValue: pair.key),
                   let date = ISO8601DateFormatter().date(from: pair.value) {
                    result[category] = date
                }
            }
        } else {
            self.reminderTimes = [:]
        }

        self.treatmentFoodTimerEnabled = dictionary["treatmentFoodTimerEnabled"] as? Bool ?? false
        self.treatmentTimerDuration = dictionary["treatmentTimerDuration"] as? Double ?? 900
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "isAdmin": isAdmin,
            "treatmentFoodTimerEnabled": treatmentFoodTimerEnabled,
            "treatmentTimerDuration": treatmentTimerDuration,
            "roomLimit": roomLimit
        ]
        if let authId = authId {
            dict["authId"] = authId
        }
        if let ownedRooms = ownedRooms {
            dict["ownedRooms"] = ownedRooms
        }
        if let subscriptionPlan = subscriptionPlan {
            dict["subscriptionPlan"] = subscriptionPlan
        }
        if !remindersEnabled.isEmpty {
            dict["remindersEnabled"] = remindersEnabled.mapKeys { $0.rawValue }
        }
        if !reminderTimes.isEmpty {
            dict["reminderTimes"] = reminderTimes.mapKeys { $0.rawValue }.mapValues { ISO8601DateFormatter().string(from: $0) }
        }
        return dict
    }

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isAdmin == rhs.isAdmin &&
               lhs.authId == rhs.authId &&
               lhs.remindersEnabled == rhs.remindersEnabled &&
               lhs.reminderTimes == rhs.reminderTimes &&
               lhs.treatmentFoodTimerEnabled == rhs.treatmentFoodTimerEnabled &&
               lhs.treatmentTimerDuration == rhs.treatmentTimerDuration &&
               lhs.ownedRooms == rhs.ownedRooms &&
               lhs.subscriptionPlan == rhs.subscriptionPlan &&
               lhs.roomLimit == rhs.roomLimit
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isAdmin, authId, remindersEnabled, reminderTimes, treatmentFoodTimerEnabled, treatmentTimerDuration, ownedRooms, subscriptionPlan, roomLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        authId = try container.decodeIfPresent(String.self, forKey: .authId)
        ownedRooms = try container.decodeIfPresent([String].self, forKey: .ownedRooms)
        subscriptionPlan = try container.decodeIfPresent(String.self, forKey: .subscriptionPlan)
        roomLimit = try container.decodeIfPresent(Int.self, forKey: .roomLimit) ?? 0

        // Decode remindersEnabled
        if let remindersEnabledDict = try container.decodeIfPresent([String: Bool].self, forKey: .remindersEnabled) {
            remindersEnabled = remindersEnabledDict.reduce(into: [Category: Bool]()) { result, pair in
                if let category = Category(rawValue: pair.key) {
                    result[category] = pair.value
                }
            }
        } else {
            remindersEnabled = [:]
        }

        // Decode reminderTimes
        if let reminderTimesDict = try container.decodeIfPresent([String: String].self, forKey: .reminderTimes) {
            reminderTimes = reminderTimesDict.reduce(into: [Category: Date]()) { result, pair in
                if let category = Category(rawValue: pair.key),
                   let date = ISO8601DateFormatter().date(from: pair.value) {
                    result[category] = date
                }
            }
        } else {
            reminderTimes = [:]
        }

        treatmentFoodTimerEnabled = try container.decodeIfPresent(Bool.self, forKey: .treatmentFoodTimerEnabled) ?? false
        treatmentTimerDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .treatmentTimerDuration) ?? 900
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encodeIfPresent(authId, forKey: .authId)
        try container.encodeIfPresent(ownedRooms, forKey: .ownedRooms)
        try container.encodeIfPresent(subscriptionPlan, forKey: .subscriptionPlan)
        try container.encode(roomLimit, forKey: .roomLimit)
        try container.encode(remindersEnabled.mapKeys { $0.rawValue }, forKey: .remindersEnabled)
        try container.encode(reminderTimes.mapKeys { $0.rawValue }.mapValues { ISO8601DateFormatter().string(from: $0) }, forKey: .reminderTimes)
        try container.encode(treatmentFoodTimerEnabled, forKey: .treatmentFoodTimerEnabled)
        try container.encode(treatmentTimerDuration, forKey: .treatmentTimerDuration)
    }
}

enum Category: String, CaseIterable {
    case medicine = "Medicine"
    case maintenance = "Maintenance"
    case treatment = "Treatment"
    case recommended = "Recommended"
}

// GroupedItem for combining items within a category
struct GroupedItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: Category
    let itemIds: [UUID] // IDs of Items in this group
    
    init(id: UUID = UUID(), name: String, category: Category, itemIds: [UUID]) {
        self.id = id
        self.name = name
        self.category = category
        self.itemIds = itemIds
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let name = dictionary["name"] as? String,
              let categoryStr = dictionary["category"] as? String,
              let category = Category(rawValue: categoryStr),
              let itemIdsArray = dictionary["itemIds"] as? [String] else { return nil }
        self.id = id
        self.name = name
        self.category = category
        self.itemIds = itemIdsArray.compactMap { UUID(uuidString: $0) }
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "category": category.rawValue,
            "itemIds": itemIds.map { $0.uuidString }
        ]
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, itemIds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let categoryString = try container.decode(String.self, forKey: .category)
        guard let decodedCategory = Category(rawValue: categoryString) else {
            throw DecodingError.dataCorruptedError(forKey: .category, in: container, debugDescription: "Invalid category value")
        }
        category = decodedCategory
        itemIds = try container.decode([UUID].self, forKey: .itemIds)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category.rawValue, forKey: .category)
        try container.encode(itemIds, forKey: .itemIds)
    }
}

struct Fraction: Identifiable, Codable, Hashable { // Add Hashable conformance
    let id = UUID()
    let numerator: Int
    let denominator: Int
    
    var decimalValue: Double {
        Double(numerator) / Double(denominator)
    }
    
    var displayString: String {
        "\(numerator)/\(denominator)"
    }
    
    static let commonFractions: [Fraction] = [
        Fraction(numerator: 1, denominator: 8),  // 0.125
        Fraction(numerator: 1, denominator: 4),  // 0.25
        Fraction(numerator: 1, denominator: 3),  // ~0.333
        Fraction(numerator: 1, denominator: 2),  // 0.5
        Fraction(numerator: 2, denominator: 3),  // ~0.666
        Fraction(numerator: 3, denominator: 4),  // 0.75
    ]
    
    static func fractionForDecimal(_ decimal: Double, tolerance: Double = 0.01) -> Fraction? {
        commonFractions.first { abs($0.decimalValue - decimal) < tolerance }
    }
    
    // Hashable conformance
    static func ==(lhs: Fraction, rhs: Fraction) -> Bool {
        lhs.numerator == rhs.numerator && lhs.denominator == rhs.denominator
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(numerator)
        hasher.combine(denominator)
    }
}

// Helper extension to transform dictionary keys
extension Dictionary {
    func mapKeys<T>(transform: (Key) -> T) -> [T: Value] {
        return reduce(into: [T: Value]()) { result, pair in
            result[transform(pair.key)] = pair.value
        }
    }
}

struct TreatmentTimer: Codable, Equatable {
    let id: String
    let isActive: Bool
    let endTime: Date
    let associatedItemIds: [UUID]?
    let notificationIds: [String]?
    let roomName: String? // Add this line
    
    init(id: String = UUID().uuidString,
         isActive: Bool = true,
         endTime: Date,
         associatedItemIds: [UUID]? = nil,
         notificationIds: [String]? = nil,
         roomName: String? = nil) { // Add roomName parameter
        self.id = id
        self.isActive = isActive
        self.endTime = endTime
        self.associatedItemIds = associatedItemIds
        self.notificationIds = notificationIds
        self.roomName = roomName // Add this line
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "isActive": isActive,
            "endTime": ISO8601DateFormatter().string(from: endTime)
        ]
        
        if let associatedItemIds = associatedItemIds {
            dict["associatedItemIds"] = associatedItemIds.map { $0.uuidString }
        }
        
        if let notificationIds = notificationIds {
            dict["notificationIds"] = notificationIds
        }
        
        if let roomName = roomName {
            dict["roomName"] = roomName
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> TreatmentTimer? {
        guard let id = dict["id"] as? String,
              let isActive = dict["isActive"] as? Bool,
              let endTimeStr = dict["endTime"] as? String,
              let endTime = ISO8601DateFormatter().date(from: endTimeStr) else {
            return nil
        }
        
        var associatedItemIds: [UUID]? = nil
        if let itemIdStrings = dict["associatedItemIds"] as? [String] {
            associatedItemIds = itemIdStrings.compactMap { UUID(uuidString: $0) }
        }
        
        var notificationIds: [String]? = nil
        if let ids = dict["notificationIds"] as? [String] {
            notificationIds = ids
        }
        
        let roomName = dict["roomName"] as? String
        
        return TreatmentTimer(
            id: id,
            isActive: isActive,
            endTime: endTime,
            associatedItemIds: associatedItemIds,
            notificationIds: notificationIds,
            roomName: roomName
        )
    }
}
enum SymptomType: String, Codable, CaseIterable, Identifiable {
    case hives = "Hives"
    case itching = "Itching"
    case redness = "Redness"
    case coughing = "Coughing"
    case vomiting = "Vomiting"
    case anaphylaxis = "Anaphylaxis"
    case other = "Other"
    
    var id: String { self.rawValue }
}

struct Reaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let itemId: UUID?
    let symptoms: [SymptomType]
    let otherSymptom: String?
    let description: String
    let userId: UUID
    
    init(id: UUID = UUID(), date: Date, itemId: UUID? = nil, symptoms: [SymptomType], otherSymptom: String? = nil, description: String, userId: UUID) {
        self.id = id
        self.date = date
        self.itemId = itemId
        self.symptoms = symptoms
        self.otherSymptom = otherSymptom
        self.description = description
        self.userId = userId
    }
    
    init?(dictionary: [String: Any]) {
        guard let idStr = dictionary["id"] as? String, let id = UUID(uuidString: idStr),
              let dateStr = dictionary["date"] as? String,
              let date = ISO8601DateFormatter().date(from: dateStr),
              let symptomsArr = dictionary["symptoms"] as? [String],
              let description = dictionary["description"] as? String,
              let userIdStr = dictionary["userId"] as? String,
              let userId = UUID(uuidString: userIdStr) else { return nil }
        
        self.id = id
        self.date = date
        self.description = description
        self.userId = userId
        
        if let itemIdStr = dictionary["itemId"] as? String {
            self.itemId = UUID(uuidString: itemIdStr)
        } else {
            self.itemId = nil
        }
        
        self.symptoms = symptomsArr.compactMap { SymptomType(rawValue: $0) }
        self.otherSymptom = dictionary["otherSymptom"] as? String
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "date": ISO8601DateFormatter().string(from: date),
            "symptoms": symptoms.map { $0.rawValue },
            "description": description,
            "userId": userId.uuidString
        ]
        
        if let itemId = itemId {
            dict["itemId"] = itemId.uuidString
        }
        
        if let otherSymptom = otherSymptom {
            dict["otherSymptom"] = otherSymptom
        }
        
        return dict
    }
}
