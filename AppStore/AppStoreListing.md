# Whist Românesc — publicare în App Store

Totul e automatizat prin Codemagic, ca la celelalte aplicații. Rămân doar câțiva pași în App Store Connect pe care API-ul Apple nu-i permite.

| Ce | Valoare |
|---|---|
| Nume în magazin | Whist Românesc |
| Nume sub iconiță | Whist |
| Bundle ID | ro.draghicioiu.whist |
| SKU | whist-ro |
| Limba principală | Română |
| Categorie | Games › Card (a doua: Board) |
| Preț | Gratuit |
| Suport | https://puiutpavel-dot.github.io/whist-legal/ |
| Confidențialitate | https://puiutpavel-dot.github.io/whist-legal/privacy.html |

## Pași, în ordine

1. **GitHub**: repo `whist-ios` (privat, codul) și `whist-legal` (public, GitHub Pages din `main`).
2. **Codemagic** → Add application → `whist-ios`. La fiecare push pe `main` rulează automat `ios-build` (verificare de compilare).
3. **Codemagic** → rulează `ios-setup` (înregistrează bundle ID-ul și profilul App Store).
4. **App Store Connect** → Apps → **+ New App**: iOS, numele de mai sus, Română, bundle ID `ro.draghicioiu.whist`, SKU `whist-ro`, acces complet.
5. În aplicația nou creată:
   - **Pricing and Availability** → Free, toate țările.
   - **App Privacy** → Data Not Collected → Publish.
   - **Age Rating** → toate întrebările „None/No” (fără pariuri, fără bani reali, fără conținut generat de utilizatori) → 4+.
   - **App Information** → Content Rights: nu conține conținut de la terți.
6. **Codemagic** → rulează `ios-appstore`: build, capturi 6.9" făcute în simulator, texte RO + EN, urcare și trimitere la review (release după aprobare).

Opțional, înainte de pasul 6: `ios-screenshots` produce doar capturile, ca să le vezi.

## Răspunsuri utile la review

- Export compliance: aplicația nu folosește criptare (`ITSAppUsesNonExemptEncryption = NO`).
- Fără cont, fără date colectate, fără internet, fără achiziții.
- Capturile se fac cu `-shot 1…7` (mod demo care aduce jocul în stările potrivite; fără argument, aplicația pornește normal).
