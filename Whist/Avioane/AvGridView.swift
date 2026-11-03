import SwiftUI

/// Callback-uri pentru drag & drop pe grilă (folosite în hangar).
struct GridDrag {
    var began: (Coord) -> Void
    var changed: (Coord) -> Void
    var ended: (_ start: Coord, _ moved: Bool) -> Void
}

/// Grila 10×10 cu litere A–J sus și cifre 1–10 în stânga.
struct GridView: View {
    let style: (Coord) -> CellStyle
    var onTap: ((Coord) -> Void)? = nil
    var drag: GridDrag? = nil
    var fx: ShotFX? = nil
    var compact = false

    @State private var dragStart: Coord?
    @State private var lastCell: Coord?
    @State private var moved = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let label: CGFloat = compact ? 11 : 18
            let cell = (side - label) / CGFloat(Board.size)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: label, height: label)
                    ForEach(0..<Board.size, id: \.self) { c in
                        axisText(Board.letters[c]).frame(width: cell, height: label)
                    }
                }
                ForEach(0..<Board.size, id: \.self) { r in
                    HStack(spacing: 0) {
                        axisText("\(r + 1)").frame(width: label, height: cell)
                        ForEach(0..<Board.size, id: \.self) { c in
                            let coord = Coord(row: r, col: c)
                            if let onTap {
                                CellView(style: style(coord), size: cell)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(coord) }
                            } else {
                                CellView(style: style(coord), size: cell)
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .overlay {
                if let fx {
                    FXLayer(fx: fx, label: label, cell: cell, side: side)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(label: label, cell: cell), including: drag == nil ? .subviews : .all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func coord(at p: CGPoint, label: CGFloat, cell: CGFloat) -> Coord {
        Coord(row: Int(floor((p.y - label) / cell)), col: Int(floor((p.x - label) / cell)))
    }

    private func dragGesture(label: CGFloat, cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let drag else { return }
                if dragStart == nil {
                    let start = coord(at: value.startLocation, label: label, cell: cell)
                    dragStart = start
                    lastCell = start
                    moved = false
                    drag.began(start)
                }
                let c = coord(at: value.location, label: label, cell: cell)
                if c != lastCell {
                    moved = true
                    lastCell = c
                    drag.changed(c)
                }
            }
            .onEnded { value in
                let start = dragStart ?? coord(at: value.startLocation, label: label, cell: cell)
                drag?.ended(start, moved)
                dragStart = nil
                lastCell = nil
                moved = false
            }
    }

    private func axisText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: compact ? 7 : 10, weight: .bold, design: .rounded))
            .foregroundStyle(AvTheme.textDim)
    }
}

struct CellView: View {
    let style: CellStyle
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(AvTheme.cell)
            content
        }
        .frame(width: size, height: size)
        .overlay(Rectangle().stroke(AvTheme.gridLine, lineWidth: 0.5))
    }

    private var radius: CGFloat { size * 0.2 }
    private var inset: CGFloat { size * 0.08 }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .water:
            EmptyView()

        case let .ship(head, state):
            RoundedRectangle(cornerRadius: radius)
                .fill(shipFill(head: head, state: state))
                .padding(inset)
                .overlay {
                    if head {
                        Circle().fill(AvTheme.bg.opacity(0.7)).frame(width: size * 0.22)
                    }
                }

        case let .shipHit(head):
            RoundedRectangle(cornerRadius: radius)
                .fill(AvTheme.shipDark)
                .padding(inset)
                .overlay {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(head ? AvTheme.gold : AvTheme.hit)
                }

        case .miss:
            ZStack {
                Circle().stroke(AvTheme.water.opacity(0.35), lineWidth: 1).frame(width: size * 0.5)
                Circle().fill(AvTheme.water).frame(width: size * 0.22)
            }
            .transition(.scale.combined(with: .opacity))

        case .hit:
            RoundedRectangle(cornerRadius: radius)
                .fill(AvTheme.hit)
                .padding(inset)
                .overlay {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: AvTheme.hit.opacity(0.6), radius: 4)
                .transition(.scale.combined(with: .opacity))

        case let .wreck(head):
            RoundedRectangle(cornerRadius: radius)
                .fill(AvTheme.redGradient)
                .padding(inset)
                .overlay {
                    Image(systemName: head ? "scope" : "xmark")
                        .font(.system(size: size * (head ? 0.55 : 0.4), weight: .heavy))
                        .foregroundStyle(head ? AvTheme.gold : .white.opacity(0.85))
                }
                .shadow(color: AvTheme.red.opacity(0.5), radius: 4)
                .transition(.scale.combined(with: .opacity))

        case let .ghost(head):
            RoundedRectangle(cornerRadius: radius)
                .stroke(head ? AvTheme.gold : AvTheme.ship.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .padding(inset)
        }
    }

    private func shipFill(head: Bool, state: ShipState) -> LinearGradient {
        switch state {
        case .invalid:
            return AvTheme.redGradient
        case .selected:
            return head ? LinearGradient(colors: [.white, AvTheme.gold], startPoint: .top, endPoint: .bottom) : AvTheme.goldGradient
        case .normal:
            return head
                ? AvTheme.goldGradient
                : LinearGradient(colors: [AvTheme.ship, AvTheme.shipDark], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Animații de bătălie

/// Desenează proiectilul sau impactul peste grilă, aliniat la căsuțe.
struct FXLayer: View {
    let fx: ShotFX
    let label: CGFloat
    let cell: CGFloat
    let side: CGFloat

    private func center(_ c: Coord) -> CGPoint {
        CGPoint(x: label + (CGFloat(c.col) + 0.5) * cell,
                y: label + (CGFloat(c.row) + 0.5) * cell)
    }

    var body: some View {
        ZStack {
            switch fx.kind {
            case .launch:
                ProjectileView(from: CGPoint(x: side / 2, y: side + cell), to: center(fx.coord), size: cell)
            case .impact(let kind):
                if kind == .destroyed {
                    // Avionul „arde”: explozii în lanț pe fiecare pătrățel.
                    ForEach(Array(fx.cells.enumerated()), id: \.offset) { i, c in
                        BurstView(kind: .destroyed, size: cell * 0.8, delay: 0.05 + Double(i) * 0.045)
                            .position(center(c))
                    }
                }
                BurstView(kind: kind, size: cell, delay: 0)
                    .position(center(fx.coord))
            }
        }
        .frame(width: side, height: side)
        .id(fx.id) // fiecare lovitură pornește animația de la zero
        .allowsHitTesting(false)
    }
}

/// Proiectilul care pleacă de jos și coboară pe țintă.
struct ProjectileView: View {
    let from: CGPoint
    let to: CGPoint
    let size: CGFloat
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(AvTheme.gold.opacity(0.35))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: 4)
            Circle()
                .fill(RadialGradient(colors: [.white, AvTheme.gold], center: .center, startRadius: 0, endRadius: size * 0.2))
                .frame(width: size * 0.38, height: size * 0.38)
        }
        .scaleEffect(1.8 - 0.8 * progress)
        .position(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
        .onAppear {
            withAnimation(.easeIn(duration: 0.26)) { progress = 1 }
        }
    }
}

/// Impactul: inele de apă la ratare, explozie cu scântei la lovitură.
struct BurstView: View {
    let kind: NetResult
    let size: CGFloat
    let delay: Double
    @State private var go = false

    private var color: Color {
        switch kind {
        case .miss: return AvTheme.water
        case .hit: return AvTheme.hit
        case .destroyed: return AvTheme.red
        }
    }

    private var duration: Double { kind == .destroyed ? 0.85 : 0.6 }

    var body: some View {
        ZStack {
            // Unda de șoc / valul
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(go ? (kind == .miss ? 2.2 : 3.0) : 0.2)
                .opacity(go ? 0 : 0.9)
            if kind == .miss {
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .scaleEffect(go ? 1.5 : 0.1)
                    .opacity(go ? 0 : 0.8)
            } else {
                // Mingea de foc
                Circle()
                    .fill(RadialGradient(colors: [.white, AvTheme.gold, color, color.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: size))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(go ? 1.15 : 0.1)
                    .opacity(go ? 0 : 1)
                // Scântei
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) / 8 * 2 * .pi
                    let reach = size * (kind == .destroyed ? 1.9 : 1.4)
                    Circle()
                        .fill(i.isMultiple(of: 2) ? AvTheme.gold : color)
                        .frame(width: size * 0.18, height: size * 0.18)
                        .offset(x: go ? CGFloat(cos(angle)) * reach : 0, y: go ? CGFloat(sin(angle)) * reach : 0)
                        .opacity(go ? 0 : 1)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: duration).delay(delay)) { go = true }
        }
    }
}

/// Tremuratul panoului la lovitură. Crește `shakes` ca să pornești din nou efectul.
struct Shake: GeometryEffect {
    var amount: CGFloat = 5
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit * 2), y: 0))
    }
}
