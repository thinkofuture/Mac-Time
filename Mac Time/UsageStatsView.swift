import SwiftUI

struct UsageStatsView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedPeriod: UsageStatsPeriod

    @State private var stats: [AppUsageStat] = []

    private let labelWidth: CGFloat = 180
    private let rowHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            if stats.isEmpty {
                ContentUnavailableView(
                    L10n.Stats.empty,
                    systemImage: "chart.bar.xaxis"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(stats) { stat in
                            UsageStatsRow(
                                stat: stat,
                                maxDuration: maxDuration,
                                labelWidth: labelWidth,
                                rowHeight: rowHeight,
                                color: viewModel.getColor(for: stat.bundleId) ?? .accentColor
                            )
                        }
                    }
                    .padding(20)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .onAppear(perform: loadStats)
        .onChange(of: selectedPeriod) { _, _ in loadStats() }
        .onChange(of: viewModel.selectedDate) { _, _ in loadStats() }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDataDidUpdate)) { _ in
            loadStats()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Picker(selection: $selectedPeriod) {
                ForEach(UsageStatsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Spacer()

            Text(durationString(totalDuration))
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var maxDuration: TimeInterval {
        stats.map(\.duration).max() ?? 0
    }

    private var totalDuration: TimeInterval {
        stats.reduce(0) { $0 + $1.duration }
    }

    private func loadStats() {
        viewModel.fetchUsageStats(for: selectedPeriod) { newStats in
            stats = newStats.filter { totalMinutes($0.duration) > 0 }
        }
    }
}

private struct UsageStatsRow: View {
    let stat: AppUsageStat
    let maxDuration: TimeInterval
    let labelWidth: CGFloat
    let rowHeight: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if let icon = icon(for: stat.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 18, height: 18)
                }

                Text(stat.appName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .frame(width: labelWidth, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor).opacity(0.2))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: barWidth(in: geometry.size.width), height: 10)

                    Text(durationString(stat.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, barWidth(in: geometry.size.width) + 8)
                        .lineLimit(1)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: rowHeight)
        }
        .frame(height: rowHeight)
    }

    private func barWidth(in availableWidth: CGFloat) -> CGFloat {
        guard maxDuration > 0 else { return 0 }

        let labelSpace: CGFloat = 72
        let availableBarWidth = max(availableWidth - labelSpace, 0)
        let proportionalWidth = availableBarWidth * CGFloat(stat.duration / maxDuration)
        return max(min(proportionalWidth, availableBarWidth), 2)
    }

    private func icon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

private func durationString(_ duration: TimeInterval) -> String {
    let totalMinutes = totalMinutes(duration)
    let days = totalMinutes / (24 * 60)
    let hours = (totalMinutes % (24 * 60)) / 60
    let minutes = totalMinutes % 60

    if days > 0 {
        return L10n.Duration.daysHoursMinutes(days: days, hours: hours, minutes: minutes)
    }

    if hours > 0 {
        return L10n.Duration.hoursMinutes(hours: hours, minutes: minutes)
    }

    return L10n.Duration.minutes(minutes)
}

private func totalMinutes(_ duration: TimeInterval) -> Int {
    max(Int(duration.rounded(.down)) / 60, 0)
}
