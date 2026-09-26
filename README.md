# NEON CITY – Roblox (v0.3)

Multiplayer-Tycoon / Resort-Management mit NPC-Besuchern, Skill-Minispiel, Straßenrennen und
Stadt-Events – umgesetzt nach dem *NEON CITY Game Design Document* (Abschnitt 29: MVP).

## Schnellstart: in Roblox Studio öffnen

1. **`build/NEON_CITY.rbxl` herunterladen** (auf GitHub die Datei öffnen → „Download raw file“).
2. Doppelklick auf die Datei **oder** in Roblox Studio: *File → Open from File…* → `NEON_CITY.rbxl`.
3. Oben auf **Play** (F5) drücken – fertig.

In Studio wird der Fortschritt **nicht gespeichert** (Hinweis erscheint im Spiel), und alle Game-Pässe
gelten zum Testen als gekauft (`Config.Monetization.GrantAllInStudio`).

### Veröffentlichen (damit Speichern funktioniert)

1. *File → Publish to Roblox* (neues Erlebnis anlegen).
2. *Game Settings → Security → „Enable Studio Access to API Services“* einschalten (für DataStores in Studio).
3. *Game Settings → Places → Max Players = 15* (das Design ist auf 15 Spieler pro Server ausgelegt).
4. Optional: Game-Pässe „VIP Pass“ (399 R$), „Cyberpunk Pack“ (199 R$) und „Neon Hyper Car“ (249 R$) auf der
   Roblox-Website anlegen und die IDs in `ReplicatedStorage.Shared.Config` → `Config.Monetization.Passes` eintragen.
5. Optional: Im Creator Hub unter *Localization* „Automatic translation“ einschalten – dann sehen deutsche
   Spieler die Texte automatisch auf Deutsch.

**Mit mehreren Spielern testen:** in Studio *Test → Clients and Servers* (z. B. 2 Spieler) starten.

### Admin-Werkzeuge zum Testen

In Studio (und live für den Ersteller des Spiels) gibt es unter **SETTINGS → ADMIN TOOLS** Knöpfe für
+$10K / +$1M, +5 Level, Level 100, jedes Event sofort starten, Aufgaben erledigen/neu würfeln und
das Tutorial neu starten. Weitere Admins: User-IDs in `Config.Admins` eintragen.

## Was ist drin?

| Bereich | Inhalt |
|---|---|
| Karte | Main Plaza (Spawn, Leaderboard, Event-Tafel, Kiosks, Teleport-Pads, Fontäne mit Partikeln), Resort District mit **16 Grundstücken**, Entertainment District (The Grand Neon, Card-Rush- und Neon-Reflex-Automat, Konzertbühne, Generatoren), Racing District (Rundkurs mit 5 Checkpoints), Shopping District (Mall, VIP-Lounge, Bahnhof), **Neon Beach** mit Pier, Gehwege, Palmen-Alleen, Werbetafeln, Skyline mit blinkenden Antennen |
| Spielerdaten | DataStore-Speicherung (Cash, XP, Level, Prestige, Gebäude + Positionen, Kosmetik, Quests, Einstellungen, Statistiken), Autosave, Validierung |
| Bauen | 26 Gebäude in 7 Kategorien (inkl. VIP-Penthouse und Cyberpunk-Deko), eigene **Neonfarbe pro Gebäude**, Resort-Statistik, Platzieren / Verschieben / Drehen / Löschen (50 % Erstattung) / Kopieren, 4-Stud-Raster mit sichtbarem Gitter, **Upgrades bis Stufe 3** (mehr Einnahmen, Dachkrone + Stufenlichter), Speichern & Wiederherstellen |
| NPCs | 6 Besuchertypen (Tourist, Luxury, Racer, Family, Business, Event Fan), laufen zu Resorts, gehen hinein, **geben Geld aus** („+$40“ über dem Gebäude), Familien mit Kindern, Sprechblasen |
| Wirtschaft | NPC-Ausgaben + passives Resort-Einkommen, Resort-Level 1–5, Level 1–100 mit Freischaltungen |
| Minispiele | **Card Rush** (Karten-Skillspiel, 7 Fragetypen) und **Neon Reflex** (Reaktionsspiel) – **kein Glücksspiel / keine Einsätze** |
| Autos | **CAR-Knopf**: eigenes Auto spawnen und frei durch die Stadt fahren; Karosserien (Muscle Car, Drift Coupe, Hyper) und Lackierungen im Shop – alle gleich schnell |
| Rennen | **Street Race** bis 8 Spieler, mit NPC-Fahrern aufgefüllt (auch allein spielbar), 2 Runden, Belohnung für Top 3; **Time Trial** (Solo-Runde, Rekord-Bonus, globale Bestenliste) |
| Job | **Lieferjob** (optional): Paket quer durch die Stadt bringen, Timer + Leuchtpfad |
| Events | City Blackout (Generatoren reparieren), Live Concert, VIP Night, Race Rush (2× Rennbelohnung), **Lost & Found** (Geldbörsen finden) – automatisch alle 2,5–4 Min. |
| Fortschritt | **Tutorial** für neue Spieler, tägliche Aufgaben (5 aus 11, jeden Tag andere), Statistiken, Leaderboard, optionales Prestige ab Level 100 |
| Sozial | Andere Resorts in der MAP besuchen und **liken** (Besitzer bekommt Geld/XP, Likes auf dem Schild) |
| Shop | Autolackierungen für Spielgeld, 2 Robux-Game-Pässe mit klar definiertem Inhalt (kein Pay-to-win) |
| UI | Minimap (PC), Mobile-first, skaliert automatisch, große Touch-Buttons, Sounds, Animationen; „NEXT GOAL“-Hinweis sagt immer, was als Nächstes zu tun ist |

**Steuerung:** BUILD, SHOP, PLAY, TASKS, MAP, CAR, SETTINGS unten (PC) bzw. rechts (Handy).
Bauen am PC: Maus zielen, Klick = platzieren, **R** = drehen, **Q** = abbrechen. Handy: auf den Boden tippen, dann PLACE.
Autos: W/S bzw. Pfeiltasten oder Thumbstick.

## Projektstruktur (Rojo)

```
default.project.json           Rojo-Projekt → baut build/NEON_CITY.rbxl
src/ReplicatedStorage/Shared   Config, Gebäudekatalog, Progression, Platzierung, Modelle, Remotes
src/ServerScriptService        Main.server.luau + Services/ (ein Modul pro System)
src/StarterPlayerScripts       Client.client.luau + Controllers/ (HUD, Bauen, Shop, Rennen, …)
src/Workspace/*.model.json     Karte (generiert von tools/generate_map.py)
tools/generate_map.py          Kartengenerator – nach Änderungen neu ausführen
PROGRESS.md                    Entwicklungsprotokoll (was, Dateien, Tests, bekannte Probleme, nächste Schritte)
tests/                         Simulator-Test (spielt das ganze Spiel automatisch durch) + API-Check
```

Alle Zahlen (Preise, Belohnungen, NPC-Anzahl, Event-Zeiten …) stehen in `src/ReplicatedStorage/Shared/Config.luau`,
alle Gebäude in `Buildings.luau`.

### Neu bauen

```bash
python3 tools/generate_map.py          # nur nötig, wenn die Karte geändert wurde
rojo build -o build/NEON_CITY.rbxl
```

Oder live mit Studio synchronisieren: `rojo serve` + Rojo-Plugin in Studio.

## Sicherheit & Roblox-Regeln

- Der Server entscheidet über **alles** (Geld, XP, Gebäude, Rennen, Quests, Käufe); Remotes sind nur Anfragen.
- Casino-Optik ist reine Deko. Kein Roulette/Blackjack/Slots, keine Einsätze, keine Zufallsbelohnungen für Robux.
- Robux-Produkte haben klar bekannten Inhalt; alle Autos sind gleich schnell.
- Vor der Veröffentlichung die aktuellen Roblox-Richtlinien prüfen (siehe Design-Dokument Abschnitt 21).
