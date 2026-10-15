# Whist — aplicație iOS nativă (SwiftUI)

Whist românesc: tu contra 2–5 adversari controlați de calculator.

## Publicare
Vezi `AppStore/AppStoreListing.md`: build-urile, capturile și fișa din magazin merg prin Codemagic (`codemagic.yaml`).

## Cum o rulezi
1. Deschide `Whist.xcodeproj` în **Xcode 16 sau mai nou**.
2. Target „Whist” → Signing & Capabilities → alege echipa ta (bundle id: `ro.draghicioiu.whist`, schimbă-l dacă vrei).
3. Rulează pe simulator sau pe iPhone (iOS 17+). Aplicația e doar pentru iPhone, în portret.

Fișierele din folderul `Whist/` sunt sincronizate automat cu proiectul — orice fișier .swift adăugat acolo intră în build.

## Reguli implementate
- 3–6 jucători, 8 cărți / jucător (A…9 la 3 jucători, A…7 la 4, A…3 la 6)
- Formate 1-8-1 și 8-1-8 (24 de mâini la 4 jucători)
- Atu = cartea întoarsă după împărțire; la mâinile de 8 — fără atu
- Licitația începe din stânga celui care împarte; ultimul nu poate face suma egală cu numărul de cărți
- Obligat la culoare, apoi obligat la atu
- Punctaj: 5 + levate la contract exact, −1 pe levată de diferență altfel
- Opțional: ±10 pentru 5 contracte reușite / ratate la rând (mâinile de o carte nu contează)

## Structură
| Fișier | Rol |
|---|---|
| `Models.swift` | Cărți, pachet, setări, secvența de mâini |
| `GameEngine.swift` | Starea jocului, licitație, levate, punctaj, ritmul adversarilor |
| `BotAI.swift` | Estimarea levatelor și alegerea cărții pentru adversari |
| `Theme.swift` | Paleta, fonturi rotunjite, butoane, panouri |
| `HomeView.swift` | Ecranul principal + setări + statistici |
| `GameView.swift` | Masa de joc, licitație, mâna ta, rezumatul mâinii |
| `ScoreboardView.swift` | Tabela de scor clasică + ecranul de reguli |
| `ScreenshotMode.swift` | Mod demo pentru capturile App Store (`-shot N`) |
