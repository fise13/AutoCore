import SwiftUI
import AuthenticationServices

#if os(iOS)

/// Корневой контейнер для всего auth‑flow на iOS:
/// Splash → Welcome/Login → (создать компанию / присоединиться по invite) → основное приложение.
struct IOSAuthRootView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ZStack {
            IOSScreenBackground()
            
            Group {
                if let authViewModel = appState.authViewModel {
                    switch authViewModel.authState {
                    case .authenticated:
                        authenticatedContent(authViewModel: authViewModel)
                    case .authenticating:
                        IOSSplashView(title: L10n.IOS.loading)
                    case .unauthenticated:
                        IOSWelcomeAndLoginContainer(authViewModel: authViewModel)
                    }
                } else {
                    IOSSplashView(title: L10n.IOS.loading)
                }
            }
            .animation(.easeInOut, value: appState.companyId)
        }
    }
    
    @ViewBuilder
    private func authenticatedContent(authViewModel: AuthViewModel) -> some View {
        if let appViewModel = appState.appViewModel {
            if appState.companyId.isEmpty {
                IOSEnsureCompanyView(authViewModel: authViewModel, onFallbackToOnboarding: {})
            } else {
                IOSAppRootView(appState: appState, appViewModel: appViewModel)
                    .ignoresSafeArea()
            }
        } else {
            IOSSplashView(title: L10n.IOS.loadingData)
        }
    }
}

// MARK: - Автосоздание компании при первом входе (без бесконечного поиска бухгалтерии)

struct IOSEnsureCompanyView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onFallbackToOnboarding: () -> Void
    
    @StateObject private var companyViewModel: CompanyViewModel
    @State private var isCreating = true
    @State private var errorMessage: String?
    @State private var showManualOnboarding = false
    
    init(authViewModel: AuthViewModel, onFallbackToOnboarding: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onFallbackToOnboarding = onFallbackToOnboarding
        _companyViewModel = StateObject(wrappedValue: CompanyViewModel(
            companyService: FirestoreCompanyService(),
            authViewModel: authViewModel
        ))
    }
    
    var body: some View {
        ZStack {
            IOSScreenBackground()
            if showManualOnboarding {
                IOSOnboardingView(authViewModel: authViewModel)
            } else if let error = errorMessage {
                VStack(spacing: 24) {
                    Text(L10n.IOS.ensureCompanyFailed)
                        .font(.headline)
                        .foregroundStyle(IOSPalette.textPrimary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    HStack(spacing: 12) {
                        Button(L10n.IOS.retry) {
                            errorMessage = nil
                            isCreating = true
                            Task { await ensureCompany() }
                        }
                        .buttonStyle(IOSPrimaryButtonStyle())
                        Button(L10n.IOS.createManually) {
                            showManualOnboarding = true
                        }
                        .buttonStyle(IOSOutlinedBlueButtonStyle())
                    }
                }
                .padding(Spacing.x3)
            } else {
                IOSSplashView(title: isCreating ? L10n.IOS.creatingAccounting : L10n.IOS.loading)
            }
        }
        .task {
            guard isCreating else { return }
            await ensureCompany()
        }
    }
    
    private func ensureCompany() async {
        guard (authViewModel.currentUser?.companyId)?.isEmpty ?? true else {
            isCreating = false
            return
        }
        isCreating = true
        errorMessage = nil
        await companyViewModel.ensureDefaultCompany()
        if companyViewModel.errorMessage != nil {
            await MainActor.run {
                errorMessage = companyViewModel.errorMessage
                isCreating = false
            }
            return
        }
        do {
            try await authViewModel.refreshCurrentUser()
            await MainActor.run { isCreating = false }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

// MARK: - Splash

struct IOSSplashView: View {
    let title: String

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        ZStack {
            IOSPalette.loginGradient
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)

                    Image(systemName: "building.columns.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 10) {
                    Text("AutoCore")
                        .font(IOSDesign.Typography.largeTitle)
                        .foregroundStyle(.white)
                    Text("Accounting")
                        .font(IOSDesign.Typography.subtitle)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .opacity(titleOpacity)

                HStack(spacing: 4) {
                    Text(title)
                        .font(IOSDesign.Typography.subtitle)
                        .foregroundStyle(.white.opacity(0.85))
                    loadingDots
                }
                .opacity(subtitleOpacity)
            }
            .padding(Spacing.x3)
        }
        .onAppear {
            withAnimation(IOSMotion.appear) {
                iconScale = 1
                iconOpacity = 1
            }
            withAnimation(IOSMotion.appear.delay(0.2)) {
                titleOpacity = 1
            }
            withAnimation(IOSMotion.appear.delay(0.4)) {
                subtitleOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    private var loadingDots: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let phase = Int(timeline.date.timeIntervalSince1970 / 0.4) % 3
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(phase == index ? 1 : 0.35))
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase == index ? 1.2 : 1)
                }
            }
            .animation(IOSMotion.quick, value: phase)
        }
    }
}

// MARK: - Welcome + Login контейнер

private enum AuthScreen {
    case welcome
    case login
    case registration
}

struct IOSWelcomeAndLoginContainer: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showLogin = false
    @State private var showRegistration = false
    
    private var currentScreen: AuthScreen {
        if showLogin {
            return showRegistration ? .registration : .login
        }
        return .welcome
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch currentScreen {
                case .welcome:
                    IOSWelcomeView(
                        onLogin: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showLogin = true
                            showRegistration = false
                        }},
                        onRegister: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showLogin = true
                            showRegistration = true
                        }}
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                case .login:
                    IOSLoginView(
                        authViewModel: authViewModel,
                        onBack: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { showLogin = false }},
                        onSwitchToRegistration: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { showRegistration = true }}
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                case .registration:
                    IOSRegistrationView(
                        authViewModel: authViewModel,
                        onBack: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { showRegistration = false }},
                        onSwitchToLogin: { withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { showRegistration = false }}
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.88), value: currentScreen)
        }
    }
}

// MARK: - Modern Fintech Welcome Screen

struct IOSWelcomeView: View {
    let onLogin: () -> Void
    let onRegister: () -> Void

    var body: some View {
        WelcomeScreen(
            onLogin: onLogin,
            onRegister: onRegister
        )
        .navigationBarHidden(true)
    }
}

// MARK: - Welcome Screen (Main Container)

struct WelcomeScreen: View {
    let onLogin: () -> Void
    let onRegister: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            welcomeBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    TopCardsView()
                    TransactionPreviewCard()
                    CategoryIconsRow()
                    WelcomeTextSection()
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Spacing.x3)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }

            AuthButtonsView(onLogin: onLogin, onRegister: onRegister)
                .padding(.horizontal, Spacing.x3)
                .padding(.bottom, 36)
        }
        .ignoresSafeArea()
    }

    private var welcomeBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.78, blue: 1),
                Color(red: 0.25, green: 0.55, blue: 0.95),
                IOSPalette.flowlyBlue
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Top Cards (Savings + Goal)

struct TopCardsView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SavingsCard()
            GoalCard()
        }
    }
}

private struct SavingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Вы сэкономили")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.85))
            Text("350 ₸")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            miniGraphLine
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        )
        .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0))
    }

    private var miniGraphLine: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.15))
                .frame(height: 4)
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height - 2))
                path.addLine(to: CGPoint(x: 10, y: size.height - 6))
                path.addLine(to: CGPoint(x: 22, y: size.height - 4))
                path.addLine(to: CGPoint(x: 34, y: size.height - 8))
                path.addLine(to: CGPoint(x: size.width, y: 2))
                context.stroke(path, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 48, height: 14)
        }
    }
}

private struct GoalCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Дом")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("420 ₸ / 500 ₸")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))
            ProgressView(value: 0.84)
                .tint(.white)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        )
        .rotation3DEffect(.degrees(4), axis: (x: 0, y: 1, z: 0))
    }
}

// MARK: - Transaction Preview Card

struct TransactionPreviewCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: "engine.combustion.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Мотор EJ253")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("200 000 тенге")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            Spacer()
            Text("200 000 ₸")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Category Icons Row

struct CategoryIconsRow: View {
    private let categories: [(icon: String, color: Color)] = [
        ("airplane", IOSPalette.travelBlue),
        ("house.fill", IOSPalette.houseOrange),
        ("bag.fill", IOSPalette.shoppingPink),
        ("fork.knife", IOSPalette.healthGreen),
        ("film.fill", Color(red: 0.95, green: 0.9, blue: 1))
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(categories.enumerated()), id: \.offset) { _, item in
                ZStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(IOSPalette.flowlyBlue)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Welcome Text Section

struct WelcomeTextSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("Добро пожаловать в ")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("AutoCore")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.97, blue: 1))
            }
            Text("Контролируйте финансы компании в реальном времени.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Auth Buttons

struct AuthButtonsView: View {
    let onLogin: () -> Void
    let onRegister: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onRegister) {
                Text("Регистрация")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSWelcomeAnimatedPrimaryStyle())

            Button(action: onLogin) {
                Text("Войти")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSWelcomeAnimatedSecondaryStyle())
        }
    }
}

/// Primary button with press animation for welcome screen
struct IOSWelcomeAnimatedPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.accentGradient)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary button with press animation for welcome screen
struct IOSWelcomeAnimatedSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct IOSWelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(IOSPalette.flowlyBlue)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.flowlyBlue.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(IOSMotion.standard, value: configuration.isPressed)
    }
}

// MARK: - Login Error Banner

struct LoginErrorBanner: View {
    let message: String
    let canRetry: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 18))
                    .foregroundStyle(IOSPalette.negative)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(IOSPalette.negative.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(IOSPalette.negative.opacity(0.35), lineWidth: 1)
                    )
            )
            Text("Попробуйте: выключить VPN, сменить WiFi или мобильный интернет")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.75))
            HStack(spacing: 12) {
                if canRetry {
                    Button(action: onRetry) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Повторить")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(IOSPalette.flowlyBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                Link(destination: URL(string: "https://www.google.com")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Проверить подключение")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(IOSPalette.flowlyBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, Spacing.x3)
        .padding(.bottom, 16)
    }
}

// MARK: - Modern Fintech Login Screen

struct IOSLoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onBack: () -> Void
    var onSwitchToRegistration: (() -> Void)? = nil

    var body: some View {
        ZStack {
            IOSPalette.loginGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LoginHeader(title: "Вход", subtitle: "Бухгалтерский аккаунт", onBack: onBack)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    if let errorMessage = authViewModel.errorMessage {
                        LoginErrorBanner(
                            message: errorMessage,
                            canRetry: authViewModel.canRetry,
                            onRetry: { Task { await authViewModel.retryLastAction() } },
                            onDismiss: { authViewModel.clearError() }
                        )
                    }

                    LoginFormCard {
                        VStack(spacing: 24) {
                            AuthButtons(authViewModel: authViewModel)
                            LoginDivider()
                            EmailPasswordForm(authViewModel: authViewModel)
                        }
                        .padding(24)
                    }
                    .padding(.horizontal, Spacing.x3)
                    .padding(.bottom, 24)

                    if let onSwitch = onSwitchToRegistration {
                        Button(action: onSwitch) {
                            Text("Нет аккаунта? Регистрация")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - LoginHeader

struct LoginHeader: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.x3)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
        }
    }
}

// MARK: - LoginFormCard

struct LoginFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
            )
    }
}

// MARK: - AuthButtons

struct AuthButtons: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResult):
                        if let credential = authResult.credential as? ASAuthorizationAppleIDCredential {
                            Task { await authViewModel.handleAppleSignIn(credential: credential) }
                        }
                    case .failure(let error):
                        authViewModel.setError("Ошибка входа через Apple ID: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .cornerRadius(16)

            Button {
                Task { await authViewModel.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("Войти через Google")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(IOSLoginCardButtonStyle())
        }
    }
}

// MARK: - LoginDivider

struct LoginDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.35))
            Text("или по email")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.35))
        }
    }
}

// MARK: - EmailPasswordForm

struct EmailPasswordForm: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 20) {
            LoginTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )
            LoginTextField(
                icon: "lock.fill",
                placeholder: "Пароль",
                text: $password,
                isSecure: true
            )
            LoginButton(
                title: "Войти",
                action: { Task { await authViewModel.signIn(email: email, password: password) } },
                disabled: email.isEmpty || password.isEmpty
            )
        }
    }
}

// MARK: - LoginTextField

struct LoginTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var hasError: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 24, alignment: .center)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(hasError ? IOSPalette.negative : Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .foregroundStyle(.white)
    }
}

// MARK: - LoginButton

struct LoginButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.184, green: 0.502, blue: 0.929),
                                    Color(red: 0.11, green: 0.431, blue: 0.835)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 0.11, green: 0.43, blue: 0.84).opacity(0.5), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(IOSLoginCardButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}

// MARK: - IOSLoginCardButtonStyle

struct IOSLoginCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Modern Fintech Registration Screen

struct IOSRegistrationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onBack: () -> Void
    let onSwitchToLogin: () -> Void

    var body: some View {
        ZStack {
            IOSPalette.loginGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LoginHeader(title: "Регистрация", subtitle: "Создайте аккаунт", onBack: onBack)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    if let errorMessage = authViewModel.errorMessage {
                        LoginErrorBanner(
                            message: errorMessage,
                            canRetry: authViewModel.canRetry,
                            onRetry: { Task { await authViewModel.retryLastAction() } },
                            onDismiss: { authViewModel.clearError() }
                        )
                    }

                    LoginFormCard {
                        VStack(spacing: 24) {
                            AuthButtons(authViewModel: authViewModel)
                            LoginDivider()
                            RegistrationEmailForm(authViewModel: authViewModel)
                        }
                        .padding(24)
                    }
                    .padding(.horizontal, Spacing.x3)
                    .padding(.bottom, 24)

                    Button(action: onSwitchToLogin) {
                        Text("Уже есть аккаунт? Войти")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - RegistrationEmailForm

struct RegistrationEmailForm: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordMismatch: Bool = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 20) {
            LoginTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )
            LoginTextField(
                icon: "lock.fill",
                placeholder: "Пароль",
                text: $password,
                isSecure: true
            )
            LoginTextField(
                icon: "lock.fill",
                placeholder: "Повторите пароль",
                text: $confirmPassword,
                isSecure: true,
                hasError: passwordMismatch
            )
            .onChange(of: confirmPassword) { _, _ in
                passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
            }

            if passwordMismatch {
                Text("Пароли не совпадают")
                    .font(.footnote)
                    .foregroundStyle(IOSPalette.negative)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LoginButton(
                title: "Зарегистрироваться",
                action: {
                    passwordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                    guard canSubmit else { return }
                    Task { await authViewModel.signUp(email: email, password: password) }
                },
                disabled: !canSubmit
            )
        }
    }
}

// MARK: - Onboarding: создать компанию или присоединиться по invite

struct IOSOnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var companyViewModel: CompanyViewModel
    @StateObject private var inviteViewModel: InviteViewModel
    
    @State private var choice: IOSOnboardingChoice = .choose
    @State private var companyName = ""
    
    enum IOSOnboardingChoice {
        case choose
        case create
        case join
    }
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        _companyViewModel = StateObject(wrappedValue: CompanyViewModel(
            companyService: FirestoreCompanyService(),
            authViewModel: authViewModel
        ))
        _inviteViewModel = StateObject(wrappedValue: InviteViewModel(
            membershipService: FirestoreCompanyMembershipService(inviteService: FirestoreInviteService()),
            authViewModel: authViewModel
        ))
    }
    
    var body: some View {
        ZStack {
            IOSScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    IOSFlowlyHeader(title: "Добро пожаловать", subtitle: "Создайте компанию или присоединитесь по коду")

                    VStack(alignment: .leading, spacing: Spacing.x3) {
                        switch choice {
                        case .choose:
                            IOSFlowlyCard {
                                VStack(spacing: 12) {
                                    Button {
                                        choice = .create
                                    } label: {
                                        HStack {
                                            Image(systemName: "building.2")
                                            Text("Создать компанию")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(IOSPrimaryButtonStyle())

                                    Button {
                                        choice = .join
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.badge.key")
                                            Text("У меня есть код приглашения")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(IOSOutlinedBlueButtonStyle())
                                }
                            }

                        case .create:
                            createCompanyForm

                        case .join:
                            joinCompanyForm
                        }
                    }
                    .padding(Spacing.x3)
                }
            }
        }
    }
    
    private var createCompanyForm: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Button {
                    choice = .choose
                    companyName = ""
                    companyViewModel.errorMessage = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                    .foregroundStyle(IOSPalette.flowlyBlue)
                }

                Text("Название компании")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)

                TextField("Введите название", text: $companyName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)

                if let error = companyViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(IOSPalette.negative)
                }

                Button {
                    Task {
                        await companyViewModel.createCompany(name: companyName.trimmingCharacters(in: .whitespacesAndNewlines))
                        if companyViewModel.errorMessage == nil {
                            await authViewModel.refreshCurrentUser()
                        }
                    }
                } label: {
                    Text("Создать")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IOSPrimaryButtonStyle())
                .disabled(companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, Spacing.x3)
    }
    
    private var joinCompanyForm: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Button {
                choice = .choose
                inviteViewModel.code = ""
                inviteViewModel.errorMessage = nil
                inviteViewModel.successMessage = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Назад")
                }
                .foregroundStyle(IOSPalette.flowlyBlue)
            }
            .padding(.horizontal, Spacing.x3)

            IOSFlowlyCard {
                VStack(spacing: Spacing.x3) {
                    ZStack {
                        Circle()
                            .fill(IOSPalette.flowlyBlue.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(IOSPalette.flowlyBlue)
                    }

                    Text("Присоединиться к компании")
                        .font(IOSDesign.Typography.subtitle.weight(.semibold))
                        .foregroundStyle(IOSPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Введите код приглашения, который вам передал владелец или администратор компании")
                        .font(.footnote)
                        .foregroundStyle(IOSPalette.textSecondary)
                        .multilineTextAlignment(.center)

                    TextField("Например: ABC123", text: $inviteViewModel.code)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(IOSPalette.backgroundElevated)
                        .cornerRadius(IOSDesign.Radius.button)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .disabled(inviteViewModel.isLoading)

                    if let error = inviteViewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.footnote)
                        }
                        .foregroundStyle(IOSPalette.negative)
                    }

                    if let success = inviteViewModel.successMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text(success)
                                .font(.footnote)
                        }
                        .foregroundStyle(IOSPalette.positive)
                    }

                    Button {
                        Task { await inviteViewModel.joinCompanyWithCode(code: inviteViewModel.code) }
                    } label: {
                        HStack {
                            if inviteViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Присоединиться")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IOSPrimaryButtonStyle())
                    .disabled(inviteViewModel.code.trimmingCharacters(in: .whitespaces).isEmpty || inviteViewModel.isLoading)
                }
            }
            .padding(.horizontal, Spacing.x3)

            if inviteViewModel.successMessage != nil {
                Button("Продолжить") {
                    Task {
                        await authViewModel.refreshCurrentUser()
                    }
                }
                .buttonStyle(IOSPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.x3)
            }
        }
    }
}

#endif

