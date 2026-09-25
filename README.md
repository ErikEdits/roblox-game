# NEON CITY – Roblox MVP (v0.1)

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
4. Optional: Game-Pässe „VIP Pass“ (399 R$) und „Neon Hyper Car“ (249 R$) auf der Roblox-Website anlegen
   und die IDs in `ReplicatedStorage.Shared.Config` → `Config.Monetization.Passes` eintragen.

## Was ist drin?

| Bereich | Inhalt |
|---|---|
| Karte | Main Plaza (Spawn, Leaderboard, Event-Tafel, Kiosks, Teleport-Pads), Resort District mit **16 Grundstücken**, Entertainment District (The Grand Neon, Card-Rush-Automat, Konzertbühne, Generatoren), Racing District (Rundkurs mit 5 Checkpoints), Shopping District (Mall, VIP-Lounge, Bahnhof), Skyline |
| Spielerdaten | DataStore-Speicherung (Cash, XP, Level, Prestige, Gebäude + Positionen, Kosmetik, Quests, Einstellungen, Statistiken), Autosave, Validierung |
| Bauen | 21 Gebäude in 7 Kategorien, Platzieren / Verschieben / Drehen / Löschen (50 % Erstattung) / Kopieren, 4-Stud-Raster, Speichern & Wiederherstellen |
| NPCs | 6 Besuchertypen (Tourist, Luxury, Racer, Family, Business, Event Fan), laufen zu Resorts, gehen hinein, **geben Geld aus** („+$40“ über dem Gebäude) |
| Wirtschaft | NPC-Ausgaben + passives Resort-Einkommen, Resort-Level 1–5, Level 1–100 mit Freischaltungen |
| Minispiel | **Card Rush** – schnelles Karten-Skillspiel, 7 Fragetypen, **kein Glücksspiel / keine Einsätze** |
| Rennen | **Street Race** bis 8 Spieler, mit NPC-Fahrern aufgefüllt (auch allein spielbar), 2 Runden, Belohnung für Top 3 |
| Events | City Blackout (Generatoren reparieren), Live Concert, VIP Night, Race Rush (2× Rennbelohnung) – automatisch alle 2,5–4 Min. |
| Fortschritt | Tägliche Aufgaben (5), Statistiken, Leaderboard (Server + globale Bestzeit), optionales Prestige ab Level 100 |
| Shop | Autolackierungen für Spielgeld, 2 Robux-Game-Pässe mit klar definiertem Inhalt (kein Pay-to-win) |
| UI | Mobile-first, skaliert automatisch, große Touch-Buttons; „NEXT GOAL“-Hinweis sagt immer, was als Nächstes zu tun ist |

**Steuerung:** BUILD, SHOP, PLAY, TASKS, MAP, SETTINGS unten (PC) bzw. rechts (Handy).
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
