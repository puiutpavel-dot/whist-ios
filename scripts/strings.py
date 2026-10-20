#!/usr/bin/env python3
"""Sursa unică pentru traducerile aplicației. Rulează `python3 scripts/strings.py`
ca să regenerezi Whist/Localizable.xcstrings (Whist, Remi, Renț și meniul principal).

Ordinea limbilor în fiecare tuplu: ro, en, de, fr, it, es, hu.
Argumentele sunt poziționale (%1$@, %2$ld), ca fiecare limbă să le poată reordona.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from strings_whist import W  # noqa: E402
from strings_rentz import R, H  # noqa: E402

LANGS = ["ro", "en", "de", "fr", "it", "es", "hu"]

S = {
    # ---------- Piese și culori ----------
    "color.red": ("roșu", "red", "Rot", "rouge", "rosso", "rojo", "piros"),
    "color.yellow": ("galben", "yellow", "Gelb", "jaune", "giallo", "amarillo", "sárga"),
    "color.blue": ("albastru", "blue", "Blau", "bleu", "blu", "azul", "kék"),
    "color.black": ("negru", "black", "Schwarz", "noir", "nero", "negro", "fekete"),
    "tile.label": ("%1$ld %2$@", "%2$@ %1$ld", "%2$@ %1$ld", "%1$ld %2$@", "%1$ld %2$@", "%1$ld %2$@", "%2$@ %1$ld"),
    "tile.joker": ("Joker", "Joker", "Joker", "Joker", "Jolly", "Comodín", "Joker"),
    "tile.jokerFace": ("JOLY", "JOKER", "JOKER", "JOKER", "JOLLY", "COMODÍN", "JOKER"),

    # ---------- Nume ----------
    "name.you": ("Tu", "You", "Du", "Vous", "Tu", "Tú", "Te"),
    "bot.1": ("Gică", "Bob", "Klaus", "Pierre", "Gino", "Paco", "Laci"),
    "bot.2": ("Lili", "Lily", "Heidi", "Margot", "Lucia", "Lola", "Zsuzsa"),
    "bot.3": ("Mitică", "Mike", "Otto", "Marcel", "Beppe", "Manolo", "Feri"),

    # ---------- Erori de reguli ----------
    "err.alreadyDrew": (
        "Ai luat deja o piesă în tura asta.",
        "You've already taken a tile this turn.",
        "Du hast in diesem Zug schon einen Stein genommen.",
        "Vous avez déjà pris une tuile ce tour-ci.",
        "Hai già preso una tessera in questo turno.",
        "Ya has cogido una ficha en este turno.",
        "Ebben a körben már vettél fel lapkát."),
    "err.firstRoundStockOnly": (
        "În prima rundă se trage doar din grămadă.",
        "In the first round you can only draw from the pile.",
        "In der ersten Runde ziehst du nur vom Stapel.",
        "Au premier tour, on pioche uniquement dans la pioche.",
        "Al primo giro si pesca solo dal pozzo.",
        "En la primera ronda solo se roba del montón.",
        "Az első körben csak a halomból húzhatsz."),
    "err.firstRowTile": (
        "Prima piesă din șir nu poate fi folosită.",
        "The first tile in the discard row can't be used.",
        "Der erste Stein der Ablagereihe darf nicht genommen werden.",
        "La première tuile de la rangée ne peut pas être utilisée.",
        "La prima tessera della fila non si può usare.",
        "La primera ficha de la fila no se puede usar.",
        "A sor első lapkáját nem lehet felhasználni."),
    "err.lowTilesStockOnly": (
        "Cu 1–2 piese pe tablă ești obligat să tragi din grămadă.",
        "With 1–2 tiles on your rack you must draw from the pile.",
        "Mit 1–2 Steinen auf der Bank musst du vom Stapel ziehen.",
        "Avec 1 ou 2 tuiles sur le chevalet, vous devez piocher.",
        "Con 1–2 tessere sul leggio devi pescare dal pozzo.",
        "Con 1–2 fichas en el atril debes robar del montón.",
        "1–2 lapkával a tartón kötelező a halomból húzni."),
    "err.breakNeedsOpen": (
        "Poți rupe șirul doar după ce te-ai etalat.",
        "You can break the row only after you've laid down.",
        "Du darfst die Reihe erst aufbrechen, wenn du ausgelegt hast.",
        "Vous ne pouvez couper la rangée qu'après avoir posé.",
        "Puoi spezzare la fila solo dopo aver calato.",
        "Solo puedes romper la fila después de haber bajado.",
        "A sort csak a lerakás után törheted meg."),
    "err.threeTilesLastOnly": (
        "Cu 3 piese pe tablă poți lua doar ultima piesă din șir.",
        "With 3 tiles on your rack you can only take the last tile in the row.",
        "Mit 3 Steinen darfst du nur den letzten Stein der Reihe nehmen.",
        "Avec 3 tuiles, vous ne pouvez prendre que la dernière tuile de la rangée.",
        "Con 3 tessere puoi prendere solo l'ultima tessera della fila.",
        "Con 3 fichas solo puedes coger la última ficha de la fila.",
        "3 lapkával csak a sor utolsó lapkáját veheted fel."),
    "err.notInRow": (
        "Piesa nu mai e în șir.",
        "That tile is no longer in the row.",
        "Dieser Stein liegt nicht mehr in der Reihe.",
        "Cette tuile n'est plus dans la rangée.",
        "La tessera non è più nella fila.",
        "La ficha ya no está en la fila.",
        "Ez a lapka már nincs a sorban."),
    "err.atuTaken": (
        "Atuul a fost deja luat.",
        "The trump tile has already been taken.",
        "Der Trumpfstein wurde schon genommen.",
        "L'atout a déjà été pris.",
        "La briscola è già stata presa.",
        "El triunfo ya se ha cogido.",
        "Az adut már felvették."),
    "err.drawFirst": (
        "Întâi ia o piesă.",
        "Take a tile first.",
        "Nimm zuerst einen Stein.",
        "Prenez d'abord une tuile.",
        "Prima prendi una tessera.",
        "Primero coge una ficha.",
        "Előbb vegyél fel egy lapkát."),
    "err.noMeldFirstRound": (
        "În prima rundă nu se poate etala.",
        "You can't lay down in the first round.",
        "In der ersten Runde darf nicht ausgelegt werden.",
        "On ne peut pas poser au premier tour.",
        "Al primo giro non si può calare.",
        "En la primera ronda no se puede bajar.",
        "Az első körben nem lehet lerakni."),
    "err.noNewMeldsLow": (
        "Cu 1–2 piese pe tablă nu mai poți face formații, doar lipiri.",
        "With 1–2 tiles left you can't make new melds, only add to existing ones.",
        "Mit 1–2 Steinen darfst du nur noch anlegen, keine neuen Kombinationen.",
        "Avec 1 ou 2 tuiles, vous ne pouvez plus que compléter des combinaisons.",
        "Con 1–2 tessere puoi solo attaccare, non fare nuove combinazioni.",
        "Con 1–2 fichas solo puedes añadir, no hacer combinaciones nuevas.",
        "1–2 lapkával már csak hozzátenni lehet, új kombinációt nem."),
    "err.selectThree": (
        "Selectează minim 3 piese pentru o formație.",
        "Select at least 3 tiles to make a meld.",
        "Wähle mindestens 3 Steine für eine Kombination.",
        "Sélectionnez au moins 3 tuiles pour une combinaison.",
        "Seleziona almeno 3 tessere per una combinazione.",
        "Selecciona al menos 3 fichas para una combinación.",
        "Válassz ki legalább 3 lapkát egy kombinációhoz."),
    "err.keepClosingTile": (
        "Trebuie să-ți rămână o piesă cu care să închizi.",
        "You must keep one tile to discard when you go out.",
        "Du brauchst noch einen Stein zum Ausmachen.",
        "Il doit vous rester une tuile pour fermer.",
        "Ti deve restare una tessera per chiudere.",
        "Te tiene que quedar una ficha para cerrar.",
        "Kell maradnia egy lapkának, amellyel zársz."),
    "err.twoJokers": (
        "O formație cu 2 Jokeri are nevoie de încă 4 piese reale (și Jokerii nu stau alăturați).",
        "A meld with 2 Jokers needs 4 more real tiles, and the Jokers can't sit next to each other.",
        "Eine Kombination mit 2 Jokern braucht 4 echte Steine, und die Joker dürfen nicht nebeneinander liegen.",
        "Une combinaison avec 2 Jokers demande 4 vraies tuiles, et les Jokers ne peuvent pas se toucher.",
        "Una combinazione con 2 Jolly richiede altre 4 tessere vere e i Jolly non possono stare vicini.",
        "Una combinación con 2 comodines necesita 4 fichas reales y los comodines no pueden ir juntos.",
        "2 Jokerrel a kombinációhoz még 4 valódi lapka kell, és a Jokerek nem lehetnek egymás mellett."),
    "err.invalidMeld": (
        "Nu e o formație validă: suită (aceeași culoare, consecutive) sau terță (același număr, culori diferite).",
        "Not a valid meld: a run (same color, consecutive) or a group (same number, different colors).",
        "Keine gültige Kombination: Reihe (gleiche Farbe, fortlaufend) oder Gruppe (gleiche Zahl, verschiedene Farben).",
        "Combinaison invalide : suite (même couleur, consécutives) ou série (même nombre, couleurs différentes).",
        "Combinazione non valida: scala (stesso colore, consecutive) o gruppo (stesso numero, colori diversi).",
        "Combinación no válida: escalera (mismo color, seguidas) o grupo (mismo número, colores distintos).",
        "Érvénytelen kombináció: sor (azonos szín, egymást követő) vagy csoport (azonos szám, eltérő színek)."),
    "err.addNeedsOpen": (
        "Poți lipi la formațiile de pe masă doar din tura de după prima etalare.",
        "You can add to melds on the table from the turn after you first lay down.",
        "Anlegen darfst du erst ab dem Zug nach deinem ersten Auslegen.",
        "Vous pouvez compléter les combinaisons à partir du tour qui suit votre première pose.",
        "Puoi attaccare alle combinazioni dal turno dopo la prima calata.",
        "Puedes añadir a las combinaciones desde el turno siguiente a tu primera bajada.",
        "Az asztalon lévő kombinációkhoz az első lerakás utáni körtől tehetsz."),
    "err.jokerOthers": (
        "Jokerul nu se poate lipi la formațiile altor jucători.",
        "A Joker can't be added to another player's meld.",
        "Ein Joker darf nicht bei anderen Spielern angelegt werden.",
        "Un Joker ne peut pas compléter la combinaison d'un autre joueur.",
        "Il Jolly non si può attaccare alle combinazioni degli altri.",
        "El comodín no se puede añadir a combinaciones de otros jugadores.",
        "Jokert nem tehetsz más játékos kombinációjához."),
    "err.doesntFit": (
        "%@ nu se potrivește la formația asta.",
        "%@ doesn't fit this meld.",
        "%@ passt nicht an diese Kombination.",
        "%@ ne va pas avec cette combinaison.",
        "%@ non va bene per questa combinazione.",
        "%@ no encaja en esta combinación.",
        "%@ nem illik ehhez a kombinációhoz."),
    "err.replaceNeedsOpen": (
        "Poți schimba un Joker doar după ce te-ai etalat.",
        "You can swap a Joker only after you've laid down.",
        "Einen Joker tauschen darfst du erst nach dem Auslegen.",
        "Vous ne pouvez échanger un Joker qu'après avoir posé.",
        "Puoi scambiare un Jolly solo dopo aver calato.",
        "Solo puedes cambiar un comodín después de haber bajado.",
        "Jokert csak a lerakás után cserélhetsz."),
    "err.noJokerToReplace": (
        "%@ nu înlocuiește niciun Joker din formația asta.",
        "%@ doesn't replace any Joker in this meld.",
        "%@ ersetzt keinen Joker in dieser Kombination.",
        "%@ ne remplace aucun Joker de cette combinaison.",
        "%@ non sostituisce nessun Jolly in questa combinazione.",
        "%@ no sustituye a ningún comodín de esta combinación.",
        "%@ egyetlen Jokert sem vált ki ebben a kombinációban."),
    "err.notInHand": (
        "Piesa nu e pe tabla ta.",
        "That tile isn't on your rack.",
        "Dieser Stein liegt nicht auf deiner Bank.",
        "Cette tuile n'est pas sur votre chevalet.",
        "La tessera non è sul tuo leggio.",
        "Esa ficha no está en tu atril.",
        "Ez a lapka nincs a tartódon."),
    "err.atuMustClose": (
        "Atuul se ia doar dacă faci formație cu el și închizi în aceeași tură.",
        "You can take the trump tile only if you meld it and go out in the same turn.",
        "Den Trumpf darfst du nur nehmen, wenn du ihn auslegst und im selben Zug ausmachst.",
        "L'atout ne se prend que si vous le posez et fermez dans le même tour.",
        "La briscola si prende solo se la cali e chiudi nello stesso turno.",
        "El triunfo solo se coge si lo bajas y cierras en el mismo turno.",
        "Az adut csak akkor veheted fel, ha kombinációba teszed és ugyanabban a körben zársz."),
    "err.rowTileMustBeUsed": (
        "Piesa luată din șir trebuie folosită într-o formație nouă în tura asta.",
        "The tile taken from the row must go into a new meld this turn.",
        "Der Stein aus der Reihe muss in diesem Zug in eine neue Kombination.",
        "La tuile prise dans la rangée doit entrer dans une nouvelle combinaison ce tour-ci.",
        "La tessera presa dalla fila va usata in una nuova combinazione in questo turno.",
        "La ficha cogida de la fila debe usarse en una combinación nueva este turno.",
        "A sorból felvett lapkát ebben a körben új kombinációba kell tenni."),
    "err.firstMeldRule": (
        "Prima etalare: minim 45 de puncte și cel puțin o suită (sau o terță de 1). Ai %ld puncte.",
        "First lay-down: at least 45 points with at least one run (or a group of 1s). You have %ld points.",
        "Erstes Auslegen: mindestens 45 Punkte mit mindestens einer Reihe (oder einer Gruppe aus Einsen). Du hast %ld Punkte.",
        "Première pose : au moins 45 points avec au moins une suite (ou une série de 1). Vous avez %ld points.",
        "Prima calata: almeno 45 punti con almeno una scala (o un gruppo di 1). Hai %ld punti.",
        "Primera bajada: al menos 45 puntos con al menos una escalera (o un grupo de unos). Tienes %ld puntos.",
        "Első lerakás: legalább 45 pont, legalább egy sorral (vagy egy egyesekből álló csoporttal). Neked %ld pontod van."),
    "err.atuCloseNow": (
        "Ai luat atuul: trebuie să închizi în tura asta (să-ți rămână doar piesa de închidere).",
        "You took the trump tile: you must go out this turn, keeping only the closing tile.",
        "Du hast den Trumpf genommen: Du musst in diesem Zug ausmachen und nur den letzten Stein behalten.",
        "Vous avez pris l'atout : vous devez fermer ce tour-ci, avec seulement la tuile de fermeture.",
        "Hai preso la briscola: devi chiudere in questo turno, tenendo solo la tessera di chiusura.",
        "Has cogido el triunfo: debes cerrar este turno y quedarte solo con la ficha de cierre.",
        "Felvetted az adut: ebben a körben zárnod kell, csak a záró lapka maradhat."),
    "err.selectOneDiscard": (
        "Selectează o singură piesă de aruncat.",
        "Select exactly one tile to discard.",
        "Wähle genau einen Stein zum Ablegen.",
        "Sélectionnez une seule tuile à défausser.",
        "Seleziona una sola tessera da scartare.",
        "Selecciona una sola ficha para descartar.",
        "Válassz ki pontosan egy lapkát eldobásra."),

    # ---------- Jurnal și note de scor ----------
    "log.atu": ("Atu: %@", "Trump: %@", "Trumpf: %@", "Atout : %@", "Briscola: %@", "Triunfo: %@", "Adu: %@"),
    "log.atuDouble": (
        "Atu: %@ — joc dublu!", "Trump: %@ — double game!", "Trumpf: %@ — doppeltes Spiel!",
        "Atout : %@ — partie double !", "Briscola: %@ — gioco doppio!", "Triunfo: %@ — ¡partida doble!",
        "Adu: %@ — dupla játék!"),
    "log.hasAtu": (
        "%@ are atuul (+50).", "%@ holds the trump tile (+50).", "%@ hat den Trumpfstein (+50).",
        "%@ a l'atout (+50).", "%@ ha la briscola (+50).", "%@ tiene el triunfo (+50).", "%@ kezében az adu (+50)."),
    "log.opened": (
        "%@ s-a etalat.", "%@ laid down.", "%@ hat ausgelegt.", "%@ a posé.", "%@ ha calato.",
        "%@ ha bajado.", "%@ lerakott."),
    "log.closed": (
        "%1$@ a închis cu %2$@!", "%1$@ went out with %2$@!", "%1$@ macht aus mit %2$@!",
        "%1$@ ferme avec %2$@ !", "%1$@ chiude con %2$@!", "¡%1$@ cierra con %2$@!", "%1$@ zárt ezzel: %2$@!"),
    "log.stockEmpty": (
        "S-au terminat grămezile.", "The pile has run out.", "Der Stapel ist leer.", "La pioche est vide.",
        "Il pozzo è finito.", "Se acabó el montón.", "Elfogyott a halom."),
    "note.closed": (
        "a închis (+100)", "went out (+100)", "ausgemacht (+100)", "a fermé (+100)", "ha chiuso (+100)",
        "cerró (+100)", "zárt (+100)"),
    "note.closedJoker": (
        "închis cu Joker ×2", "out with a Joker ×2", "mit Joker ausgemacht ×2", "fermé avec un Joker ×2",
        "chiuso col Jolly ×2", "cerró con comodín ×2", "Jokerrel zárt ×2"),
    "note.closedOne": (
        "închis cu 1 ×2", "out with a 1 ×2", "mit einer 1 ausgemacht ×2", "fermé avec un 1 ×2",
        "chiuso con un 1 ×2", "cerró con un 1 ×2", "1-essel zárt ×2"),
    "note.notOpened": (
        "neetalat (−100)", "never laid down (−100)", "nicht ausgelegt (−100)", "n'a pas posé (−100)",
        "non ha calato (−100)", "no bajó (−100)", "nem rakott le (−100)"),
    "note.atu": ("atu +50", "trump +50", "Trumpf +50", "atout +50", "briscola +50", "triunfo +50", "adu +50"),
    "note.double": (
        "joc dublu ×2", "double game ×2", "doppeltes Spiel ×2", "partie double ×2", "gioco doppio ×2",
        "partida doble ×2", "dupla játék ×2"),

    # ---------- Stare și mesaje în joc ----------
    "status.handOver": (
        "Mâna s-a terminat.", "The hand is over.", "Das Spiel ist vorbei.", "La manche est terminée.",
        "La mano è finita.", "La mano ha terminado.", "A leosztás véget ért."),
    "status.botPlaying": (
        "%@ joacă…", "%@ is playing…", "%@ ist am Zug…", "%@ joue…", "%@ sta giocando…", "%@ está jugando…",
        "%@ következik…"),
    "status.drawFirstRound": (
        "Trage o piesă din grămadă.", "Draw a tile from the pile.", "Zieh einen Stein vom Stapel.",
        "Piochez une tuile.", "Pesca una tessera dal pozzo.", "Roba una ficha del montón.",
        "Húzz egy lapkát a halomból."),
    "status.drawLow": (
        "Cu 1–2 piese tragi doar din grămadă.", "With 1–2 tiles you can only draw from the pile.",
        "Mit 1–2 Steinen ziehst du nur vom Stapel.", "Avec 1 ou 2 tuiles, vous piochez uniquement.",
        "Con 1–2 tessere peschi solo dal pozzo.", "Con 1–2 fichas solo robas del montón.",
        "1–2 lapkával csak a halomból húzhatsz."),
    "status.draw": (
        "Trage din grămadă sau ia din șir.", "Draw from the pile or take from the row.",
        "Zieh vom Stapel oder nimm aus der Reihe.", "Piochez ou prenez dans la rangée.",
        "Pesca dal pozzo o prendi dalla fila.", "Roba del montón o coge de la fila.",
        "Húzz a halomból vagy vegyél a sorból."),
    "status.firstRoundDiscard": (
        "Prima rundă: aruncă o piesă în șir.", "First round: discard a tile to the row.",
        "Erste Runde: Leg einen Stein in die Reihe ab.", "Premier tour : défaussez une tuile.",
        "Primo giro: scarta una tessera nella fila.", "Primera ronda: descarta una ficha en la fila.",
        "Első kör: dobj el egy lapkát a sorba."),
    "status.addOnly": (
        "Lipește ce poți, apoi aruncă o piesă.", "Add what you can, then discard a tile.",
        "Leg an, was du kannst, dann leg einen Stein ab.", "Complétez ce que vous pouvez, puis défaussez.",
        "Attacca ciò che puoi, poi scarta una tessera.", "Añade lo que puedas y descarta una ficha.",
        "Tedd hozzá, amit tudsz, aztán dobj el egy lapkát."),
    "status.openFirst": (
        "Etalează minim 45p (cu o suită), apoi aruncă.", "Lay down 45+ points (with a run), then discard.",
        "Leg mind. 45 Punkte aus (mit einer Reihe), dann ablegen.", "Posez 45 pts min. (avec une suite), puis défaussez.",
        "Cala almeno 45 punti (con una scala), poi scarta.", "Baja 45 puntos o más (con una escalera) y descarta.",
        "Rakj le legalább 45 pontot (egy sorral), aztán dobj."),
    "status.play": (
        "Etalează, lipește sau schimbă Jokeri, apoi aruncă.", "Lay down, add or swap Jokers, then discard.",
        "Auslegen, anlegen oder Joker tauschen, dann ablegen.", "Posez, complétez ou échangez un Joker, puis défaussez.",
        "Cala, attacca o scambia Jolly, poi scarta.", "Baja, añade o cambia comodines y luego descarta.",
        "Rakj le, tegyél hozzá vagy cserélj Jokert, aztán dobj."),
    "msg.selectForAdd": (
        "Selectează piesa pe care vrei s-o lipești, apoi atinge formația.",
        "Select the tile you want to add, then tap the meld.",
        "Wähle den Stein zum Anlegen und tippe dann auf die Kombination.",
        "Sélectionnez la tuile à ajouter, puis touchez la combinaison.",
        "Seleziona la tessera da attaccare, poi tocca la combinazione.",
        "Selecciona la ficha que quieres añadir y toca la combinación.",
        "Válaszd ki a lapkát, majd koppints a kombinációra."),
    "msg.tookJoker": (
        "Ai luat Jokerul! Îl poți folosi în altă formație.",
        "You got the Joker! Use it in another meld.",
        "Du hast den Joker! Nutze ihn in einer anderen Kombination.",
        "Vous avez le Joker ! Utilisez-le dans une autre combinaison.",
        "Hai preso il Jolly! Usalo in un'altra combinazione.",
        "¡Tienes el comodín! Úsalo en otra combinación.",
        "Megszerezted a Jokert! Használd egy másik kombinációban."),
    "msg.canMeld": (
        "Poți face formația selectată.", "You can lay down the selected meld.",
        "Du kannst die markierte Kombination auslegen.", "Vous pouvez poser la combinaison sélectionnée.",
        "Puoi calare la combinazione selezionata.", "Puedes bajar la combinación seleccionada.",
        "A kijelölt kombinációt lerakhatod."),
    "msg.openingPlan": (
        "Ai %ld formații pentru etalare — începe cu cea selectată.",
        "You have %ld melds to lay down. Start with the selected one.",
        "Du hast %ld Kombinationen zum Auslegen. Fang mit der markierten an.",
        "Vous avez %ld combinaisons à poser. Commencez par celle sélectionnée.",
        "Hai %ld combinazioni da calare. Inizia da quella selezionata.",
        "Tienes %ld combinaciones para bajar. Empieza por la seleccionada.",
        "%ld kombinációt rakhatsz le. Kezdd a kijelölttel."),
    "msg.canAdd": (
        "%@ se poate lipi pe masă.", "%@ can be added to a meld on the table.",
        "%@ kannst du auf dem Tisch anlegen.", "%@ peut compléter une combinaison.",
        "%@ si può attaccare sul tavolo.", "%@ se puede añadir en la mesa.",
        "%@ hozzátehető egy kombinációhoz."),
    "msg.discardHint": (
        "Nu vezi formații. Ți-aș arunca %@.", "No melds in sight. I'd discard %@.",
        "Keine Kombination in Sicht. Ich würde %@ ablegen.", "Aucune combinaison en vue. Je défausserais %@.",
        "Nessuna combinazione in vista. Io scarterei %@.", "No hay combinaciones. Yo descartaría %@.",
        "Nincs kombináció. Én ezt dobnám el: %@."),

    # ---------- Ecranul de joc ----------
    "game.handOf": (
        "Mâna %1$ld din %2$ld", "Hand %1$ld of %2$ld", "Spiel %1$ld von %2$ld", "Manche %1$ld sur %2$ld",
        "Mano %1$ld di %2$ld", "Mano %1$ld de %2$ld", "%1$ld. leosztás / %2$ld"),
    "game.double": ("JOC DUBLU", "DOUBLE GAME", "DOPPELT", "PARTIE DOUBLE", "GIOCO DOPPIO", "PARTIDA DOBLE", "DUPLA JÁTÉK"),
    "game.firstRoundNoMelds": (
        "Prima rundă — nu se etalează încă.", "First round: no laying down yet.",
        "Erste Runde: noch kein Auslegen.", "Premier tour : pas encore de pose.",
        "Primo giro: non si cala ancora.", "Primera ronda: aún no se baja.",
        "Első kör: még nem lehet lerakni."),
    "game.noMelds": (
        "Nicio formație etalată încă.", "No melds on the table yet.", "Noch keine Kombinationen ausgelegt.",
        "Aucune combinaison posée.", "Nessuna combinazione calata.", "Aún no hay combinaciones en la mesa.",
        "Még nincs kombináció az asztalon."),
    "game.yourMelds": (
        "FORMAȚIILE TALE", "YOUR MELDS", "DEINE KOMBINATIONEN", "VOS COMBINAISONS", "LE TUE COMBINAZIONI",
        "TUS COMBINACIONES", "A KOMBINÁCIÓID"),
    "game.atu": ("ATU", "TRUMP", "TRUMPF", "ATOUT", "BRISCOLA", "TRIUNFO", "ADU"),
    "game.rowPlaceholder": (
        "Șirul de piese aruncate", "Discard row", "Ablagereihe", "Rangée de défausse", "Fila degli scarti",
        "Fila de descartes", "Eldobott lapkák sora"),
    "game.opened": ("ETALAT", "LAID DOWN", "AUSGELEGT", "POSÉ", "CALATO", "BAJADO", "LERAKOTT"),
    "game.atuBonus": ("ATU +50", "TRUMP +50", "TRUMPF +50", "ATOUT +50", "BRISCOLA +50", "TRIUNFO +50", "ADU +50"),
    "game.tilesPoints": (
        "%1$ld piese · %2$ld p", "%1$ld tiles · %2$ld pts", "%1$ld Steine · %2$ld P.", "%1$ld tuiles · %2$ld pts",
        "%1$ld tessere · %2$ld pt", "%1$ld fichas · %2$ld pts", "%1$ld lapka · %2$ld p"),
    "game.meldButton": ("Etalează", "Lay down", "Auslegen", "Poser", "Cala", "Bajar", "Lerak"),
    "game.drawButton": ("Trage", "Draw", "Ziehen", "Piocher", "Pesca", "Robar", "Húzás"),
    "game.discardButton": ("Aruncă", "Discard", "Ablegen", "Défausser", "Scarta", "Descartar", "Eldob"),
    "game.exitTitle": (
        "Ieși din joc?", "Leave the game?", "Spiel verlassen?", "Quitter la partie ?", "Uscire dalla partita?",
        "¿Salir de la partida?", "Kilépsz a játékból?"),
    "game.exitToMenu": (
        "Ieși la meniu", "Back to menu", "Zum Menü", "Retour au menu", "Torna al menu", "Volver al menú",
        "Vissza a menübe"),
    "game.newGame": ("Joc nou", "New game", "Neues Spiel", "Nouvelle partie", "Nuova partita", "Nueva partida", "Új játék"),
    "game.continue": ("Continuă", "Keep playing", "Weiterspielen", "Continuer", "Continua", "Seguir jugando", "Folytatás"),
    "chip.left": ("MAI ARE %ld", "%ld LEFT", "NOCH %ld", "PLUS QUE %ld", "ANCORA %ld", "LE QUEDAN %ld", "MÉG %ld"),

    # ---------- Rezultate ----------
    "result.youClosed": (
        "Ai închis jocul!", "You went out!", "Du hast ausgemacht!", "Vous avez fermé !", "Hai chiuso!",
        "¡Has cerrado!", "Te zártál!"),
    "result.closed": (
        "%@ a închis jocul", "%@ went out", "%@ hat ausgemacht", "%@ a fermé", "%@ ha chiuso", "%@ ha cerrado",
        "%@ zárt"),
    "result.stockOut": (
        "S-au terminat grămezile", "The pile ran out", "Der Stapel ist leer", "La pioche est vide",
        "Il pozzo è finito", "Se acabó el montón", "Elfogyott a halom"),
    "result.closingTile": (
        "Piesa de închidere:", "Closing tile:", "Letzter Stein:", "Tuile de fermeture :", "Tessera di chiusura:",
        "Ficha de cierre:", "Záró lapka:"),
    "result.player": ("Jucător", "Player", "Spieler", "Joueur", "Giocatore", "Jugador", "Játékos"),
    "result.melded": ("Etalat", "Melded", "Ausgelegt", "Posé", "Calato", "Bajado", "Lerakva"),
    "result.rack": ("Tablă", "Rack", "Bank", "Chevalet", "Leggio", "Atril", "Tartó"),
    "result.hand": ("Mână", "Hand", "Spiel", "Manche", "Mano", "Mano", "Leosztás"),
    "result.total": ("Total", "Total", "Gesamt", "Total", "Totale", "Total", "Összesen"),
    "result.matchOver": (
        "Partida s-a încheiat", "The match is over", "Die Partie ist vorbei", "La partie est terminée",
        "La partita è finita", "La partida ha terminado", "A játszma véget ért"),
    "result.winner": (
        "Câștigă %1$@ cu %2$ld puncte", "%1$@ wins with %2$ld points", "%1$@ gewinnt mit %2$ld Punkten",
        "%1$@ gagne avec %2$ld points", "Vince %1$@ con %2$ld punti", "Gana %1$@ con %2$ld puntos",
        "%1$@ nyert %2$ld ponttal"),
    "result.and": (" și ", " and ", " und ", " et ", " e ", " y ", " és "),
    "result.newMatch": ("Partidă nouă", "New match", "Neue Partie", "Nouvelle partie", "Nuova partita", "Nueva partida", "Új játszma"),
    "result.nextHand": ("Mâna următoare", "Next hand", "Nächstes Spiel", "Manche suivante", "Mano successiva", "Siguiente mano", "Következő leosztás"),

    # ---------- Meniu ----------
    "menu.tagline": (
        "Jocul românesc cu piese, contra calculatorului",
        "The classic Romanian tile rummy, against the computer",
        "Das rumänische Rommé mit Steinen, gegen den Computer",
        "Le rami roumain aux tuiles, contre l'ordinateur",
        "Il ramino rumeno con le tessere, contro il computer",
        "El rummy rumano de fichas, contra el ordenador",
        "A román römi kövekkel, a gép ellen"),
    "menu.play": ("Joacă", "Play", "Spielen", "Jouer", "Gioca", "Jugar", "Játék"),
    "menu.rules": ("Regulile jocului", "How to play", "Spielregeln", "Règles du jeu", "Regole del gioco", "Reglas del juego", "Játékszabály"),
    "menu.yourName": ("NUMELE TĂU", "YOUR NAME", "DEIN NAME", "VOTRE NOM", "IL TUO NOME", "TU NOMBRE", "A NEVED"),
    "menu.players": ("JUCĂTORI LA MASĂ", "PLAYERS AT THE TABLE", "SPIELER AM TISCH", "JOUEURS À LA TABLE", "GIOCATORI AL TAVOLO", "JUGADORES EN LA MESA", "JÁTÉKOSOK AZ ASZTALNÁL"),
    "menu.hands": ("MÂINI PE PARTIDĂ", "HANDS PER MATCH", "SPIELE PRO PARTIE", "MANCHES PAR PARTIE", "MANI PER PARTITA", "MANOS POR PARTIDA", "LEOSZTÁS JÁTSZMÁNKÉNT"),

    # ---------- Reguli ----------
    "rules.title": ("Reguli", "Rules", "Regeln", "Règles", "Regole", "Reglas", "Szabályok"),
    "rules.done": ("Gata", "Done", "Fertig", "OK", "Fine", "Listo", "Kész"),
    "rules.s1": ("Setul", "The set", "Das Spiel", "Le matériel", "Il set", "El juego", "A készlet"),
    "rules.s1.1": (
        "106 piese: numere de la 1 la 13 în patru culori (roșu, galben, albastru, negru), câte două serii, plus 2 Jokeri (Joly).",
        "106 tiles: numbers 1 to 13 in four colors (red, yellow, blue, black), two of each, plus 2 Jokers.",
        "106 Steine: Zahlen von 1 bis 13 in vier Farben (Rot, Gelb, Blau, Schwarz), je zweimal, dazu 2 Joker.",
        "106 tuiles : nombres de 1 à 13 en quatre couleurs (rouge, jaune, bleu, noir), en double, plus 2 Jokers.",
        "106 tessere: numeri da 1 a 13 in quattro colori (rosso, giallo, blu, nero), due serie, più 2 Jolly.",
        "106 fichas: números del 1 al 13 en cuatro colores (rojo, amarillo, azul, negro), dos de cada, y 2 comodines.",
        "106 lapka: 1-től 13-ig négy színben (piros, sárga, kék, fekete), mindegyikből kettő, plusz 2 Joker."),
    "rules.s1.2": (
        "Se joacă în 2, 3 sau 4 jucători. Cine începe primește 15 piese, ceilalți câte 14.",
        "2, 3 or 4 players. Whoever starts gets 15 tiles, everyone else 14.",
        "2, 3 oder 4 Spieler. Wer beginnt, bekommt 15 Steine, alle anderen 14.",
        "2, 3 ou 4 joueurs. Celui qui commence reçoit 15 tuiles, les autres 14.",
        "Da 2, 3 o 4 giocatori. Chi inizia riceve 15 tessere, gli altri 14.",
        "De 2, 3 o 4 jugadores. Quien empieza recibe 15 fichas; los demás, 14.",
        "2, 3 vagy 4 játékos. Aki kezd, 15 lapkát kap, a többiek 14-et."),
    "rules.s1.3": (
        "O piesă e întoarsă la început: atuul. Dacă atuul e 1 sau Joker, toată mâna se joacă la dublu.",
        "One tile is turned face up at the start: the trump. If the trump is a 1 or a Joker, the whole hand scores double.",
        "Zu Beginn wird ein Stein aufgedeckt: der Trumpf. Ist er eine 1 oder ein Joker, zählt das ganze Spiel doppelt.",
        "Une tuile est retournée au début : l'atout. Si c'est un 1 ou un Joker, toute la manche compte double.",
        "All'inizio si scopre una tessera: la briscola. Se è un 1 o un Jolly, tutta la mano vale doppio.",
        "Al empezar se descubre una ficha: el triunfo. Si es un 1 o un comodín, toda la mano cuenta doble.",
        "Az elején felfordítanak egy lapkát: ez az adu. Ha 1-es vagy Joker, az egész leosztás duplán számít."),
    "rules.s1.4": (
        "Cine are de la început piesa identică cu atuul primește 50 de puncte la final.",
        "Whoever is dealt the twin of the trump tile gets 50 bonus points at the end.",
        "Wer den gleichen Stein wie den Trumpf erhält, bekommt am Ende 50 Punkte.",
        "Celui qui reçoit la tuile identique à l'atout gagne 50 points à la fin.",
        "Chi riceve la tessera gemella della briscola ottiene 50 punti alla fine.",
        "Quien recibe la ficha gemela del triunfo gana 50 puntos al final.",
        "Aki megkapja az aduval azonos lapkát, a végén 50 pontot kap."),
    "rules.s2": ("Formațiile", "Melds", "Kombinationen", "Combinaisons", "Combinazioni", "Combinaciones", "Kombinációk"),
    "rules.s2.1": (
        "Suită: minim 3 piese de aceeași culoare, consecutive. 1 poate sta la început (1-2-3) sau după 13 (12-13-1), dar nu mai continui cu 2.",
        "Run: 3 or more consecutive tiles of one color. A 1 can go low (1-2-3) or after 13 (12-13-1), but the run can't wrap on to 2.",
        "Reihe: mindestens 3 aufeinanderfolgende Steine einer Farbe. Die 1 steht am Anfang (1-2-3) oder nach der 13 (12-13-1), danach geht es nicht mit 2 weiter.",
        "Suite : au moins 3 tuiles consécutives d'une même couleur. Le 1 se place au début (1-2-3) ou après 13 (12-13-1), sans continuer avec 2.",
        "Scala: almeno 3 tessere consecutive dello stesso colore. L'1 va all'inizio (1-2-3) o dopo il 13 (12-13-1), ma poi non si continua col 2.",
        "Escalera: 3 o más fichas seguidas del mismo color. El 1 va al principio (1-2-3) o tras el 13 (12-13-1), pero no se sigue con el 2.",
        "Sor: legalább 3 egymást követő, azonos színű lapka. Az 1-es lehet az elején (1-2-3) vagy a 13 után (12-13-1), de utána nem jöhet 2-es."),
    "rules.s2.2": (
        "Terță: minim 3 piese cu același număr, toate de culori diferite (maxim 4).",
        "Group: 3 or 4 tiles with the same number, all in different colors.",
        "Gruppe: 3 oder 4 Steine mit derselben Zahl in verschiedenen Farben.",
        "Série : 3 ou 4 tuiles du même nombre, toutes de couleurs différentes.",
        "Gruppo: 3 o 4 tessere con lo stesso numero, tutte di colori diversi.",
        "Grupo: 3 o 4 fichas del mismo número, todas de colores distintos.",
        "Csoport: 3 vagy 4 azonos számú lapka, mind különböző színű."),
    "rules.s2.3": (
        "O formație cu un Joker are nevoie de încă 2 piese reale; cu 2 Jokeri, de încă 4 piese reale, iar Jokerii nu stau unul lângă altul.",
        "A meld with one Joker needs 2 real tiles; with 2 Jokers it needs 4 real tiles, and the Jokers can't be next to each other.",
        "Eine Kombination mit einem Joker braucht 2 echte Steine, mit 2 Jokern 4 echte Steine, und die Joker liegen nicht nebeneinander.",
        "Une combinaison avec un Joker demande 2 vraies tuiles ; avec 2 Jokers, 4 vraies tuiles, et les Jokers ne se touchent pas.",
        "Una combinazione con un Jolly richiede 2 tessere vere; con 2 Jolly ne servono 4 e i Jolly non stanno vicini.",
        "Una combinación con un comodín necesita 2 fichas reales; con 2 comodines, 4 fichas reales, y los comodines no van juntos.",
        "Egy Jokerrel 2 valódi lapka kell a kombinációhoz, 2 Jokerrel 4, és a Jokerek nem lehetnek egymás mellett."),
    "rules.s3": ("Tura", "Your turn", "Dein Zug", "Le tour", "Il turno", "El turno", "A kör"),
    "rules.s3.1": (
        "Fiecare tură începe prin a lua o piesă și se termină prin a arunca una în șir.",
        "Every turn starts by taking a tile and ends by discarding one to the row.",
        "Jeder Zug beginnt mit dem Nehmen eines Steins und endet mit dem Ablegen eines Steins in die Reihe.",
        "Chaque tour commence en prenant une tuile et se termine en défaussant une tuile dans la rangée.",
        "Ogni turno inizia prendendo una tessera e finisce scartandone una nella fila.",
        "Cada turno empieza cogiendo una ficha y termina descartando una en la fila.",
        "Minden kör egy lapka felvételével kezdődik és egy lapka sorba dobásával végződik."),
    "rules.s3.2": (
        "Prima piesă din șir stă orizontal și nu poate fi folosită de nimeni.",
        "The first tile in the row lies sideways and nobody can use it.",
        "Der erste Stein der Reihe liegt quer und darf von niemandem genommen werden.",
        "La première tuile de la rangée est posée en travers et personne ne peut la prendre.",
        "La prima tessera della fila sta di traverso e nessuno può usarla.",
        "La primera ficha de la fila va en horizontal y nadie puede usarla.",
        "A sor első lapkája keresztben fekszik, és senki sem használhatja."),
    "rules.s3.3": (
        "În prima rundă doar tragi din grămadă și arunci — nu se etalează.",
        "In the first round you only draw from the pile and discard. No laying down.",
        "In der ersten Runde ziehst du nur vom Stapel und legst ab. Ausgelegt wird noch nicht.",
        "Au premier tour, on pioche et on défausse seulement. Pas de pose.",
        "Al primo giro peschi dal pozzo e scarti soltanto. Non si cala.",
        "En la primera ronda solo robas del montón y descartas. No se baja.",
        "Az első körben csak húzol a halomból és dobsz. Lerakni még nem lehet."),
    "rules.s4": ("Prima etalare", "First lay-down", "Erstes Auslegen", "Première pose", "Prima calata", "Primera bajada", "Első lerakás"),
    "rules.s4.1": (
        "Din runda a doua poți etala formații care adunate fac minim 45 de puncte și conțin cel puțin o suită.",
        "From the second round you can lay down melds worth at least 45 points in total, including at least one run.",
        "Ab der zweiten Runde darfst du Kombinationen mit zusammen mindestens 45 Punkten auslegen, darunter mindestens eine Reihe.",
        "Dès le deuxième tour, vous pouvez poser des combinaisons valant au moins 45 points, dont au moins une suite.",
        "Dal secondo giro puoi calare combinazioni che valgono almeno 45 punti, con almeno una scala.",
        "Desde la segunda ronda puedes bajar combinaciones que sumen al menos 45 puntos, con al menos una escalera.",
        "A második körtől lerakhatsz összesen legalább 45 pontot érő kombinációkat, köztük legalább egy sorral."),
    "rules.s4.2": (
        "Excepție: te poți etala și doar cu o terță de 1.",
        "Exception: a group of 1s on its own is also enough.",
        "Ausnahme: Eine Gruppe aus Einsen allein reicht auch.",
        "Exception : une série de 1 suffit aussi à elle seule.",
        "Eccezione: basta anche un gruppo di 1 da solo.",
        "Excepción: también basta un grupo de unos.",
        "Kivétel: egy egyesekből álló csoport önmagában is elég."),
    "rules.s4.3": (
        "Poți lua ultima piesă aruncată în șir doar dacă o folosești imediat într-o formație nouă.",
        "You can take the last discarded tile only if you use it right away in a new meld.",
        "Den zuletzt abgelegten Stein darfst du nur nehmen, wenn du ihn sofort in einer neuen Kombination auslegst.",
        "Vous pouvez prendre la dernière tuile défaussée seulement si vous la posez aussitôt dans une nouvelle combinaison.",
        "Puoi prendere l'ultima tessera scartata solo se la usi subito in una nuova combinazione.",
        "Puedes coger la última ficha descartada solo si la usas enseguida en una combinación nueva.",
        "Az utoljára eldobott lapkát csak akkor veheted fel, ha rögtön új kombinációba teszed."),
    "rules.s5": ("După etalare", "After laying down", "Nach dem Auslegen", "Après la pose", "Dopo la calata", "Después de bajar", "Lerakás után"),
    "rules.s5.1": (
        "Din tura următoare poți lipi piese la orice formație de pe masă. Punctele piesei lipite sunt ale tale.",
        "From your next turn you can add tiles to any meld on the table. The points for those tiles are yours.",
        "Ab dem nächsten Zug darfst du an jede Kombination auf dem Tisch anlegen. Die Punkte der angelegten Steine gehören dir.",
        "Dès le tour suivant, vous pouvez compléter n'importe quelle combinaison. Les points des tuiles ajoutées sont à vous.",
        "Dal turno successivo puoi attaccare tessere a qualsiasi combinazione sul tavolo. I punti di quelle tessere sono tuoi.",
        "Desde el turno siguiente puedes añadir fichas a cualquier combinación de la mesa. Sus puntos son tuyos.",
        "A következő körtől bármelyik kombinációhoz tehetsz lapkát. A hozzátett lapkák pontjai a tieid."),
    "rules.s5.2": (
        "Poți rupe șirul: iei orice piesă (în afară de prima), dacă ești etalat, ai minim 4 piese și o folosești imediat într-o formație nouă. Piesele de după ea vin pe tabla ta.",
        "You can break the row: take any tile but the first if you've laid down, have 4+ tiles and use it at once in a new meld. The tiles after it come to your rack.",
        "Du darfst die Reihe aufbrechen: einen beliebigen Stein außer dem ersten nehmen, wenn du ausgelegt hast, mindestens 4 Steine hast und ihn sofort neu auslegst. Die Steine danach kommen auf deine Bank.",
        "Vous pouvez couper la rangée : prendre n'importe quelle tuile sauf la première si vous avez posé, avez 4 tuiles ou plus et la posez aussitôt. Les tuiles suivantes vont sur votre chevalet.",
        "Puoi spezzare la fila: prendi qualsiasi tessera tranne la prima se hai calato, hai almeno 4 tessere e la usi subito in una nuova combinazione. Le tessere successive vanno sul tuo leggio.",
        "Puedes romper la fila: coger cualquier ficha salvo la primera si ya bajaste, tienes 4 o más fichas y la usas enseguida en una combinación nueva. Las fichas posteriores van a tu atril.",
        "Megtörheted a sort: bármelyik lapkát felveheted az elsőn kívül, ha már lerakóztál, van legalább 4 lapkád, és rögtön új kombinációba teszed. Az utána következő lapkák a tartódra kerülnek."),
    "rules.s5.3": (
        "Dacă ai exact piesa pe care o ține locul unui Joker etalat, o poți pune în locul lui și iei Jokerul. Un Joker se poate schimba o singură dată.",
        "If you hold the exact tile a Joker on the table stands for, you can swap it in and take the Joker. Each Joker can be swapped only once.",
        "Hast du genau den Stein, den ein ausgelegter Joker ersetzt, kannst du ihn tauschen und den Joker nehmen. Jeder Joker wird nur einmal getauscht.",
        "Si vous avez la tuile exacte que remplace un Joker posé, vous pouvez l'échanger et prendre le Joker. Un Joker ne s'échange qu'une fois.",
        "Se hai la tessera esatta che un Jolly calato sostituisce, puoi metterla al suo posto e prendere il Jolly. Ogni Jolly si scambia una sola volta.",
        "Si tienes la ficha exacta que sustituye un comodín de la mesa, puedes ponerla y quedarte el comodín. Cada comodín se cambia una sola vez.",
        "Ha nálad van az a lapka, amelyet egy lerakott Joker helyettesít, kicserélheted, és megkapod a Jokert. Minden Joker csak egyszer cserélhető."),
    "rules.s5.4": (
        "Jokerul nu se lipește la formațiile altor jucători.",
        "A Joker can't be added to another player's meld.",
        "Joker werden nicht bei anderen Spielern angelegt.",
        "Un Joker ne peut pas compléter la combinaison d'un autre joueur.",
        "Il Jolly non si attacca alle combinazioni degli altri giocatori.",
        "El comodín no se añade a combinaciones de otros jugadores.",
        "Jokert nem lehet más játékos kombinációjához tenni."),
    "rules.s6": ("Ultimele piese", "Last tiles", "Die letzten Steine", "Dernières tuiles", "Ultime tessere", "Últimas fichas", "Az utolsó lapkák"),
    "rules.s6.1": (
        "Când mai ai cel mult 3 piese, ceilalți sunt anunțați (aplicația face asta automat).",
        "When a player has 3 tiles or fewer, everyone is told (the app shows it automatically).",
        "Hat jemand höchstens 3 Steine, wird es angesagt (die App zeigt es automatisch).",
        "Quand un joueur a 3 tuiles ou moins, tout le monde est prévenu (l'appli l'affiche).",
        "Quando un giocatore ha 3 tessere o meno, viene annunciato (l'app lo mostra da sola).",
        "Cuando a alguien le quedan 3 fichas o menos, se anuncia (la app lo muestra sola).",
        "Ha valakinek legfeljebb 3 lapkája maradt, az mindenki látja (az app kiírja)."),
    "rules.s6.2": (
        "Cu 3 piese poți lua doar ultima piesă din șir; cu 1–2 piese tragi obligatoriu din grămadă și doar lipești.",
        "With 3 tiles you can only take the last tile in the row; with 1–2 tiles you must draw from the pile and can only add to melds.",
        "Mit 3 Steinen darfst du nur den letzten Stein der Reihe nehmen; mit 1–2 Steinen ziehst du vom Stapel und legst nur noch an.",
        "Avec 3 tuiles, seule la dernière tuile de la rangée peut être prise ; avec 1 ou 2, on pioche et on ne fait que compléter.",
        "Con 3 tessere puoi prendere solo l'ultima della fila; con 1–2 peschi dal pozzo e puoi solo attaccare.",
        "Con 3 fichas solo puedes coger la última de la fila; con 1–2 robas del montón y solo puedes añadir.",
        "3 lapkával csak a sor utolsó lapkáját veheted fel; 1–2 lapkával húznod kell, és csak hozzátenni lehet."),
    "rules.s6.3": (
        "Atuul îl poți lua doar dacă faci formație cu el și închizi în aceeași tură.",
        "You can take the trump tile only if you meld it and go out in the same turn.",
        "Den Trumpf darfst du nur nehmen, wenn du ihn auslegst und im selben Zug ausmachst.",
        "L'atout ne se prend que si vous le posez et fermez dans le même tour.",
        "La briscola si prende solo se la cali e chiudi nello stesso turno.",
        "El triunfo solo se coge si lo bajas y cierras en el mismo turno.",
        "Az adut csak akkor veheted fel, ha kombinációba teszed és ugyanabban a körben zársz."),
    "rules.s7": ("Valoarea pieselor", "Tile values", "Steinwerte", "Valeur des tuiles", "Valore delle tessere", "Valor de las fichas", "A lapkák értéke"),
    "rules.s7.1": (
        "2–9: 5 puncte · 10–13: 10 puncte.",
        "2–9: 5 points · 10–13: 10 points.",
        "2–9: 5 Punkte · 10–13: 10 Punkte.",
        "2–9 : 5 points · 10–13 : 10 points.",
        "2–9: 5 punti · 10–13: 10 punti.",
        "2–9: 5 puntos · 10–13: 10 puntos.",
        "2–9: 5 pont · 10–13: 10 pont."),
    "rules.s7.2": (
        "1 în suita 1-2-3: 5 p · 1 în suita 12-13-1: 10 p · 1 în terță de 1: 25 p.",
        "1 in a 1-2-3 run: 5 pts · 1 in a 12-13-1 run: 10 pts · 1 in a group of 1s: 25 pts.",
        "1 in der Reihe 1-2-3: 5 P. · 1 in der Reihe 12-13-1: 10 P. · 1 in einer Einser-Gruppe: 25 P.",
        "1 dans la suite 1-2-3 : 5 pts · 1 dans 12-13-1 : 10 pts · 1 dans une série de 1 : 25 pts.",
        "1 nella scala 1-2-3: 5 pt · 1 nella scala 12-13-1: 10 pt · 1 in un gruppo di 1: 25 pt.",
        "1 en la escalera 1-2-3: 5 pts · 1 en 12-13-1: 10 pts · 1 en un grupo de unos: 25 pts.",
        "1-es az 1-2-3 sorban: 5 p · a 12-13-1 sorban: 10 p · egyesek csoportjában: 25 p."),
    "rules.s7.3": (
        "În timpul jocului Jokerul valorează cât piesa înlocuită; la final un Joker etalat valorează 50 (Joker re-folosit: 0).",
        "During play a Joker is worth the tile it replaces; at the end a Joker on the table counts 50 (a reused Joker counts 0).",
        "Während des Spiels zählt der Joker wie der ersetzte Stein; am Ende zählt ein ausgelegter Joker 50 (ein wiederverwendeter 0).",
        "En cours de jeu, le Joker vaut la tuile remplacée ; à la fin, un Joker posé vaut 50 (un Joker réutilisé : 0).",
        "Durante il gioco il Jolly vale quanto la tessera sostituita; alla fine un Jolly calato vale 50 (riutilizzato: 0).",
        "Durante la partida el comodín vale lo que la ficha que sustituye; al final, un comodín en la mesa vale 50 (reutilizado: 0).",
        "Játék közben a Joker annyit ér, mint a helyettesített lapka; a végén egy lerakott Joker 50 pont (újrahasznált Joker: 0)."),
    "rules.s8": ("Final și punctaj", "Going out and scoring", "Ende und Wertung", "Fin et décompte", "Fine e punteggio", "Cierre y puntuación", "Zárás és pontozás"),
    "rules.s8.1": (
        "Închide cine rămâne fără piese, aruncând ultima piesă în șir: +100 de puncte peste ce a etalat.",
        "You go out when you discard your last tile to the row: +100 points on top of what you laid down.",
        "Wer seinen letzten Stein in die Reihe ablegt, macht aus: +100 Punkte zusätzlich zu den ausgelegten.",
        "On ferme en défaussant sa dernière tuile : +100 points en plus de ce qu'on a posé.",
        "Chiude chi scarta l'ultima tessera nella fila: +100 punti oltre a quelli calati.",
        "Cierra quien descarta su última ficha en la fila: +100 puntos sobre lo que bajó.",
        "Az zár, aki az utolsó lapkáját a sorba dobja: +100 pont a lerakottakon felül."),
    "rules.s8.2": (
        "Ceilalți: punctele etalate minus piesele rămase pe tablă (1 = 25 p, Joker = 50 p).",
        "Everyone else: points laid down minus tiles left on the rack (1 = 25 pts, Joker = 50 pts).",
        "Alle anderen: ausgelegte Punkte minus Steine auf der Bank (1 = 25 P., Joker = 50 P.).",
        "Les autres : points posés moins les tuiles restées sur le chevalet (1 = 25 pts, Joker = 50 pts).",
        "Gli altri: punti calati meno le tessere rimaste sul leggio (1 = 25 pt, Jolly = 50 pt).",
        "Los demás: puntos bajados menos las fichas que quedan en el atril (1 = 25 pts, comodín = 50 pts).",
        "A többiek: lerakott pontok mínusz a tartón maradt lapkák (1-es = 25 p, Joker = 50 p)."),
    "rules.s8.3": (
        "Cine nu s-a etalat deloc pierde 100 de puncte.",
        "Anyone who never laid down loses 100 points.",
        "Wer gar nicht ausgelegt hat, verliert 100 Punkte.",
        "Celui qui n'a jamais posé perd 100 points.",
        "Chi non ha mai calato perde 100 punti.",
        "Quien no ha bajado nunca pierde 100 puntos.",
        "Aki egyáltalán nem rakott le, 100 pontot veszít."),
    "rules.s8.4": (
        "Închis cu Joker sau cu 1: rezultatul celui care închide se dublează.",
        "Going out with a Joker or a 1 doubles that player's score.",
        "Wer mit einem Joker oder einer 1 ausmacht, bekommt doppelte Punkte.",
        "Fermer avec un Joker ou un 1 double le score de celui qui ferme.",
        "Chiudere con un Jolly o un 1 raddoppia il punteggio di chi chiude.",
        "Cerrar con un comodín o un 1 duplica la puntuación de quien cierra.",
        "Jokerrel vagy 1-essel zárva a záró játékos pontjai duplázódnak."),
    "rules.s8.5": (
        "Dacă se termină grămada, nimeni nu primește cele 100 de puncte.",
        "If the pile runs out, nobody gets the 100 points.",
        "Ist der Stapel leer, bekommt niemand die 100 Punkte.",
        "Si la pioche est vide, personne ne reçoit les 100 points.",
        "Se il pozzo finisce, nessuno prende i 100 punti.",
        "Si se acaba el montón, nadie se lleva los 100 puntos.",
        "Ha elfogy a halom, senki sem kapja meg a 100 pontot."),
    "rules.notIncluded": (
        "Variante neincluse", "Not included", "Nicht enthalten", "Variantes non incluses", "Varianti non incluse",
        "Variantes no incluidas", "Nem szereplő változatok"),
    "rules.notIncludedText": (
        "Schimbul de duble, „stricarea jocului” cu 3 duble și închiderea pe tablă nu sunt incluse în această versiune.",
        "Swapping pairs, calling a redeal with 3 pairs and going out straight from the rack aren't in this version.",
        "Das Tauschen von Paaren, das Neugeben bei 3 Paaren und das Ausmachen direkt von der Bank sind in dieser Version nicht enthalten.",
        "L'échange de paires, la redistribution avec 3 paires et la fermeture directe depuis le chevalet ne sont pas inclus.",
        "Lo scambio delle coppie, la ridistribuzione con 3 coppie e la chiusura direttamente dal leggio non sono inclusi.",
        "El intercambio de parejas, repartir de nuevo con 3 parejas y cerrar directamente desde el atril no están incluidos.",
        "A párok cseréje, az újraosztás 3 párnál és a közvetlenül a tartóról zárás ebben a változatban nem szerepel."),
    "rules.source": (
        "Regulament complet: cumsejoaca.ro", "Full rules in Romanian: cumsejoaca.ro",
        "Vollständige Regeln (Rumänisch): cumsejoaca.ro", "Règles complètes (en roumain) : cumsejoaca.ro",
        "Regolamento completo (in rumeno): cumsejoaca.ro", "Reglamento completo (en rumano): cumsejoaca.ro",
        "Teljes szabályzat (románul): cumsejoaca.ro"),
}


def main():
    for extra in (W, R, H):
        dup = set(extra) & set(S)
        assert not dup, dup
        S.update(extra)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    for key in sorted(S):
        vals = S[key]
        assert len(vals) == len(LANGS), key
        out["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                lang: {"stringUnit": {"state": "translated", "value": val}}
                for lang, val in zip(LANGS, vals)
            },
        }
    path = os.path.join(root, "Whist", "Localizable.xcstrings")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"{len(S)} chei × {len(LANGS)} limbi → {path}")


if __name__ == "__main__":
    main()


INFOPLIST = {"CFBundleDisplayName": ("Cărți Românești", "Romanian Cards", "Karten RO", "Cartes RO", "Carte RO", "Cartas RO", "Román kártya")}


def infoplist():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    for key, vals in INFOPLIST.items():
        out["strings"][key] = {"extractionState": "manual", "localizations": {
            lang: {"stringUnit": {"state": "translated", "value": v}} for lang, v in zip(LANGS, vals)}}
    with open(os.path.join(root, "Whist", "InfoPlist.xcstrings"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)


infoplist()
