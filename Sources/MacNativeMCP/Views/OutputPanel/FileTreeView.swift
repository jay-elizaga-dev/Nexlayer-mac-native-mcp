import SwiftUI

struct FileTreeView: View {
    let entries: [FileEntry]

    var body: some View {
        List {
            ForEach(entries) { entry in
                FileTreeRowView(entry: entry)
            }
        }
        .listStyle(.plain)
        .background(AppColors.background)
    }
}

private struct FileTreeRowView: View {
    let entry: AppState.FileEntry
    @State private var expanded: Bool = false

    var body: some View {
        if entry.isDirectory {
            // Folder row with expand/collapse
            DisclosureGroup(
                isExpanded: $expanded,
                content: {
                    if let children = entry.children {
                        ForEach(children) { child in
                            FileTreeRowView(entry: child)
                        }
                    }
                },
                label: {
                    HStack(spacing: 8) {
                        // Chevron icon
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 12, height: 12)

                        // Folder icon
                        Image(systemName: expanded ? "folder.fill" : "folder")
                            .font(.body)
                            .foregroundColor(AppColors.accent)

                        // Folder name
                        Text(entry.name)
                            .font(AppFonts.prose)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()
                    }
                }
            )
        } else {
            // File row
            HStack(spacing: 8) {
                // Indent to align with disclosure group content
                Color.clear
                    .frame(width: 20, height: 0)

                // File icon
                Image(systemName: "doc")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)

                // File name
                Text(entry.name)
                    .font(AppFonts.prose)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // File size label if available
                if let size = entry.size {
                    Text(formatFileSize(size))
                        .font(AppFonts.label)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // TODO: POST read_file to server if supported
                // For now, this is a no-op stub
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    let sampleEntries = [
        AppState.FileEntry(
            path: "/",
            name: "Root",
            isDirectory: true,
            children: [
                AppState.FileEntry(
                    path: "/Sources",
                    name: "Sources",
                    isDirectory: true,
                    children: [
                        AppState.FileEntry(
                            path: "/Sources/main.swift",
                            name: "main.swift",
                            isDirectory: false,
                            size: 2048
                        ),
                        AppState.FileEntry(
                            path: "/Sources/Utils.swift",
                            name: "Utils.swift",
                            isDirectory: false,
                            size: 4096
                        ),
                    ]
                ),
                AppState.FileEntry(
                    path: "/README.md",
                    name: "README.md",
                    isDirectory: false,
                    size: 1024
                ),
            ]
        ),
    ]

    return FileTreeView(entries: sampleEntries)
        .background(AppColors.background)
}
