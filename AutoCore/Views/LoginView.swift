import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import AppKit

#if os(macOS)

private enum LoginStage {
    case entry
    case signIn
    case signUp
}

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var stage: LoginStage = .entry
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentNonce = ""
    @State private var inlineMessage: String?
    @State private var isAppleHovered = false
    private let appleSignInCoordinator = AppleSignInCoordinator()

    private var emailTrimmed: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        Self.emailRegex.evaluate(with: emailTrimmed)
    }

    private var passwordsMatch: Bool {
        stage != .signUp || confirmPassword == password
    }

    private var canSubmit: Bool {
        guard isEmailValid, !password.isEmpty else { return false }
        if stage == .signUp {
            return password.count >= 6 && !confirmPassword.isEmpty && passwordsMatch
        }
        return true
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 24)

                if stage == .entry {
                    logoView
                        .padding(.bottom, 40)
                }

                ZStack {
                    switch stage {
                    case .entry:
                        VStack(spacing: 14) {
                            entryButtons
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    case .signIn:
                        VStack(spacing: 14) {
                            signInForm
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .signUp:
                        VStack(spacing: 14) {
                            signUpForm
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: 320)

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: stage)
        .onChange(of: stage) { _, _ in
            inlineMessage = nil
            authViewModel.clearError()
            if stage == .entry {
                email = ""
                password = ""
                confirmPassword = ""
            }
        }
    }

    private var logoView: some View {
        Image("LoginLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 76, height: 76)
            .shadow(color: Color.red.opacity(0.2), radius: 12, x: 0, y: 0)
    }

    private var entryButtons: some View {
        VStack(spacing: 12) {
            googleButton(title: "Продолжить с Google")
            appleButton
            primaryButton(title: "Зарегистрироваться") {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    stage = .signUp
                }
            }
            loginTextButton {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    stage = .signIn
                }
            }
        }
    }

    private var signInForm: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        stage = .entry
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryText)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Вход")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Color.clear.frame(width: 14, height: 14)
            }

            authMessages
            textField("Email", text: $email)
            secureField("Пароль", text: $password)
            submitButton(title: "Войти")
        }
    }

    private var signUpForm: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        stage = .entry
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryText)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Регистрация")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Color.clear.frame(width: 14, height: 14)
            }

            authMessages
            textField("Email", text: $email)
            secureField("Пароль", text: $password)
            secureField("Повторите пароль", text: $confirmPassword)
            if !passwordsMatch && !confirmPassword.isEmpty {
                Text("Пароли не совпадают")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            submitButton(title: "Зарегистрироваться")
        }
    }

    private var authMessages: some View {
        VStack(spacing: 10) {
            if let error = authViewModel.errorMessage {
                messageBanner(error, isError: true)
            }
            if let inlineMessage {
                messageBanner(inlineMessage, isError: true)
            }
        }
    }

    private func googleButton(title: String) -> some View {
        SoftActionButton(
            title: title,
            isLoading: false,
            isDisabled: authViewModel.isProviderSigningIn
        ) {
            Task { await authViewModel.signInWithGoogle() }
        }
    }

    private var appleButton: some View {
        Button(action: startAppleSignIn) {
            Label("Вход с Apple", systemImage: "applelogo")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? AppColors.border : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    colorScheme == .dark ? AppColors.border : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
        .opacity(authViewModel.isProviderSigningIn ? 0.7 : (isAppleHovered ? 1.0 : 0.9))
        .scaleEffect(authViewModel.isProviderSigningIn ? 1.0 : (isAppleHovered ? 1.02 : 1.0))
        .onHover { hovering in
            guard !authViewModel.isProviderSigningIn else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isAppleHovered = hovering
            }
        }
        .disabled(authViewModel.isProviderSigningIn)
    }

    private func startAppleSignIn() {
        guard !authViewModel.isProviderSigningIn else { return }
        let nonce = randomNonceString()
        currentNonce = nonce
        appleSignInCoordinator.startSignIn(rawNonce: nonce) { result in
            switch result {
            case .success(let credential):
                Task {
                    await authViewModel.handleAppleSignIn(credential: credential, rawNonce: nonce)
                }
            case .failure(let error):
                authViewModel.setAppleSignInError(error)
            }
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        SoftActionButton(title: title, isLoading: false, isDisabled: false, action: action)
    }

    private func loginTextButton(action: @escaping () -> Void) -> some View {
        LoginTextButton(action: action)
    }

    private func messageBanner(_ text: String, isError: Bool) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? Color.red.opacity(0.95) : Color.green.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isError ? Color.red : Color.green).opacity(0.12))
            )
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundStyle(primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(inputBorder, lineWidth: 1)
            )
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundStyle(primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(inputBorder, lineWidth: 1)
            )
    }

    private func submitButton(title: String) -> some View {
        SoftActionButton(
            title: title,
            isLoading: authViewModel.isSigningIn,
            isDisabled: !canSubmit || authViewModel.isProviderSigningIn || authViewModel.isSigningIn,
            action: submit
        )
    }

    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [AppColors.background, AppColors.backgroundElevated],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.97, blue: 0.98),
                Color(red: 0.90, green: 0.90, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var primaryText: Color {
        colorScheme == .dark ? AppColors.textPrimary : Color.black.opacity(0.85)
    }

    private var inputBackground: Color {
        colorScheme == .dark ? AppColors.surface : Color.white.opacity(0.62)
    }

    private var inputBorder: Color {
        colorScheme == .dark ? AppColors.border : Color.black.opacity(0.12)
    }

    private func submit() {
        authViewModel.clearError()
        inlineMessage = nil

        guard isEmailValid else {
            inlineMessage = "Введите корректный email."
            return
        }

        if stage == .signUp {
            guard password.count >= 6 else {
                inlineMessage = "Пароль должен быть не короче 6 символов."
                return
            }
            guard passwordsMatch else {
                inlineMessage = "Пароли не совпадают."
                return
            }
            Task { await authViewModel.signUp(email: emailTrimmed, password: password) }
        } else {
            Task { await authViewModel.signIn(email: emailTrimmed, password: password) }
        }
    }

    private static let emailRegex: NSPredicate = {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern)
    }()
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms: [UInt8] = (0..<16).map { _ in 0 }
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if errorCode != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let hashed = SHA256.hash(data: Data(input.utf8))
    return hashed.map { String(format: "%02x", $0) }.joined()
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((Result<ASAuthorizationAppleIDCredential, Error>) -> Void)?

    func startSignIn(rawNonce: String, completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        if let firstWindow = NSApplication.shared.windows.first {
            return firstWindow
        }
        return ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion?(.success(credential))
        } else {
            completion?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный тип credential"])))
        }
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }
}

private struct SoftActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.7 : (isHovered ? 1.0 : 0.9))
        .scaleEffect(isDisabled ? 1.0 : (isHovered ? 1.02 : 1.0))
        .onHover { hovering in
            guard !isDisabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.82)
        }
        return Color.black.opacity(0.82)
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return isHovered ? Color.white.opacity(1.0) : Color.white.opacity(0.9)
        }
        return isHovered ? Color.white.opacity(0.95) : Color.white.opacity(0.9)
    }

    private var borderColor: Color {
        colorScheme == .dark ? AppColors.border : Color.white.opacity(0.08)
    }
}

private struct LoginTextButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("Войти")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(loginTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var loginTextColor: Color {
        if colorScheme == .dark {
            return isHovered ? AppColors.textPrimary : AppColors.textSecondary
        }
        return Color.black.opacity(isHovered ? 0.8 : 0.46)
    }
}

struct AppColors {
    static let background = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let backgroundElevated = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let surface = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let button = Color.white.opacity(0.08)
    static let buttonHover = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.10)
    static let textPrimary = Color.white.opacity(0.90)
    static let textSecondary = Color.white.opacity(0.60)
    static let textDisabled = Color.white.opacity(0.40)
    static let divider = Color.white.opacity(0.08)
    static let icon = Color.white.opacity(0.80)
}

#endif
