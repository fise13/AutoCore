//
//  IOSTutorialView.swift
//  AutoCoreAccounting
//
//  Обучение для новых пользователей: пошаговый тур по приложению с анимациями.
//

import SwiftUI

#if os(iOS)
import UIKit

private let tutorialCompletedKey = "AutoCoreAccounting.tutorialCompleted"

enum TutorialStore {
    static var hasCompletedTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialCompletedKey) }
    }
}

struct IOSTutorialStep: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct IOSTutorialView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var iconBreath: CGFloat = 1

    private let steps: [IOSTutorialStep] = [
        IOSTutorialStep(
            id: 0,
            icon: "hand.wave.fill",
            iconColor: IOSPalette.flowlyBlue,
            title: "Добро пожаловать!",
            description: "AutoCore Accounting — ваш помощник в учёте финансов. Давайте за пару минут узнаем, как устроено приложение."
        ),
        IOSTutorialStep(
            id: 1,
            icon: "chart.pie.fill",
            iconColor: IOSPalette.houseOrange,
            title: "Главная",
            description: "Здесь вы видите денежную позицию: баланс Кассы и Kaspi, график операций за неделю и последние транзакции. Потяните вниз для обновления."
        ),
        IOSTutorialStep(
            id: 2,
            icon: "chart.bar.fill",
            iconColor: IOSPalette.travelBlue,
            title: "Операции",
            description: "Полный список продаж, приходов, расходов и возвратов. Фильтруйте по типу и просматривайте детали каждой операции."
        ),
        IOSTutorialStep(
            id: 3,
            icon: "person.2.fill",
            iconColor: IOSPalette.positive,
            title: "Ещё",
            description: "Создайте код приглашения для сотрудников, настройте профиль, просмотрите участников компании и управляйте настройками."
        ),
        IOSTutorialStep(
            id: 4,
            icon: "checkmark.circle.fill",
            iconColor: IOSPalette.positive,
            title: "Всё готово!",
            description: "Данные синхронизируются автоматически и доступны офлайн. Удачи в работе с AutoCore!"
        )
    ]

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                skipButton

                TabView(selection: $currentStep) {
                    ForEach(steps) { step in
                        stepCard(step)
                            .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(IOSMotion.standard, value: currentStep)

                progressDots
                actionButton
            }
        }
        .onChange(of: currentStep) { _, _ in
            animateStepAppearance()
        }
        .onAppear {
            animateStepAppearance()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                IOSPalette.flowlyBlue.opacity(0.4),
                IOSPalette.backgroundBase,
                IOSPalette.backgroundBase
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("Пропустить") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                completeTutorial()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(IOSPalette.textSecondary)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 56)
            .padding(.bottom, 8)
        }
    }

    private func stepCard(_ step: IOSTutorialStep) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .scaleEffect(iconBreath)
                Circle()
                    .fill(step.iconColor.opacity(0.25))
                    .frame(width: 110, height: 110)
                Image(systemName: step.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(step.iconColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
            .frame(height: 160)

            VStack(spacing: 12) {
                Text(step.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(IOSPalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)

                Text(step.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(IOSPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.x3)
                    .opacity(textOpacity)
            }

            Spacer()
            Spacer()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 10) {
            ForEach(steps.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? IOSPalette.flowlyBlue : IOSPalette.textSecondary.opacity(0.3))
                    .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                    .animation(IOSMotion.standard, value: currentStep)
            }
        }
        .padding(.bottom, 24)
    }

    private var actionButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if currentStep < steps.count - 1 {
                withAnimation(IOSMotion.emphasis) {
                    currentStep += 1
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                completeTutorial()
            }
        } label: {
            HStack {
                Text(currentStep < steps.count - 1 ? "Далее" : "Начать")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                if currentStep < steps.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(IOSPrimaryButtonStyle())
        .padding(.horizontal, Spacing.x3)
        .padding(.bottom, 50)
    }

    private func animateStepAppearance() {
        iconScale = 0.5
        iconOpacity = 0
        textOpacity = 0
        iconBreath = 0.95

        withAnimation(IOSMotion.appear) {
            iconScale = 1
            iconOpacity = 1
            textOpacity = 1
        }

        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            iconBreath = 1.08
        }
    }

    private func completeTutorial() {
        TutorialStore.hasCompletedTutorial = true
        withAnimation(IOSMotion.emphasis) {
            onComplete()
        }
    }
}

struct IOSTutorialOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                IOSTutorialView(onComplete: { isPresented = false })
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(100)
            }
        }
        .animation(IOSMotion.emphasis, value: isPresented)
    }
}

extension View {
    func iosTutorialOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(IOSTutorialOverlayModifier(isPresented: isPresented))
    }
}

#endif
