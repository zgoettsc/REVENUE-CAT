//
//  IsInsideNavigationViewKey.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/24/25.
//


import SwiftUI

struct IsInsideNavigationViewKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isInsideNavigationView: Bool {
        get { self[IsInsideNavigationViewKey.self] }
        set { self[IsInsideNavigationViewKey.self] = newValue }
    }
}