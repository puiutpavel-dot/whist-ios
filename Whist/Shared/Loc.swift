import Foundation

/// Text tradus pentru o cheie din Localizable.xcstrings.
/// Limba vine automat din setările telefonului (Setări › Limbă, sau limba aleasă doar pentru aplicație);
/// dacă limba telefonului nu e printre cele 7, aplicația folosește engleza.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Text tradus cu argumente (%@ pentru texte, %ld pentru numere întregi).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}
