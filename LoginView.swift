import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingPasswordReset = false
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 242/255, green: 247/255, blue: 255/255).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Logo and Title
                    VStack(spacing: 10) {
                        Image(systemName: "fork.knife")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        
                        Text("Tolerance Tracker")
                            .font(.largeTitle.bold())
                            .foregroundColor(.blue)
                        
                        Text("Track your daily progress")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                    
                    // Login Form
                    VStack(spacing: 15) {
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
                            
                            SecureField("Enter your password", text: $password)
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                        }
                        
                        // Error Message
                        if let errorMessage = authViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 5)
                        }
                        
                        // Forgot Password Link
                        HStack {
                            Spacer()
                            Button(action: {
                                showingPasswordReset = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 5)
                    }
                    .padding(.horizontal)
                    
                    // Sign In Button
                    Button(action: {
                        authViewModel.signIn(email: email, password: password)
                    }) {
                        if authViewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(email.isEmpty || password.isEmpty || authViewModel.isProcessing)
                    
                    // Sign Up Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        Text("Don't have an account? Sign Up")
                            .font(.callout)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
