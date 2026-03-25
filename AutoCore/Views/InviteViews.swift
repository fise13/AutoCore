//
//  InviteViews.swift
//  AutoCore
//

import SwiftUI

struct JoinCompanyView: View {
    @StateObject var viewModel: InviteViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Присоединиться к компании")
                .font(.title3.weight(.semibold))
            
            TextField("Код приглашения", text: $viewModel.code)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .disabled(viewModel.isLoading)
                .frame(maxWidth: 260)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if let success = viewModel.successMessage {
                Text(success)
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Button {
                Task { await viewModel.joinCompanyWithCode(code: viewModel.code) }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Присоединиться")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.code.isEmpty || viewModel.isLoading)
            .frame(maxWidth: 260)
        }
        .padding()
#if os(macOS)
        .frame(minWidth: 320)
#endif
    }
}

