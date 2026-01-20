import SwiftUI

struct ContentView: View {
    enum Tab: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    @State private var selectedTab: Tab = .day
    @StateObject private var healthViewModel = HealthKitViewModel()
    @StateObject private var settingsStore = SettingsStore()
    @State private var isShowingSettings = false
    @StateObject private var streakManager = StreakManager()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                TopBar(selectedTab: $selectedTab, settingsAction: { isShowingSettings = true })

                switch selectedTab {
                case .day:
                    DayView(
                        viewModel: healthViewModel,
                        settingsStore: settingsStore,
                        streakManager: streakManager
                    )
                case .week:
                    WeekView(viewModel: healthViewModel, settingsStore: settingsStore)
                case .month:
                    MonthBlankView()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .tint(AppTheme.primaryAccent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(store: settingsStore)
        }
        .task {
            await healthViewModel.requestAndLoad(recentHRMinutes: settingsStore.recentHRWindowMinutes)
        }
        .onChange(of: settingsStore.recentHRWindowMinutes) { newValue in
            healthViewModel.refresh(recentHRMinutes: newValue)
        }
        .onChange(of: healthViewModel.last7DaysSteps) { _ in
            refreshStreak()
        }
        .onChange(of: settingsStore.dailyStepTarget) { _ in
            refreshStreak()
        }
    }

    private func refreshStreak() {
        Task {
            await refreshStreakAsync()
        }
    }

    private func refreshStreakAsync() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let bonusState = settingsStore.bonusStateObject()
        guard healthViewModel.isAuthorized else { return }
        let lastUpdated = calendar.startOfDay(for: bonusState.lastUpdated)
        let startDate = calendar.date(byAdding: .day, value: 1, to: lastUpdated) ?? today
        let fetchStart = min(startDate, today)

        let stepsMap = await healthViewModel.fetchDailySteps(from: fetchStart, to: today)
        streakManager.refresh(
            dailySteps: stepsMap,
            goalSteps: settingsStore.dailyStepTarget,
            bonusState: bonusState
        )
        settingsStore.updateBonusBalance(bonusState.currentBalanceValue)
    }
}

private struct TopBar: View {
    @Binding var selectedTab: ContentView.Tab
    let settingsAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            SegmentedTabs(selectedTab: $selectedTab)
            Spacer()
            Button(action: settingsAction) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.topBarIcon)
            }
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SegmentedTabs: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                selectedTab == tab
                                ? AppTheme.selectedTabText
                                : AppTheme.unselectedTabText
                            )
                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.primaryAccent : .clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct DayView: View {
    @ObservedObject var viewModel: HealthKitViewModel
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var streakManager: StreakManager

    var body: some View {
        VStack(spacing: 18) {
            if let message = viewModel.statusMessage {
                HealthStatusBanner(
                    message: message,
                    action: { viewModel.refresh(recentHRMinutes: settingsStore.recentHRWindowMinutes) }
                )
            }
            DialView(dateLabel: "Today", steps: todaySteps, goal: goalSteps)

            StatTileRow(tiles: statTiles)

            StepsGraphView(values: viewModel.last7DaysSteps)

            UserVsBotView(userSteps: todaySteps, botSteps: botSteps)
        }
    }

    private var todaySteps: Int {
        viewModel.todaySteps
    }

    private var statTiles: [(String, String)] {
        [
            ("Streak", "\(streakManager.streakCount)"),
            ("kcal", "\(viewModel.activeEnergyKcal)"),
            ("miles", String(format: "%.1f", viewModel.distanceMiles)),
            ("bpm", viewModel.heartRate.map { "\($0)" } ?? "--")
        ]
    }

    private var goalSteps: Int {
        max(1, settingsStore.dailyStepTarget)
    }

    private var botSteps: Int {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
        let elapsedSeconds = now.timeIntervalSince(startOfDay)
        let progress = min(max(elapsedSeconds / totalSeconds, 0), 1)
        return Int((Double(goalSteps) * progress).rounded())
    }
}

private struct WeekView: View {
    @ObservedObject var viewModel: HealthKitViewModel
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 18) {
            WeekBarChart(values: viewModel.last7DaysSteps)

            StatTileRow(tiles: statTiles)

            StepsGraphView(values: viewModel.last7WeekBlocksSteps)

            UserVsBotView(userSteps: viewModel.weekStepsTotal, botSteps: weekBotSteps)
        }
    }

    private var statTiles: [(String, String)] {
        [
            ("Streak", "0"),
            ("kcal", "\(viewModel.weekEnergyKcal)"),
            ("miles", String(format: "%.1f", viewModel.weekDistanceMiles))
        ]
    }

    private var weekBotSteps: Int {
        let goalSteps = max(1, settingsStore.dailyStepTarget)
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

        var total = 0
        for offset in 0..<6 {
            let day = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startOfToday
            if day < startOfToday {
                total += goalSteps
            }
        }

        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let totalSeconds = endOfToday.timeIntervalSince(startOfToday)
        let elapsedSeconds = now.timeIntervalSince(startOfToday)
        let progress = min(max(elapsedSeconds / totalSeconds, 0), 1)
        total += Int((Double(goalSteps) * progress).rounded())
        return total
    }
}

private struct WeekBarChart: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let normalized = normalizedValues(values: values)
            let barWidth = width / CGFloat(max(values.count * 2 - 1, 1))

            HStack(alignment: .bottom, spacing: barWidth) {
                ForEach(normalized.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text("\(values[index])")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.dayLabel)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.primaryAccent.opacity(0.85))
                            .frame(width: barWidth, height: max(8, height * normalized[index]))
                    }
                    .frame(width: barWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 180)
    }

    private func normalizedValues(values: [Int]) -> [CGFloat] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return Array(repeating: 0.2, count: max(values.count, 1))
        }
        return values.map { CGFloat($0) / CGFloat(maxValue) }
    }
}

private struct DialView: View {
    let dateLabel: String
    let steps: Int
    let goal: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.dialTrack, lineWidth: 14)
                .frame(width: 220, height: 220)
            VStack(spacing: 8) {
                Text(dateLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryAccent)
                Text("\(steps)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text("Of \(goal) steps")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatTileRow: View {
    let tiles: [(String, String)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tiles.indices, id: \.self) { index in
                    StatTile(title: tiles[index].0, value: tiles[index].1)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(width: 90, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.capsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.capsuleBorder.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct StepsGraphView: View {
    let values: [Int]

    private let dayCount = 7

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = proxy.size.width
            let padded = GraphNormalizer.paddedValues(values, count: dayCount)
            let points = GraphNormalizer.normalizedPoints(values: padded, size: proxy.size)

            ZStack {
                Path { path in
                    let step = width / CGFloat(max(dayCount - 1, 1))
                    for index in 0..<dayCount {
                        let x = CGFloat(index) * step
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(AppTheme.guideLine, lineWidth: 1)

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    if points.count == 1 {
                        return
                    }
                    for index in 1..<points.count {
                        let p0 = points[max(index - 2, 0)]
                        let p1 = points[index - 1]
                        let p2 = points[index]
                        let p3 = points[min(index + 1, points.count - 1)]
                        addCatmullRomSegment(
                            path: &path,
                            p0: p0,
                            p1: p1,
                            p2: p2,
                            p3: p3
                        )
                    }
                }
                .stroke(AppTheme.chartAccent, lineWidth: 2)

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.pointMarker)
                        .frame(width: 4, height: 4)
                        .position(points[index])
                }
            }
        }
        .frame(height: 140)
    }

    private func addCatmullRomSegment(
        path: inout Path,
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint
    ) {
        let smoothing: CGFloat = 0.35
        let d1 = distance(p1, p2)
        let d0 = max(distance(p0, p1), 0.001)
        let d2 = max(distance(p2, p3), 0.001)

        let control1 = CGPoint(
            x: p1.x + (p2.x - p0.x) * smoothing * (d1 / d0),
            y: p1.y + (p2.y - p0.y) * smoothing * (d1 / d0)
        )
        let control2 = CGPoint(
            x: p2.x - (p3.x - p1.x) * smoothing * (d1 / d2),
            y: p2.y - (p3.y - p1.y) * smoothing * (d1 / d2)
        )

        path.addCurve(to: p2, control1: control1, control2: control2)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private struct UserVsBotView: View {
    let userSteps: Int
    let botSteps: Int

    var body: some View {
        let userFirst = userSteps >= botSteps
        VStack(alignment: .leading, spacing: 10) {
            if userFirst {
                UserVsBotRow(title: "User", steps: userSteps, isWinner: true)
                UserVsBotRow(title: "Walking Bot", steps: botSteps, isWinner: false)
            } else {
                UserVsBotRow(title: "Walking Bot", steps: botSteps, isWinner: true)
                UserVsBotRow(title: "User", steps: userSteps, isWinner: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.capsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.capsuleBorder.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct UserVsBotRow: View {
    let title: String
    let steps: Int
    let isWinner: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(steps)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryAccent)
            }
        }
    }
}

private struct HealthStatusBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryAccent)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Button("Retry", action: action)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.capsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.capsuleBorder.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("Coming soon.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
    }
}

private struct MonthBlankView: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Daily Goal")) {
                    Stepper(value: $store.dailyStepTarget, in: 1000...40000, step: 500) {
                        HStack {
                            Text("Target Steps")
                            Spacer()
                            Text("\(store.dailyStepTarget)")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }

                Section(header: Text("Bonus Days")) {
                    Stepper(value: $store.bonusEarnEveryN, in: 1...30, step: 1) {
                        HStack {
                            Text("Earn Every N Days")
                            Spacer()
                            Text("\(store.bonusEarnEveryN)")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    Stepper(value: $store.maxBonusDays, in: 0...30, step: 1) {
                        HStack {
                            Text("Max Bonus Days")
                            Spacer()
                            Text("\(store.maxBonusDays)")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    HStack {
                        Text("Current Bonus Days")
                        Spacer()
                        Text("\(store.currentBonusDays)")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Section(header: Text("Heart Rate")) {
                    Stepper(value: $store.recentHRWindowMinutes, in: 1...60, step: 1) {
                        HStack {
                            Text("Recency Window (min)")
                            Spacer()
                            Text("\(store.recentHRWindowMinutes)")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
