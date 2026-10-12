import SwiftUI
import UIKit

private struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct GameView: View {
    @StateObject private var model = GameModel()
    @State private var dragIndex: Int?
    @State private var dragPoint: CGPoint = .zero
    @State private var boardFrame: CGRect = .zero
    @State private var muted = Sound.shared.muted

    private let lift: CGFloat = 80   // piece floats above the finger so it stays visible

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 32, geo.size.height * 0.52)
            let cell = side / CGFloat(GameModel.size)

            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 22) {
                    header
                    board(side: side, cell: cell)
                    tray(cell: cell)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                if let i = dragIndex, let p = model.tray[i] {
                    PieceView(piece: p, cell: cell)
                        .position(x: dragPoint.x, y: dragPoint.y - lift)
                        .allowsHitTesting(false)
                }

                if let b = model.banner {
                    Text(b)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Capsule().fill(Theme.boardBackground.opacity(0.95)))
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: 1.5))
                        .position(x: geo.size.width / 2, y: boardFrame.minY + 4)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                if model.isGameOver { gameOver }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "root")
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.banner)
            .onChange(of: model.isGameOver) { over in if over { Sound.shared.play("gameover") } }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Picker("Mode", selection: Binding(
                    get: { model.mode },
                    set: { newMode in withAnimation { model.start(newMode) } })) {
                    Text("Classic").tag(GameMode.classic)
                    Text("Daily").tag(GameMode.daily)
                }
                .pickerStyle(.segmented)

                Button {
                    muted.toggle(); Sound.shared.muted = muted
                } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(Theme.accent).frame(width: 34, height: 34)
                }
                Button {
                    withAnimation { model.restart() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(Theme.accent).frame(width: 34, height: 34)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.mode == .daily ? "TODAY'S BEST" : "BEST")
                        .font(.caption.bold()).foregroundColor(Theme.textDim)
                    Text("\(model.best)").font(.system(.title3, design: .rounded).bold())
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(model.mode == .daily ? "DAILY CHALLENGE" : "MULBERRY BLAST")
                        .font(.caption.bold()).foregroundColor(Theme.textDim)
                    Text("\(model.score)").font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: model.score)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("COMBO").font(.caption.bold()).foregroundColor(Theme.textDim)
                    Text("x\(model.combo)").font(.system(.title3, design: .rounded).bold())
                        .foregroundColor(model.combo > 0 ? Theme.accent : Theme.textDim)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Board

    private func ghostCells(cell: CGFloat) -> (cells: Set<Cell>, color: Int)? {
        guard let i = dragIndex, let p = model.tray[i], let (r, c) = target(for: p, cell: cell) else { return nil }
        return (Set(p.cells.map { Cell(r: r + $0.r, c: c + $0.c) }), p.color)
    }

    private func target(for p: Piece, cell: CGFloat) -> (Int, Int)? {
        let w = CGFloat(p.cols) * cell, h = CGFloat(p.rows) * cell
        let x = dragPoint.x - w / 2 - boardFrame.minX
        let y = dragPoint.y - lift - h / 2 - boardFrame.minY
        let c = Int((x / cell).rounded()), r = Int((y / cell).rounded())
        return model.canPlace(p, r: r, c: c) ? (r, c) : nil
    }

    private func board(side: CGFloat, cell: CGFloat) -> some View {
        let ghost = ghostCells(cell: cell)
        return VStack(spacing: 0) {
            ForEach(0..<GameModel.size, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<GameModel.size, id: \.self) { c in
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(Theme.emptyCell)
                            if let color = model.grid[r][c] {
                                BlockView(color: color)
                                    .transition(.scale.combined(with: .opacity))
                            } else if let g = ghost, g.cells.contains(Cell(r: r, c: c)) {
                                BlockView(color: g.color).opacity(0.4)
                            }
                        }
                        .padding(1.5)
                        .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.boardBackground))
        .animation(.easeOut(duration: 0.25), value: model.grid)
        .background(
            GeometryReader { g in
                Color.clear.preference(key: BoardFrameKey.self, value: g.frame(in: .named("root")))
            }
            .padding(6)
        )
        .onPreferenceChange(BoardFrameKey.self) { boardFrame = $0 }
    }

    // MARK: Tray

    private func tray(cell: CGFloat) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    if i < model.tray.count, let p = model.tray[i] {
                        PieceView(piece: p, cell: cell * 0.55)
                            .opacity(dragIndex == i ? 0 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cell * 3)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("root"))
                        .onChanged { v in
                            guard i < model.tray.count, model.tray[i] != nil, !model.isGameOver else { return }
                            if dragIndex == nil { UIImpactFeedbackGenerator(style: .light).impactOccurred(); Sound.shared.play("tap") }
                            dragIndex = i
                            dragPoint = v.location
                        }
                        .onEnded { v in
                            dragPoint = v.location
                            if let p = model.tray[i], let (r, c) = target(for: p, cell: cell) {
                                if model.place(index: i, r: r, c: c) {
                                    let style: UIImpactFeedbackGenerator.FeedbackStyle =
                                        model.lastClear > 0 ? .heavy : .medium
                                    UIImpactFeedbackGenerator(style: style).impactOccurred()
                                    if model.lastPerfect { Sound.shared.play("perfect") }
                                    else if model.lastClear > 0 { Sound.shared.play(model.combo >= 2 ? "combo" : "clear") }
                                    else { Sound.shared.play("place") }
                                }
                            }
                            dragIndex = nil
                        }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Game over

    private var gameOver: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Game Over").font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Score \(model.score)").font(.title2.bold()).foregroundColor(Theme.accent)
                Text("Best \(model.best)").foregroundColor(Theme.textDim)
                Button {
                    withAnimation { model.restart() }
                } label: {
                    Text("Play Again")
                        .font(.headline).foregroundColor(.white)
                        .padding(.horizontal, 36).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.blocks[0]))
                }
                .padding(.top, 6)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.boardBackground))
        }
        .transition(.opacity)
    }
}

// MARK: - Building blocks

struct BlockView: View {
    let color: Int
    var body: some View {
        let base = Theme.blocks[color % Theme.blocks.count]
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [base.opacity(0.95), base.opacity(0.7)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: base.opacity(0.5), radius: 3)
    }
}

struct PieceView: View {
    let piece: Piece
    let cell: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(piece.cells, id: \.self) { c in
                BlockView(color: piece.color)
                    .padding(1.5)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(c.c) * cell, y: CGFloat(c.r) * cell)
            }
        }
        .frame(width: CGFloat(piece.cols) * cell, height: CGFloat(piece.rows) * cell, alignment: .topLeading)
    }
}
