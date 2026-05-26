# Anforderungsdokumentation: OpenRing Desktop

**Projektname:** OpenRing Desktop
**Version:** 0.2 
**Datum:** 05. April 2026
**Autor:** [Name]
**Status:** In Bearbeitung

---

## 1. Vision & Scope

### 1.1 Produktvision

OpenRing Desktop ist eine Open-Source-Desktopanwendung, die als vollwertige Alternative zur mobilen QRing-App für Colmi Smart Rings dient. Die Anwendung ermöglicht es Vitaldaten ihres Colmi Rings direkt am Desktop zu empfangen, zu visualisieren und zu analysieren.

Ein integrierter Overlay-Modus zeigt ausgewählte Vitalparameter dauerhaft im Vordergrund an, sodass der Nutzer seine Werte jederzeit im Blick hat, während er am Computer arbeitet.

### 1.2 Problemstellung

Die offizielle QRing-App existiert ausschließlich für iOS und Android. Nutzer, die ihren Colmi Ring am Desktop verwenden möchten haben derzeit keine native Möglichkeit, ihre Vitaldaten live zu überwachen oder historische Daten auszuwerten. Bestehende Drittanbieter-Lösungen sind entweder reine CLI-Tools (z. B. colmi_r02_client, RingCLI) oder mobile Apps.

### 1.3 Zielgruppe

- Nutzer eines Colmi Smart Rings (R02, R03, R06, R10, R12 und kompatible Modelle), die primär am Desktop arbeiten
- Nutzer, die ihre Vitaldaten lokal und offline verwalten möchten
- Nutzer, die eine datenschutzfreundliche Alternative ohne Cloud-Anbindung suchen

### 1.4 Abgrenzung (Out of Scope für v1.0)

- Smartphone-Unterstützung (iOS/Android)
- Cloud-Synchronisation oder Server-Komponente
- Integration mit Apple Health, Google Fit oder Strava
- Sportmodus-Aufzeichnung (Workout-Tracking)
- Firmware-Updates des Rings
- Medizinische Diagnose oder Beratung

## 2. Funktionale Anforderungen

### 2.1 Verbindung & Gerätemanagement

| ID    | Anforderung | Priorität |
|-------|-------------|-------|
| VM-01 | Das System listet alle über BLE erreichbaren Colmi Rings mit Name und MAC-Adresse auf. | Hoch |
| VM-02 | Der Nutzer wählt einen Ring aus der Liste aus und stellt die BLE-Verbindung her. | Hoch |
| VM-03 | Das System speichert die MAC-Adresse des zuletzt verbundenen Rings persistent. | Hoch |
| VM-04 | Das System stellt bei Programmstart automatisch die Verbindung zum gespeicherten Ring her. | Niedrig |
| VM-05 | Das System zeigt den aktuellen Verbindungsstatus als einen der vier Zustände „Suche", „Verbinden", „Verbunden" oder „Getrennt" an. | Hoch |
| VM-06 | Das System versucht bei Verbindungsverlust automatisch eine Wiederherstellung der Verbindung. | Hoch |
| VM-07 | Das System zeigt das Gerätemodell des verbundenen Rings an. | Mittel |
| VM-08 | Das System zeigt die Firmware-Version des verbundenen Rings an. | Niedrig |
| VM-09 | Das System zeigt die MAC-Adresse des verbundenen Rings an. | Mittel |
| VM-10 | Der Nutzer kann die bestehende BLE-Verbindung manuell trennen. | Mittel |
| VM-11 | Das System synchronisiert die Uhrzeit des Rings mit der Systemuhrzeit des Desktops bei jedem Verbindungsaufbau. | Mittel |

### 2.2 Herzfrequenz-Monitoring

| ID    | Anforderung                                                                                            | Priorität |
|-------|--------------------------------------------------------------------------------------------------------|-----------|
| HF-01 | Das System zeigt die aktuelle Herzfrequenz des Rings in BPM (Beats per Minute) als numerischen Wert an. | Hoch |
| HF-02 | Das System speichert jeden empfangenen Herzfrequenz-Messwert mit Zeitstempel in der lokalen Datenbank. | Hoch |
| HF-03 | Das System stellt den Herzfrequenzverlauf eines ausgewählten Tages graphisch dar.                      | Hoch |
| HF-04 | Das System stellt den Herzfrequenzverlauf einer ausgewählten Woche graphisch dar.                      | Mittel |
| HF-05 | Das System stellt den Herzfrequenzverlauf eines ausgewählten Monats graphisch dar.                     | Mittel |
| HF-06 | Das System berechnet den Tagesdurchschnitt der Herzfrequenz und zeigt ihn als numerischen Wert an.     | Mittel |
| HF-07 | Das System ermittelt den Tagesminimalwert der Herzfrequenz und zeigt ihn als numerischen Wert an.      | Mittel |
| HF-08 | Das System ermittelt den Tagesmaximalwert der Herzfrequenz und zeigt ihn als numerischen Wert an.      | Mittel |
| HF-09 | Das System synchronisiert die auf dem Ring gespeicherten Herzfrequenz-Logdaten bei Verbindungsaufbau.  | Hoch |

### 2.3 Herzfrequenzvariabilität (HRV)

| ID | Anforderung                                                                                   | Priorität |
|----|-----------------------------------------------------------------------------------------------|-----------|
| HV-01 | Das System zeigt den aktuellen HRV-Wert an.                                                   | Mittel |
| HV-02 | Das System speichert jeden empfangenen HRV-Messwert mit Zeitstempel in der lokalen Datenbank. | Mittel |
| HV-03 | Das System stellt den HRV-Verlauf eines ausgewählten Tages graphisch dar.                     | Niedrig |
| HV-04 | Das System zeigt eine Meldung an, wenn der verbundene Ring keine HRV-Daten liefert.           | Niedrig |
| HV-05 | Das System synchronisiert die auf dem Ring gespeicherten HRV-Logdaten bei Verbindungsaufbau.  | Mittel |

### 2.4 Blutsauerstoff (SpO₂)

| ID    | Anforderung                                                                                    | Priorität |
|-------|------------------------------------------------------------------------------------------------|-----------|
| SP-01 | Das System zeigt den aktuellen SpO₂-Wert an.                                                   | Hoch |
| SP-02 | Das System speichert jeden empfangenen SpO₂-Messwert mit Zeitstempel in der lokalen Datenbank. | Hoch |
| SP-03 | Das System stellt den SpO₂-Verlauf eines ausgewählten Tages graphisch dar.            | Mittel |
| SP-04 | Das System stellt den SpO₂-Verlauf einer ausgewählten Woche graphisch dar.            | Niedrig |
| SP-05 | Das System synchronisiert die auf dem Ring gespeicherten SpO₂-Logdaten bei Verbindungsaufbau.  | Hoch |

### 2.5 Schlafanalyse

| ID | Anforderung                                                   | Priorität |
|----|---------------------------------------------------------------|-----------|
| SA-01 | Das System synchronisiert die Schlafdaten des Rings bei Verbindungsaufbau. | Mittel |
| SA-02 | Das System zeigt die Einschlafzeit an.                        | Mittel |
| SA-03 | Das System zeigt die Aufwachzeit an.                          | Mittel |
| SA-04 | Das System zeigt die gesamte Schlafdauer an.                  | Mittel |
| SA-05 | Das System zeigt die Dauer der Leichtschlafphase an.          | Mittel |
| SA-06 | Das System zeigt die Dauer der Tiefschlafphase an.            | Mittel |
| SA-07 | Das System zeigt die Dauer der REM-Schlafphase an.            | Niedrig |
| SA-08 | Das System zeigt die Anzahl der nächtlichen Wachphasen an.    | Niedrig |
| SA-09 | Das System stellt den Schlafverlauf einer Nacht graphisch dar. | Mittel |
| SA-10 | Das System stellt den Schlafverlauf farblich dar.             | Niedrig |
| SA-11 | Das System zeigt einen Schlafüberblick der letzten 7 Tage an. | Niedrig |

### 2.6 Aktivitätstracking

| ID | Anforderung                                                                                     | Priorität |
|----|-------------------------------------------------------------------------------------------------|-----------|
| AT-01 | Das System zeigt die Schrittzahl des aktuellen Tages an.                                        | Mittel |
| AT-02 | Das System zeigt die verbrannten Kalorien des aktuellen Tages an.                               | Mittel |
| AT-03 | Das System zeigt die zurückgelegte Distanz des aktuellen Tages an.                              | Niedrig |
| AT-04 | Der Nutzer kann ein tägliches Schrittziel als Ganzzahl festlegen.                               | Niedrig |
| AT-05 | Das System zeigt den Fortschritt zum Schrittziel an.                                            | Niedrig |
| AT-06 | Das System stellt die Schrittzahl der letzten 7 Tage graphisch dar.                             | Niedrig |
| AT-07 | Das System stellt die Schrittzahl der letzten 30 Tage graphisch dar.                            | Niedrig |
| AT-08 | Das System synchronisiert die auf dem Ring gespeicherten Aktivitätsdaten bei Verbindungsaufbau. | Mittel |

### 2.7 Stresslevel

| ID    | Anforderung                                                                                 | Priorität |
|-------|---------------------------------------------------------------------------------------------|-----------|
| SL-01 | Das System zeigt den aktuellen Stresslevel an.   | Mittel |
| SL-02 | Das System speichert jeden empfangenen Stresswert mit Zeitstempel in der lokalen Datenbank. | Niedrig |
| SL-03 | Das System stellt den Stressverlauf eines ausgewählten Tages graphisch dar.        | Niedrig |

### 2.8 Accelerometer

| ID    | Anforderung                                                                                      | Priorität |
|-------|--------------------------------------------------------------------------------------------------|-----------|
| AC-01 | Das System zeigt die aktuellen Accelerometer-Rohdaten (X-, Y-, Z-Achse) als numerische Werte an. | Niedrig |
| AC-02 | Das System stellt die Accelerometer-Daten graphisch dar.                                         | Niedrig |
| AC-03 | (Idee: Ring als maus nutzen)                                                                     | Niedrig |

### 2.9 Batterie & Gerätestatus

| ID | Anforderung                                                                      | Priorität |
|----|----------------------------------------------------------------------------------|-----------|
| BA-01 | Das System zeigt den aktuellen Batteriestand des Rings an.                       | Hoch |
| BA-02 | Das System zeigt den Ladestatus des Rings als „Lädt" an.                         | Mittel |
| BA-03 | Das System zeigt eine visuelle Warnung, wenn der Batteriestand unter 20 % fällt. | Mittel |
| BA-04 | Das System zeigt den Ladeverlauf des Rings an.                                   | Mittel |

### 2.10 Gerätefunktionen

| ID | Anforderung                                                            | Priorität |
|----|------------------------------------------------------------------------|-----------|
| GF-01 | Der Nutzer kann die LED des Rings zum Blinken bringen (Find-Funktion). | Mittel |
| GF-02 | Der Nutzer kann den Ring neu starten.                                  | Niedrig |
| GF-03 | Der Nutzer kann den Ring reseten.                                      | Niedrig |

### 2.11 Datenspeicherung & Export

| ID    | Anforderung                                                        | Priorität |
|-------|--------------------------------------------------------------------|-----------|
| DE-01 | Das System speichert alle Daten in einer lokalen SQLite-Datenbank. | Hoch |
| DE-02 | Der Nutzer kann einen Datumsbereich für den Datenexport auswählen. | Mittel |
| DE-03 | Der Nutzer kann die ausgewählten Daten als CSV-Datei exportieren.  | Mittel |
| DE-04 | Der Nutzer kann die ausgewählten Daten als JSON-Datei exportieren. | Niedrig |
| DE-05 | Der Nutzer kann individuell festlegen, welche Daten exportiert werden.          | Niedrig |

---

## 3. Overlay-Anforderungen

### 3.1 Architekturentscheidung: Integrierter Modus

Das Overlay wird als **integrierter Modus innerhalb der Hauptanwendung** realisiert. Begründung:

- **Gemeinsame BLE-Verbindung:** Der Ring erlaubt nur eine aktive BLE-Verbindung.

- **Nahtloser Übergang:** Der Nutzer wechselt jederzeit zwischen Hauptansicht und Overlay über das Tray-Icon oder einen Hotkey.

### 3.2 Funktionale Overlay-Anforderungen

| ID    | Anforderung                                                                                         | Priorität |
|-------|-----------------------------------------------------------------------------------------------------|-----------|
| OV-01 | Das System zeigt das Overlay-Fenster stets im Vordergrund aller anderen Fenster an (Always-on-Top). | Hoch |
| OV-02 | Das Overlay zeigt die aktuelle Herzfrequenz in BPM als numerischen Wert an.                         | Hoch |
| OV-03 | Das Overlay zeigt den aktuellen SpO₂-Wert als Prozentwert an.                                       | Hoch |
| OV-04 | Das Overlay zeigt den aktuellen Batteriestand des Rings als Prozentwert an.                         | Mittel |
| OV-05 | Das Overlay zeigt die Schrittzahl des aktuellen Tages als Ganzzahl an.                              | Niedrig |
| OV-06 | Das Overlay zeigt BPM-Werte über 120 BPM in roter Schriftfarbe an.                                  | Mittel |
| OV-07 | Das Overlay zeigt SpO₂-Werte unter 95 % in roter Schriftfarbe an.                                   | Mittel |
| OV-08 | Der Nutzer kann die Schwellenwerte für OV-07 und OV-08 in den Einstellungen konfigurieren.          | Niedrig |
| OV-09 | Der Nutzer kann das Overlay-Fenster per Drag & Drop frei auf dem Bildschirm positionieren.          | Hoch |
| OV-10 | Das System speichert die Position des Overlay-Fensters persistent.                                  | Mittel |
| OV-11 | Der Nutzer kann die Position des Overlays über eine Sperrfunktion fixieren.                         | Mittel |
| OV-12 | Der Nutzer kann die Transparenz (Opacity) des Overlays einstellen.                                  | Niedrig |
| OV-13 | Das System zeigt das Overlay-Fenster nicht in der Taskleiste an.                                    | Niedrig |
| OV-14 | Das Overlay zeigt den Verbindungsstatus des Rings als Icon an (grün = verbunden, grau = getrennt).  | Niedrig |
| OV-15 | Der Nutzer kann für jeden Parameter einzeln einstellen, ob er im Overlay sichtbar ist.              | Mittel |
| OV-16 | Der Nutzer kann die Schriftgröße des Overlays einstellen.                                           | Niedrig |
| OV-17 | Der Nutzer kann die Anzeigefarbe jedes Parameters im Overlay individuell festlegen.                 | Niedrig |
| OV-18 | Der Nutzer aktiviert das Overlay über einen Button im System.                                       | Hoch |
| OV-19 | Das System bleibt nach Aktivierung des Overlays geöffnet und bedienbar.                             | Hoch |
| OV-20 | Der Nutzer deaktiviert das Overlay über einen Button im System.                                 | Hoch |

---

## 4. Nicht-funktionale Anforderungen

### 4.1 Plattformen

| ID    | Anforderung                              | Priorität |
|-------|------------------------------------------|-----------|
| NF-01 | Das System ist auf Windows 11 lauffähig. | Hoch |
| NF-02 | Das System ist auf Linux lauffähig.      | Mittel |

### 4.2 Leistung

| ID | Anforderung | Priorität |
|----|-------------|-----------|
| NF-03 | Das System erreicht den betriebsbereiten Zustand innerhalb von 5 Sekunden nach Programmstart. | Mittel |
| NF-04 | Das Overlay-Fenster belegt im Leerlauf weniger als 50 MB RAM. | Mittel |
| NF-05 | Das System stellt die BLE-Verbindung zum Ring innerhalb von 10 Sekunden her. | Mittel |
| NF-06 | Das System zeigt einen empfangenen Echtzeit-Herzfrequenzwert innerhalb von 2 Sekunden nach Empfang an. | Mittel |

### 4.3 Datenschutz & Sicherheit

| ID | Anforderung | Priorität |
|----|-------------|-----------|
| NF-07 | Das System speichert alle Nutzerdaten ausschließlich lokal auf dem Rechner des Nutzers. | Hoch |
| NF-08 | Das System sendet keine Nutzerdaten an externe Server. | Hoch |

### 4.4 Usability

| ID | Anforderung | Priorität |
|----|-------------|-----------|
| NF-09 | Das Hauptfenster der Anwendung verwendet eine Seitenleiste zur Navigation zwischen den Funktionsbereichen. | Mittel |
| NF-10 | Das System ist vollständig per Tastatur bedienbar. | Niedrig |

## 5. Technische Rahmenbedingungen

### 5.1 Colmi Ring BLE-Protokoll

Die Kommunikation mit dem Ring erfolgt über BLE (Bluetooth Low Energy). Wichtige technische Details:

- **GATT Service UUID:** `6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX Characteristic (Write):** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX Characteristic (Notify):** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- **Paketformat:** 16 Byte pro Paket (1 Byte Command, 14 Byte Payload, 1 Byte Checksum)
- **Checksum:** Summe der ersten 15 Bytes modulo 255
- **Kein Pairing/Binding erforderlich** – der Ring akzeptiert Verbindungen ohne Sicherheitsschlüssel

### 5.2 Gleichzeitige Messungen

Der Ring verwendet einen einzelnen optischen Sensor (Vcare VC30F) für Herzfrequenz- und SpO₂-Messungen. Beide Messungen nutzen unterschiedliche LED-Wellenlängen (grünes Licht für HR, duales Rot/Infrarot für SpO₂). Das BLE-Protokoll verarbeitet Anfragen sequentiell. Das bedeutet: Eine laufende Echtzeit-HR-Messung muss beendet werden, bevor eine SpO₂-Messung gestartet werden kann. Die Interval-basierte automatische Messung auf dem Ring (HR-Log) kann hingegen unabhängig im Hintergrund laufen, da der Ring diese autonom durchführt und die Daten bei der nächsten Synchronisation überträgt. Für das Overlay ergibt sich daraus, dass BPM und SpO₂ im Wechsel abgefragt werden müssen, nicht gleichzeitig.

### 5.3 Bestehende Referenzimplementierungen

- **colmi_r02_client** (Python): Open-Source-Client mit dokumentiertem BLE-Protokoll → https://github.com/tahnok/colmi_r02_client
- **RingCLI** (Go/TinyGo): CLI-Zugriff auf Ring-Daten → https://github.com/smittytone/RingCLI
- **ATC_RF03_Ring** (C): Custom Firmware und Hardware-Dokumentation → https://github.com/atc1441/ATC_RF03_Ring


---

## 6. Glossar

| Begriff | Bedeutung |
|---------|-----------|
| BLE | Bluetooth Low Energy – energiesparendes Bluetooth-Protokoll |
| BPM | Beats per Minute – Herzschläge pro Minute |
| SpO₂ | Periphere Sauerstoffsättigung des Blutes |
| HRV | Heart Rate Variability – Herzfrequenzvariabilität |
| GATT | Generic Attribute Profile – BLE-Kommunikationsprotokoll |
| Overlay | Ein kleines, stets sichtbares Fenster über anderen Anwendungen |
| System Tray | Infobereich der Taskleiste (Windows) bzw. Benachrichtigungsbereich (Linux) |
| PPG | Photoplethysmographie – optische Messtechnik für Puls/SpO₂ |

---

*Dieses Dokument dient als lebende Spezifikation und wird iterativ erweitert.*
