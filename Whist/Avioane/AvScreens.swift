import SwiftUI

// Toate textele de mai jos sunt chei din Localizable.xcstrings (engleză = limba sursă).
// iOS alege automat limba telefonului dintre cele 7 traduceri.

// MARK: - Root

struct AvioaneRootView: View {
    @ObservedObject private var game = GameViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LoungeBackground()
            switch game.phase {
            case .home:
                AvioaneHomeView(game: game).transition(.opacity)
            case .placement:
                PlacementView(game: game).transition(.move(edge: .trailing).combined(with: .opacity))
            case .battle:
                BattleView(game: game).transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: game.phase)
        .preferredColorScheme(.dark)
        .toolbar(game.phase == .home ? .visible : .hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(game.phase != .home)
        .onAppear { game.onAppear() }
        .onDisappear { SoundManager.shared.updateMusic(appActive: false) }
        .onChange(of: scenePhase) { newPhase in
            SoundManager.shared.updateMusic(appActive: newPhase == .active)
        }
        .alert(item: $game.alert) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Home

struct AvioaneHomeView: View {
    @ObservedObject var game: GameViewModel
    @ObservedObject private var gameCenter = GameCenter.shared
    @State private var showRules = false
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                content(compact: geo.size.height < 780)
                    .frame(minHeight: geo.size.height)
            }
        }
        .sheet(isPresented: $showRules) { AvRulesView() }
        .sheet(isPresented: $showSettings) { SettingsView(game: game) }
    }

    /// Pe ecrane joase totul se strânge; dacă tot nu încape, ecranul se derulează (nimic nu e tăiat).
    private func content(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 18) {
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.headline)
                        .foregroundStyle(AvTheme.text)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AvTheme.surfaceHigh))
                }
                .accessibilityLabel(Text("Settings"))
            }
            RadarBadge(scale: compact ? 0.62 : 1).frame(height: compact ? 96 : 150)

            VStack(spacing: compact ? 2 : 6) {
                Text(verbatim: "AVIOANE")
                    .font(.system(size: compact ? 34 : 44, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(AvTheme.text)
                Text("The classic paper game, now on iPhone")
                    .font(.subheadline)
                    .foregroundStyle(AvTheme.textDim)
            }

            HStack(spacing: 10) {
                StatTile(title: "Wins", value: "\(game.stats.wins)", tint: AvTheme.gold)
                StatTile(title: "Losses", value: "\(game.stats.losses)", tint: AvTheme.red)
                StatTile(title: "Accuracy", value: "\(game.stats.accuracy)%", tint: AvTheme.text)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text("Planes")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(AvTheme.textDim)
                Picker("Planes", selection: $game.planeChoice) {
                    ForEach(1...3, id: \.self) { n in
                        Text(verbatim: "\(n) ✈︎").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(spacing: 8) {
                Button { game.playOnline() } label: {
                    Label("Play online", systemImage: "globe")
                }
                .buttonStyle(AvPrimaryButtonStyle())

                Text(gameCenter.isAuthenticated || GameViewModel.screenshotScene != nil
                     ? LocalizedStringKey("Invite a friend or get matched with a random player.")
                     : LocalizedStringKey("Sign in to Game Center to play online."))
                    .font(.caption)
                    .foregroundStyle(AvTheme.textDim)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                SectionLabel("OR PRACTISE AGAINST THE BOT")
                Picker("Difficulty", selection: $game.difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Button { game.playBot() } label: {
                    Label("Play vs. Bot", systemImage: "cpu")
                }
                .buttonStyle(AvSecondaryButtonStyle())
            }

            HStack(spacing: 22) {
                LinkButton(title: "Rules", icon: "book.closed") { showRules = true }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, compact ? 4 : 0)
        .padding(.bottom, 16)
    }
}

struct LinkButton: View {
    let title: LocalizedStringKey
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.headline)
                Text(title)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(AvTheme.gold)
            .frame(maxWidth: .infinity)
        }
    }
}

struct RadarBadge: View {
    var scale: CGFloat = 1
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .stroke(AvTheme.red.opacity(0.28), lineWidth: 1)
                    .frame(width: CGFloat(i) * 55 * scale, height: CGFloat(i) * 55 * scale)
            }
            Circle()
                .fill(AngularGradient(colors: [AvTheme.red.opacity(0), AvTheme.red.opacity(0), AvTheme.red.opacity(0.5)],
                                      center: .center))
                .frame(width: 165 * scale, height: 165 * scale)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Image(systemName: "airplane")
                .font(.system(size: 48 * scale, weight: .bold))
                .foregroundStyle(AvTheme.goldGradient)
                .rotationEffect(.degrees(-45))
                .shadow(color: AvTheme.gold.opacity(0.4), radius: 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .textCase(.uppercase)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(AvTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AvTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.06)))
    }
}

// MARK: - Hangar (plasare)

struct PlacementView: View {
    @ObservedObject var game: GameViewModel

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760
            // Spațiul rămas pentru grilă după bara de sus, butoane și „Gata de luptă”.
            let reserved: CGFloat = (compact ? 310 : 345) + (game.mode == .online ? 24 : 0)
            let side = max(200, min(geo.size.width - 32, geo.size.height - reserved))
            content(compact: compact, side: side)
        }
    }

    private func content(compact: Bool, side: CGFloat) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            TopBar(title: "Your hangar", onBack: game.goHome)

            if game.mode == .online {
                Label("vs. \(game.opponentName)", systemImage: "globe")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(AvTheme.gold)
            }

            Text("Drag a plane to move it. Tap it again to rotate it, or tap an empty square to move it there.")
                .font(compact ? .caption : .footnote)
                .foregroundStyle(AvTheme.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Panel {
                GridView(
                    style: game.placementStyle(for:),
                    drag: GridDrag(began: game.dragBegan(at:),
                                   changed: game.dragChanged(to:),
                                   ended: game.dragEnded(at:moved:))
                )
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: game.playerPlanes)

            HStack(spacing: 10) {
                ForEach(game.playerPlanes) { p in
                    PlaneChip(plane: p,
                              selected: p.id == game.selectedPlaneID,
                              invalid: game.invalidPlaneIDs.contains(p.id)) {
                        game.selectPlane(p.id)
                    }
                }
            }

            HStack(spacing: 12) {
                Button { game.rotateSelected() } label: { Label("Rotate", systemImage: "rotate.right") }
                    .buttonStyle(AvSecondaryButtonStyle())
                Button { game.randomizeLayout() } label: { Label("Shuffle", systemImage: "shuffle") }
                    .buttonStyle(AvSecondaryButtonStyle())
            }

            Spacer(minLength: 0)

            if !game.layoutIsValid {
                Label("Red planes overlap or leave the grid.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AvTheme.red)
            }

            Button { game.confirmPlacement() } label: {
                Label("Ready for battle!", systemImage: "scope")
            }
            .buttonStyle(AvPrimaryButtonStyle())
            .disabled(!game.layoutIsValid)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .overlay {
            if game.onlineStatus == .waitingForOpponent {
                WaitingOverlay(opponent: game.opponentName, onLeave: game.goHome)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.onlineStatus)
    }
}

struct WaitingOverlay: View {
    let opponent: String
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(AvTheme.gold).scaleEffect(1.4)
                Text("Waiting for \(opponent)…")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(AvTheme.text)
                    .multilineTextAlignment(.center)
                Text("Your opponent is still placing their planes.")
                    .font(.subheadline)
                    .foregroundStyle(AvTheme.textDim)
                    .multilineTextAlignment(.center)
                Button(action: onLeave) { Label("Leave match", systemImage: "xmark") }
                    .buttonStyle(AvSecondaryButtonStyle())
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AvTheme.surface))
            .padding(24)
        }
    }
}

struct PlaneChip: View {
    let plane: Plane
    let selected: Bool
    let invalid: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "airplane")
                    .rotationEffect(.degrees(plane.orientation.symbolAngle))
                Text("Plane \(plane.id + 1)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(selected ? AvTheme.bg : AvTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(selected ? AnyShapeStyle(AvTheme.goldGradient) : AnyShapeStyle(AvTheme.surfaceHigh)))
            .overlay(Capsule().stroke(invalid ? AvTheme.red : .white.opacity(0.08), lineWidth: invalid ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bătălia

struct BattleView: View {
    @ObservedObject var game: GameViewModel
    @State private var confirmQuit = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760
            let mini: CGFloat = compact ? 118 : 150
            let side = max(200, min(geo.size.width - 32, geo.size.height - (compact ? 375 : 410)))
            content(compact: compact, side: side, mini: mini)
        }
    }

    private func content(compact: Bool, side: CGFloat, mini: CGFloat) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            TopBar(title: "Battle") {
                if game.outcome == nil { confirmQuit = true } else { game.goHome() }
            }

            TurnPill(text: game.turnText, active: game.canFire || game.outcome != nil)

            HStack {
                SectionLabel("ATTACK RADAR")
                Spacer()
                Text(game.opponentName)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(AvTheme.textDim)
                    .lineLimit(1)
                PlanesLeft(remaining: game.enemyBoard.remaining, total: game.enemyBoard.totalPlanes, tint: AvTheme.red)
            }

            Panel {
                GridView(style: game.enemyStyle(for:), onTap: game.fire(at:), fx: game.radarFX)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: game.enemyBoard.marks)
            .modifier(Shake(animatableData: CGFloat(game.radarShake)))
            .animation(.linear(duration: 0.4), value: game.radarShake)
            .allowsHitTesting(game.canFire)
            .opacity(game.isPlayerTurn || game.outcome != nil ? 1 : 0.8)

            MessageCard(mine: game.playerMessage, theirs: game.enemyMessage)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("YOUR BOARD")
                    Panel(padding: 6) {
                        GridView(style: game.playerStyle(for:), fx: game.ownFX, compact: true)
                    }
                    .frame(width: mini)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: game.playerBoard.marks)
                    .modifier(Shake(amount: 4, animatableData: CGFloat(game.ownShake)))
                    .animation(.linear(duration: 0.4), value: game.ownShake)
                }
                VStack(alignment: .leading, spacing: 12) {
                    StatLine(title: "Shots fired", value: "\(game.shots)")
                    StatLine(title: "Accuracy", value: "\(game.accuracy)%")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your planes").font(.caption).foregroundStyle(AvTheme.textDim)
                        PlanesLeft(remaining: game.playerBoard.remaining, total: game.playerBoard.totalPlanes, tint: AvTheme.gold)
                    }
                }
                .padding(.top, compact ? 16 : 22)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .overlay {
            if let outcome = game.outcome {
                ResultOverlay(
                    won: outcome == .won,
                    title: game.resultTitle,
                    subtitle: game.resultSubtitle,
                    shots: game.shots,
                    accuracy: game.accuracy,
                    canRematch: game.canRematch,
                    onRematch: game.rematch,
                    onMenu: game.goHome
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: game.outcome)
        .confirmationDialog("Leave the match?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { game.goHome() }
            Button("Keep fighting", role: .cancel) {}
        }
    }
}

struct TurnPill: View {
    let text: String
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(active ? AvTheme.gold : AvTheme.red)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(AvTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(AvTheme.surfaceHigh))
        .overlay(Capsule().stroke((active ? AvTheme.gold : AvTheme.red).opacity(0.4)))
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}

struct MessageCard: View {
    let mine: String
    let theirs: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mine)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AvTheme.text)
            if !theirs.isEmpty {
                Text(theirs)
                    .font(.footnote)
                    .foregroundStyle(AvTheme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AvTheme.surface))
    }
}

struct StatLine: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(AvTheme.textDim)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(AvTheme.text)
                .monospacedDigit()
        }
    }
}

struct ResultOverlay: View {
    let won: Bool
    let title: String
    let subtitle: String
    let shots: Int
    let accuracy: Int
    let canRematch: Bool
    let onRematch: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: won ? "trophy.fill" : "airplane.departure")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(won ? AnyShapeStyle(AvTheme.goldGradient) : AnyShapeStyle(AvTheme.redGradient))
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(AvTheme.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AvTheme.textDim)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    StatTile(title: "Shots", value: "\(shots)", tint: AvTheme.text)
                    StatTile(title: "Accuracy", value: "\(accuracy)%", tint: AvTheme.gold)
                }
                Button(action: onRematch) { Label("Rematch", systemImage: "arrow.clockwise") }
                    .buttonStyle(AvPrimaryButtonStyle())
                    .disabled(!canRematch)
                Button(action: onMenu) { Label("Menu", systemImage: "house") }
                    .buttonStyle(AvSecondaryButtonStyle())
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(AvTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AvTheme.gold.opacity(0.25)))
            .padding(16)
        }
    }
}

// MARK: - Reguli

struct AvRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rule("1. The board", "Each player has a 10×10 grid (A–J, 1–10): your board with your planes, and the attack radar where you see your own shots.")
                    VStack(alignment: .leading, spacing: 10) {
                        rule("2. The plane", "Each player has 3 planes of 10 squares: the nose (cockpit), 5-square wings, the body and a 3-square tail. They can be rotated in 4 directions.")
                        ShapePreview().frame(maxWidth: .infinity)
                    }
                    rule("3. Placement", "Planes cannot overlap or leave the grid. They may touch side by side.")
                    rule("4. Attack", "Players take turns firing one shot. The answer is always one of three: 🌊 Water, 💥 Hit or ✈️ Destroyed.")
                    rule("5. Destroyed", "A plane goes down instantly if you hit its nose, or once all 10 of its squares are hit. A downed plane is shown in full on the radar.")
                    rule("6. Victory", "The first player to shoot down all 3 of the opponent's planes wins.")
                    rule("1, 2 or 3 planes", "Before a match, choose how many planes each player has. Online, Auto-Match pairs you with players who chose the same number; with a friend, the smaller choice is used.")
                    rule("Online", "Play with a friend or a random opponent through Game Center. Your planes stay on your phone — your opponent only learns the result of each shot.")
                }
                .padding(20)
            }
            .background(AvTheme.bg)
            .navigationTitle("Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rule(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(AvTheme.gold)
            Text(body)
                .font(.body)
                .foregroundStyle(AvTheme.text.opacity(0.85))
        }
    }
}

/// Desenul avionului pe o mini-grilă 5×4.
struct ShapePreview: View {
    var body: some View {
        let cells = Set(Plane.shapeUp.map { Coord(row: $0.0, col: $0.1 + 2) })
        VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { c in
                        let coord = Coord(row: r, col: c)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(cells.contains(coord)
                                  ? (r == 0 ? AnyShapeStyle(AvTheme.goldGradient) : AnyShapeStyle(AvTheme.ship))
                                  : AnyShapeStyle(AvTheme.surfaceHigh))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(AvTheme.surface))
    }
}
