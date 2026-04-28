// ProcessesView.swift
// Process manager with glass design

import SwiftUI

struct ProcessesView: View {
    @ObservedObject var viewModel: ProcessesViewModel
    @State private var processToKill: ProcessInfo? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            headerBar

            // Process list
            if viewModel.isLoading && viewModel.processes.isEmpty {
                Spacer()
                ProgressView().tint(AppColors.accent)
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                processList
            }
        }
        .alert("Kill Process", isPresented: .init(
            get: { processToKill != nil },
            set: { if !$0 { processToKill = nil } }
        )) {
            Button("Cancel", role: .cancel) { processToKill = nil }
            Button("SIGTERM") {
                if let p = processToKill { viewModel.killProcess(p) }
                processToKill = nil
            }
            Button("SIGKILL", role: .destructive) {
                if let p = processToKill { viewModel.killProcess(p, signal: "SIGKILL") }
                processToKill = nil
            }
        } message: {
            Text("Kill \(processToKill?.name ?? "process") (PID \(processToKill?.pid ?? 0))?")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Sort picker
            Menu {
                ForEach(ProcessesViewModel.SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortBy = option
                        viewModel.loadProcesses()
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                GlassPill {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text(viewModel.sortBy.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent)
                }
            }

            Spacer()

            // Auto-refresh toggle
            Button {
                viewModel.toggleAutoRefresh()
            } label: {
                GlassPill {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.autoRefresh ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(viewModel.autoRefresh ? "Pause" : "Auto")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(viewModel.autoRefresh ? AppColors.success : AppColors.textDim)
                }
            }

            // Refresh
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.loadProcesses()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Process List

    private var processList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.processes) { process in
                    processRow(process)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
        }
        .refreshable {
            viewModel.loadProcesses()
        }
    }

    private func processRow(_ process: ProcessInfo) -> some View {
        Button {
            processToKill = process
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textPri)
                        .lineLimit(1)

                    Text("PID \(process.pid)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppColors.textDim)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("CPU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textDim)
                        Text(String(format: "%.1f%%", process.cpu))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.percentColor(process.cpu))
                    }

                    HStack(spacing: 4) {
                        Text("MEM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textDim)
                        Text(String(format: "%.1f%%", process.memory))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppColors.violet)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.glassSubtle, in: RoundedRectangle(cornerRadius: AppRadii.sm))
        }
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
            GlassActionButton(title: "Retry", icon: "arrow.clockwise") {
                viewModel.loadProcesses()
            }
            .frame(width: 150)
            Spacer()
        }
    }
}
