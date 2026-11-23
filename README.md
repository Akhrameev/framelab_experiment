# FrameLab

A small iOS image-effects pipeline with a rendering issue to investigate.
Requires Xcode, an installed iOS Simulator runtime, and simulator Metal support.
No third-party dependencies, downloads, media assets, or signing credentials.

## QA report

Local development previews look correct. QA reports that frames exported by
another build lose their source content for some effects. One effect gives a
black frame; another still shows its artwork, but the image underneath is
missing. Other effects work. No rendering exception is reported, and automated
checks are green.

Investigate and repair the pipeline. Preserve all three effects, the artwork,
and normal error handling. Add tests that would have caught the problem.

## Run

Open `FrameLab.xcodeproj` and test the FrameLab scheme, or use:

```sh
xcrun simctl list devices available
./run.sh Debug YOUR_SIMULATOR_UUID
./run.sh Release YOUR_SIMULATOR_UUID
```

The local workflow uses Debug. The QA/export workflow uses Release. Both use
the same Xcode installation in this lab. The commands save six PNG frames and
an attachment manifest under `Results/`. Inspect the PNGs as well as the test
status. In Xcode, choose the configuration in Scheme → Edit Scheme → Test → Info.

Two synthetic source frames alternate a deterministic asymmetric RGB pattern.
Metal processes the frames before composition. Effects are:

- `tone`: invert source colors.
- `poster`: retain source colors.
- `sticker`: retain source colors and add fixed artwork.

The source texture is intentionally small (8×8), expanded to a 256×192 export.
This keeps the expected pixels easy to reason about. There is no video decoder,
encoder, camera, audio, random seed, or network activity to debug. The outputs
are individual frames, not a recreation of an unavailable video editor.

Behavior can depend on toolchain and platform. If the reported symptom does
not occur, record the environment and output evidence rather than assuming a
successful reproduction. Record `xcodebuild -version`, SDK/runtime versions,
build configuration, changes made, and checks run in your investigation.
