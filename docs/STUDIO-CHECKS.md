# Studio checks

Status: not yet run live. Record the Studio version, date and outcome when testing.

1. Install `FlashMeasure.rbxmx` in a separate test place. Check toolbar toggling, a narrow dock and light/dark themes.
2. Try selection-only and expanded scopes, including overlapping roots and removed objects. Verify counts against Explorer.
3. Try the valid and invalid examples in the README. Rejected operations must not edit the place.
4. Start a play test; the plugin must refuse its work. Stop the test and verify it remains usable.
5. Disable/reload the plugin and check for leftover UI, connections or errors.

6. Measure a 2×4×6 part before and after a 90-degree rotation. Confirm local Size stays 2×4×6 and world bounds rotate appropriately.
7. Measure two 2×2×2 parts at origins (0,0,0) and (5,0,0); expect origin distance 5 and X box gap 3. Check touching, overlapping and diagonal cases.
8. Confirm no helper objects or undo entries are created. Change a part after measuring and confirm a new measurement refreshes the snapshot. Click a row whose part was removed and check for a rescan message.
