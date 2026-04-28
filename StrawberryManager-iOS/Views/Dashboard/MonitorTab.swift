// MonitorTab.swift
// Real-time telemetry monitoring with glass cards and arc gauges

import SwiftUI

struct MonitorTab: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // System overview gauges
                if let frame = viewModel.telemetryFrame {
                    systemOverview(frame)
                }

                // CPU Card
                if let cpu = viewModel.telemetryFrame?.cpu {
                    cpuCard(cpu)
                }

                // RAM Card
                if let ram = viewModel.telemetryFrame?.ram {
                    ramCard(ram)
                }

                // Thermal Card
                if let fan = viewModel.telemetryFrame?.fan {
                    thermalCard(fan)
                }

                // Disk + Network row
                if let frame = viewModel.telemetryFrame {
                    HStack(spacing: AppSpacing.lg) {
                        if let disk = frame.disk.first {
                            diskCard(disk)
                        }
                        if let net = frame.primaryNet {
                            networkCard(net)
                        }
                    }
                }

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.sm)
        }
    }

    // MARK: - System Overview

    private func systemOverview(_ frame: TelemetryFrame) -> some View {
        GlassCardView(style: .subtle) {
            HStack(spacing: AppSpacing.lg) {
                if let cpu = frame.cpu {
                    ArcGauge(
                        value: cpu.percent / 100,
                        color: Color.percentColor(cpu.percent),
                        label: "\(Int(cpu.percent))%",
                        sub: "CPU"
                    )
                }
                if let ram = frame.ram {
                    ArcGauge(
                        value: ram.percent / 100,
                        color: Color.percentColor(ram.percent),
                        label: "\(Int(ram.percent))%",
                        sub: "RAM"
                    )
                }
                if let fan = frame.fan {
                    ArcGauge(
                        value: min(fan.apuTempC / 100, 1),
                        color: Color.temperatureColor(for: fan.apuTempC),
                        label: "\(Int(fan.apuTempC))",
                        sub: "TEMP"
                    )
                }
                if let disk = frame.disk.first {
                    ArcGauge(
                        value: disk.percent / 100,
                        color: AppColors.green,
                        label: "\(Int(disk.percent))%",
                        sub: "DISK"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - CPU Card

    private func cpuCard(_ cpu: CPUData) -> some View {
        GlassCardView(tint: AppColors.glassTintCyan) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    StatLabel("PROCESSOR")
                    Spacer()
                    Text("\(Int(cpu.freqMhz)) MHz")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(AppColors.textDim)
                }

                // History graph
                if !viewModel.cpuHistory.isEmpty {
                    TelemetryGraph(
                        data: viewModel.cpuHistory,
                        color: AppColors.cyan,
                        maxValue: 100
                    )
                    .frame(height: 60)
                }

                // Per-core pills
                if !cpu.perCore.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(cpu.perCore.indices, id: \.self) { i in
                            corePill(index: i, usage: cpu.perCore[i])
                        }
                    }
                }

                Divider().overlay(AppColors.border)

                MetricRow(label: "Cores", value: "\(cpu.coreCount)")
                MetricRow(label: "Frequency", value: String(format: "%.1f GHz", cpu.freqMhz / 1000))
                MetricRow(label: "Load (1m)", value: String(format: "%.2f", cpu.load1))
            }
        }
    }

    private func corePill(index: Int, usage: Double) -> some View {
        HStack(spacing: 4) {
            Text("C\(index)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textDim)
            Text("\(Int(usage))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.percentColor(usage))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.glassSubtle, in: Capsule())
        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 0.5))
    }

    // MARK: - RAM Card

    private func ramCard(_ ram: RAMData) -> some View {
        GlassCardView(tint: AppColors.glassTintViolet) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                StatLabel("MEMORY")

                if !viewModel.ramHistory.isEmpty {
                    TelemetryGraph(
                        data: viewModel.ramHistory,
                        color: AppColors.violet,
                        maxValue: 100
                    )
                    .frame(height: 60)
                }

                Divider().overlay(AppColors.border)

                MetricRow(label: "Total", value: String(format: "%.0f MB", ram.totalMb))
                MetricRow(label: "Used", value: String(format: "%.0f MB", ram.usedMb))
                MetricRow(label: "Cached", value: String(format: "%.0f MB", ram.cachedMb))
            }
        }
    }

    // MARK: - Thermal Card

    private func thermalCard(_ fan: FanData) -> some View {
        let tempColor = Color.temperatureColor(for: fan.apuTempC)

        return GlassCardView(tint: AppColors.glassTintAmber) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                StatLabel("THERMAL")

                if !viewModel.tempHistory.isEmpty {
                    TelemetryGraph(
                        data: viewModel.tempHistory,
                        color: tempColor,
                        maxValue: 100
                    )
                    .frame(height: 60)
                }

                Divider().overlay(AppColors.border)

                MetricRow(label: "APU Temperature", value: String(format: "%.0fC", fan.apuTempC), color: tempColor)
                MetricRow(label: "Fan Speed", value: fan.rpm == 0 ? "Off" : "\(fan.rpm) RPM")
                MetricRow(label: "Fan Threshold", value: "\(fan.thresholdC)C")
            }
        }
    }

    // MARK: - Disk Card

    private func diskCard(_ disk: DiskData) -> some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                StatLabel("DISK")
                MetricRow(label: "Used", value: String(format: "%.1f/%.1f GB", disk.usedGb, disk.totalGb))
                MetricRow(label: "Usage", value: String(format: "%.0f%%", disk.percent))
            }
        }
    }

    // MARK: - Network Card

    private func networkCard(_ net: NetData) -> some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                StatLabel("NETWORK")
                MetricRow(label: "Download", value: formatBytes(net.bytesRecvS))
                MetricRow(label: "Upload", value: formatBytes(net.bytesSentS))
            }
        }
    }
}

func formatBytes(_ bps: Double) -> String {
    if bps < 1024 { return "\(Int(bps)) B/s" }
    if bps < 1048576 { return String(format: "%.1f KB/s", bps / 1024) }
    return String(format: "%.1f MB/s", bps / 1048576)
}
