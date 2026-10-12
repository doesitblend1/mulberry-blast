import SwiftUI

struct Cell: Hashable { let r: Int; let c: Int }

struct Piece: Identifiable, Equatable {
    let id = UUID()
    let cells: [Cell]
    let color: Int
    var rows: Int { (cells.map(\.r).max() ?? 0) + 1 }
    var cols: Int { (cells.map(\.c).max() ?? 0) + 1 }
}

enum GameMode: String { case classic, daily }

/// Deterministic RNG so everyone gets the same Daily Challenge on a given date.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private let shapeDefs: [[String]] = [
    ["#"], ["##"], ["#", "#"], ["###"], ["#", "#", "#"],
    ["####"], ["#", "#", "#", "#"], ["#####"], ["#", "#", "#", "#", "#"],
    ["##", "##"], ["###", "###", "###"], ["###", "###"], ["##", "##", "##"],
    ["#.", "##"], [".#", "##"], ["##", "#."], ["##", ".#"],
    ["#..", "#..", "###"], ["..#", "..#", "###"], ["###", "#..", "#.."], ["###", "..#", "..#"],
    ["#.", "#.", "##"], [".#", ".#", "##"], ["##", "#.", "#."], ["##", ".#", ".#"],
    ["###", ".#."], [".#.", "###"], ["#.", "##", "#."], [".#", "##", ".#"],
    ["##.", ".##"], [".##", "##."], [".#", "##", "#."], ["#.", "##", ".#"],
]

private let shapes: [[Cell]] = shapeDefs.map { rows in
    var cells: [Cell] = []
    for (r, line) in rows.enumerated() {
        for (c, ch) in line.enumerated() where ch == "#" { cells.append(Cell(r: r, c: c)) }
    }
    return cells
}

final class GameModel: ObservableObject {
    static let size = 8
    static let perfectBonus = 200

    @Published var grid: [[Int?]] = GameModel.emptyGrid()
    @Published var tray: [Piece?] = []
    @Published var score = 0
    @Published var combo = 0
    @Published var isGameOver = false
    @Published var lastClear = 0
    @Published var lastPerfect = false
    @Published var banner: String?
    @Published var mode: GameMode = .classic
    @Published var best = 0

    private var rng = SplitMix64(state: 0)
    private var seeded = false

    init() { start(.classic) }

    // MARK: Modes / persistence

    static func todayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private var bestKey: String {
        mode == .classic ? "mulberryblast.best" : "mulberryblast.daily.\(GameModel.todayKey())"
    }

    static func emptyGrid() -> [[Int?]] {
        Array(repeating: Array(repeating: nil, count: size), count: size)
    }

    func start(_ newMode: GameMode) {
        mode = newMode
        grid = GameModel.emptyGrid()
        score = 0; combo = 0; lastClear = 0; lastPerfect = false
        isGameOver = false; banner = nil
        best = UserDefaults.standard.integer(forKey: bestKey)

        if newMode == .daily {
            seeded = true
            rng = SplitMix64(state: UInt64(GameModel.todayKey())! &* 2654435761)
            // A few pre-placed blocks so each day starts with its own puzzle.
            for _ in 0..<(6 + Int(rng.next() % 5)) {
                let r = Int(rng.next() % UInt64(GameModel.size))
                let c = Int(rng.next() % UInt64(GameModel.size))
                grid[r][c] = Int(rng.next() % UInt64(Theme.blocks.count))
            }
        } else {
            seeded = false
        }
        tray = newTray()
    }

    func restart() { start(mode) }

    // MARK: Rules

    func canPlace(_ p: Piece, r: Int, c: Int) -> Bool {
        for cell in p.cells {
            let rr = r + cell.r, cc = c + cell.c
            guard rr >= 0, rr < GameModel.size, cc >= 0, cc < GameModel.size else { return false }
            if grid[rr][cc] != nil { return false }
        }
        return true
    }

    func fitsAnywhere(_ p: Piece) -> Bool {
        for r in 0..<GameModel.size {
            for c in 0..<GameModel.size where canPlace(p, r: r, c: c) { return true }
        }
        return false
    }

    @discardableResult
    func place(index: Int, r: Int, c: Int) -> Bool {
        guard index < tray.count, let p = tray[index], canPlace(p, r: r, c: c) else { return false }
        for cell in p.cells { grid[r + cell.r][c + cell.c] = p.color }
        score += p.cells.count

        let n = GameModel.size
        let fullRows = (0..<n).filter { r in grid[r].allSatisfy { $0 != nil } }
        let fullCols = (0..<n).filter { c in (0..<n).allSatisfy { grid[$0][c] != nil } }
        let lines = fullRows.count + fullCols.count
        lastClear = lines
        lastPerfect = false

        if lines > 0 {
            combo += 1
            score += 10 * lines * lines + 5 * combo * lines
            for r in fullRows { for c in 0..<n { grid[r][c] = nil } }
            for c in fullCols { for r in 0..<n { grid[r][c] = nil } }

            if grid.allSatisfy({ $0.allSatisfy { $0 == nil } }) {
                lastPerfect = true
                score += GameModel.perfectBonus
                showBanner("PERFECT CLEAR  +\(GameModel.perfectBonus)")
            } else if combo >= 2 {
                showBanner("COMBO x\(combo)")
            }
        } else {
            combo = 0
        }

        tray[index] = nil
        if tray.allSatisfy({ $0 == nil }) { tray = newTray() }
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: bestKey)
        }
        if !tray.contains(where: { $0.map(fitsAnywhere) ?? false }) {
            isGameOver = true
        }
        return true
    }

    private func showBanner(_ text: String) {
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            if self?.banner == text { self?.banner = nil }
        }
    }

    // MARK: Piece generation

    private func randomPiece() -> Piece {
        if seeded {
            let s = shapes[Int(rng.next() % UInt64(shapes.count))]
            return Piece(cells: s, color: Int(rng.next() % UInt64(Theme.blocks.count)))
        }
        return Piece(cells: shapes.randomElement()!, color: Int.random(in: 0..<Theme.blocks.count))
    }

    private func newTray() -> [Piece?] {
        var set: [Piece] = []
        for _ in 0..<40 {
            set = (0..<3).map { _ in randomPiece() }
            if set.contains(where: fitsAnywhere) { break }
        }
        return set
    }
}
