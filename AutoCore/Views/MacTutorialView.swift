import SwiftUI

#if os(macOS)

struct MacTutorialStep: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct MacTutorialView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0

    private let steps: [MacTutorialStep] = [
        MacTutorialStep(
            id: 0,
            icon: "sparkles",
            iconColor: .blue,
            title: "Добро пожаловать в AutoCore",
            description: "Это короткое обучение по ключевым функциям macOS-версии."
        ),
        MacTutorialStep(
            id: 1,
            icon: "tablecells",
            iconColor: .indigo,
            title: "Excel-таблица моторов",
            description: "Редактируйте данные прямо в таблице. Изменения сохраняются по Cmd+S, а статус виден внизу экрана."
        ),
        MacTutorialStep(
            id: 2,
            icon: "folder.fill",
            iconColor: .orange,
            title: "Специфичные папки",
            description: "Используйте папки как локации/секции. Записи можно переносить между папками через поле \"Лист\"."
        ),
        MacTutorialStep(
            id: 3,
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: "Продажи и бухгалтерия",
            description: "Помечайте мотор как проданный, следите за операциями и удаляйте ненужные записи в соответствующих разделах."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Обучение")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Пропустить") {
                    onComplete()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            tutorialCard(step: steps[currentStep])
                .id(currentStep)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.easeInOut(duration: 0.2), value: currentStep)

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 16)

            HStack {
                Button("Назад") {
                    if currentStep > 0 { currentStep -= 1 }
                }
                .disabled(currentStep == 0)

                Spacer()

                Button(currentStep == steps.count - 1 ? "Начать работу" : "Далее") {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 560, height: 360)
    }

    private func tutorialCard(step: MacTutorialStep) -> some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 104, height: 104)
                Image(systemName: step.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(step.iconColor)
            }

            Text(step.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 470)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#endif
