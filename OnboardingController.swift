//
//  OnboardingController.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 5/12/25.
//


import SwiftUI

struct OnboardingController: View {
    @State private var showOnboarding: Bool = false
    
    var body: some View {
        EmptyView()
            .onAppear {
                // Check if first-time user
                let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                showOnboarding = !hasCompletedOnboarding
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isShowingOnboarding: $showOnboarding)
            }
    }
}