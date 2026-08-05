# Live Heart-Rate History Rendering

This document describes how OpenRing currently handles timestamps for live
heart-rate values from COLMI rings when rendering the History graph.

## Background

The COLMI ring does not provide live heart-rate values as a continuous stream of
independent point measurements. Instead, values arrive in blocks. The number of values 
in each block varies.

A heart-rate value calculated from PPG data is not a true instantaneous value.
The ring firmware needs several optical samples before it can report a BPM value. 
The displayed BPM value is therefore an estimate calculated over a measurement 
window.

In the observed live heart-rate data, values within one block use timestamps
that increase in one-second steps.

During testing, the first timestamp of such a block appeared to align with the
end of the longer green PPG LED measurement phase. After this phase, the LED
remained off for a noticeable pause.

The history therefore uses the first timestamp of a block as the best available
estimate for the end of the optical measurement window.

The 4-second pause used between nearby display windows is based on the same
observation. During testing, the ring's green PPG LED appeared to stay off for
about 3 seconds between live measurement phases. The History uses 4 seconds instead
as a small tolerance margin.

This interpretation is an empirically motivated heuristic. The 
COLMI live protocol is not fully documented, so other firmware or hardware
variants may use different timestamp semantics. For example, a different ring
variant could theoretically use the last timestamp of a block as the block end.

## Display Timestamp Calculation

For the History graph, OpenRing calculates separate display timestamps. The
original timestamps stored in the database are not rewritten.

A live measurement block is detected when consecutive live values are no more
than 6 seconds apart. For each detected block, the first timestamp in that block
is used as the estimated end of the associated optical measurement window.

The values in the block are then distributed evenly across an estimated
measurement window:

- If a previous live measurement block exists within 1 minute, the new
  measurement window starts 4 seconds after the estimated end of the previous
  block.
- If there is no previous live measurement block within 1 minute, OpenRing uses
  a fallback window of 30 seconds before the estimated end of the current block.

The calculated display timestamps are used only for graph rendering. They are
estimates and must not be interpreted as exact sensor measurement times. Their
purpose is to place processed heart-rate result values into a plausible section
of the preceding PPG measurement window.

This prevents a block of transmitted result values from appearing in the graph
as several nearly simultaneous heart-rate events.

Ring log data with its own historical timestamps is not adjusted.

## Assumptions and Limits

This timestamp reconstruction is based on empirical observations from the COLMI
ring used during development and the observed green LED activity during live
heart-rate measurement. Because there is no complete official technical
documentation for the COLMI live protocol, this is not a verified description of
the ring firmware internals.

The implementation is intentionally conservative:

- Original timestamps remain unchanged in storage.
- Estimated display timestamps are calculated separately.
- The calculated timestamps are used only for visualization.
- Ring log data with its own historical timestamps is not adjusted.
- The method may produce different results for other firmware versions or
  hardware variants.

The goal is not to reconstruct exact physiological measurement times. The goal
is to provide a more understandable and less misleading visualization of
blockwise live heart-rate data.

## Implementation Reference

The display timestamp adjustment is implemented in
[lib/src/storage/storage_repository.dart](../lib/src/storage/storage_repository.dart).

Relevant functions:

- `_correctLiveHistoryTimes`
- `_liveMeasurementBlocks`
- `_spreadHistoryBlock`

Relevant constants:

- `_liveBlockGap`: maximum gap between consecutive live values within one block
- `_liveBlockPause`: assumed pause between nearby display windows
- `_liveBlockFallbackDuration`: fallback window when no recent previous block
  exists
- `_liveBlockPreviousWindow`: maximum distance to reuse the previous block as a
  timing reference

The behavior is covered by focused tests in
[test/storage/storage_repository_test.dart](../test/storage/storage_repository_test.dart).
