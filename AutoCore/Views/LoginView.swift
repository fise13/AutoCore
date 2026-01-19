//
//  LoginView.swift
//  AutoCore
//
//  Presentation Layer: Login View
//  macOS-style форма входа - системный, спокойный, профессиональный
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: LoginField?
    
    enum LoginField: Hashable {
        case email
        case password
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Центрированный контент
            VStack(spacing: 32) {
                // Заголовок
                VStack(spacing: 6) {
                    Text("AutoCore")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text("Sign in to continue")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                // Форма входа
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .email)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .frame(width: 360)
                            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                focusedField == .email ? Color.accentColor : Color(NSColor.separatorColor),
                                                lineWidth: focusedField == .email ? 2 : 1
                                            )
                                    )
                            )
                            .onSubmit {
                                if !email.isEmpty {
                                    focusedField = .password
                                }
                            }
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .password)
                            .textContentType(.password)
                            .frame(width: 360)
                            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                focusedField == .password ? Color.accentColor : Color(NSColor.separatorColor),
                                                lineWidth: focusedField == .password ? 2 : 1
                                            )
                                    )
                            )
                            .onSubmit {
                                if !email.isEmpty && !password.isEmpty {
                                    handleSignIn()
                                }
                            }
                    }
                    
                    // Error message
                    if let errorMessage = authViewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                    }
                    
                    // Sign In button
                    Button(action: handleSignIn) {
                        Group {
                            if authViewModel.isSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .frame(width: 360)
                        .frame(height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authViewModel.isSigningIn || email.isEmpty || password.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color(NSColor.separatorColor))
                        Text("or")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color(NSColor.separatorColor))
                    }
                    .frame(width: 360)
                    
                    // Sign in with Google
                    Button(action: handleSignInWithGoogle) {
                        Group {
                            if authViewModel.isSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Sign in with Google", systemImage: "globe")
                            }
                        }
                        .frame(width: 360)
                        .frame(height: 36)
                    }
                    .buttonStyle(.bordered)
                    .disabled(authViewModel.isSigningIn)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Фокус на email поле при появлении
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .email
            }
        }
        .onExitCommand {
            // Esc → очистка ошибки
            authViewModel.clearError()
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSignIn() {
        guard !email.isEmpty && !password.isEmpty else { return }
        guard !authViewModel.isSigningIn else { return }
        
        Task {
            await authViewModel.signIn(email: email, password: password)
        }
    }
    
    private func handleSignInWithGoogle() {
        guard !authViewModel.isSigningIn else { return }
        
        Task {
            await authViewModel.signInWithGoogle()
        }
    }
}
