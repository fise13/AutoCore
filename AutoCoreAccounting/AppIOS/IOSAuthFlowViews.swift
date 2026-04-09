import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

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
        WelcomeScreen(onLogin: onLogin, onRegister: onRegister)
            .navigationBarHidden(true)
    }
}

// MARK: - Welcome Theme Helpers

private enum WelcomeTheme {
    static func fg(_ cs: ColorScheme) -> Color {
        cs == .dark ? .white : IOSPalette.textPrimary
    }
    static func fgSecondary(_ cs: ColorScheme) -> Color {
        cs == .dark ? .white.opacity(0.65) : IOSPalette.textSecondary
    }
    static func fgTertiary(_ cs: ColorScheme) -> Color {
        cs == .dark ? .white.opacity(0.4) : IOSPalette.textTertiary
    }
    static func cardFill(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    static func cardBorder(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    static func ringStroke(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)
    }
    static func pillFill(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }
    static func indicatorActive(_ cs: ColorScheme) -> Color {
        cs == .dark ? .white : IOSPalette.flowlyBlue
    }
    static func indicatorInactive(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.15)
    }
}

// MARK: - Welcome Screen (Full Showcase)

struct WelcomeScreen: View {
    let onLogin: () -> Void
    let onRegister: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0
    @State private var appeared = false

    private let pageCount = 4

    var body: some View {
        ZStack {
            welcomeBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomeHeroPage().tag(0)
                    WelcomeDashboardPage().tag(1)
                    WelcomeTeamPage().tag(2)
                    WelcomeSmartToolsPage().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)

                bottomSection
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    // MARK: Background

    private var welcomeBackground: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.16),
                        Color(red: 0.06, green: 0.12, blue: 0.24),
                        Color(red: 0.03, green: 0.06, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.97, blue: 1.0),
                        Color(red: 0.93, green: 0.95, blue: 0.99),
                        Color(red: 0.95, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Circle()
                .fill(IOSPalette.flowlyBlue.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(red: 0.4, green: 0.2, blue: 0.8).opacity(colorScheme == .dark ? 0.06 : 0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 150, y: 300)
        }
    }

    // MARK: Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(currentPage == i
                              ? WelcomeTheme.indicatorActive(colorScheme)
                              : WelcomeTheme.indicatorInactive(colorScheme))
                        .frame(width: currentPage == i ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                }
            }

            VStack(spacing: 12) {
                Button {
                    IOSHaptics.impact(.medium)
                    onRegister()
                } label: {
                    Text("Начать бесплатно")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IOSWelcomeAnimatedPrimaryStyle())

                Button {
                    IOSHaptics.impact(.light)
                    onLogin()
                } label: {
                    Text("У меня есть аккаунт")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IOSWelcomeAnimatedSecondaryStyle())
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 36)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }
}

// MARK: - Page 1: Hero

private struct WelcomeHeroPage: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(WelcomeTheme.ringStroke(colorScheme), lineWidth: 1)
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)
                Circle()
                    .stroke(WelcomeTheme.ringStroke(colorScheme).opacity(0.6), lineWidth: 1)
                    .frame(width: 190, height: 190)
                    .scaleEffect(pulseScale + 0.02)

                Circle()
                    .fill(IOSPalette.flowlyBlue.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .blur(radius: 16)

                Image(systemName: "building.columns.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(colorScheme == .dark ? .white : IOSPalette.flowlyBlue)
                    .shadow(color: IOSPalette.flowlyBlue.opacity(0.3), radius: 16, x: 0, y: 6)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("AutoCore")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(WelcomeTheme.fg(colorScheme))
                Text("ACCOUNTING")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSPalette.flowlyBlue)
                    .tracking(5)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            Text("Полный контроль финансов\nвашего бизнеса")
                .font(.system(size: 14))
                .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulseScale = 1.06 }
        }
    }
}

// MARK: - Page 2: Dashboard Preview

private struct WelcomeDashboardPage: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    @State private var chartAnimated = false

    private let bars: [CGFloat] = [0.4, 0.65, 0.5, 0.85, 0.6, 0.75, 0.9]
    private let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text("Дашборд")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IOSPalette.flowlyBlue)
                Text("1 830 000 ₸")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WelcomeTheme.fg(colorScheme))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    pill("Касса 1.2M", IOSPalette.positive)
                    pill("Kaspi 630K", IOSPalette.flowlyBlue)
                }
                .padding(.top, 2)
            }
            .opacity(appeared ? 1 : 0)

            chartCard
                .opacity(appeared ? 1 : 0)

            txList
                .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appeared = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.4)) { chartAnimated = true }
        }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(WelcomeTheme.pillFill(colorScheme)))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Неделя")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WelcomeTheme.fgTertiary(colorScheme))
                Spacer()
                Text("+23%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(IOSPalette.positive)
            }
            GeometryReader { geo in
                let sp: CGFloat = 4
                let bw = (geo.size.width - sp * 6) / 7
                HStack(alignment: .bottom, spacing: sp) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(IOSPalette.flowlyBlue.opacity(0.85))
                                .frame(width: bw, height: chartAnimated ? geo.size.height * 0.7 * v : 2)
                            Text(days[i])
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(WelcomeTheme.fgTertiary(colorScheme))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 60)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WelcomeTheme.cardFill(colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(WelcomeTheme.cardBorder(colorScheme), lineWidth: 1))
        )
    }

    private var txList: some View {
        VStack(spacing: 0) {
            txRow("arrow.up.right", "Продажа мотора", "+200 000", IOSPalette.positive)
            Divider().overlay(WelcomeTheme.cardBorder(colorScheme))
            txRow("minus", "Закупка запчастей", "-45 000", IOSPalette.negative)
            Divider().overlay(WelcomeTheme.cardBorder(colorScheme))
            txRow("plus", "Внесение средств", "+80 000", IOSPalette.positive)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WelcomeTheme.cardFill(colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(WelcomeTheme.cardBorder(colorScheme), lineWidth: 1))
        )
    }

    private func txRow(_ icon: String, _ title: String, _ amount: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 24, height: 24)
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(amount)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Page 3: Team & Roles

private struct WelcomeTeamPage: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    private let icons = ["person.fill", "chart.pie.fill", "doc.text.fill", "gearshape.fill"]

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let angle = Double(i) * 90
                    let r: CGFloat = 50
                    Circle()
                        .fill(WelcomeTheme.cardFill(colorScheme))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: icons[i]).font(.system(size: 14)).foregroundStyle(WelcomeTheme.fgSecondary(colorScheme)))
                        .offset(
                            x: appeared ? cos(angle * .pi / 180) * Double(r) : 0,
                            y: appeared ? sin(angle * .pi / 180) * Double(r) : 0
                        )
                        .opacity(appeared ? 1 : 0)
                }
                ZStack {
                    Circle().fill(IOSPalette.flowlyBlue.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(colorScheme == .dark ? .white : IOSPalette.flowlyBlue)
                }
            }
            .frame(height: 130)

            VStack(spacing: 6) {
                Text("Команда и роли")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WelcomeTheme.fg(colorScheme))
                Text("Каждая роль — свои права доступа")
                    .font(.system(size: 13))
                    .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
            }
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 4) {
                featureRow("person.badge.key.fill", "Invite-коды для сотрудников")
                featureRow("lock.shield.fill", "Разграничение прав доступа")
                featureRow("eye.fill", "Аудит: кто что изменил")
                featureRow("icloud.and.arrow.up.fill", "Синхронизация в реальном времени")
            }
            .padding(.top, 4)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(IOSPalette.flowlyBlue)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
            Spacer()
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Page 4: Smart Tools

private struct WelcomeSmartToolsPage: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private let tools: [(icon: String, title: String, sub: String, color: Color)] = [
        ("doc.viewfinder", "Скан", "Камера → черновик", Color(red: 0.4, green: 0.7, blue: 1)),
        ("chart.bar.xaxis", "Аналитика", "Расходы и доходы", Color(red: 0.3, green: 0.85, blue: 0.5)),
        ("square.grid.2x2.fill", "Виджеты", "Баланс на экране", Color(red: 1, green: 0.65, blue: 0.3)),
        ("bell.badge.fill", "Пуши", "Ничего не пропустите", Color(red: 0.9, green: 0.4, blue: 0.5)),
        ("iphone.gen3", "Офлайн", "Работает без сети", Color(red: 0.6, green: 0.5, blue: 0.9)),
        ("shield.checkered", "Защита", "Данные зашифрованы", Color(red: 0.4, green: 0.8, blue: 0.8))
    ]

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            VStack(spacing: 5) {
                Text("Инструменты")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WelcomeTheme.fg(colorScheme))
                Text("Всё для бизнеса в одном приложении")
                    .font(.system(size: 13))
                    .foregroundStyle(WelcomeTheme.fgSecondary(colorScheme))
            }
            .opacity(appeared ? 1 : 0)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(tools.enumerated()), id: \.offset) { i, t in
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(t.color.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: t.icon).font(.system(size: 13, weight: .medium)).foregroundStyle(t.color)
                        }
                        Text(t.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WelcomeTheme.fg(colorScheme).opacity(0.85))
                        Text(t.sub)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(WelcomeTheme.fgTertiary(colorScheme))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(WelcomeTheme.cardFill(colorScheme))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(WelcomeTheme.cardBorder(colorScheme), lineWidth: 1))
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : CGFloat(10 + i * 2))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.06), value: appeared)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }
}

// MARK: - Auth Buttons

struct AuthButtonsView: View {
    let onLogin: () -> Void
    let onRegister: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onRegister) {
                Text("Начать бесплатно")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSWelcomeAnimatedPrimaryStyle())

            Button(action: onLogin) {
                Text("У меня есть аккаунт")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IOSWelcomeAnimatedSecondaryStyle())
        }
    }
}

struct IOSWelcomeAnimatedPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [IOSPalette.flowlyBlue, IOSPalette.flowlyBlueDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: IOSPalette.flowlyBlue.opacity(0.35), radius: 16, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct IOSWelcomeAnimatedSecondaryStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.85) : IOSPalette.flowlyBlue)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : IOSPalette.flowlyBlue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : IOSPalette.flowlyBlue.opacity(0.25), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
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
    @State private var currentNonce = ""

    var body: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.nonce = sha256(nonce)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResult):
                        if let credential = authResult.credential as? ASAuthorizationAppleIDCredential {
                            let nonce = currentNonce
                            Task { await authViewModel.handleAppleSignIn(credential: credential, rawNonce: nonce) }
                        }
                    case .failure(let error):
                        authViewModel.setAppleSignInError(error)
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
                    GoogleLogoView(size: 20)
                    Text("Войти через Google")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(IOSLoginCardButtonStyle())
        }
    }
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

// MARK: - LoginDivider

// MARK: - Google Logo

struct GoogleLogoView: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: size, height: size)
            Canvas { ctx, canvasSize in
                let r = min(canvasSize.width, canvasSize.height) / 2
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let lineW = r * 0.38

                let blue = Color(red: 66/255, green: 133/255, blue: 244/255)
                let red = Color(red: 234/255, green: 67/255, blue: 53/255)
                let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
                let green = Color(red: 52/255, green: 168/255, blue: 83/255)

                func arc(_ start: Angle, _ end: Angle, _ color: Color) {
                    var path = Path()
                    path.addArc(center: center, radius: r * 0.65, startAngle: start, endAngle: end, clockwise: false)
                    ctx.stroke(path, with: .color(color), lineWidth: lineW)
                }

                arc(.degrees(-45), .degrees(45), red)
                arc(.degrees(45), .degrees(135), yellow)
                arc(.degrees(135), .degrees(225), green)
                arc(.degrees(225), .degrees(315), blue)

                let bar = Path(CGRect(x: center.x - r * 0.05, y: center.y - lineW / 2, width: r * 0.55, height: lineW))
                ctx.fill(bar, with: .color(blue))
            }
            .frame(width: size, height: size)
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
            membershipService: FirestoreFunctionsCompanyMembershipService(),
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

