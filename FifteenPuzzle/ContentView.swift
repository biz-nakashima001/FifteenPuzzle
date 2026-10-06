import SwiftUI

struct PuzzleBoard: Equatable {
    var tiles = Array(1...15) + [0]
    static func goal(reverse: Bool) -> [Int] {
        reverse ? [0] + Array((1...15).reversed()) : Array(1...15) + [0]
    }
    func solved(reverse: Bool = false) -> Bool { tiles == Self.goal(reverse: reverse) }
    func completedRows(reverse: Bool = false) -> Set<Int> {
        let target = Self.goal(reverse: reverse)
        return Set((0..<4).filter { row in
            (0..<4).allSatisfy { column in
                let index = row * 4 + column
                return tiles[index] == target[index]
            }
        })
    }
    static func isSolvable(_ tiles: [Int], reverse: Bool = false) -> Bool {
        guard tiles.count == 16, Set(tiles) == Set(0...15), let blank = tiles.firstIndex(of: 0) else { return false }
        let goal = Self.goal(reverse: reverse)
        let rank = Dictionary(uniqueKeysWithValues: goal.enumerated().compactMap { index, tile in
            tile == 0 ? nil : (tile, index)
        })
        let numbers = tiles.filter { $0 != 0 }.map { rank[$0]! }
        var inversions = 0
        for i in numbers.indices {
            for j in numbers.indices where j > i && numbers[i] > numbers[j] { inversions += 1 }
        }
        let rowFromBottom = 4 - blank / 4
        let goalBlank = 4 - (goal.firstIndex(of: 0)! / 4)
        return (inversions + rowFromBottom + goalBlank) % 2 == 0
    }
    mutating func shuffle(reverse: Bool = false) {
        repeat { tiles.shuffle() } while !Self.isSolvable(tiles, reverse: reverse) || solved(reverse: reverse)
    }
    mutating func move(at index: Int) -> Bool {
        guard tiles.indices.contains(index), let blank = tiles.firstIndex(of: 0), index != blank,
              abs(index / 4 - blank / 4) + abs(index % 4 - blank % 4) == 1 else { return false }
        tiles.swapAt(index, blank)
        return true
    }
}

struct ContentView: View {
    @State private var board = PuzzleBoard()
    @State private var moves = 0
    @State private var started: Date?
    @State private var finishedSeconds: Int?
    @State private var history: [[Int]] = []
    @State private var askNew = false
    @State private var askModeChange = false
    @State private var initialized = false
    @State private var rowFlashes: [Int: Date] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bestMoves") private var bestMoves = 0
    @AppStorage("reverseMode") private var reverseMode = false
    private let accent = Color(red: 0.12, green: 0.62, blue: 0.55)

    func newGame() {
        board.shuffle(reverse: reverseMode)
        moves = 0
        started = nil
        finishedSeconds = nil
        history = []
        rowFlashes = [:]
    }
    func requestModeChange() {
        if moves > 0 && finishedSeconds == nil {
            askModeChange = true
        } else {
            reverseMode.toggle()
            newGame()
        }
    }
    func changeModeAndStartGame() {
        reverseMode.toggle()
        newGame()
    }
    func move(_ index: Int) {
        guard finishedSeconds == nil else { return }
        let previous = board.tiles
        let previousRows = board.completedRows(reverse: reverseMode)
        guard board.move(at: index) else { return }
        celebrateRows(after: previousRows)
        if started == nil { started = Date() }
        history.append(previous)
        moves += 1
        if board.solved(reverse: reverseMode) {
            finishedSeconds = Int(Date().timeIntervalSince(started ?? Date()))
            if bestMoves == 0 || moves < bestMoves { bestMoves = moves }
        }
    }
    func undo() {
        guard finishedSeconds == nil, let previous = history.popLast() else { return }
        let previousRows = board.completedRows(reverse: reverseMode)
        board.tiles = previous
        celebrateRows(after: previousRows)
        moves = max(0, moves - 1)
    }
    func celebrateRows(after previousRows: Set<Int>) {
        for row in board.completedRows(reverse: reverseMode).subtracting(previousRows) {
            let stamp = Date()
            rowFlashes[row] = stamp
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1100))
                if rowFlashes[row] == stamp { rowFlashes[row] = nil }
            }
        }
    }
    func clock(_ date: Date) -> String {
        let seconds = finishedSeconds ?? started.map { max(0, Int(date.timeIntervalSince($0))) } ?? 0
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("15 PUZZLE").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(3).foregroundStyle(accent)
                    Text("ひとマスずつ、整える。").font(.system(size: 25, weight: .semibold))
                }
                Spacer()
                Image(systemName: "square.grid.3x3.fill").font(.system(size: 28)).foregroundStyle(accent)
            }
            HStack(spacing: 0) {
                metric("手数", value: "\(moves)")
                Divider().frame(height: 34)
                TimelineView(.periodic(from: .now, by: 1)) { context in metric("時間", value: clock(context.date)) }
                Divider().frame(height: 34)
                metric("最少手数", value: bestMoves == 0 ? "-" : "\(bestMoves)")
            }.padding(.vertical, 14).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            Button(action: requestModeChange) {
                Label(reverseMode ? "通常順モードへ（1 → 15）" : "逆順モードへ（15 → 1）",
                      systemImage: reverseMode ? "arrow.uturn.backward.circle" : "arrow.uturn.forward.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("切り替えると新しい盤面が始まります")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<16, id: \.self) { index in
                    let value = board.tiles[index]
                    if value == 0 {
                        RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.4))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4])))
                            .aspectRatio(1, contentMode: .fit).accessibilityLabel("空きマス")
                    } else {
                        let isInPlace = board.tiles[index] == PuzzleBoard.goal(reverse: reverseMode)[index]
                        Button { withAnimation(.easeInOut(duration: 0.12)) { move(index) } } label: {
                            Text("\(value)").font(.system(size: 34, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(isInPlace ? accent.opacity(0.18) : Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(isInPlace ? accent : .primary)
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.05)))
                        }.buttonStyle(.plain).accessibilityLabel("タイル \(value)")
                    }
                }
            }.padding(12).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    GeometryReader { geometry in
                        let tileHeight = (geometry.size.height - 24 - 30) / 4
                        ForEach(rowFlashes.keys.sorted(), id: \.self) { row in
                            if let started = rowFlashes[row] {
                                RowLightning(started: started, reduceMotion: reduceMotion)
                                    .frame(width: geometry.size.width - 24, height: tileHeight)
                                    .offset(x: 12, y: 12 + CGFloat(row) * (tileHeight + 10))
                            }
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
            VStack(spacing: 7) {
                if finishedSeconds != nil {
                    Label("完成！ おめでとうございます。", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(accent)
                } else {
                    Text("空きマスの隣の数字をクリックして移動").font(.callout)
                }
                Text(reverseMode ? "15から1へ右下まで。左上を空きマスにします。" : "1〜15を左上から順番に。右下を空きマスにします。 ").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button { undo() } label: { Label("ひとつ戻す", systemImage: "arrow.uturn.backward") }
                    .disabled(history.isEmpty || finishedSeconds != nil).keyboardShortcut("z", modifiers: .command)
                Spacer()
                Button { if moves > 0 && finishedSeconds == nil { askNew = true } else { newGame() } } label: {
                    Label("新しいゲーム", systemImage: "shuffle")
                }.buttonStyle(.borderedProminent).tint(accent).keyboardShortcut("n", modifiers: .command)
            }
        }.padding(30).frame(width: 500).frame(minWidth: 560, minHeight: 800)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if !initialized { newGame(); initialized = true } }
        .alert("新しいゲームを始めますか？", isPresented: $askNew) {
            Button("キャンセル", role: .cancel) {}
            Button("始める") { newGame() }
        } message: { Text("現在の盤面と手数がリセットされます。") }
        .alert("モードを切り替えますか？", isPresented: $askModeChange) {
            Button("キャンセル", role: .cancel) {}
            Button("切り替える") { changeModeAndStartGame() }
        } message: { Text("モードを切り替えると、新しい盤面が始まります。") }
    }
    func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }
}

private struct RowLightning: View {
    let started: Date
    let reduceMotion: Bool

    // Stable within each 65 ms frame, so the bolt crackles without random redraw noise.
    private func noise(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(value - floor(value))
    }
    private func path(_ points: [CGPoint]) -> Path {
        var result = Path()
        if let first = points.first { result.move(to: first) }
        for point in points.dropFirst() { result.addLine(to: point) }
        return result
    }
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(started))
            let progress = min(1, elapsed / 1.1)
            Canvas { context, size in
                let frame = CGRect(origin: .zero, size: size)
                if reduceMotion {
                    let fade = sin(.pi * progress)
                    context.fill(Path(roundedRect: frame, cornerRadius: 14), with: .color(.cyan.opacity(fade * 0.18)))
                } else {
                    let fade = min(1, elapsed / 0.07) * max(0, 1 - (elapsed - 0.35) / 0.75)
                    let flicker = 0.7 + 0.3 * pow(sin(elapsed * 77), 2)
                    context.opacity = fade * flicker
                    let tick = Int(elapsed / 0.065) * 97
                    let amplitude = min(23, size.height * 0.23)
                    let center = size.height / 2
                    let points = (0...30).map { step in
                        CGPoint(x: size.width * CGFloat(step) / 30,
                                y: center + (step == 0 || step == 30 ? 0 : (noise(tick + step) * 2 - 1) * amplitude))
                    }
                    let bolt = path(points)
                    var branches = Path()
                    for step in stride(from: 4, through: 27, by: 3) {
                        let origin = points[step]
                        let sign: CGFloat = step % 2 == 0 ? -1 : 1
                        branches.addPath(path([
                            origin,
                            CGPoint(x: origin.x + 8 + noise(tick + step + 31) * 14, y: origin.y + sign * amplitude * 0.7),
                            CGPoint(x: origin.x + 22 + noise(tick + step + 42) * 16, y: origin.y + sign * amplitude * 1.4),
                            CGPoint(x: origin.x + 33 + noise(tick + step + 53) * 19, y: origin.y + sign * amplitude * 1.8)
                        ]))
                    }
                    context.clip(to: Path(CGRect(x: -20, y: -30, width: (size.width + 40) * min(1, elapsed / 0.16), height: size.height + 60)))
                    let style = StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    var glow = context
                    glow.addFilter(.blur(radius: 14))
                    glow.stroke(bolt, with: .color(.blue), style: style)
                    glow.stroke(branches, with: .color(.cyan), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    context.stroke(bolt, with: .color(.cyan), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    context.stroke(branches, with: .color(.cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    context.stroke(bolt, with: .color(.white), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    context.stroke(branches, with: .color(.white), lineWidth: 1)
                    for step in stride(from: 2, through: 24, by: 2) {
                        let point = points[step]
                        let spark = CGRect(x: point.x + noise(tick + step + 64) * 20 - 10,
                                           y: point.y + noise(tick + step + 75) * 64 - 32, width: 2, height: 2)
                        context.fill(Path(ellipseIn: spark), with: .color(.white))
                    }
                }
            }
        }
    }
}
