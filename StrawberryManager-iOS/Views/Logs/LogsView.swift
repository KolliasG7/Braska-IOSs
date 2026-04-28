// LogsView.swift
// Journalctl log viewer - ported from Flutter logs_screen.dart

import SwiftUI

struct LogsView: View {
    @StateObject private var viewModel: LogsViewModel
    @Environment(\.dismiss) var dismiss

    init(apiService: APIService) {
        _viewModel = StateObject(wrappedValue: LogsViewModel(apiService: apiService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Log content
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    Spacer()
                    ProgressView().tint(AppColors.accent)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.entries.isEmpty {
                    emptyView
                } else {
                    logContent
                }
            }
            .navigationTitle("System Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.loadLogs()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: AppSpacing.sm) {
            // Line count chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    Text("Lines:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textDim)

                    ForEach(LogsViewModel.lineOptions, id: \.self) { count in
                        filterChip(
                            label: "\(count)",
                            selected: viewModel.lineCount == count
                        ) {
                            viewModel.setLineCount(count)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            // Priority chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    Text("Priority:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textDim)

                    ForEach(LogsViewModel.priorityOptions, id: \.label) { option in
                        filterChip(
                            label: option.label,
                            selected: viewModel.priority == option.value
                        ) {
                            viewModel.setPriority(option.value)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface1)
    }

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? AppColors.accent : AppColors.textDim)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    selected ? AppColors.accent.opacity(0.15) : AppColors.glassSubtle,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(selected ? AppColors.accent.opacity(0.3) : AppColors.glassBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(viewModel.entries.indices, id: \.self) { i in
                    Text(viewModel.entries[i])
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(logColor(for: viewModel.entries[i]))
                        .textSelection(.enabled)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 2)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.surface0)
        .refreshable {
            viewModel.loadLogs()
        }
    }

    private func logColor(for line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("err") || lower.contains("fatal") {
            return AppColors.danger
        }
        if lower.contains("warn") {
            return AppColors.warn
        }
        if lower.contains("debug") {
            return AppColors.textDim
        }
        return AppColors.textPri
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.danger)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSec)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textDim)
            Text("No log entries found")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSec)
            Spacer()
        }
    }
}
