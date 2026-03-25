import SwiftUI

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onDismiss: () -> Void
    
    @State private var displayName: String = ""
    @FocusState private var focusedField: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Профиль")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    if let user = authViewModel.currentUser {
                        if !user.email.isEmpty {
                            Group {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(user.email)
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Group {
                            Text("Роль")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(user.role.localizedDisplayName)
                                .foregroundStyle(.primary)
                        }
                        
                        Group {
                            Text("Имя")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Имя", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField)
                        }
                        
                        Button("Сохранить") {
                            Task {
                                await authViewModel.updateProfile(displayName: displayName.isEmpty ? nil : displayName)
                                if authViewModel.errorMessage == nil {
                                    onDismiss()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(displayName == (user.displayName ?? ""))
                    }
                    
                    if let msg = authViewModel.errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 360, minHeight: 280)
        .onAppear {
            displayName = authViewModel.currentUser?.displayName ?? ""
        }
    }
}
