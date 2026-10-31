# Flash Measure

Read part dimensions, rotated Size-box bounds and spacing in Studio. The plugin makes no place edits and creates no adornments or helper parts.

## Install

1. Download this repository as a ZIP and extract it. No package installation is needed to use the plugin.
2. In a separate Studio test place, use Explorer's **Insert from File** action to insert `FlashMeasure.rbxmx`.
3. Select the root Script named `FlashMeasure` and choose **Save as Local Plugin**. It contains four child ModuleScripts.
4. Remove the imported root from the place. Open **Flash Measure → Measure** on the Plugins toolbar.

The plugin runs in edit mode. Measuring, previewing and applying are refused during play tests.

## Use it

Select one or more BaseParts. To measure a Model or folder's parts, choose **Include descendants**. Set decimal places (0–6) and click **Measure selection**. Click a result row to select its part. Results are snapshots; measure again after edits or selection changes.

The report shows:

- Each part's local Size and CFrame origin in studs.
- A combined world-axis bounding box, built from all eight transformed corners of every Size box. Rotated parts are included.
- The sum of each part's `Size.X * Size.Y * Size.Z`. This is **summed Size-box volume**, not actual solid volume. Overlaps are counted more than once; spheres, cylinders, unions and meshes are not integrated as solids.
- For exactly two parts, CFrame-origin distance, nonnegative world-axis box gaps and their Euclidean length.

For example, two 2×2×2 parts at `(0, 0, 0)` and `(5, 0, 0)` have origin distance 5 and an X-axis box gap of 3. Their combined world-axis box is 7×2×2. Touching or overlapping world boxes have gap 0.

## Limits

- Up to 500 selection roots, 5000 discovered objects and 1000 eligible parts. Terrain, parts outside Workspace, and parts in nested WorldModels are excluded. Overlapping selections are deduplicated. Locked parts can be measured.
- CFrame origins and box corners must be finite and within one million studs per axis. Sizes must be positive, finite and at most one million studs per axis.
- Only 100 part rows are displayed; all eligible parts in the snapshot contribute to aggregate measurements.
- World-axis boxes are approximations of occupied geometry. Their gap can be zero while the actual shapes are separated. It is **not a mesh, surface-distance, collision or clearance test**.
- CFrame origin distance uses CFrame.Position, not the center of mass, pivot offset or a mesh vertex. Engine precision and display rounding apply.
- No model transforms, script-source reads, physics simulation, file writes or network requests. There is no Apply button or undo recording.

## Inputs and outputs

`Adapter.measure(selection, options)` reads CFrame and Size, transforms eight local box corners with PointToWorldSpace, then returns a report. Options are `{expand, decimals}`. `Rules.report(records)` combines the numeric records and computes two-part metrics when applicable. `Adapter.format(result)` returns the summary and up to 100 row labels. Display rounding never changes the source geometry or the unrounded report values.

See Roblox's [CFrame API](https://create.roblox.com/docs/reference/engine/datatypes/CFrame) and [BasePart API](https://create.roblox.com/docs/reference/engine/classes/BasePart).

## Development and tests

Source is in `src`. The native dock panel follows Studio's theme. UI and scope helpers are copied into each Flash plugin repository so each installs independently. There are no runtime packages, external assets or background services.

Rebuild with Python 3.11+:

```sh
python build.py
python -m unittest discover -s tests -v
```

Run Luau checks with Lune 0.11.1:

```sh
lune run tests/run
```

GitHub Actions compiles all source files, tests the real rules and adapters with fake Studio objects, compares the plugin XML against its source and checks reproducible builds. Measurement tests use Lune's CFrame/Vector3 datatypes and known geometric results. Lune is installed on the CI runner, not on your computer.

**Live Studio installation and dock-panel behavior have not been verified.** Automated checks do not replace the [Studio checklist](docs/STUDIO-CHECKS.md).

MIT licensed; see [LICENSE](LICENSE).
