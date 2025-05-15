//
//  InfoButton.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/18/25.
//


import SwiftUI

struct InfoButton: View {
    let text: String
    @State private var showingInfo = false
    
    var body: some View {
        Button(action: {
            showingInfo = true
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        }
        .alert("Information", isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(text)
        }
    }
}
struct WithInfoButton: ViewModifier {
    let text: String
    
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
            InfoButton(text: text)
        }
    }
}

extension View {
    func withInfo(_ text: String) -> some View {
        modifier(WithInfoButton(text: text))
    }
}

//            .withInfo("Cycles correspond to the treatment foods challenged. If you are working on your first set of treatment foods- pick cycle 1. If this is your 10th set- pick cycle 10")
