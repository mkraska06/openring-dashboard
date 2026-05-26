# Requirements Test Matrix

This document maps the requirements from
[initial-requirements.md](initial-requirements.md) to automated tests, partial
test coverage, or manual acceptance checks.

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
| VM-04 | Auto-connect to saved ring on app startup | Integration + Manual | Open | Add startup/controller test with stored device ID and fake BLE service; manual startup acceptance test. |
| VM-05 | Show connection status as searching, connecting, connected, or disconnected | Unit / Widget | Partial | Add state/controller test for status transitions and widget test for displayed status. |
| VM-06 | Reconnect automatically after connection loss | Integration + Manual | Open | Add fake BLE disconnect stream test; manual reconnect test with ring powered off/on or moved out of range. |
| VM-07 | Show connected ring model | Integration + Widget | Open | Add parser/service model source first, then widget/controller test. |
| VM-08 | Show firmware version | Integration + Widget | Open | Requires implemented firmware query/parser. |
| VM-09 | Show connected ring MAC address | Widget / Integration | Partial | Storage has device ID coverage; add widget/controller test for displayed selected device. |
| VM-10 | User can manually disconnect BLE connection | Integration + Manual | Open | Add controller test that disconnect action calls BLE port; manual test with real ring. |
| VM-11 | Sync ring time with desktop clock on connection | Unit / Integration | Partial | Add golden packet test for set-time command and controller test that connect flow sends it. |

## 2. Heart Rate Monitoring

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| HF-01 | Show current heart rate in BPM | Unit / Widget | Partial | Real-time parser is covered; add controller/widget test for displaying latest heart-rate snapshot. |
| HF-02 | Store every received heart-rate value with timestamp | Storage | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) covers live vital sample persistence and pending-value filtering. |
| HF-03 | Display selected day's heart-rate history graphically | Storage / Unit / Widget | Partial | Storage day filtering and chart models covered; add widget test for chart rendering with sample data. |
| HF-04 | Display selected week's heart-rate history | Storage / Widget | Open | Implement week aggregation/query first. |
| HF-05 | Display selected month's heart-rate history | Storage / Widget | Open | Implement month aggregation/query first. |
| HF-06 | Calculate and display daily average heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily average. |
| HF-07 | Calculate and display daily minimum heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily minimum. |
| HF-08 | Calculate and display daily maximum heart rate | Storage / Unit | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) checks daily maximum. |
| HF-09 | Sync stored heart-rate logs on connection | Unit / Integration + Manual | Partial | [test/protocol/hr_log_test.dart](../../test/protocol/hr_log_test.dart) covers log parsing; add connect-flow test and manual ring sync test. |

## 3. Heart Rate Variability

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| HV-01 | Show current HRV value | Unit / Widget | Partial | Real-time parser supports HRV; add controller/widget test for latest HRV display. |
| HV-02 | Store every received HRV value with timestamp | Storage | Partial | Existing vital-sample storage pattern covers generic vitals; add explicit HRV case. |
| HV-03 | Display selected day's HRV history | Storage / Widget | Open | Add day history fixture for HRV and widget/chart rendering test. |
| HV-04 | Show message when ring provides no HRV data | Widget / Manual | Open | Add unsupported/timeout state in controller, then widget test. |
| HV-05 | Sync stored HRV logs on connection | Integration + Manual | Open | Requires known HRV log protocol support. |

## 4. Blood Oxygen

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| SP-01 | Show current SpO2 value | Unit / Widget | Partial | Real-time parser supports SpO2; add controller/widget test for latest SpO2 display. |
| SP-02 | Store every received SpO2 value with timestamp | Storage | Covered | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) stores a valid SpO2 reading. |
| SP-03 | Display selected day's SpO2 history | Storage / Widget | Partial | Storage supports vital kinds; add explicit SpO2 history and chart widget test. |
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
| AT-01 | Show current day's step count | Storage / Widget | Partial | [test/storage/storage_repository_test.dart](../../test/storage/storage_repository_test.dart) covers daily activity totals; add widget display test. |
| AT-02 | Show current day's calories | Storage / Widget | Partial | Daily activity totals are covered; add widget display test. |
| AT-03 | Show current day's distance | Storage / Widget | Partial | Daily activity totals are covered; add widget display test. |
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
| AC-01 | Show current accelerometer X/Y/Z values | Unit / Widget | Partial | [test/protocol/accelerometer_test.dart](../../test/protocol/accelerometer_test.dart) covers signed parsing; add UI/controller display test. |
| AC-02 | Display accelerometer data graphically | Unit / Widget | Open | Add chart model and widget test after graph implementation. |
| AC-03 | Use ring as mouse | Manual / Integration | Open | Experimental idea; needs concrete acceptance criteria before testing. |

## 9. Battery And Device Status

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| BA-01 | Show current battery level | Unit / Widget | Partial | [test/protocol/battery_test.dart](../../test/protocol/battery_test.dart) and storage tests cover parsing/persistence; add widget display test. |
| BA-02 | Show charging status | Unit / Widget | Partial | Battery parser/storage covered; add widget display test for charging state. |
| BA-03 | Show warning when battery is below 20% | Unit / Widget | Open | Add threshold styling/state test. |
| BA-04 | Show battery history | Storage / Widget | Open | Add battery history query and chart test after implementation. |

## 10. Device Functions

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| GF-01 | User can make ring LED blink | Unit / Integration + Manual | Partial | Add command packet test for blink; add controller test that button calls BLE port; manual ring blink test. |
| GF-02 | User can restart ring | Unit / Integration + Manual | Partial | Add command packet test for reboot; add controller test; manual ring reboot test. |
| GF-03 | User can reset ring | Unit / Integration + Manual | Open | Requires implemented reset command and clear acceptance criteria. |

## 11. Data Storage And Export

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| DE-01 | Store all data in a local SQLite database | Storage | Partial | Drift storage tests cover implemented data types; add checks as new data types are added. |
| DE-02 | User can choose an export date range | Widget / Integration | Open | Implement export UI/controller first. |
| DE-03 | Export selected data as CSV | Unit / Integration | Open | Add exporter test with fixed fixture data and expected CSV output. |
| DE-04 | Export selected data as JSON | Unit / Integration | Open | Add exporter test with fixed fixture data and expected JSON output. |
| DE-05 | User can choose which data types to export | Widget / Integration | Open | Add export options state and UI test after implementation. |

## 12. Overlay Requirements

| ID | Requirement Summary | Test Type | Status | Evidence / Suggested Test |
| --- | --- | --- | --- | --- |
| OV-01 | Overlay window is always on top | Manual | Partial | State/controller can be tested, but native always-on-top needs manual Windows/Linux validation. |
| OV-02 | Overlay shows current heart rate in BPM | Widget | Open | Add overlay widget test with heart-rate state. |
| OV-03 | Overlay shows current SpO2 percentage | Widget | Open | Add overlay widget test with SpO2 state. |
| OV-04 | Overlay shows battery percentage | Widget | Open | Add overlay widget test with battery state. |
| OV-05 | Overlay shows current day's steps | Widget | Open | Add overlay widget test with activity state. |
| OV-06 | Overlay renders BPM values over 120 in red | Widget | Open | Add threshold style test. |
| OV-07 | Overlay renders SpO2 values under 95% in red | Widget | Open | Add threshold style test. |
| OV-08 | User can configure thresholds | Storage / Widget | Open | Implement settings first, then persistence and UI tests. |
| OV-09 | User can drag overlay freely | Manual / Widget | Partial | Native drag behavior manual; controller state can be tested. |
| OV-10 | Persist overlay position | Storage / Integration | Open | Add settings persistence test. |
| OV-11 | User can lock overlay position | Unit / Widget | Open | Add overlay-state and widget test. |
| OV-12 | User can configure overlay opacity | Unit / Widget | Open | Add overlay-state and widget test. |
| OV-13 | Overlay is hidden from taskbar | Manual | Open | Native desktop acceptance test. |
| OV-14 | Overlay shows connection status icon | Widget | Open | Add overlay widget test for connected/disconnected states. |
| OV-15 | User can toggle each overlay parameter | Unit / Widget | Open | Add overlay visibility state and widget test. |
| OV-16 | User can configure overlay font size | Unit / Widget | Open | Add settings and widget style test. |
| OV-17 | User can configure parameter colors | Unit / Widget | Open | Add settings and widget style test. |
| OV-18 | User activates overlay through a button | Widget / Integration | Open | Add UI/controller test for activation action. |
| OV-19 | App remains open and usable after overlay activation | Manual / Integration | Open | Add controller integration test; manual desktop acceptance test. |
| OV-20 | User deactivates overlay through a button | Widget / Integration | Open | Add UI/controller test for deactivation action. |

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
| NF-09 | Main window uses sidebar navigation | Widget / Manual | Open | Add widget test once navigation structure is stable. |
| NF-10 | App is fully keyboard operable | Widget / Manual | Open | Add focused accessibility/manual keyboard test plan. |

## Recommended Next Steps

1. Create missing tests in this order:
   - protocol command packets that are already implemented
   - storage and history requirements that already have model support
   - controller tests with fake BLE ports for connection and sync flows
   - widget tests for overlay value display and threshold styling
2. Keep hardware-dependent checks as manual acceptance tests until a reliable
   desktop integration test setup exists.
