//
//  FinanceFormComponents.swift
//  AutoCore
//
//  Reusable components for premium expense/income forms: glass cards, hero input, pill selectors, chips, floating labels.
//  Dark-mode first, tactile, motion-aware.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private func triggerLightHaptic() {
    #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
}

private func triggerMediumHaptic() {
    #if os(iOS)
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    #endif
}

// MARK: - Fintech Panel Container (replaces glass; uses design system)

struct GlassCardContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        FintechPanel(cornerRadius: 20, edgeGlowOpacity: 0.2) {
            content
        }
    }
}

// MARK: - Hero Amount Input

struct HeroAmountInput<F: Hashable>: View {
    @Binding var amount: String
    var currencySymbol: String = "₸"
    @FocusState.Binding var focusedField: F?
    let focusValue: F
    
    private var isFocused: Bool { focusedField == focusValue }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("0", text: $amount)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .focused($focusedField, equals: focusValue)
                .foregroundStyle(isFocused ? Color.primary : Color.primary.opacity(0.9))
            
            Text(currencySymbol)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(FintechColors.steel)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isFocused ? FintechColors.backgroundHighlight.opacity(0.6) : FintechColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isFocused ? FintechColors.accent.opacity(0.5) : FintechColors.steel.opacity(0.2), lineWidth: isFocused ? 2 : 1)
                }
                .shadow(color: isFocused ? FintechShadows.glowAccent.opacity(0.2) : .clear, radius: 12)
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Pill Selector (generic)

struct PillSelector<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(value: T, label: String)]
    var onSelect: ((T) -> Void)?
    
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    let isSelected = selection == option.value
                    Button {
                        triggerLightHaptic()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selection = option.value
                            onSelect?(option.value)
                        }
                    } label: {
                        Text(option.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(PillButtonStyle(isSelected: isSelected))
                }
            }
        }
    }
}

private struct PillButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule()
                    .fill(isSelected ? LinearGradient(colors: [FintechColors.accent, FintechColors.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [FintechColors.backgroundHighlight], startPoint: .leading, endPoint: .trailing))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Tag Chip (selectable)

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            triggerLightHaptic()
            action()
        }) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(ChipButtonStyle(isSelected: isSelected))
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule()
                    .fill(isSelected ? FintechColors.accent : FintechColors.backgroundHighlight.opacity(0.6))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Floating Text Field

struct FloatingTextField<F: Hashable>: View {
    let label: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...4
    @FocusState.Binding var focusedField: F?
    let focusValue: F
    
    private var isFocused: Bool { focusedField == focusValue }
    private var isFloating: Bool { isFocused || !text.isEmpty }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .offset(y: isFloating ? -28 : 0)
                .scaleEffect(isFloating ? 0.85 : 1, anchor: .leading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFloating)
            
            TextField("", text: $text, axis: axis)
                .lineLimit(lineLimit)
                .font(.body)
                .focused($focusedField, equals: focusValue)
                .padding(.top, isFloating ? 12 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FintechColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isFocused ? FintechColors.accent.opacity(0.4) : FintechColors.steel.opacity(0.15), lineWidth: 1)
                }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Animated Confirm Button

struct AnimatedConfirmButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            triggerMediumHaptic()
            action()
        }) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(ConfirmButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct ConfirmButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isEnabled
                        ? LinearGradient(colors: [FintechColors.accent, FintechColors.accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [FintechColors.steel.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
