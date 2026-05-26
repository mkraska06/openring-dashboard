# Motion Research Lab

Diese Notiz beschreibt den aktuellen Zwischenstand der Bewegungsdaten-Arbeit in
OpenRing. Sie soll verständlich machen, welche Daten der COLMI-Ring sendet, wie
OpenRing sie aktuell interpretiert, was bereits implementiert wurde und welche
Schritte als Nächstes sinnvoll sind.

OpenRing ist weiterhin ein experimentelles Projekt. Die folgenden Aussagen
beschreiben den beobachteten Ring und Firmwarestand, nicht garantiert alle
COLMI-Modelle.

## Ziel

Das Ziel des Motion-Deep-Dives ist, die Bewegungsdaten des Rings nicht nur als
einzelne Live-Zahlen zu sehen, sondern als zeitliches Signal zu verstehen.

Damit sollen später Fragen beantwortet werden wie:

- Welche Achse zeigt in welcher Ringlage wohin?
- Wie stabil ist der Sensor, wenn der Ring ruhig liegt?
- Wie stark rauscht der Sensor?
- Welche Bewegungen sind mit der Stock-Firmware überhaupt sichtbar?
- Wann clippt der Messbereich?
- Kann man aus den Rohdaten eigene Auswertungen ableiten, zum Beispiel
  Bewegung während einer HR-/SpO2-Messung, Lagewechsel, einfache Gesten oder
  Aktivitätsmuster?

Der aktuelle Stand ist bewusst ein Research-Werkzeug. Es ist noch keine fertige
Aktivitäts- oder Gestenerkennung.

## Grundlagen: Was misst der Bewegungssensor?

Der Ring sendet rohe Daten eines 3-Achsen-Beschleunigungssensors. Pro Sample
kommen drei Werte an:

```text
X
Y
Z
```

Diese Werte gehören zu den Sensorachsen im Ring. Sie sind nicht automatisch
gleichbedeutend mit "links/rechts", "oben/unten" oder "Finger nach vorne". Die
Orientierung hängt davon ab, wie der Sensor auf der Ringplatine verbaut ist und
wie der Ring am Finger oder auf dem Tisch liegt.

Ein Beschleunigungssensor misst nicht nur aktive Bewegung. Wenn der Ring ruhig
liegt, misst er trotzdem die Erdgravitation. Deshalb ist der Betrag des
Beschleunigungsvektors in Ruhe ungefähr:

```text
1 g
```

`1 g` ist die Erdbeschleunigung:

```text
1 g ~= 9.81 m/s^2
```

Wenn der Ring ruhig auf einer Fläche liegt, verteilt sich diese Gravitation auf
die drei Sensorachsen. Liegt der Ring so, dass fast die ganze Gravitation auf X
fällt, sieht ein plausibler Messpunkt zum Beispiel so aus:

```text
X = 0.95 g
Y = -0.07 g
Z = -0.13 g
```

Wenn der Ring anders gedreht wird, wandert dieser Anteil auf eine andere Achse.
Bei schneller Bewegung entstehen zusätzliche Beschleunigungen. Dann kann der
Betrag deutlich über oder unter `1 g` liegen.

## Rohdaten aus dem COLMI-Protokoll

Der Ring sendet Accelerometer-Daten über das Raw-Sensor-Kommando:

```text
0xA1
```

OpenRing startet den Raw-Sensor-Stream mit:

```text
a1 04 04 ...
```

und stoppt ihn mit:

```text
a1 02 ...
```

Im laufenden Raw-Stream wurden drei wiederkehrende Subtypen beobachtet:

```text
a1 01 ...
a1 02 ...
a1 03 ...
```

Aktuell interpretiert OpenRing nur:

```text
a1 03 = Accelerometer-Daten
```

Die Subtypen `0x01` und `0x02` werden im Debuglog markiert, aber nicht als
Bewegungsdaten geparst. Sie wirken wie weitere Rohdatenkanäle aus dem
Sensor-/Firmwarepfad und werden für das Motion Lab vorerst ignoriert.

Ein Accelerometer-Paket sieht zum Beispiel so aus:

```text
a1 03 1e 89 fd f2 fb 4b 00 00 00 00 00 00 00 80
```

Dabei sind die Achsenbytes:

```text
1e 89 -> X
fd f2 -> Y
fb 4b -> Z
```

Die wichtige Erkenntnis aus den Tests mit echten Ringdaten war: Die Achsenwerte
müssen als `signed 16-bit big-endian` gelesen werden.

Das bedeutet:

```text
1e 89 -> 0x1E89 ->  7817
fd f2 -> 0xFDF2 ->  -526
fb 4b -> 0xFB4B -> -1205
```

Vorher wurden die Werte als little-endian interpretiert. Dadurch entstanden sehr
große und unplausible Zahlen für einen ruhig liegenden Ring.

Die korrigierte Dekodierung ist:

```text
accX = signed16((byte2 << 8) | byte3)
accY = signed16((byte4 << 8) | byte5)
accZ = signed16((byte6 << 8) | byte7)
```

## Umrechnung von Counts nach g

Die Werte, die aus dem BLE-Paket kommen, sind zunächst Rohwerte, also Counts.

Beispiel:

```text
X = 7817
Y = -526
Z = -1205
```

Damit diese Werte leichter verständlich werden, zeigt OpenRing zusätzlich eine
Annäherung in `g` an.

Die aktuell verwendete empirische Skalierung lautet:

```text
8192 Counts ~= 1 g
```

Die Umrechnung ist deshalb:

```text
xG = accX / 8192
yG = accY / 8192
zG = accZ / 8192
```

Für das Beispiel:

```text
xG =  7817 / 8192 ~=  0.954 g
yG =  -526 / 8192 ~= -0.064 g
zG = -1205 / 8192 ~= -0.147 g
```

Zusätzlich berechnet OpenRing den Betrag des Beschleunigungsvektors:

```text
|a| = sqrt(xG^2 + yG^2 + zG^2)
```

Für das Beispiel:

```text
|a| = sqrt(0.954^2 + (-0.064)^2 + (-0.147)^2)
|a| ~= 0.968 g
```

Das ist plausibel für einen ruhig liegenden Ring, weil der Sensor in Ruhe
ungefähr `1 g` Erdgravitation misst.

Die `8192 Counts/g` sind noch keine finale Kalibrierung für alle Ringe. Sie
passen aber gut zu den beobachteten Ruhelagewerten und zu den Clipping-Werten:

```text
32768 Counts / 8192 Counts/g = 4 g
```

In Bewegungsaufnahmen wurden Werte an `-32768` oder `32767` beobachtet. Das
spricht dafür, dass der Sensor oder die Firmware in einem ungefähr `+-4 g`
Bereich arbeitet und schnelle Bewegungen einzelne Achsen sättigen können.

Darum speichert OpenRing weiterhin die Rohwerte als Quelle der Wahrheit. Die
`g`-Werte sind eine abgeleitete Darstellung.

## Was bisher implementiert wurde

### 1. Korrekte Accelerometer-Dekodierung

OpenRing parst `0xA1/0x03`-Pakete jetzt als signed 16-bit big-endian. Dadurch
werden die Rohwerte für ruhende und bewegte Ringlagen plausibel.

Die Live-Anzeige zeigt weiterhin die Rohwerte:

```text
X=7817  Y=-526  Z=-1205
```

Zusätzlich zeigt sie die berechneten `g`-Werte und den Betrag:

```text
X=0.954 g  Y=-0.064 g  Z=-0.147 g  |a|=0.968 g
```

### 2. Debug-Konsole für Raw-Sensor-Pakete

Die BLE-Debugausgabe unterscheidet jetzt die Raw-Sensor-Subtypen:

```text
[RX raw subtype 01] ...
[RX raw subtype 02] ...
[RX raw accel] ...
```

Damit kann man im Terminal sofort sehen, welche Pakete tatsächliche
Accelerometer-Samples sind.

### 3. Motion Lab im Dashboard

Im Dashboard gibt es ein erstes Motion Lab. Es erlaubt:

- Accelerometer-Stream starten
- Sessionnamen vergeben
- Aufnahme starten
- Aufnahme stoppen
- Samplezahl sehen
- aktuelle oder zuletzt gespeicherte Aufnahme plotten

Die Aufnahme ist absichtlich vom Accelerometer-Start getrennt:

- `Starten` aktiviert den Raw-Accelerometer-Stream.
- `Record` startet eine benannte Aufnahmesession.
- `Stop` beendet nur die Aufnahmesession.
- Der Accelerometer-Stream kann weiterlaufen.

### 4. Lokale Speicherung

Motion-Daten werden in SQLite gespeichert.

Es gibt zwei neue Tabellen:

```text
motion_sessions
motion_samples
```

`motion_sessions` speichert:

- Session-ID
- Ring/Gerät
- Name
- Startzeit
- Endzeit

`motion_samples` speichert:

- Session-ID
- Empfangszeitpunkt
- `accX`
- `accY`
- `accZ`

Gespeichert werden die Rohcounts, nicht die abgeleiteten `g`-Werte.

### 5. Plot

Das Motion Lab zeigt vier Kurven:

```text
X
Y
Z
|a|
```

Die Y-Achse ist in `g`, die X-Achse zeigt Sekunden seit Beginn der Session.

Die Kurve `|a|` ist der Betrag des Beschleunigungsvektors. Sie ist hilfreich,
um Bewegungsintensität unabhängig von der aktuellen Ringlage zu sehen.

## Erste Beobachtungen aus echten Aufnahmen

Es wurden erste Sessions aufgezeichnet:

- `bewegen`
- `liegen`

Die Session `liegen` hatte:

```text
Dauer:   67 s
Samples: 66
```

Das entspricht ungefähr 1 Sample pro Sekunde. Das passt zum beobachteten
Verhalten der Stock-Firmware.

Die Magnitude der ruhigen Session lag ungefähr in diesem Bereich:

```text
min |a| ~= 0.831 g
avg |a| ~= 1.071 g
max |a| ~= 1.174 g
```

Es gab keine geclippten Samples. Das ist für eine ruhige Aufnahme plausibel.

Die Session `bewegen` hatte:

```text
Dauer:   77 s
Samples: 77
```

Hier wurden mehrere geclippte Samples beobachtet. Das bedeutet, dass einzelne
Achsen den Messbereich erreicht haben, zum Beispiel:

```text
-32768
32767
```

Das passt zu schnellen oder stärkeren Bewegungen.

## Kalibrierstand vom 2026-05-26

Die folgenden Kalibrieraufnahmen wurden mit einem COLMI R03 gemacht. Sie
beschreiben also zunächst diesen Ring und diesen Firmwarestand.

Ziel der Kalibrierung war, den Ring in ruhigen Lagen so auszurichten, dass
jeweils eine Sensorachse dominiert. Dadurch kann man herausfinden, welche
physische Ringlage zu welchem Vorzeichen der X-, Y- oder Z-Achse gehört.

Eine versehentliche Kurzaufnahme `flach_unten` mit nur 2 Samples wurde
ignoriert. Sie überschreibt keine Daten, weil jede Aufnahme als eigene
Motion-Session gespeichert wird.

Verwendete Sessions:

| Session | Samples | X g | Y g | Z g | Betrag | Bewertung |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `flach_oben` | 26 | `-1.032` | `-0.101` | `-0.169` | `1.051 g` | gut |
| `flach_unten` | 26 | `0.951` | `-0.042` | `-0.111` | `0.958 g` | gut |
| `kontakt_unten` | 26 | `-0.014` | `-1.058` | `-0.092` | `1.062 g` | gut |
| `kontakt_oben` | 26 | `-0.061` | `0.930` | `-0.157` | `0.945 g` | gut |
| `kontakt_links` | 10 | `-0.014` | `-0.050` | `-1.153` | `1.154 g` | gut |
| `kontakt_rechts` | 10 | `-0.064` | `0.031` | `0.845` | `0.848 g` | brauchbar |

Die daraus abgeleitete Achsenkarte:

| Physische Lage | Dominante Sensorantwort |
| --- | --- |
| `flach_oben` | X negativ |
| `flach_unten` | X positiv |
| `kontakt_unten` | Y negativ |
| `kontakt_oben` | Y positiv |
| `kontakt_links` | Z negativ |
| `kontakt_rechts` | Z positiv |

Damit sind alle drei Achsen mit beiden Vorzeichen beobachtet. Die X- und
Y-Lagen sind sehr sauber. Die Z-negative Lage ist ebenfalls sehr sauber. Die
Z-positive Lage ist brauchbar, liegt mit `0.845 g` aber etwas niedriger als
ideal. Für die aktuelle Achsenkarte reicht sie aus; für eine genauere
Skalierung könnte diese Lage später noch einmal wiederholt werden.

Die Kalibrierung bestätigt die bisherige Skalierungsannahme:

```text
8192 Counts ~= 1 g
```

Die ruhigen Lagen liegen überwiegend im Bereich von ungefähr `0.95 g` bis
`1.15 g`. Das ist für manuell ausgerichtete Consumer-Hardware plausibel.

Wichtig ist: Die Kalibrierung macht aus abstrakten X-/Y-/Z-Werten eine
interpretierbare Ring-Achsenkarte. OpenRing kann dadurch künftig besser
einordnen, ob ein Wert nur eine andere Lage des Rings beschreibt oder ob
tatsächlich stärkere Bewegung stattfindet.

## Was der Plot bringt

Ein einzelner Live-Wert zeigt nur einen Moment:

```text
X=0.95 g, Y=-0.07 g, Z=-0.13 g
```

Ein Plot zeigt den Verlauf:

- bleibt der Ring ruhig?
- kippt die Lage?
- wandert Gravitation von einer Achse zur anderen?
- gibt es kurze Ausschläge?
- clippt der Sensor?
- wie regelmäßig kommen Samples?

Damit wird aus einzelnen Zahlen ein Signal, das man untersuchen kann.

Für die Stock-Firmware ist besonders wichtig: Der Stream liefert ungefähr 1 Hz.
Das bedeutet, dass sehr schnelle Bewegungen wie kurze Taps leicht verpasst
werden können. Langsamere Lageänderungen und grobe Bewegungen sind aber gut
sichtbar.

## Aktuelle Grenzen

Das Motion Lab ist ein erster Forschungsstand. Es gibt noch wichtige Grenzen:

- Die `8192 Counts/g` sind eine beobachtete Skalierung, keine finale
  Kalibrierung.
- Die Achsenorientierung wurde für einen COLMI R03 kartiert, sollte aber für
  andere Modelle oder Firmwarestände erneut geprüft werden.
- Die Sample-Rate ist mit Stock-Firmware niedrig.
- Es gibt noch keinen CSV-/JSON-Export.
- Es gibt noch keinen Session-Browser.
- Es gibt noch keine automatische Bewegungs- oder Gestenerkennung.
- Die Subtypen `0xA1/0x01` und `0xA1/0x02` sind noch nicht dekodiert.

## Sinnvolle nächste Schritte

### 1. Kalibrierung verfeinern

Die erste R03-Achsenkarte ist brauchbar. Optional kann die Z-positive Lage noch
einmal wiederholt werden, um näher an `1 g` zu kommen:

```text
kontakt_rechts
```

Dabei sollte vor dem Start der Aufnahme im Live-Wert darauf geachtet werden,
dass X und Y nahe `0 g` liegen und Z positiv dominiert.

Weiteres Ziel:

- prüfen, ob die Z-positive Lage stabil näher an `1 g` gebracht werden kann
- die R03-Achsenkarte bei Bedarf mit weiteren Ringen vergleichen
- Offset und Rauschen je Achse genauer messen

### 2. CSV-Export

Der nächste technische Schritt sollte ein CSV-Export für Motion-Sessions sein.

Damit kann man die gespeicherten Samples außerhalb von OpenRing analysieren,
zum Beispiel in:

- Python
- Jupyter Notebook
- Excel
- LibreOffice

Ein sinnvoller CSV-Aufbau wäre:

```text
session_id,session_name,received_at,elapsed_ms,acc_x,acc_y,acc_z,x_g,y_g,z_g,mag_g
```

Damit lassen sich Kurven, Mittelwerte, Rauschen und Clipping leichter
untersuchen.

### 3. Session-Browser

Aktuell lädt das Dashboard nur die letzte nicht-leere Motion-Session. Für mehr
Analyse wäre ein kleiner Session-Browser sinnvoll:

- Liste gespeicherter Sessions
- Name
- Dauer
- Samplezahl
- Startzeit
- Öffnen im Plot
- später eventuell löschen oder exportieren

### 4. Bewegungsqualität für Vitalmessungen

Ein sehr praktischer Anwendungsfall ist die Bewertung von Bewegung während
Herzfrequenz- oder SpO2-Messungen.

Idee:

```text
Wenn |a| stark schwankt, ist die optische Messung wahrscheinlich unzuverlässiger.
```

Daraus könnte später ein einfacher Qualitätsindikator entstehen:

```text
ruhig
leicht bewegt
stark bewegt
```

Das wäre nützlich, weil optische Messungen am Finger durch Bewegung gestört
werden können.

### 5. Eigene Bewegungserkennung

Erst nach Kalibrierung und Export lohnt sich eigene Logik wie:

- Lagewechsel erkennen
- grobe Aktivität erkennen
- einfache Gesten testen
- Schritt- oder Bewegungsmuster vergleichen
- Ring-als-Maus-Idee bewerten

Diese Schritte brauchen echte Datensätze. Das Motion Lab ist die Grundlage
dafür.

## Kurzfazit

Der bisherige Stand ist ein wichtiger Zwischenschritt:

- Die Accelerometer-Pakete werden plausibel dekodiert.
- Rohwerte werden als Counts gespeichert.
- `g`-Werte und Vektorbetrag werden berechnet.
- Aufnahmen können als Sessions gespeichert werden.
- Bewegungsverläufe sind im Dashboard sichtbar.
- Erste echte Daten zeigen klare Unterschiede zwischen Ruhe und Bewegung.

Damit ist OpenRing jetzt nicht mehr nur ein Live-Monitor für einzelne
Accelerometerzahlen, sondern ein kleines lokales Messlabor für Bewegungsdaten
des Rings.
