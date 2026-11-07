# WRAITHSTEEL - Was DU noch tun musst (Schritt für Schritt)

Der Code wurde ohne Roblox getestet (automatisch, mit Simulation: Kämpfe, Bosse, Handel, Raids,
Käufe, die ganze Story). **In echtem Roblox lief er aber noch nie.** Die folgenden Dinge kann nur
ein Mensch in Roblox Studio / im Roblox-Dashboard machen. Arbeite die Liste von oben nach unten ab.
**Wenn etwas kaputt ist: kopiere die rote Fehlermeldung aus dem Output-Fenster und schick sie mir.**

---

## Schritt 1 - Spiel öffnen und ausprobieren (10 Minuten)

1. Roblox Studio öffnen.
2. `File > Open from File...` und die Datei **Wraithsteel-Playtest.rbxl** wählen.
3. Oben auf **Play** klicken (grüner Pfeil).
4. Du startest in der Stadt "Ninefold Crossing". Probier:
   - **Linke Maustaste** = Angriff, **R** = schwerer Angriff, **F halten** = Blocken, **Ctrl** = Ausweichen
   - **E** an den Ständen (Waffenschmied, Laternen, Quests ...)
   - Links in der Leiste: **Blade / Spirits / World / Bonds / Market** öffnen
5. Wenn Fehler im Fenster **Output** (View > Output) rot erscheinen: Screenshot oder Text an mich.

**Wichtig:** Das Spiel wurde noch nie in echtem Roblox gespielt. Rechne mit kleinen Fehlern
(Animationen, Größen, Kameras). Das ist normal - schick sie mir, ich repariere sie.

## Schritt 2 - Zu zweit testen (wichtig für Duelle, Handel, Raids)

1. In Studio: `Test` -> `Clients and Servers` -> **Players: 2** -> `Start`.
2. Teste mit zwei Fenstern: Party einladen, Handel (nah beieinander stehen), Duell
   (Menü Bonds > Duels), Bell Dice (Market > Bell Dice).
3. Achte besonders darauf, ob **Blocken/Parieren** sich zu spät oder zu früh anfühlt.

## Schritt 3 - Daten-Speicherung testen (optional, aber empfohlen)

1. `File > Publish to Roblox` (als **privat** lassen!).
2. `Home > Game Settings > Security` -> **Enable Studio Access to API Services** einschalten.
3. Spielen, Spiel beenden, wieder starten: Dein Fortschritt (Ember, Level) muss noch da sein.

## Schritt 4 - Pässe und Produkte im Dashboard anlegen (Pflicht für Einnahmen)

1. Auf https://create.roblox.com -> dein Spiel -> **Monetization**.
2. **Passes** anlegen (Name frei, Preis wie unten), danach die **ID** kopieren.
3. **Developer Products** anlegen, ebenfalls ID kopieren.
4. Die IDs in die Datei `src/config/MonetizationConfig.luau` eintragen (statt `id = 0`).
   Das mache ich gern für dich: schick mir einfach die Liste "Name = ID".

| Typ | Schlüssel im Code | Name im Spiel | Preis (Robux) |
|---|---|---|---|
| Pass | DoubleEmber | Ember Furnace | 299 |
| Pass | LuckyCharm | Ninefold Charm | 249 |
| Pass | ExtraSpiritSlots | Spirit Shrine | 199 |
| Pass | DoubleXP | Scroll of Swift Learning | 249 |
| Pass | ExtraFlask | Bottomless Gourd | 149 |
| Pass | VIP | Bell-Bearer's Seal (VIP) | 399 |
| Pass | TripleOpen | Lantern Festival | 149 |
| Pass | LongExpeditions | Long Road | 99 |
| Produkt | JadeSmall | Pouch of Jade | 49 |
| Produkt | JadeMedium | Chest of Jade | 249 |
| Produkt | JadeLarge | Vault of Jade | 499 |
| Produkt | EmberSmall | Sack of Ember | 39 |
| Produkt | EmberLarge | Furnace of Ember | 199 |
| Produkt | LevelUp1 | Level Up | 29 |
| Produkt | LevelUp5 | Five Levels | 119 |
| Produkt | LevelUp10 | Ten Levels | 199 |
| Produkt | StarterBundle | Wanderer's Bundle | 99 |
| Produkt | EmberBoost30 | Ember Incense (30 min) | 39 |
| Produkt | LuckBoost15 | Fortune Incense (15 min) | 49 |
| Produkt | GiftDoubleEmber | Gift: Ember Furnace | 299 |
| Produkt | GiftLuckyCharm | Gift: Ninefold Charm | 299 |
| Produkt | GiftExtraSpiritSlots | Gift: Spirit Shrine | 299 |

Solange die IDs `0` sind, sind Käufe in Studio **kostenlos simuliert** (zum Testen) und im echten
Spiel nicht kaufbar - nichts geht kaputt.

## Schritt 5 - Roblox-Fragebogen (Pflicht vor dem Veröffentlichen)

Im Dashboard unter **Settings / Age Guidelines (Fragebogen)** ehrlich ankreuzen:

- **Zufallsgegenstände, die man mit Robux/echtem Geld kaufen kann** -> **JA**
  (Spirit-Laternen: Jade ist mit Robux kaufbar, und Ember wird ebenfalls mit Robux verkauft.
  Die Quoten stehen im Spiel VOR dem Kauf, und für Konten mit Einschränkung sind sie gesperrt.)
- **Simuliertes Glücksspiel** -> **JA** (Bell Dice: nur mit kostenlosen Glücks-Chips,
  die man NIE kaufen kann; kein Echtgeld, keine Auszahlung.)
- **Handel zwischen Spielern** -> JA (nur Spirits).
- **Kampf / Gewalt** -> Fantasy-Kampf mit Schwertern, kein Blut.
- **Chat** -> normaler Roblox-Chat.

Wenn du unsicher bist: Lieber "JA" ankreuzen. Falsche Angaben können das Spiel sperren.

## Schritt 6 - Veröffentlichen

1. Erst **privat** testen (Schritte 1-3), mit 1-2 Freunden.
2. Wenn alles läuft: `Game Settings > Basic Info` -> Name, Beschreibung, Thumbnail setzen.
3. **Public** schalten.

---

## Was noch "Platzhalter" ist (macht das Spiel hübscher, ist aber nicht nötig zum Spielen)

- Echte Animationen, 3D-Modelle, Sounds (jetzt: Code-Animationen, einfache Figuren, Standard-Sounds).
- Die Burg "Ironcrow Keep" ist eine grobe Form und kann in Studio verschönert werden.
- Raid-Arena `Workspace.RaidArena`, Night-Market-Stand, Raid-Tor (Details: `AssetLog.md`).

## Bekannte Entscheidung (nur zur Info, nichts zu tun)

Ember-Laternen gelten wegen des Ember-Verkaufs als "bezahlter Zufall" und sind für eingeschränkte
Konten gesperrt (kostenlose Öffnungen funktionieren weiterhin). Wenn du Ember **nicht** mehr
für Robux verkaufen willst: in `MonetizationConfig.luau` die Produkte `EmberSmall`,
`EmberLarge` und `StarterBundle` (Ember-Anteil) entfernen - dann sind Ember-Laternen automatisch
wieder normaler Zufall.
