import SwiftUI

struct RemiGameView: View {
    @ObservedObject var engine: RemiEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false
    @State private var confirmExit = false

    private var state: RemiState { engine.state }

    var body: some View {
        ZStack {
            RemiTheme.background.ignoresSafeArea()
            VStack(spacing: 8) {
                topBar
                opponents
                table
                centerStrip
                statusLine
                handRack
                actionBar
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            if let message = engine.message {
                MessageBanner(text: message) { engine.message = nil }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 210)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.message)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $engine.showResult) {
            RemiResultView(engine: engine) {
                engine.showResult = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showRules) { RemiRulesView() }
        .confirmationDialog(L("game.exitTitle"), isPresented: $confirmExit, titleVisibility: .visible) {
            Button(L("game.exitToMenu"), role: .destructive) {
                engine.stop()
                dismiss()
            }
            Button(L("game.newGame")) { engine.restartMatch() }
            Button(L("game.continue"), role: .cancel) {}
        }
    }

    // MARK: - Bara de sus

    private var topBar: some View {
        HStack {
            Button { confirmExit = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(RemiTheme.panelLight))
            }
            .foregroundStyle(.white)

            Spacer()
            VStack(spacing: 0) {
                Text(verbatim: "REMI ETALAT")
                    .font(.system(size: 13, weight: .black, design: .serif))
                    .tracking(3)
                    .foregroundStyle(RemiTheme.gold)
                Text(L("game.handOf", engine.handNumber, engine.handsToPlay) + (state.doubleGame ? " · " + L("game.double") : ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.doubleGame ? RemiTheme.crimson : RemiTheme.textDim)
            }
            Spacer()

            Button { showRules = true } label: {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(RemiTheme.panelLight))
            }
            .foregroundStyle(.white)
        }
    }

    // MARK: - Adversari

    private var opponents: some View {
        HStack(spacing: 8) {
            ForEach(state.players.filter { $0.id != engine.human }) { p in
                PlayerChip(player: p, total: engine.totals[p.id], isActive: state.current == p.id && state.phase != .handOver)
            }
        }
    }

    // MARK: - Masa (formațiile etalate)

    private var table: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                let owners = state.players.filter { p in state.melds.contains { $0.owner == p.id } }
                if owners.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "suit.spade.fill").font(.title2)
                        Text(state.isFirstRound && state.current == engine.human
                             ? L("game.firstRoundNoMelds")
                             : L("game.noMelds"))
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                ForEach(owners) { owner in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(owner.id == engine.human ? L("game.yourMelds") : owner.name.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(RemiTheme.gold.opacity(0.85))
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(state.melds.filter { $0.owner == owner.id }) { meld in
                                MeldView(meld: meld,
                                         highlighted: engine.canPlaceSelected(on: meld),
                                         isNew: state.meldsCreatedThisTurn.contains(meld.id) && state.current == engine.human)
                                    .onTapGesture { engine.tapMeld(meld) }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RemiTheme.felt)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [RemiTheme.gold.opacity(0.6), RemiTheme.woodDark],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
        )
    }

    // MARK: - Grămada, atu, șir

    private var centerStrip: some View {
        HStack(spacing: 10) {
            Button { engine.drawStock() } label: {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        TileBack(size: .table).offset(x: -3, y: -3)
                        TileBack(size: .table)
                    }
                    Text(verbatim: "\(state.stock.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.75)))
                        .foregroundStyle(.white)
                        .offset(x: 6, y: 5)
                }
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(RemiTheme.gold, lineWidth: engine.isHumanTurn && state.phase == .draw ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                if let atu = state.atu {
                    Button { engine.takeAtu() } label: { TileView(tile: atu, size: .table) }
                        .buttonStyle(.plain)
                } else {
                    TileView(tile: state.atuTile, size: .table, faded: true)
                }
                Text(L("game.atu")).font(.system(size: 8, weight: .black)).tracking(1).foregroundStyle(RemiTheme.gold)
            }

            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 40)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        if state.row.isEmpty {
                            Text(L("game.rowPlaceholder"))
                                .font(.caption2).foregroundStyle(RemiTheme.textDim)
                        }
                        ForEach(Array(state.row.enumerated()), id: \.element.id) { index, tile in
                            Group {
                                if index == 0 {
                                    // Prima piesă stă orizontal și nu se folosește.
                                    TileView(tile: tile, size: .table, faded: true)
                                        .rotationEffect(.degrees(90))
                                        .frame(width: TileSize.table.height, height: TileSize.table.height)
                                } else {
                                    TileView(tile: tile, size: .table)
                                }
                            }
                            .id(tile.id)
                            .onTapGesture { engine.tapRow(index: index) }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .onChange(of: state.row.count) { _, _ in
                    if let last = state.row.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .trailing) }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 14).fill(RemiTheme.panel))
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            if engine.botThinking {
                ProgressView().controlSize(.mini).tint(RemiTheme.gold)
            }
            Text(engine.statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(engine.isHumanTurn ? RemiTheme.gold : RemiTheme.textDim)
            Spacer()
            if let last = state.log.last {
                Text(last)
                    .font(.system(size: 11))
                    .foregroundStyle(RemiTheme.textDim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Tabla jucătorului

    private var handRack: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(engine.me.name.uppercased())
                    .font(.system(size: 11, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(RemiTheme.gold)
                if engine.me.opened { Badge(text: L("game.opened"), color: RemiTheme.feltLight) }
                if engine.me.hasAtuBonus { Badge(text: L("game.atuBonus"), color: RemiTheme.crimsonDark) }
                Spacer()
                Text(L("game.tilesPoints", engine.me.hand.count, engine.totals[engine.human]))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RemiTheme.textDim)
            }
            FlowLayout(spacing: 4, lineSpacing: 10) {
                ForEach(engine.humanHand) { tile in
                    TileView(tile: tile, size: .hand,
                             selected: engine.selected.contains(tile.id),
                             marked: state.mustUseTileID == tile.id && state.current == engine.human)
                        .onTapGesture { engine.toggle(tile) }
                }
            }
            .padding(.top, 8)
            .frame(minHeight: 130, alignment: .top)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RemiTheme.wood)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(state.current == engine.human && state.phase != .handOver
                                      ? RemiTheme.gold : Color.white.opacity(0.06), lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: engine.humanHand.map(\.id))
    }

    private var actionBar: some View {
        HStack(spacing: 6) {
            Button { engine.undoTurn() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(PillButtonStyle())
                .disabled(!engine.canUndo)
                .opacity(engine.canUndo ? 1 : 0.4)
            Button { engine.suggest() } label: { Image(systemName: "lightbulb.fill") }
                .buttonStyle(PillButtonStyle())
            Button {
                engine.sortMode = engine.sortMode == .color ? .number : .color
            } label: {
                Image(systemName: engine.sortMode == .color ? "paintpalette.fill" : "number")
            }
            .buttonStyle(PillButtonStyle())
            Spacer(minLength: 4)
            Button { engine.makeMeld() } label: { Label(L("game.meldButton"), systemImage: "square.stack.3d.up.fill") }
                .buttonStyle(PillButtonStyle())
                .disabled(!engine.isHumanTurn || engine.selected.count < 3)
                .opacity(engine.isHumanTurn && engine.selected.count >= 3 ? 1 : 0.45)
            if engine.isHumanTurn && state.phase == .draw {
                // Întâi se trage: butonul principal ia o piesă din grămadă.
                Button { engine.drawStock() } label: { Label(L("game.drawButton"), systemImage: "square.stack.3d.down.right.fill") }
                    .buttonStyle(PillButtonStyle(prominent: true))
            } else {
                Button { engine.discardSelected() } label: { Label(L("game.discardButton"), systemImage: "arrow.down.to.line") }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(!engine.isHumanTurn || state.phase != .play || engine.selected.count != 1)
                    .opacity(engine.isHumanTurn && state.phase == .play && engine.selected.count == 1 ? 1 : 0.45)
            }
        }
    }
}

// MARK: - Componente

struct MeldView: View {
    let meld: Meld
    var highlighted = false
    var isNew = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(meld.slots) { slot in
                TileView(tile: slot.tile, size: .table,
                         marked: slot.fixedScore != nil || slot.jokerReused)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(highlighted ? 0.35 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(highlighted ? RemiTheme.gold : (isNew ? Color.white.opacity(0.5) : .clear),
                              style: StrokeStyle(lineWidth: highlighted ? 2 : 1, dash: isNew && !highlighted ? [4, 3] : []))
        )
        .shadow(color: highlighted ? RemiTheme.gold.opacity(0.5) : .clear, radius: 6)
        .contentShape(Rectangle())
    }
}

struct PlayerChip: View {
    let player: RemiPlayer
    let total: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(RemiTheme.crimsonGradient)
                Text(String(player.name.prefix(1)))
                    .font(.system(size: 15, weight: .black, design: .serif))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(RemiTheme.gold, lineWidth: isActive ? 2 : 0))

            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.3x3.fill").font(.system(size: 8))
                    Text(verbatim: "\(player.hand.count)")
                    Text(verbatim: "· \(total)p")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(player.hand.count <= 3 && player.turnsTaken > 0 ? RemiTheme.crimson : RemiTheme.textDim)
            }
            Spacer(minLength: 0)
            if player.opened {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(RemiTheme.feltLight)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? RemiTheme.panelLight : RemiTheme.panel)
        )
        .overlay(alignment: .topTrailing) {
            if player.hand.count <= 3 && player.turnsTaken > 0 {
                Text(L("chip.left", player.hand.count))
                    .font(.system(size: 7, weight: .black))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Capsule().fill(RemiTheme.crimson))
                    .foregroundStyle(.white)
                    .offset(x: 2, y: -6)
            }
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .black))
            .tracking(0.8)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(color))
            .foregroundStyle(.white)
    }
}

struct MessageBanner: View {
    let text: String
    let onClose: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(RemiTheme.gold)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(RemiTheme.textDim)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RemiTheme.panelLight)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RemiTheme.crimson.opacity(0.7)))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
        .task(id: text) {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            onClose()
        }
    }
}
