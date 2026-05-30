import SwiftUI
import Combine

private enum MainTab: Hashable {
    case timeline
    case data
    case stats
}

struct ContentView: View {
    @ObservedObject var viewModel: TimelineViewModel

    @State private var hourHeight: Double = 120
    @State private var selectedTab: MainTab = .timeline
    @State private var selectedUsagePeriod: UsageStatsPeriod = .day
    private var minuteHeight: Double { hourHeight / 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding()
                .zIndex(1)

            TabView(selection: $selectedTab) {
                timelineView
                    .tabItem {
                        Label(L10n.Tab.timeline, systemImage: "clock")
                    }
                    .tag(MainTab.timeline)

                UsageStatsView(
                    viewModel: viewModel,
                    selectedPeriod: $selectedUsagePeriod
                )
                    .tabItem {
                        Label(L10n.Tab.stats, systemImage: "chart.bar.xaxis")
                    }
                    .tag(MainTab.stats)

                SessionListView(
                    sessions: viewModel.sessions,
                    onDelete: { session in
                        viewModel.deleteSession(session)
                    },
                    onEdit: { session, name, bundle, start, end in
                        viewModel.updateSession(session, newName: name, newBundle: bundle, newStart: start, newEnd: end)
                    }
                )
                    .tabItem {
                        Label(L10n.Tab.data, systemImage: "tablecells")
                    }
                    .tag(MainTab.data)
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    

    // MARK: - 主时间轴区域
    private var timelineView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Time Grid Layer
                    timeGrid
                        .frame(maxWidth: .infinity)

                    // Activity Layer
                    activityLayer

                    // Current Time Indicator
                    if Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()) {
                        currentTimeIndicator
                            .zIndex(100)
                    }
                }
                .frame(minWidth: 600, maxWidth: .infinity, alignment: .topLeading)
                .onAppear {
                    scrollToCurrentTime(proxy: proxy)
                }
                .onReceive(timer) { _ in
                    currentTime = Date()
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        let hour = Calendar.current.component(.hour, from: Date())
        // Scroll to the hour before the current one for better visibility/context
        let targetHour = max(0, hour - 1)
        withAnimation {
            proxy.scrollTo(targetHour, anchor: .top)
        }
    }

    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .offset(x: 42)

                // Dashed Line
                GeometryReader { lineGeo in
                    Path { path in
                        let y = lineGeo.size.height / 2
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: lineGeo.size.width, y: y))
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                }
                .frame(height: 1)
                .padding(.leading, 46)
            }
            .position(x: geo.size.width / 2, y: getYPosition(for: currentTime))
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 头部
    private var header: some View {
        HStack(spacing: 12) {
            // 导航按钮
            HStack(spacing: 2) {
                Button(action: { moveSelectedDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.changeDate(Date()) }) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.Toolbar.today)

                Button(action: { moveSelectedDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .font(.title2)
            .foregroundColor(.secondary)

            // 日期显示
            Text(headerTitle)
                .font(.system(size: 24, weight: .medium))

            Spacer()
            
            // 缩放按钮
            if selectedTab == .timeline {
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            hourHeight = max(hourHeight * 0.8, 20)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.Toolbar.zoomOut)

                    Button(action: {
                        withAnimation {
                            hourHeight = min(hourHeight * 1.2, 300)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.Toolbar.zoomIn)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 时间网格
    private var timeGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .top) {
                    HStack(alignment: .top) {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .trailing)
                            .offset(y: -6) // Align text with line
                        
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            }
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        }
                        .frame(height: 1) // 高度占位
                    }
                    
                    // 四分之一刻度
                    VStack(spacing: 0) {
                        Spacer()
                        ForEach(0..<3) { _ in 
                            HStack {
                                Spacer().frame(width: 42) // Offset from left to align near text
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 3, height: 1)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour) // Allow scrolling to specific hour
            }
        }
    }

    // MARK: - 活动层
    private var activityLayer: some View {
        // Offset to align with grid lines (right of time labels)
        // Time labels are width 50, plus spacing
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(viewModel.mergedBlocks.enumerated()), id: \.element.id) { index, block in
                    let nextStart: Date = (index + 1 < viewModel.mergedBlocks.count)
                        ? viewModel.mergedBlocks[index + 1].startAt
                        : Calendar.current.startOfDay(for: block.startAt).addingTimeInterval(24 * 3600)
                    
                    let gap = nextStart.timeIntervalSince(block.startAt)
                    // Ensure gap is at least the block's own duration (data integrity fallback)
                    let validGap = max(gap, block.duration)
                    
                    let gapHeight = validGap / 60 * minuteHeight
                    let durationHeight = block.duration / 60 * minuteHeight
                    
                    // Cap the rendering frame to avoid capturing clicks for hours of empty space
                    // But allow enough space for the Info view (e.g. 200pt max or just duration if large)
                    let renderHeight = min(gapHeight, max(durationHeight, 200))

                    ActivityBlockView(
                        block: block,
                        minuteHeight: minuteHeight,
                        availableHeight: gapHeight,
                        viewModel: viewModel
                    )
                    .frame(height: renderHeight, alignment: .top) // Align top so content flows down
                    .position(
                        x: geo.size.width / 2,
                        y: getYPosition(for: block.startAt) + renderHeight / 2
                    )
                    .frame(width: geo.size.width) // Fill available width
                }
            }
        }
        .padding(.leading, 60) // Width of time column
    }

    private func getYPosition(for date: Date) -> Double {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: viewModel.selectedDate)
        // If date is before start of day (e.g. crossing midnight), clamp or handle? 
        // Assuming simple same-day for now.
        let minutes = date.timeIntervalSince(startOfDay) / 60
        return minutes * minuteHeight
    }

    private var headerTitle: String {
        guard selectedTab == .stats else {
            return dateFormatter.string(from: viewModel.selectedDate)
        }

        return usagePeriodTitle(
            for: selectedUsagePeriod,
            containing: viewModel.selectedDate
        )
    }

    private func moveSelectedDate(by value: Int) {
        if selectedTab == .stats {
            let component = selectedUsagePeriod.navigationComponent
            if let newDate = Calendar.current.date(byAdding: component, value: value, to: viewModel.selectedDate) {
                viewModel.changeDate(newDate)
            }
        } else {
            viewModel.moveDate(by: value)
        }
    }

    private func usagePeriodTitle(
        for period: UsageStatsPeriod,
        containing date: Date
    ) -> String {
        let calendar = Calendar.current
        let interval = TimelineViewModel.dateInterval(for: period, containing: date)
        let currentYear = calendar.component(.year, from: Date())

        switch period {
        case .day:
            return formatDay(interval.start, omittingYear: isInCurrentYear(interval.start, currentYear: currentYear))
        case .month:
            return fullMonthFormatter.string(from: interval.start)
        case .year:
            return yearFormatter.string(from: interval.start)
        }
    }

    private func isInCurrentYear(_ date: Date, currentYear: Int) -> Bool {
        Calendar.current.component(.year, from: date) == currentYear
    }

    private func formatDay(_ date: Date, omittingYear: Bool) -> String {
        let formatter = omittingYear ? monthDayFormatter : fullDateFormatter
        return formatter.string(from: date)
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("yMMMd")
        return f
    }()

    private let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter
    }()

    private let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private let fullMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    private let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter
    }()
}

private extension UsageStatsPeriod {
    var navigationComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

struct ActivityBlockView: View {
    let block: SessionBlock
    let minuteHeight: Double
    let availableHeight: Double
    @ObservedObject var viewModel: TimelineViewModel
    
    @State private var showTooltip = false
    @State private var showColorPicker = false
    @State private var hoverWorkItem: DispatchWorkItem?

    var body: some View {
        // Calculate block visual height
        let blockHeight = block.duration / 60 * minuteHeight
        // Only show info if strict height allows (e.g. at least 20pt)
        let isInfoVisible = blockHeight >= 20

        HStack(alignment: .top, spacing: 16) {
            // Color Rectangle
            // Visual Container for the Block Group
            ZStack(alignment: .top) {
                // Background of the main app color (light opacity) or just empty?
                // Using the segments to render the "True" timeline
                GeometryReader { geo in
                    ForEach(block.segments) { segment in
                        // Calculate relative position and height
                        let segmentStart = segment.startAt.timeIntervalSince(block.startAt)
                        let segmentY = segmentStart / 60 * minuteHeight
                        let segmentHeight = max(segment.duration / 60 * minuteHeight, 1) // Min 1pt visibility
                        
                        // Resolve color for this specific segment
                        let segmentColor = viewModel.getColor(for: segment.bundleId) ?? .gray
                        
                        ActivitySegmentView(
                            segment: segment,
                            color: segmentColor,
                            width: geo.size.width,
                            height: segmentHeight
                        )
                        .position(x: geo.size.width / 2, y: segmentY + segmentHeight / 2)
                    }
                }
            }
            .frame(width: 60) // Width of the column
            .frame(height: blockHeight)
            .padding(.leading, 10)
            .contentShape(Rectangle()) // Make the whole area tappable
            .onTapGesture {
                showColorPicker = true
            }
            .popover(isPresented: $showColorPicker) {
                 ColorPickerPopView(selectedColor: block.color ?? .gray) { newColor in
                     viewModel.updateColor(for: block.bundleId, color: newColor)
                     showColorPicker = false
                 }
            }
            .zIndex(10)
            
            // Info
            if isInfoVisible {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        // App Icon
                        if let icon = getIcon(for: block.bundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        
                        // App Name / Title
                        Text(block.displayTitle)
                            .font(.system(size: 12, weight: .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        Text(durationString(block.duration))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8) // Add some internal padding
                .frame(height: max(blockHeight - 1, 1), alignment: .top) // Subtract 1pt to avoid double border overlap
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
                .padding(.trailing, 20)
            } else {
                Spacer()
            }
        }
        .zIndex(1) // Keep blocks above grid
    }
    
    private func getIcon(for bundleId: String) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
    
    func durationString(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 {
            return String(format: "%d:%02d", h, m)
        } else {
            return String(format: "0:%02d", m)
        }
    }
}

struct ActivitySegmentView: View {
    let segment: Session
    let color: Color
    let width: Double
    let height: Double
    
    @State private var showTooltip = false
    @State private var hoverWorkItem: DispatchWorkItem?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(color)
            .frame(width: width, height: height)
            .onHover { hovering in
                hoverWorkItem?.cancel()
                
                if hovering {
                    let item = DispatchWorkItem {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.showTooltip = true
                        }
                    }
                    hoverWorkItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
                } else {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        showTooltip = false
                    }
                }
            }
            .overlay(alignment: .leading) { // Tooltip relative to segment
                if showTooltip {
                    Text(tooltipString(for: segment))
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .shadow(radius: 4)
                        .fixedSize()
                        .offset(x: width + 10, y: 0) // Offset to the right of the segment
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .zIndex(showTooltip ? 100 : 0)
    }
    
    private func tooltipString(for session: Session) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: session.startAt)
        let endStr = formatter.string(from: session.endAt)
        
        // Duration
        let duration = session.duration
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let durationStr = h > 0 ? String(format: "%d:%02d", h, m) : String(format: "0:%02d", m)
        
        let title = session.windowTitle ?? session.appName
        return "\(title)\n\(startStr) - \(endStr) (\(durationStr))"
    }
}

struct ColorPickerPopView: View {
    let selectedColor: Color
    let onSelect: (Color) -> Void
    
    let colors: [Color] = TimelineViewModel.palette
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 12) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                    )
                    .shadow(radius: 2)
                    .onTapGesture {
                        onSelect(color)
                    }
            }
        }
        .padding()
        .frame(width: 240)
    }
}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: .preview)
            .preferredColorScheme(.dark)
    }
}
#endif
