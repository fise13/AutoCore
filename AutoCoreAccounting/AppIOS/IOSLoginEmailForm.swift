import SwiftUI

#if os(iOS)

struct IOSLoginEmailForm: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(IOSPalette.backgroundElevated.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                        .stroke(IOSPalette.border, lineWidth: 1)
                )
                .cornerRadius(IOSDesign.Radius.button)
            
            SecureField("Пароль", text: $password)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(IOSPalette.backgroundElevated.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                        .stroke(IOSPalette.border, lineWidth: 1)
                )
                .cornerRadius(IOSDesign.Radius.button)
            
            Button {
                Task {
                    await authViewModel.signIn(email: email, password: password)
                }
            } label: {
                Text("Войти")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSPrimaryButtonStyle())
            .disabled(email.isEmpty || password.isEmpty)
        }
    }
}

// MARK: - Форма регистрации (тот же стиль полей)

struct IOSRegistrationEmailForm: View {
    @ObservedObject var authViewModel: AuthViewModel

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordMismatch: Bool = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(IOSPalette.backgroundElevated.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                        .stroke(IOSPalette.border, lineWidth: 1)
                )
                .cornerRadius(IOSDesign.Radius.button)

            SecureField("Пароль", text: $password)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(IOSPalette.backgroundElevated.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                        .stroke(IOSPalette.border, lineWidth: 1)
                )
                .cornerRadius(IOSDesign.Radius.button)

            SecureField("Повторите пароль", text: $confirmPassword)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(IOSPalette.backgroundElevated.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                        .stroke(passwordMismatch ? IOSPalette.negative : IOSPalette.border, lineWidth: 1)
                )
                .cornerRadius(IOSDesign.Radius.button)
                .onChange(of: confirmPassword) { _, _ in
                    passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                }

            if passwordMismatch {
                Text("Пароли не совпадают")
                    .font(.footnote)
                    .foregroundStyle(IOSPalette.negative)
            }

            Button {
                passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                guard canSubmit else { return }
                Task {
                    await authViewModel.signUp(email: email, password: password)
                }
            } label: {
                Text("Зарегистрироваться")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSPrimaryButtonStyle())
            .disabled(!canSubmit)
        }
    }
}

#endif

