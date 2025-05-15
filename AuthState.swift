//
//  AuthState.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/20/25.
//


import Foundation
import FirebaseAuth

// Authentication states
enum AuthState {
    case signedIn
    case signedOut
    case loading
}

// User authentication model
struct AuthUser {
    let uid: String
    let email: String?
    let displayName: String?
    let isAnonymous: Bool
    
    init(user: FirebaseAuth.User) {
        self.uid = user.uid
        self.email = user.email
        self.displayName = user.displayName
        self.isAnonymous = user.isAnonymous
    }
}

// Authentication error types
enum AuthError: Error {
    case invalidEmail
    case weakPassword
    case emailInUse
    case invalidCredentials
    case unknown(message: String)
    
    var message: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters long."
        case .emailInUse:
            return "This email is already in use. Please try another or sign in."
        case .invalidCredentials:
            return "Incorrect email or password. Please try again."
        case .unknown(let message):
            return message
        }
    }
}