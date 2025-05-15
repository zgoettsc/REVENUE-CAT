//
//  SignUpView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/20/25.
//


import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var localErrorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 242/255, green: 247/255, blue: 255/255).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Create Account")
                            .font(.largeTitle.bold())
                            .foregroundColor(.blue)
                            .padding(.top, 30)
                        
                        // Form
                        VStack(spacing: 15) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Full Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                TextField("Your name", text: $name)
                                    .foregroundColor(.black)
                                    .autocapitalization(.words)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                TextField("youremail@example.com", text: $email)
                                    .foregroundColor(.black)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                SecureField("Create a password", text: $password)
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                                
                                Text("Password must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                SecureField("Re-enter your password", text: $passwordConfirm)
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Error Messages
                        if let errorMessage = localErrorMessage ?? authViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Sign Up Button
                        Button(action: {
                            validateAndSignUp()
                        }) {
                            if authViewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(isFormValid() ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(!isFormValid() || authViewModel.isProcessing)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func isFormValid() -> Bool {
        return !name.isEmpty && 
               !email.isEmpty && 
               !password.isEmpty && 
               password.count >= 6 && 
               password == passwordConfirm
    }
    
    private func validateAndSignUp() {
        localErrorMessage = nil
        
        // Validate password match
        if password != passwordConfirm {
            localErrorMessage = "Passwords do not match"
            return
        }
        
        // Validate password length
        if password.count < 6 {
            localErrorMessage = "Password must be at least 6 characters long"
            return
        }
        
        // All validations passed, proceed with sign up
        authViewModel.signUp(name: name, email: email, password: password)
    }
}
