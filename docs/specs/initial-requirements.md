# OpenRing Desktop Requirements Specification

**Project name:** OpenRing Desktop  
**Version:** 1.0  
**Date:** July 7, 2026  
**Authors:** Marcel Kraska, Andreas Bujarski  
**Status:** Living requirements document

This document describes the functional and technical requirements for OpenRing
Desktop. It is intentionally maintained as a living specification: some
requirements are implemented, others describe the target direction, and some
remain open until the relevant protocol areas are understood more reliably. The
current implementation and test status is tracked in
[requirements-test-matrix.md](requirements-test-matrix.md).

---

## 1. Vision & Scope

### 1.1 Product Vision

OpenRing Desktop is an experimental desktop application for Colmi-compatible
smart rings. The application receives, visualizes, and locally stores vital and
sensor data directly on the desktop.

An integrated overlay mode keeps selected values visible above other windows so
the user can keep an eye on the data while working at the computer. The project
also investigates which desktop controls are possible with the accelerometer
data exposed by the ring.

### 1.2 Problem Statement

The official QRing app is available only for iOS and Android and uses a mobile
app as the central user interface. For users who primarily work on a desktop or
want to inspect their data locally, there is no comfortable native application.
Existing third-party solutions are either CLI tools, such as `colmi_r02_client`
or `RingCLI`, or are not designed for continuous desktop use with an overlay,
history view, and local database.

### 1.3 Target Audience

- users of a Colmi smart ring, including R02, R03, R06, R10, R12, and compatible
  models, who primarily work on a desktop
- users who want to manage vital data locally and offline
- users who want a privacy-friendly alternative without cloud synchronization

### 1.4 Out of Scope for v1.0

- smartphone support for iOS or Android
- cloud synchronization or a server component
- integration with Apple Health, Google Fit, or Strava
- sport mode recording or workout tracking
- ring firmware updates
- complete sleep and stress analysis while the required protocol areas are not
  stable enough
- medical diagnosis or medical advice

## 2. Functional Requirements

### 2.1 Connection & Device Management

| ID | Requirement | Priority |
| --- | --- | --- |
| VM-01 | The system lists all reachable Colmi rings over BLE with name and MAC address. | High |
| VM-02 | The user selects a ring from the list and establishes the BLE connection. | High |
| VM-03 | The system persistently stores the MAC address of the last connected ring. | High |
| VM-04 | On startup, the system automatically connects to the stored ring. | Low |
| VM-05 | The system shows the current connection status as one of four states: searching, connecting, connected, or disconnected. | High |
| VM-06 | The system attempts to restore the connection automatically after connection loss. | High |
| VM-07 | The system shows the connected ring model. | Medium |
| VM-08 | The system shows the firmware version of the connected ring. | Low |
| VM-09 | The system shows the MAC address of the connected ring. | Medium |
| VM-10 | The user can manually disconnect the existing BLE connection. | Medium |
| VM-11 | The system synchronizes the ring time with the desktop system clock on every connection. | Medium |

### 2.2 Heart-Rate Monitoring

| ID | Requirement | Priority |
| --- | --- | --- |
| HF-01 | The system shows the current heart rate from the ring in BPM as a numeric value. | High |
| HF-02 | The system stores every received heart-rate value with a timestamp in the local database. | High |
| HF-03 | The system displays the heart-rate history for a selected day graphically. | High |
| HF-04 | The system displays the heart-rate history for a selected week graphically. | Medium |
| HF-05 | The system displays the heart-rate history for a selected month graphically. | Medium |
| HF-06 | The system calculates and shows the daily average heart rate as a numeric value. | Medium |
| HF-07 | The system determines and shows the daily minimum heart rate as a numeric value. | Medium |
| HF-08 | The system determines and shows the daily maximum heart rate as a numeric value. | Medium |
| HF-09 | The system synchronizes stored heart-rate log data from the ring when the connection is established. | High |

### 2.3 Heart-Rate Variability (HRV)

| ID | Requirement | Priority |
| --- | --- | --- |
| HV-01 | The system shows the current HRV value. | Medium |
| HV-02 | The system stores every received HRV value with a timestamp in the local database. | Medium |
| HV-03 | The system displays the HRV history for a selected day graphically. | Low |
| HV-04 | The system shows a message when the connected ring does not provide HRV data. | Low |
| HV-05 | The system synchronizes stored HRV log data from the ring when the connection is established. | Medium |

### 2.4 Blood Oxygen (SpO2)

| ID | Requirement | Priority |
| --- | --- | --- |
| SP-01 | The system shows the current SpO2 value. | High |
| SP-02 | The system stores every received SpO2 value with a timestamp in the local database. | High |
| SP-03 | The system displays the SpO2 history for a selected day graphically. | Medium |
| SP-04 | The system displays the SpO2 history for a selected week graphically. | Low |
| SP-05 | The system synchronizes stored SpO2 log data from the ring when the connection is established. | High |

### 2.5 Sleep Analysis

| ID | Requirement | Priority |
| --- | --- | --- |
| SA-01 | The system synchronizes sleep data from the ring when the connection is established. | Medium |
| SA-02 | The system shows sleep start time. | Medium |
| SA-03 | The system shows wake time. | Medium |
| SA-04 | The system shows total sleep duration. | Medium |
| SA-05 | The system shows light-sleep duration. | Medium |
| SA-06 | The system shows deep-sleep duration. | Medium |
| SA-07 | The system shows REM-sleep duration. | Low |
| SA-08 | The system shows the number of nightly wake phases. | Low |
| SA-09 | The system displays a sleep graph for one night. | Medium |
| SA-10 | The system displays the sleep graph with phase colors. | Low |
| SA-11 | The system shows a sleep overview for the last 7 days. | Low |

### 2.6 Activity Tracking

| ID | Requirement | Priority |
| --- | --- | --- |
| AT-01 | The system shows the current day's step count. | Medium |
| AT-02 | The system shows the current day's calories burned. | Medium |
| AT-03 | The system shows the current day's distance. | Low |
| AT-04 | The user can set a daily step goal as an integer. | Low |
| AT-05 | The system shows progress toward the step goal. | Low |
| AT-06 | The system displays step count for the last 7 days graphically. | Low |
| AT-07 | The system displays step count for the last 30 days graphically. | Low |
| AT-08 | The system synchronizes stored activity data from the ring when the connection is established. | Medium |

### 2.7 Stress Level

| ID | Requirement | Priority |
| --- | --- | --- |
| SL-01 | The system shows the current stress level. | Medium |
| SL-02 | The system stores every received stress value with a timestamp in the local database. | Low |
| SL-03 | The system displays the stress history for a selected day graphically. | Low |

### 2.8 Accelerometer, Motion Lab & Gesture Hub

The accelerometer area is not only an additional display. It is an experimental
part of the project that helps understand, record, and use the motion data
exposed by the ring for simple desktop controls.

| ID | Requirement | Priority |
| --- | --- | --- |
| AC-01 | The system shows the current raw accelerometer values for the X, Y, and Z axes as numeric values. | Medium |
| AC-02 | The system additionally converts the raw values into approximate g values and the acceleration vector magnitude. | Medium |
| AC-03 | The system can record accelerometer sessions locally and store them with a custom or predefined name. | Medium |
| AC-04 | The system displays saved accelerometer sessions graphically. | Medium |
| AC-05 | The system provides simple per-session analysis, such as sample count, duration, min/max/average values, and stability. | Low |
| AC-06 | The system supports predefined presets for held hand positions so gesture recordings can be named reproducibly. | Medium |
| AC-07 | The system classifies held hand positions based on measured accelerometer centers. | Medium |
| AC-08 | The user can trigger simple desktop actions through the Gesture Hub, such as scrolling, relative volume changes, mouse movement, and left click. | Medium |

### 2.9 Battery & Device Status

| ID | Requirement | Priority |
| --- | --- | --- |
| BA-01 | The system shows the current ring battery level. | High |
| BA-02 | The system shows the ring charging state. | Medium |
| BA-03 | The system shows a visual warning when the battery level falls below 20%. | Medium |
| BA-04 | The system shows the battery history. | Medium |

### 2.10 Device Functions

| ID | Requirement | Priority |
| --- | --- | --- |
| GF-01 | The user can make the ring LED blink as a find function. | Medium |
| GF-02 | The user can restart the ring. | Low |
| GF-03 | The user can reset the ring. | Low |

### 2.11 Data Storage & Export

| ID | Requirement | Priority |
| --- | --- | --- |
| DE-01 | The system stores all data in a local SQLite database. | High |
| DE-02 | The user can choose a date range for data export. | Medium |
| DE-03 | The user can export the selected data as a CSV file. | Medium |
| DE-04 | The user can export the selected data as a JSON file. | Low |
| DE-05 | The user can choose individually which data types are exported. | Low |
| DE-06 | Export includes recorded motion sessions in addition to vital, battery, and activity data when those sessions fall into the selected date range. | Low |

---

## 3. Overlay Requirements

### 3.1 Architectural Decision: Integrated Mode

The overlay is implemented as an integrated mode inside the main application.
Rationale:

- **Shared BLE connection:** The ring allows only one active BLE connection.
- **Seamless transition:** The user can switch between main view and overlay at
  any time through the tray icon or a hotkey.

### 3.2 Functional Overlay Requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| OV-01 | The system keeps the overlay window above all other windows (always on top). | High |
| OV-02 | The overlay shows the current heart rate in BPM as a numeric value. | High |
| OV-03 | The overlay shows the current SpO2 value as a percentage. | High |
| OV-04 | The overlay shows the current ring battery level as a percentage. | Medium |
| OV-05 | The overlay shows the current day's step count as an integer. | Low |
| OV-06 | The overlay renders BPM values above 120 BPM in red. | Medium |
| OV-07 | The overlay renders SpO2 values below 95% in red. | Medium |
| OV-08 | The user can configure the threshold values for OV-06 and OV-07 in settings. | Low |
| OV-09 | The user can freely position the overlay window on screen by dragging it. | High |
| OV-10 | The system persistently stores the overlay window position. | Medium |
| OV-11 | The user can lock the overlay position. | Medium |
| OV-12 | The user can configure overlay opacity. | Low |
| OV-13 | The system hides the overlay window from the taskbar. | Low |
| OV-14 | The overlay shows the ring connection status as an icon (green = connected, grey = disconnected). | Low |
| OV-15 | The user can configure whether each individual parameter is visible in the overlay. | Medium |
| OV-16 | The user can configure the overlay font size. | Low |
| OV-17 | The user can configure the display color of each overlay parameter individually. | Low |
| OV-18 | The user activates the overlay through a UI action, global hotkey, or system tray. | High |
| OV-19 | The system remains open and usable after overlay activation. | High |
| OV-20 | The user deactivates the overlay through a UI action, global hotkey, or system tray. | High |

---

## 4. Non-Functional Requirements

### 4.1 Platform Scope

| ID | Requirement | Priority |
| --- | --- | --- |
| NF-01 | The application targets Windows 11 as the primary desktop platform. | High |
| NF-02 | The application keeps the codebase portable enough to support Linux desktop builds where the required BLE and native-window dependencies are available. | Medium |

### 4.2 Privacy and Data Ownership

| ID | Requirement | Priority |
| --- | --- | --- |
| NF-03 | The application stores user data locally by default. | High |
| NF-04 | The application does not require a cloud account or backend service for its core functionality. | High |

### 4.3 Maintainability and Testability

| ID | Requirement | Priority |
| --- | --- | --- |
| NF-05 | Protocol parsing and packet generation should be deterministic and covered by automated tests. | High |
| NF-06 | Hardware-dependent behavior should be isolated behind service or controller boundaries where practical. | Medium |

## 5. Technical Constraints

### 5.1 Colmi Ring BLE Protocol

Communication with the ring uses BLE (Bluetooth Low Energy). Important
technical details:

- **GATT service UUID:** `6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX characteristic (write):** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX characteristic (notify):** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- **Packet format:** 16 bytes per packet (1 byte command, 14 bytes payload, 1 byte checksum)
- **Checksum:** sum of the first 15 bytes, limited to one byte (`sum & 0xFF`)
- **No pairing/binding required:** the ring accepts connections without a security key

### 5.2 Simultaneous Measurements

The observed Colmi rings use a shared optical measurement path for heart rate,
SpO2 and HRV real-time values. The BLE protocol exposes separate start
and stop commands, but in practice these measurements should be handled
sequentially. A running real-time heart-rate measurement must be stopped before a
SpO2 or HRV measurement can be started reliably.

The ring's interval-based automatic measurement mode, such as the HR log, can be
considered separately because the ring performs it autonomously and transfers
the data later. For the dashboard and overlay, this means that several live
values should be requested through a scheduler in rotation, not in parallel.

### 5.3 Existing Reference Implementations

- **colmi_r02_client** (Python): open-source client with documented BLE protocol -> https://github.com/tahnok/colmi_r02_client
- **RingCLI** (Go/TinyGo): CLI access to ring data -> https://github.com/smittytone/RingCLI
- **ATC_RF03_Ring** (C): custom firmware and hardware documentation -> https://github.com/atc1441/ATC_RF03_Ring

---

## 6. Glossary

| Term | Meaning |
| --- | --- |
| BLE | Bluetooth Low Energy |
| BPM | Beats per minute |
| SpO2 | Peripheral blood oxygen saturation |
| HRV | Heart-rate variability |
| GATT | Generic Attribute Profile, the BLE communication profile used here |
| Overlay | A small window shown above other applications |
| System tray | Notification area of the taskbar on Windows or desktop environments |
| PPG | Photoplethysmography, an optical measurement method for pulse and SpO2 |

---

## AI Assistance Disclosure

This document was revised with AI assistance. The assistance was limited to:

- translating the original German requirements document into English
- improving readability and academic wording
- keeping the original requirement structure and requirement IDs unchanged

The requirements, project scope, and prioritization were defined and reviewed by the project authors.
