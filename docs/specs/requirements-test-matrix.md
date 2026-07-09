# Requirements Test Matrix

This document maps the requirements from
[initial-requirements.md](initial-requirements.md) to automated tests, partial
test coverage, or manual acceptance checks.

Last checked: 2026-07-04 against the current Flutter implementation.
`flutter test` passed with 181 tests.

Status values:

| Status | Meaning |
| --- | --- |
| Covered | The requirement is covered by an automated test. |
| Partial | Important logic is covered, but hardware, UI, or integration behavior still needs validation. |
| Manual | The requirement depends on real hardware, native desktop behavior, or platform setup. |
| Open | The feature is not implemented or no suitable test exists yet. |

Test types:

| Type | Meaning |
| --- | --- |
| Unit | Pure Dart logic, parser, packet builder, calculation, or state model test. |
| Storage | Drift/database-backed test using an in-memory database. |
| Widget | Flutter widget or UI rendering test. |
| Integration | Multi-layer app flow with fakes or a test harness. |
| Manual | Human acceptance test with real desktop behavior or ring hardware. |

## 1. Connection And Device Management

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| VM-01 | List reachable Colmi rings with name and MAC address | Integration + Manual | Partial | Fake `BleService` scan test for filtering and UI list; manual BLE scan with real ring. |
| VM-02 | User selects a ring and connects over BLE | Integration + Manual | Partial | Controller/use-case test with fake BLE connect; manual connect test with real ring. |
| VM-03 | Persist last connected ring MAC address | Storage | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks `setLastConnectedDevice` and `getLastConnectedDeviceId`. |
| VM-04 | Auto-connect to saved ring on app startup | Integration + Manual | Partial | `ScanPageNotifier` auto-connects to the saved device ID and `scan_page_controller_test.dart` covers the fake BLE flow; add manual startup acceptance test with a real ring. |
| VM-05 | Show connection status as searching, connecting, connected, or disconnected | Unit / Widget | Partial | Add state/controller test for status transitions and widget test for displayed status. |
| VM-06 | Reconnect automatically after connection loss | Integration + Manual | Partial | `ScanPageNotifier` schedules reconnect after unexpected disconnects and skips reconnect after manual disconnect; fake BLE tests cover both paths, manual ring validation still needed. |
| VM-07 | Show connected ring model | Integration + Widget | Open | Add parser/service model source first, then widget/controller test. |
| VM-08 | Show firmware version | Integration + Widget | Open | Requires implemented firmware query/parser. |
| VM-09 | Show connected ring MAC address | Widget / Integration | Partial | Storage has device ID coverage; add widget/controller test for displayed selected device. |
| VM-10 | User can manually disconnect BLE connection | Integration + Manual | Partial | Dashboard exposes a disconnect action through `ScanPageNotifier.disconnect`; add controller test that it calls the BLE port and manual ring validation. |
| VM-11 | Sync ring time with desktop clock | Unit / Integration | Partial | `makeSetTimePacket` and the Advanced sync action exist; the requirement says sync on every connection, so add a connect-flow test and automatic call if desired. |

## 2. Heart Rate Monitoring

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| HF-01 | Show current heart rate in BPM | Unit / Widget | Partial | Real-time parser and dashboard/overlay rendering paths exist; add focused widget/controller test for displaying latest heart-rate snapshot. |
| HF-02 | Store every received heart-rate value with timestamp | Storage | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) covers live vital sample persistence and pending-value filtering. |
| HF-03 | Display selected day's heart-rate history graphically | Storage / Unit / Widget | Covered | Storage day filtering, chart models, and a history widget smoke test with sample HR data are covered by `storage_repository_test.dart`, `history_chart_models_test.dart`, and `widget_test.dart`. |
| HF-04 | Display selected week's heart-rate history | Storage / Widget | Open | Implement week aggregation/query first. |
| HF-05 | Display selected month's heart-rate history | Storage / Widget | Open | Implement month aggregation/query first. |
| HF-06 | Calculate and display daily average heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily average. |
| HF-07 | Calculate and display daily minimum heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily minimum. |
| HF-08 | Calculate and display daily maximum heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily maximum. |
| HF-09 | Sync stored heart-rate logs on connection | Unit / Integration + Manual | Partial | [test/protocol/hr_log_test.dart](../../test/protocol/hr_log_test.dart) covers log parsing; add connect-flow test and manual ring sync test. |

## 3. Heart Rate Variability

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| HV-01 | Show current HRV value | Unit / Widget | Partial | Real-time parser supports HRV and the dashboard renders supported reading types; add explicit controller/widget test for latest HRV display. |
| HV-02 | Store every received HRV value with timestamp | Storage | Partial | `persistRealTimeReading` maps HRV into vital samples; add explicit HRV storage fixture. |
| HV-03 | Display selected day's HRV history | Storage / Widget | Partial | History page has an HRV chart card backed by generic vital history; add explicit HRV day fixture and widget/chart rendering test. |
| HV-04 | Show message when ring provides no HRV data | Widget / Manual | Open | Add unsupported/timeout state in controller, then widget test. |
| HV-05 | Sync stored HRV logs on connection | Integration + Manual | Open | Requires known HRV log protocol support. |

## 4. Blood Oxygen

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| SP-01 | Show current SpO2 value | Unit / Widget | Partial | Real-time parser and dashboard/overlay rendering paths exist; add explicit controller/widget test for latest SpO2 display. |
| SP-02 | Store every received SpO2 value with timestamp | Storage | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) stores a valid SpO2 reading. |
| SP-03 | Display selected day's SpO2 history | Storage / Widget | Partial | History page has a SpO2 chart card backed by generic vital history; add explicit SpO2 history fixture and chart widget test. |
| SP-04 | Display selected week's SpO2 history | Storage / Widget | Open | Implement week aggregation/query first. |
| SP-05 | Sync stored SpO2 logs on connection | Integration + Manual | Open | Requires stable stored SpO2 log protocol support. |

## 5. Sleep Analysis

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| SA-01 | Sync sleep data on connection | Integration + Manual | Open | Requires implemented sleep protocol/parser. |
| SA-02 | Show sleep start time | Unit / Widget | Open | Add sleep model calculation test after implementation. |
| SA-03 | Show wake time | Unit / Widget | Open | Add sleep model calculation test after implementation. |
| SA-04 | Show total sleep duration | Unit / Widget | Open | Add duration calculation test after implementation. |
| SA-05 | Show light sleep duration | Unit / Widget | Open | Add phase aggregation test after implementation. |
| SA-06 | Show deep sleep duration | Unit / Widget | Open | Add phase aggregation test after implementation. |
| SA-07 | Show REM sleep duration | Unit / Widget | Open | Add phase aggregation test after implementation. |
| SA-08 | Show number of wake phases | Unit / Widget | Open | Add phase counting test after implementation. |
| SA-09 | Display sleep graph for one night | Widget | Open | Add chart-model and widget rendering test after implementation. |
| SA-10 | Display sleep graph with phase colors | Widget | Open | Add widget/golden-style rendering assertion after implementation. |
| SA-11 | Show sleep overview for last 7 days | Unit / Widget | Open | Add 7-day aggregation test after implementation. |

## 6. Activity Tracking

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| AT-01 | Show current day's step count | Storage / Widget | Partial | Dashboard and overlay can show daily steps from live activity or step logs; storage totals are covered, but add explicit widget display tests. |
| AT-02 | Show current day's calories | Storage / Widget | Partial | Dashboard shows calories from live activity or step logs and storage totals are covered; add explicit widget display test. |
| AT-03 | Show current day's distance | Storage / Widget | Partial | Dashboard shows distance from live activity or step logs and storage totals are covered; add explicit widget display test. |
| AT-04 | User can set daily step goal | Storage / Widget | Open | Implement setting storage and UI control first. |
| AT-05 | Show progress toward step goal | Unit / Widget | Open | Add progress calculation and widget test after step goal exists. |
| AT-06 | Display step count for last 7 days | Storage / Widget | Open | Implement 7-day activity aggregation first. |
| AT-07 | Display step count for last 30 days | Storage / Widget | Open | Implement 30-day activity aggregation first. |
| AT-08 | Sync stored activity data on connection | Unit / Integration + Manual | Partial | [test/protocol/steps_test.dart](../../test/protocol/steps_test.dart) covers activity parsing; add connect-flow test and manual ring sync test. |

## 7. Stress Level

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| SL-01 | Show current stress level | Unit / Widget | Open | Requires implemented stress protocol/model. |
| SL-02 | Store every stress value with timestamp | Storage | Open | Add vital kind and storage test after implementation. |
| SL-03 | Display selected day's stress history | Storage / Widget | Open | Add history and chart tests after implementation. |

## 8. Accelerometer

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| AC-01 | Show current accelerometer X/Y/Z raw values | Unit / Widget | Covered | Parser tests cover signed axes and `widget_test.dart` covers `AccelerometerCard` rendering diagnostics and values. |
| AC-02 | Convert raw accelerometer values to g values and magnitude | Unit / Widget | Covered | Motion analysis tests and widget coverage exercise g conversion, magnitude display, and stable-session analysis. |
| AC-03 | Record named accelerometer sessions locally | Storage / Integration | Partial | Motion session storage exists and controller flows append samples; add broader controller coverage for preset/name handling. |
| AC-04 | Display saved accelerometer sessions graphically | Unit / Widget | Partial | Motion Lab records samples and renders `MotionSessionChart`; add explicit chart widget assertions for saved sessions. |
| AC-05 | Provide per-session statistics | Unit | Covered | `gesture_motion_analysis_test.dart` covers statistics, stability, and grouping behavior. |
| AC-06 | Support presets for held hand-position recordings | Unit / Widget | Partial | Preset parsing and grouping are covered in motion tests; add widget coverage for preset selection if needed. |
| AC-07 | Classify held hand positions from measured centers | Unit | Covered | `gesture_hub_controller_test.dart` covers classification of measured open-hand and fist positions. |
| AC-08 | Trigger desktop actions through Gesture Hub | Unit / Integration + Manual | Partial | Gesture Hub unit tests cover scroll, volume, mouse movement, and click mapping; native Windows behavior needs manual validation. |
| AC-09 | Avoid fast tap/swipe/double-tap as core interaction under low sample rate | Review / Manual | Partial | Design is documented in `gesture-hub.md` and `motion-research-lab.md`; manual validation should confirm held-position interaction remains usable. |

## 9. Battery And Device Status

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| BA-01 | Show current battery level | Unit / Widget | Partial | Parser, persistence, dashboard card, and overlay row exist; add explicit widget display test. |
| BA-02 | Show charging status | Unit / Widget | Partial | Parser, persistence, and dashboard icon/text exist; add widget display test for charging state. |
| BA-03 | Show warning when battery is below 20% | Unit / Widget | Open | Add threshold styling/state test. |
| BA-04 | Show battery history | Storage / Widget | Open | Add battery history query and chart test after implementation. |

## 10. Device Functions

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| GF-01 | User can make ring LED blink | Unit / Integration + Manual | Partial | Blink command and Advanced UI action exist; add command packet test, controller test, and manual ring blink test. |
| GF-02 | User can restart ring | Unit / Integration + Manual | Partial | Reboot command and confirmation UI exist; add command packet test, controller test, and manual ring reboot test. |
| GF-03 | User can reset ring | Unit / Integration + Manual | Open | Requires implemented reset command and clear acceptance criteria. |

## 11. Data Storage And Export

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| DE-01 | Store all implemented data in a local SQLite database | Storage | Partial | Drift stores devices, settings, vitals, battery, activity, and motion sessions; requirement remains partial until future sleep/stress/export data types exist. |
| DE-02 | User can choose an export date range | Widget / Integration | Partial | Export UI exposes start/end date pickers and export navigation is widget-tested; add manual file export acceptance test. |
| DE-03 | Export selected data as CSV | Unit / Integration | Partial | CSV formatter, Drift export repository, and selected-folder file writing are covered by `export_formatter_test.dart`, `export_repository_test.dart`, and `export_controller_test.dart`; native desktop folder picker needs manual validation. |
| DE-04 | Export selected data as JSON | Unit / Integration | Partial | JSON formatter and Drift export repository are covered by `export_formatter_test.dart` and `export_repository_test.dart`; export cancellation and the shared selected-folder write flow are covered by `export_controller_test.dart`, native desktop folder picker needs manual validation. |
| DE-05 | User can choose which data types to export | Widget / Integration | Covered | Export UI filter interaction and repository type filtering are covered by `export_card_test.dart` and `export_repository_test.dart`. |
| DE-06 | Export motion sessions in the selected date range | Unit / Integration | Partial | Export repository and formatter include motion rows; add manual validation with recorded motion data and selected-folder export. |

## 12. Overlay Requirements

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| OV-01 | Overlay window is always on top | Manual | Partial | `OverlayController.activateOverlay` calls `windowManager.setAlwaysOnTop(true)`; native behavior needs manual Windows/Linux validation. |
| OV-02 | Overlay shows current heart rate in BPM | Widget | Covered | `overlay_widget_test.dart` covers rendering the heart-rate value. |
| OV-03 | Overlay shows current SpO2 percentage | Widget | Covered | `overlay_widget_test.dart` covers rendering the SpO2 value. |
| OV-04 | Overlay shows battery percentage | Widget | Covered | `overlay_widget_test.dart` covers rendering the battery value. |
| OV-05 | Overlay shows current day's steps | Widget | Covered | `overlay_widget_test.dart` covers rendering daily activity steps. |
| OV-06 | Overlay renders BPM values over 120 in red | Widget | Covered | `overlay_widget_test.dart` covers high heart-rate threshold styling. |
| OV-07 | Overlay renders SpO2 values under 95% in red | Widget | Covered | `overlay_widget_test.dart` covers low SpO2 threshold styling. |
| OV-08 | User can configure thresholds | Storage / Widget | Partial | Threshold settings persist and are tested in `overlay_widget_test.dart`; visible settings UI is still missing. |
| OV-09 | User can drag overlay freely | Manual / Widget | Partial | Interactive mode calls `windowManager.startDragging`; native drag behavior needs manual validation and controller/widget tests. |
| OV-10 | Persist overlay position | Storage / Integration | Covered | `overlay_widget_test.dart` covers `OverlaySettingsNotifier` position persistence through `SharedPreferences`. |
| OV-11 | User can lock overlay position | Unit / Widget | Partial | Interactive mode toggles between click-through locked mode and draggable mode; add clearer UI/state test for the lock behavior. |
| OV-12 | User can configure overlay opacity | Unit / Widget | Partial | Opacity state, persistence, and native application exist; add visible settings UI and tests. |
| OV-13 | Overlay is hidden from taskbar | Manual | Partial | `OverlayController.activateOverlay` calls `windowManager.setSkipTaskbar(true)`; native desktop acceptance test still required. |
| OV-14 | Overlay shows connection status icon | Widget | Partial | `OverlayWidget` renders green/grey connection dot; add widget test for connected/disconnected states. |
| OV-15 | User can toggle each overlay parameter | Unit / Widget | Partial | Visibility state, persistence, and rendering gates are tested; visible settings UI is still missing. |
| OV-16 | User can configure overlay font size | Unit / Widget | Open | Add settings and widget style test. |
| OV-17 | User can configure parameter colors | Unit / Widget | Open | Add settings and widget style test. |
| OV-18 | User activates overlay through a button | Widget / Integration | Partial | Main title bar shows an overlay activation button while connected; add UI/controller test for activation action. |
| OV-19 | App remains open and usable after overlay activation | Manual / Integration | Partial | Overlay is integrated in the same app and system tray can restore the main window; add controller integration test and manual desktop acceptance test. |
| OV-20 | User deactivates overlay through the system | Widget / Integration | Partial | Deactivation exists through tray/hotkey/controller; clarify whether a visible in-app overlay button is required and add tests. |

## 13. Non-Functional Requirements

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| NF-01 | Runs on Windows 11 | Manual / CI | Partial | Manual validation today; later add Windows CI build. |
| NF-02 | Runs on Linux | Manual / CI | Partial | Manual validation today; later add Linux CI build. |
| NF-03 | Ready within 5 seconds after startup | Performance / Manual | Open | Add startup timing acceptance check once release packaging exists. |
| NF-04 | Overlay uses less than 50 MB RAM while idle | Performance / Manual | Open | Add manual/performance measurement procedure. |
| NF-05 | BLE connection established within 10 seconds | Manual | Open | Real hardware acceptance test with measured time. |
| NF-06 | Live HR value appears within 2 seconds after receipt | Integration / Manual | Open | Add fake packet-to-UI timing test; manual ring validation. |
| NF-07 | Store user data only locally | Architecture / Review | Partial | Drift/local-first design documented; add review checklist or static dependency check if needed. |
| NF-08 | Send no user data to external servers | Architecture / Review | Partial | No backend dependency currently; add review checklist/static network dependency check if needed. |
| NF-09 | Main window uses sidebar navigation | Widget / Manual | Covered | `ScanPage` uses `NavigationRail`, and `widget_test.dart` verifies switching to the History section. |
| NF-10 | App is fully keyboard operable | Widget / Manual | Open | Add focused accessibility/manual keyboard test plan. |

## Recommended Next Steps

1. Close the documentation/test gap for implemented functionality:
   - widget tests for dashboard battery, activity totals, HRV, and SpO2 display
   - remaining protocol command packet tests for set-time, blink, and reboot
   - visible settings UI for overlay thresholds, opacity, and value visibility
2. Validate reliability features with real hardware:
   - manual startup acceptance test for auto-connect to the last saved ring
   - manual reconnect test after moving the ring out of range or powering it off/on
   - UI/status checks while reconnect is pending or failing
3. Harden user-facing data export:
   - manual desktop validation of the generated file path
   - optional save-location picker if a file-picker dependency is added later
4. Keep hardware-dependent checks as manual acceptance tests until a reliable
   desktop integration test setup exists.
