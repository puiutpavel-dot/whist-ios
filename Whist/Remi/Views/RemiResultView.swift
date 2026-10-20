import SwiftUI

struct RemiResultView: View {
    @ObservedObject var engine: RemiEngine
    let onExit: () -> Void

    private var result: HandResult? { engine.state.result }

    private var headline: String {
        guard let result else { return "" }
        if let closer = result.closer {
            return closer == engine.human ? L("result.youClosed") : L("result.closed", engine.names[closer])
        }
        return L("result.stockOut")
    }

    var body: some View {
        ZStack {
            RemiTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Image(systemName: result?.closer == engine.human ? "crown.fill" : "flag.checkered")
                            .font(.system(size: 34))
                            .foregroundStyle(RemiTheme.gold)
                        Text(headline)
                            .font(.system(size: 24, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                        if let t = result?.closingTile {
                            HStack(spacing: 6) {
                                Text(L("result.closingTile")).foregroundStyle(RemiTheme.textDim)
                                TileView(tile: t, size: .mini)
                            }
                            .font(.footnote)
                        }
                        if result?.doubleGame == true {
                            Badge(text: L("game.double"), color: RemiTheme.crimson)
                        }
                    }
                    .padding(.top, 24)

                    VStack(spacing: 0) {
                        HStack {
                            Text(L("result.player")).frame(maxWidth: .infinity, alignment: .leading)
                            Text(L("result.melded")).frame(width: 52, alignment: .trailing)
                            Text(L("result.rack")).frame(width: 48, alignment: .trailing)
                            Text(L("result.hand")).frame(width: 56, alignment: .trailing)
                            Text(L("result.total")).frame(width: 58, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(RemiTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)

                        ForEach(result?.players ?? []) { r in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(r.name).bold().frame(maxWidth: .infinity, alignment: .leading)
                                    Text(verbatim: "\(r.melded)").frame(width: 52, alignment: .trailing)
                                    Text(r.inHand > 0 ? "−\(r.inHand)" : "0").frame(width: 48, alignment: .trailing)
                                    Text(r.total > 0 ? "+\(r.total)" : "\(r.total)")
                                        .bold()
                                        .foregroundStyle(r.total >= 0 ? RemiTheme.feltLight : RemiTheme.crimson)
                                        .frame(width: 56, alignment: .trailing)
                                    Text(verbatim: "\(engine.totals[r.id])").bold().frame(width: 58, alignment: .trailing)
                                }
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white)
                                if !r.note.isEmpty {
                                    Text(r.note).font(.caption2).foregroundStyle(RemiTheme.textDim)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(r.id == engine.human ? RemiTheme.panelLight : Color.clear)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(RemiTheme.panel))

                    if engine.isMatchOver {
                        let best = engine.totals.max() ?? 0
                        let winners = engine.names.indices.filter { engine.totals[$0] == best }.map { engine.names[$0] }
                        VStack(spacing: 4) {
                            Text(L("result.matchOver"))
                                .font(.headline).foregroundStyle(RemiTheme.textDim)
                            Text(L("result.winner", winners.joined(separator: L("result.and")), best))
                                .font(.system(size: 20, weight: .black, design: .serif))
                                .foregroundStyle(RemiTheme.gold)
                                .multilineTextAlignment(.center)
                        }
                        Button(L("result.newMatch")) { engine.restartMatch() }
                            .buttonStyle(PillButtonStyle(prominent: true))
                        Button(L("game.exitToMenu"), action: onExit)
                            .buttonStyle(PillButtonStyle())
                    } else {
                        Button(L("result.nextHand")) { engine.nextHand() }
                            .buttonStyle(PillButtonStyle(prominent: true))
                        Button(L("game.exitToMenu"), action: onExit)
                            .buttonStyle(PillButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }
}
