//
//  TreatmentTimerAttributes.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 5/12/25.
//


import Foundation
import ActivityKit

struct TreatmentTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var roomId: String
        var roomName: String
        var isExpired: Bool
    }
    
    var timerID: String
}