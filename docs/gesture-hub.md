# Gesture Hub

Diese Dokumentation beschreibt den aktuellen Stand des Gesture Hub in
OpenRing. Der Gesture Hub ist die zentrale Bedienkarte fuer ringbasierte
Steuerung mit gehaltenen Handpositionen. Er baut auf den Motion-Lab-Aufnahmen
auf und nutzt den Accelerometer-Stream des Rings.

Der aktuelle Stand ist bewusst experimentell. Die Steuerung ist fuer grobe,
bewusste Gesten gedacht, nicht fuer eine vollwertige Maus oder sehr schnelle
Feinsteuerung. Die wichtigste Hardwaregrenze ist die beobachtete
Accelerometer-Rate von ungefaehr `1 Hz`.

## Ziel

Der Gesture Hub soll mehrere schnelle System-Controls ueber denselben Ring
bedienbar machen:

- Scrollen
- Lautstaerke
- Maus

Statt fuer jeden Control einen eigenen Hotkey zu brauchen, gibt es eine zentrale
Aktivierung. Danach wird innerhalb des Gesture Hub zwischen Controls gewechselt.

Die wichtigsten Designentscheidungen:

- Gesten werden nicht ueber Drehgeschwindigkeit erkannt.
- V1 nutzt stabil gehaltene Handpositionen.
- `palm_vertical` wechselt zwischen Gesture-Hub-Controls.
- `palm_side` ist in den meisten Controls neutral.
- `fist_down` ist nur im Maus-Control ein Linksklick.
- Der Sensor wird nur gestoppt, wenn der Gesture Hub ihn selbst gestartet hat.

## Aktivierung und Sensorverhalten

Der Gesture Hub kann ueber die Dashboard-Karte oder den registrierten Hotkey
aktiviert werden. Beim Aktivieren prueft der Controller, ob der
Accelerometer-Stream bereits laeuft.

Wenn der Stream noch nicht laeuft:

```text
Gesture Hub aktivieren
  -> Accelerometer starten
  -> startedAccelerometer = true
```

Wenn der Stream bereits laeuft:

```text
Gesture Hub aktivieren
  -> bestehenden Stream verwenden
  -> startedAccelerometer = false
```

Beim Beenden gilt:

```text
startedAccelerometer == true  -> Stream wieder stoppen
startedAccelerometer == false -> Stream weiterlaufen lassen
```

Dadurch wird verhindert, dass der Gesture Hub einen Sensor-Stream beendet, der
z. B. manuell im Accelerometer-Panel oder fuer Motion Lab gestartet wurde.

## Datenbasis: warum gehaltene Positionen

Der urspruengliche Gedanke war ein Lean-back- oder Plus-Menue, das per
Doppelklopfen geoeffnet wird. Aus den Hardwaretests ergaben sich zwei Probleme:

- Doppelklopfen ist bei ungefaehr `1 Hz` Sample-Rate nicht verlaesslich sichtbar.
- Der Accelerometer-Stream muss aktuell aktiv gestartet werden.

Darum wurde das Konzept geaendert:

- Kein Tap-Trigger fuer V1.
- Kein Erkennen von Drehgeschwindigkeit.
- Keine schnellen Wisch- oder Richtungswechsel.
- Stattdessen stabile Handlagen mit echten Messwerten.

Das Motion Lab wurde erweitert, um solche Lagen aufzunehmen und zu vergleichen.
Die dabei relevanten Presets sind:

```text
gesture_open_down
gesture_open_side
gesture_open_up
gesture_open_vertical
gesture_fist_down
gesture_fist_side
gesture_fist_up
gesture_fist_vertical
```

Die aelteren Basic-Presets bleiben als Legacy/Grundlage erhalten:

```text
gesture_palm_up
gesture_palm_side
gesture_palm_down
gesture_double_tap
```

## Aufnahme-Workflow im Motion Lab

Fuer jede Position wurde im Motion Lab eine Session mit passendem Preset
aufgenommen. Der Sessionname dient als Label; es gibt keine eigene
Gesten-Datenbanktabelle.

Der empfohlene Ablauf:

1. Accelerometer-Stream starten.
2. Im Motion Lab ein Preset waehlen, z. B. `gesture_open_side`.
3. Hand in die gewuenschte Lage bringen.
4. Kurz ruhig werden lassen.
5. `Record` starten.
6. Hand 10 bis 20 Sekunden ruhig halten.
7. `Stop` druecken.
8. Bei Bedarf 2 bis 3 Wiederholungen aufnehmen.

Wichtige Rahmenbedingungen:

- Ring immer am selben Finger tragen.
- Ring immer in derselben Ausrichtung tragen.
- Linke Hand ist der angenommene Standard, weil rechts haeufig Maus/Tastatur
  dominiert.
- Zwischen Start/Stop koennen Anfangs- und Endbewegungen enthalten sein.
- Fuer die spaetere Erkennung sind stabile Fenster wichtiger als hektische
  Uebergaenge.

Das Motion Lab zeigt pro Session:

- Sampleanzahl
- Dauer
- Min/Max/Avg fuer `xG`, `yG`, `zG`, `|a|`
- Streuung pro Achse
- Stabilitaet
- Roll-Winkel ueber `atan2(yG, zG)`

## Gemessene Open-/Fist-Lagen

Die aktuell im Gesture Hub verwendeten Zentren stammen aus den echten
Open-Hand- und Fist-Aufnahmen. Die Werte sind in `g` angegeben und gerundet.

| Gesture-Hub-Position | Quelle | xG | yG | zG | Roll |
| --- | --- | ---: | ---: | ---: | ---: |
| `palm_down` | `gesture_open_down` | `+0.101` | `-1.041` | `-0.004` | `-90.1 deg` |
| `palm_side` | `gesture_open_side` | `-0.141` | `-0.086` | `+0.841` | `-5.9 deg` |
| `palm_up` | `gesture_open_up` | `-0.160` | `+0.907` | `-0.041` | `+92.6 deg` |
| `palm_vertical` | `gesture_open_vertical` | `-1.023` | `-0.179` | `-0.072` | `-108.0 deg` |
| `fist_down` | `gesture_fist_down` | `+0.938` | `-0.131` | `+0.026` | `-83.6 deg` |

Weitere Fist-Lagen wurden ebenfalls aufgenommen:

| Aufnahme | xG | yG | zG | Roll |
| --- | ---: | ---: | ---: | ---: |
| `gesture_fist_side` | `-0.121` | `+0.107` | `+0.799` | `+7.4 deg` |
| `gesture_fist_up` | `-1.015` | `-0.190` | `-0.149` | `-129.5 deg` |
| `gesture_fist_vertical` | `-0.027` | `-1.068` | `+0.008` | `-89.6 deg` |

Die wichtigste Schlussfolgerung:

- Open `down/side/up` trennt sich gut fuer Rotation.
- Open `vertical` ist klar als eigener Moduswechsel sichtbar.
- `fist_down` ist gut genug als einzelner Klickzustand.
- Fist wird nicht als komplette zweite Richtungsfamilie verwendet, weil die
  Interpretation sonst zu komplex und fehleranfaelliger wird.

## Klassifikation

Der Gesture Hub klassifiziert jedes Accelerometer-Sample ueber den naechsten
bekannten Mittelpunkt im 3D-Raum:

```text
distance = sqrt((xG - centerX)^2 + (yG - centerY)^2 + (zG - centerZ)^2)
```

Das Sample wird der Position mit der kleinsten Distanz zugeordnet.

Aktuelle Positionen:

```text
palm_down
palm_side
palm_up
palm_vertical
fist_down
```

Die Erkennung fragt also nicht:

```text
Wie schnell wurde die Hand gedreht?
```

sondern:

```text
Welche bekannte gehaltene Lage sieht dieses Sample am ehesten aus?
```

Das passt besser zur niedrigen Sample-Rate und zu den gemessenen stabilen
Positionen.

## Control-Wechsel

`palm_vertical` ist der Moduswechsel fuer den Gesture Hub.

Die Reihenfolge ist:

```text
Scrollen -> Lautstaerke -> Maus -> Scrollen
```

Verhalten:

- `palm_vertical` ca. `1.2 s` halten.
- Wechsel wird nur einmal pro Vertical-Hold ausgefuehrt.
- Erst wenn die Hand aus `vertical` herausgeht, wird der Wechsel wieder
  scharfgeschaltet.

Dadurch springt der Gesture Hub nicht mehrfach durch alle Controls, wenn
mehrere Samples in derselben Vertical-Haltung eintreffen.

## Control: Scrollen

Scrollen bleibt absichtlich diskret.

Mapping:

```text
palm_up   -> Wheel +120  -> hoch scrollen
palm_side -> neutral     -> nichts senden
palm_down -> Wheel -120  -> runter scrollen
```

Warum nicht analog?

Bei ca. `1 Hz` waere analoges Scrolltempo vermutlich unruhig. Scrollen ist
angenehmer, wenn pro Sample ein klarer Wheel-Schritt gesendet wird.

Technisch nutzt OpenRing unter Windows `SendInput` mit `MOUSEEVENTF_WHEEL`.

## Control: Lautstaerke

Lautstaerke ist analog-relativ.

Das bedeutet:

- Die Handstellung setzt nicht direkt einen absoluten Windows-Volume-Wert.
- Es gibt keinen Sprung auf `0%`, `50%` oder `100%`.
- Die aktuelle Systemlautstaerke wird relativ veraendert.
- `palm_side` ist immer die Ruheposition.

Der Roll-Winkel wird berechnet mit:

```text
roll = atan2(yG, zG)
```

`gesture_open_side` liegt bei ungefaehr:

```text
roll ~= -5.9 deg
```

Um diesen Side-Winkel liegt eine Deadzone. Innerhalb der Deadzone passiert
nichts. Ausserhalb davon gilt:

```text
weiter Richtung palm_up   -> lauter
weiter Richtung palm_down -> leiser
groessere Abweichung      -> groesserer relativer Schritt
```

Beispiel:

```text
Windows-Lautstaerke = 42%
palm_side           -> bleibt 42%
leicht palm_up      -> z. B. 44%
stark palm_up       -> z. B. 50%
palm_down           -> wieder leiser
```

Der Gesture Hub zeigt bei Lautstaerke die aktuelle gelesene
Systemlautstaerke als Prozentwert in der Karte/Overlay an.

## Control: Maus

Maus ist ein dritter Gesture-Hub-Control. Sie ist als grobe Nudge-Steuerung
gedacht, nicht als vollwertiger Maus-Ersatz.

Die Maus hat eine aktive Achse:

```text
Vertikal
Horizontal
```

Beim Betreten des Maus-Control ist die Achse standardmaessig:

```text
Vertikal
```

`palm_side` stoppt die Bewegung und wechselt nach kurzem Halten die Achse:

```text
Vertikal   -> Horizontal
Horizontal -> Vertikal
```

Der Wechsel wird nur einmal pro Palm-Side-Hold ausgefuehrt. Erst nach Verlassen
von `palm_side` wird er wieder scharfgeschaltet.

Mapping fuer Cursorbewegung:

```text
Achse Vertikal:
  palm_up   -> Maus hoch
  palm_down -> Maus runter

Achse Horizontal:
  palm_up   -> Maus links
  palm_down -> Maus rechts
```

`fist_down` ist der Linksklick:

```text
fist_down -> linker Mausklick
```

Auch der Klick wird nur einmal pro Fist-Hold gesendet. Erst wenn die Faust wieder
verlassen wird, kann ein neuer Klick ausgelost werden.

Wichtig: In `Scrollen` und `Lautstaerke` macht `fist_down` keine Aktion. Faust
ist bewusst nur der Klick im Maus-Control.

Technisch nutzt OpenRing unter Windows:

- `SendInput` + `MOUSEEVENTF_MOVE` fuer relative Cursorbewegung
- `SendInput` + `MOUSEEVENTF_LEFTDOWN/LEFTUP` fuer den Linksklick

## UI

Die Gesture-Hub-Karte zeigt:

- Feature-Name `Gesture Hub`
- aktiven Zustand `Aktiv` / `Inaktiv`
- auswaehlbare Controls:
  - `Lautstaerke`
  - `Scrollen`
  - `Maus`
- kompakten Sensorstatus
- bei Lautstaerke den Prozentwert
- bei Maus die aktuelle Achse
- Button `Aktivieren` bzw. `Beenden`

Das Overlay zeigt je nach Control andere Labels:

```text
Scrollen:
  Runter / Stop / Hoch

Lautstaerke:
  Leiser / Neutral / Lauter

Maus Vertikal:
  Runter / Achse / Hoch

Maus Horizontal:
  Rechts / Achse / Links
```

Das vierte Overlay-Feld bleibt der Moduswechsel:

```text
Wechsel
```

Bei Maus wird zusaetzlich angezeigt:

```text
Faust = Klick
```

## Native System Services

Der Gesture Hub nutzt kleine Service-Abstraktionen:

| Service | Aufgabe | Windows-Kanal |
| --- | --- | --- |
| `SystemVolumeService` | Systemlautstaerke lesen/setzen | `openring/system_volume` |
| `SystemScrollService` | globales Mausrad senden | `openring/system_scroll` |
| `SystemMouseService` | Cursor bewegen und linksklicken | `openring/system_mouse` |

Die nativen Windows-Implementierungen liegen im Runner und verwenden
plattformnahe APIs:

- CoreAudio fuer Lautstaerke
- `SendInput` fuer Scroll, Mausbewegung und Klick

Fehler werden nicht still verschluckt. Sie landen im Gesture-Hub-State und
werden in der UI als Error angezeigt.

## Tests

Die automatischen Tests decken die wichtige Logik ab:

- Klassifikation der gemessenen Open-Hand-Lagen
- Klassifikation von `fist_down`
- Auswahl und Sperren von Controls waehrend aktiv
- Control-Reihenfolge `Scrollen -> Lautstaerke -> Maus -> Scrollen`
- diskretes Scrollen und Rate-Limit
- analog-relative Lautstaerke mit Deadzone
- staerkere Roll-Abweichung erzeugt groessere Lautstaerke-Schritte
- Mausachsenwechsel per `palm_side`
- Mausbewegung je Achse
- horizontale Richtung: `palm_up = links`, `palm_down = rechts`
- Linksklick per `fist_down`, genau einmal pro Hold
- `fist_down` ignoriert Scrollen/Lautstaerke
- Widget-Anzeige fuer Controls, Achse und Faust-Klick-Hinweis

Vor der letzten Dokumentation liefen erfolgreich:

```bash
flutter test
flutter analyze
flutter build windows
```

## Grenzen und offene Punkte

Aktuelle Grenzen:

- Die Stock-Firmware liefert nur ungefaehr `1 Hz`.
- Sehr schnelle Gesten wie Doppelklopfen sind dadurch unzuverlaessig.
- Maussteuerung ist grob und dient eher zum Treffen einzelner UI-Ziele.
- Keine Dragging-Geste.
- Kein Rechtsklick.
- Kein Doppelklick.
- Keine adaptive Cursorbeschleunigung.
- Kalibrierwerte stammen aus den aktuellen Aufnahmen und koennen je nach Ring,
  Finger, Ausrichtung oder Firmware abweichen.

Sinnvolle naechste Schritte:

- echte manuelle Nutzung testen und Schrittweite fuer Maus feinjustieren
- pruefen, ob `fist_down` im Alltag stabil genug klickt
- optional Klick-Feedback im Overlay verbessern
- optional per UI die Maus-Schrittweite konfigurierbar machen
- spaeter pro Nutzer/Ring Kalibrierwerte speichern statt feste Zentren zu nutzen
