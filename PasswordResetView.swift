//
//  PasswordResetView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/20/25.
//


import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 242/255, green: 247/255, blue: 255/255).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 10) {
                        Text("Reset Password")
                            .font(.largeTitle.bold())
                            .foregroundColor(.blue)
                        
                        Text("Enter your email to receive a password reset link")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("youremail@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        authViewModel.resetPassword(email: email) { success in
                            if success {
                                showingSuccessAlert = true
                            }
                        }
                    }) {
                        if authViewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(email.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(email.isEmpty || authViewModel.isProcessing)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Password Reset Email Sent", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Check your email for instructions to reset your password.")
            }
        }
    }
}