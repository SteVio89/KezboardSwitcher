//
//  StatisticsView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Summary Cards
                HStack(spacing: 12) {
                    StatCard(
                        title: "Today",
                        value: "\(viewModel.switchCountToday)",
                        icon: "arrow.triangle.swap",
                        tint: Theme.accentBlue
                    )
                    StatCard(
                        title: "All Time",
                        value: "\(viewModel.totalSwitchCount)",
                        icon: "sum",
                        tint: Theme.skyBlue
                    )
                    StatCard(
                        title: "Keyboards",
                        value: "\(viewModel.keyboards.filter { $0.status == .configured }.count)",
                        icon: "keyboard",
                        tint: Theme.statusConfigured
                    )
                }

                // MARK: - Keyboard Usage
                if !viewModel.keyboardUsages.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.keyboardUsages) { usage in
                                UsageBar(usage: usage)
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Keyboard Usage", systemImage: "chart.bar.fill")
                            .font(.headline)
                    }
                }

                // MARK: - Daily Activity
                if !viewModel.dailySwitchCounts.isEmpty {
                    GroupBox {
                        DailyChart(data: viewModel.dailySwitchCounts)
                            .frame(height: 120)
                            .padding(.vertical, 4)
                    } label: {
                        Label("Last 7 Days", systemImage: "calendar")
                            .font(.headline)
                    }
                }

                if viewModel.totalSwitchCount == 0 {
                    ContentUnavailableView(
                        "No Statistics Yet",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Statistics will appear here as you switch between keyboards.")
                    )
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.caption)
                Spacer()
            }
            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Usage Bar

private struct UsageBar: View {
    let usage: KeyboardUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(usage.keyboardName)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                Text("\(usage.switchCount)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.accentBlue.gradient)
                        .frame(width: max(geo.size.width * usage.percentage, 4), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Daily Chart

private struct DailyChart: View {
    let data: [DailySwitchCount]

    private var maxCount: Int {
        max(data.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { day in
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    if day.count > 0 {
                        Text("\(day.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(barColor(for: day))
                        .frame(height: barHeight(for: day, maxHeight: 80))
                    Text(dayLabel(for: day.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for day: DailySwitchCount, maxHeight: CGFloat) -> CGFloat {
        guard day.count > 0 else { return 4 }
        return max(CGFloat(day.count) / CGFloat(maxCount) * maxHeight, 8)
    }

    private func barColor(for day: DailySwitchCount) -> some ShapeStyle {
        if Calendar.current.isDateInToday(day.date) {
            return Theme.accentBlue.gradient
        }
        return Theme.accentBlue.opacity(0.4).gradient
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
