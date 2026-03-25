//
//  LoginView.swift
//  AutoCore
//
//  Presentation Layer: Login View
//  macOS-style форма входа - системный, спокойный, профессиональный
//

import SwiftUI
import AuthenticationServices

#if os(macOS)

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var isRegistrationMode = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordMismatch: Bool = false
    
    private var canSubmit: Bool {
        if isRegistrationMode {
            !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
        } else {
            !email.isEmpty && !password.isEmpty
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(L10n.Login.appTitle)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                        Text(isRegistrationMode ? L10n.Login.createAccount : L10n.Login.chooseSignIn)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Card
                    VStack(spacing: 16) {
                        if let errorMessage = authViewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                        }
                        
                        // Quick providers (only for login)
                        if !isRegistrationMode {
                            VStack(spacing: 8) {
                                SignInWithAppleButton(
                                    .signIn,
                                    onRequest: { request in
                                        request.requestedScopes = [.fullName, .email]
                                    },
                                    onCompletion: { result in
                                        switch result {
                                        case .success(let authResult):
                                            if let credential = authResult.credential as? ASAuthorizationAppleIDCredential {
                                                Task {
                                                    await authViewModel.handleAppleSignIn(credential: credential)
                                                }
                                            }
                                        case .failure(let error):
                                            authViewModel.setError(L10n.Login.appleError(error.localizedDescription))
                                        }
                                    }
                                )
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Button {
                                    Task {
                                        await authViewModel.signInWithGoogle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "g.circle.fill")
                                        Text(L10n.Login.signInGoogle)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                            
                            // Divider
                            HStack {
                                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                                Text(L10n.Login.orEmail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                            }
                        }
                        
                        // Email / password form
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Email", text: $email)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField(L10n.Login.password, text: $password)
                                .textFieldStyle(.roundedBorder)
                            
                            if isRegistrationMode {
                                SecureField(L10n.Login.confirmPassword, text: $confirmPassword)
                                    .textFieldStyle(.roundedBorder)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(passwordMismatch ? Color.red : Color.clear, lineWidth: 1)
                                    )
                                    .onChange(of: confirmPassword) { _, _ in
                                        passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                                    }
                                
                                if passwordMismatch {
                                    Text(L10n.Login.passwordsMismatch)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            Button {
                                if isRegistrationMode {
                                    passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                                    guard canSubmit else { return }
                                    Task {
                                        await authViewModel.signUp(email: email, password: password)
                                    }
                                } else {
                                    Task {
                                        await authViewModel.signIn(email: email, password: password)
                                    }
                                }
                            } label: {
                                Text(isRegistrationMode ? L10n.Login.signUp : L10n.Login.signIn)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!canSubmit)
                        }
                        
                        // Switch mode link
                        Button {
                            isRegistrationMode.toggle()
                            confirmPassword = ""
                            passwordMismatch = false
                            authViewModel.clearError()
                        } label: {
                            Text(isRegistrationMode ? L10n.Login.haveAccountSignIn : L10n.Login.noAccountRegister)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(22)
                    .frame(width: 390)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 10)
                }
                
                Spacer()
            }
            .padding()
        }
        .onExitCommand {
            authViewModel.clearError()
        }
    }
}

#endif
