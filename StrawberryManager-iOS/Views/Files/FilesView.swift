// FilesView.swift
// Full file browser with upload, download, delete - ported from Flutter

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct FilesView: View {
    @ObservedObject var viewModel: FilesViewModel
    @State private var showingUpload = false
    @State private var fileToDelete: APIService.FileItem? = nil
    @State private var downloadCancellable: AnyCancellable? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Path breadcrumb
            pathBar

            // File list
            if viewModel.isLoading && viewModel.items.isEmpty {
                Spacer()
                ProgressView()
                    .tint(AppColors.accent)
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                fileList
            }
        }
        .fileImporter(isPresented: $showingUpload, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    viewModel.uploadFile(data: data, filename: url.lastPathComponent)
                }
            }
        }
        .alert("Delete File", isPresented: .init(
            get: { fileToDelete != nil },
            set: { if !$0 { fileToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { fileToDelete = nil }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    let path = viewModel.currentPath + "/" + file.name
                    viewModel.deleteFile(at: path)
                    fileToDelete = nil
                }
            }
        } message: {
            Text("Delete \(fileToDelete?.name ?? "this file")?")
        }
    }

    // MARK: - Path Bar

    private var pathBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.canGoBack ? AppColors.accent : AppColors.textDim)
            }
            .disabled(!viewModel.canGoBack)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(viewModel.currentPath)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppColors.textSec)
            }

            Spacer()

            if viewModel.isUploading {
                ProgressView().tint(AppColors.accent)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingUpload = true
                } label: {
                    Image(systemName: "arrow.up.doc")
                        .foregroundStyle(AppColors.accent)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.glassSubtle)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.items) { item in
                    fileRow(item)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private func fileRow(_ item: APIService.FileItem) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            if item.isDirectory {
                viewModel.navigate(to: viewModel.currentPath + "/" + item.name)
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: fileIcon(for: item))
                    .font(.system(size: 18))
                    .foregroundStyle(item.isDirectory ? AppColors.accent : AppColors.textDim)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: item.isDirectory ? .semibold : .regular))
                        .foregroundStyle(AppColors.textPri)
                        .lineLimit(1)

                    if let size = item.size, !item.isDirectory {
                        Text(formatFileSize(size))
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textDim)
                    }
                }

                Spacer()

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textDim)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.glassSubtle, in: RoundedRectangle(cornerRadius: AppRadii.sm))
        }
        .contextMenu {
            if !item.isDirectory {
                Button {
                    downloadCancellable = viewModel.downloadFile(at: viewModel.currentPath + "/" + item.name)
                        .sink(receiveCompletion: { _ in }, receiveValue: { data in
                            shareData(data, filename: item.name)
                        })
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            Button(role: .destructive) {
                fileToDelete = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
                .multilineTextAlignment(.center)
            GlassActionButton(title: "Retry", icon: "arrow.clockwise") {
                viewModel.refresh()
            }
            .frame(width: 150)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Helpers

    private func fileIcon(for item: APIService.FileItem) -> String {
        if item.isDirectory { return "folder.fill" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log":    return "doc.text"
        case "json", "xml", "yml", "yaml": return "doc.badge.gearshape"
        case "swift", "dart", "py", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "zip", "tar", "gz":    return "doc.zipper"
        case "bin", "elf":          return "cpu"
        default:                    return "doc"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1048576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1073741824 { return String(format: "%.1f MB", Double(bytes) / 1048576) }
        return String(format: "%.1f GB", Double(bytes) / 1073741824)
    }

    private func shareData(_ data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}
