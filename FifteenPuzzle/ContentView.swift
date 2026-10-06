import SwiftUI

struct PuzzleBoard: Equatable {
    var tiles = Array(1...15) + [0]
    var solved: Bool { tiles == Array(1...15) + [0] }
    var completedRows: Set<Int> {
        Set((0..<4).filter { row in
            (0..<4).allSatisfy { column in
                let index = row * 4 + column
                return tiles[index] == (index + 1) % 16
            }
        })
    }
    static func isSolvable(_ tiles: [Int]) -> Bool {
        guard tiles.count == 16, Set(tiles) == Set(0...15), let blank = tiles.firstIndex(of: 0) else { return false }
        let numbers = tiles.filter { $0 != 0 }
        var inversions = 0
        for i in numbers.indices {
            for j in numbers.indices where j > i && numbers[i] > numbers[j] { inversions += 1 }
        }
        let rowFromBottom = 4 - blank / 4
        return (inversions + rowFromBottom) % 2 == 1
    }
    mutating func shuffle() {
        repeat { tiles.shuffle() } while !Self.isSolvable(tiles) || solved
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
    @State private var initialized = false
    @State private var rowFlashes: [Int: Date] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bestMoves") private var bestMoves = 0
    private let accent = Color(red: 0.12, green: 0.62, blue: 0.55)

    func newGame() {
        board.shuffle()
        moves = 0
        started = nil
        finishedSeconds = nil
        history = []
        rowFlashes = [:]
    }
    func move(_ index: Int) {
        guard finishedSeconds == nil else { return }
        let previous = board.tiles
        let previousRows = board.completedRows
        guard board.move(at: index) else { return }
        celebrateRows(after: previousRows)
        if started == nil { started = Date() }
        history.append(previous)
        moves += 1
        if board.solved {
            finishedSeconds = Int(Date().timeIntervalSince(started ?? Date()))
            if bestMoves == 0 || moves < bestMoves { bestMoves = moves }
        }
    }
    func undo() {
        guard finishedSeconds == nil, let previous = history.popLast() else { return }
        let previousRows = board.completedRows
        board.tiles = previous
        celebrateRows(after: previousRows)
        moves = max(0, moves - 1)
    }
    func celebrateRows(after previousRows: Set<Int>) {
        for row in board.completedRows.subtracting(previousRows) {
            let stamp = Date()
            rowFlashes[row] = stamp
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(850))
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<16, id: \.self) { index in
                    let value = board.tiles[index]
                    if value == 0 {
                        RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.4))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4])))
                            .aspectRatio(1, contentMode: .fit).accessibilityLabel("空きマス")
                    } else {
                        Button { withAnimation(.easeInOut(duration: 0.12)) { move(index) } } label: {
                            Text("\(value)").font(.system(size: 34, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(value == index + 1 ? accent.opacity(0.18) : Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(value == index + 1 ? accent : .primary)
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
                Text("1〜15を左上から順番に。右下を空きマスにします。 ").font(.caption).foregroundStyle(.secondary)
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

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = min(1, max(0, timeline.date.timeIntervalSince(started) / 0.85))
            Canvas { context, size in
                let fade = sin(.pi * progress)
                let frame = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: frame, cornerRadius: 14), with: .color(.cyan.opacity(fade * 0.12)))
                if !reduceMotion {
                    var bolt = Path()
                    let head = size.width * min(1, progress * 2.5)
                    let tail = max(0, head - size.width * 0.55)
                    bolt.move(to: CGPoint(x: tail, y: size.height * 0.5))
                    for step in 1...24 {
                        let x = tail + (head - tail) * CGFloat(step) / 24
                        let zigzag: CGFloat = step % 2 == 0 ? -1 : 1
                        bolt.addLine(to: CGPoint(x: x, y: size.height * 0.5 + zigzag * size.height * 0.14))
                    }
                    var glow = context
                    glow.addFilter(.blur(radius: 8))
                    glow.stroke(bolt, with: .color(.cyan.opacity(fade)), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    context.stroke(bolt, with: .color(.cyan.opacity(fade)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    context.stroke(bolt, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                context.stroke(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: 14), with: .color(.cyan.opacity(fade * 0.8)), lineWidth: 2)
            }
        }
    }
}
