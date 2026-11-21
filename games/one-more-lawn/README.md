# One More Lawn

First-person lawn for a stream overlay. A mower sits in the foreground. The meadow behind it grows and gets cut with the grass count. Open it from the hub with **Play** (`/play/one-more-lawn`). The window has no hub chrome.

The run starts at **1,000,000** grass. If this browser has a save, that number is restored instead.

## Controls

| Control | Does |
| --- | --- |
| Add 1,000 / 10,000 / 100,000 | Adds that much. The delta flashes green under the count. |
| Remove 1,000 / 10,000 / 100,000 | Removes that much. The count stops at 0. The delta flashes red. |
| Custom slider | Stops, in order: 1, 10, 50, 100, 250, 1,000, 2,500, 5,000, 10,000, 25,000, 50,000, 100,000, 250,000, 500,000, 1,000,000. The selected stop is shown. |
| Add custom / Remove custom | Applies the selected stop. |
| Reset | Red 3-2-1 countdown, then the count returns to 1,000,000. |
| Instant reset | Returns to 1,000,000 immediately. |
| Save | Stores the current count in `localStorage` (`gamehub:one-more-lawn:grass`). |

Reset and instant reset change the live number only. The save stays until **Save** is pressed again. Reload restores the save, or 1,000,000 when there is none.

## Scene

Tall clumps and flowers stand in for uncut lawn. Lower counts hide those clumps in patches, starting near the mower, so the striped ground reads as cut grass. Counts above 1,000,000 keep the meadow full and a little taller. The field is one instanced mesh plus trees, light enough for a browser.

## Hub

Runtime is `web`. Settings stay `{ version: 1 }`. Gift events on the live stream are ignored. The counter is the on-screen buttons.
