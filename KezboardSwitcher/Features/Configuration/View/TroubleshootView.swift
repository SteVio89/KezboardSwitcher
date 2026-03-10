//
//  TroubleshootView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 10.03.26.
//

import SwiftUI
import OSLog

struct TroubleshootView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var autoRefresh = true
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .default).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.logEntries.count) entries (last hour)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Auto", isOn: $autoRefresh)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.caption)
                Button {
                    viewModel.fetchLogs()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if viewModel.logEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No log entries found. Tap refresh to reload.")
                )
            } else {
                ScrollViewReader { proxy in
                    List(viewModel.logEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                            .listRowSeparator(.visible)
                    }
                    .listStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: viewModel.logEntries.count) {
                        if let last = viewModel.logEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchLogs()
        }
        .onReceive(refreshTimer) { _ in
            if autoRefresh {
                viewModel.fetchLogs()
            }
        }
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.date))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            Text(entry.levelLabel)
                .foregroundStyle(levelColor)
                .frame(width: 50, alignment: .leading)

            Text("[\(entry.category)]")
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)

            Text(entry.message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var levelColor: Color {
        switch entry.level {
        case .error, .fault: .red
        case .notice: .orange
        case .info: .blue
        default: .secondary
        }
    }
}
