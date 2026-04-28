// TerminalView.swift
// Real PTY terminal with keyboard accessory bar

import SwiftUI

struct TerminalView: View {
    let baseURL: URL
    let token: String

    @StateObject private var terminalService: TerminalWebSocketService
    @State private var inputText = ""
    @State private var lines: [String] = []
    @State private var partial = ""
    @FocusState private var inputFocused: Bool

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
        _terminalService = StateObject(wrappedValue: TerminalWebSocketService(baseURL: baseURL, token: token))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines.indices, id: \.self) { i in
                            Text(lines[i])
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(AppColors.textPri)
                                .textSelection(.enabled)
                                .id(i)
                        }

                        if !partial.isEmpty {
                            Text(partial)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(AppColors.textPri)
                                .id("partial")
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                .background(AppColors.surface0)
                .onChange(of: lines.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        proxy.scrollTo(lines.count - 1, anchor: .bottom)
                    }
                }
            }

            // Keyboard accessory bar
            accessoryBar

            // Input bar
            inputBar
        }
        .onAppear {
            terminalService.connect()
            terminalService.onOutput = handleOutput
        }
        .onDisappear {
            terminalService.disconnect()
        }
    }

    // MARK: - Keyboard Accessory

    private var accessoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                accessoryKey("Ctrl", send: nil, isModifier: true)
                accessoryKey("Tab", send: "\t")
                accessoryKey("Esc", send: "\u{1B}")
                accessoryKey("Up", send: "\u{1B}[A")
                accessoryKey("Down", send: "\u{1B}[B")
                accessoryKey("Left", send: "\u{1B}[D")
                accessoryKey("Right", send: "\u{1B}[C")
                accessoryKey("Clear", send: nil, action: clearTerminal)
                accessoryKey("Reconn", send: nil, action: {
                    terminalService.disconnect()
                    terminalService.connect()
                })
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(AppColors.surface1)
    }

    private func accessoryKey(_ label: String, send: String? = nil, isModifier: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let action = action {
                action()
            } else if let send = send {
                terminalService.sendInput(send)
            }
            if !inputFocused { inputFocused = true }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.textSec)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.glassSubtle, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("$")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.accent)

            TextField("", text: $inputText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppColors.textPri)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($inputFocused)
                .onSubmit { sendLine() }

            Button {
                sendLine()
            } label: {
                Image(systemName: "return")
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface1)
    }

    // MARK: - Logic

    private func sendLine() {
        let text = inputText
        inputText = ""
        if text.isEmpty {
            terminalService.sendInput("\n")
        } else {
            terminalService.sendInput("\(text)\n")
        }
    }

    private func clearTerminal() {
        lines.removeAll()
        partial = ""
    }

    private func handleOutput(_ text: String) {
        // Strip ANSI escape sequences
        let clean = text
            .replacingOccurrences(of: "\\x1B\\][^\\x07]*\\x07", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\x1B\\][^\\x1B]*\\x1B\\\\", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\x1B\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        DispatchQueue.main.async {
            partial += clean
            let parts = partial.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            partial = parts.last ?? ""
            for i in 0..<(parts.count - 1) {
                if !parts[i].isEmpty || !lines.isEmpty {
                    lines.append(parts[i])
                }
            }
            if lines.count > 1000 {
                lines.removeFirst(lines.count - 1000)
            }
        }
    }
}
