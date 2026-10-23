# Changelog

## Unreleased

- Preserve all four vendor EGLFS dimensions during installer restarts to avoid
  incorrect full-screen scaling; verify the child process environment in tests.
- Keep symlink checks compatible with the device BusyBox find implementation.

- Separate photo, video and music pages; move weather and face-motion switches
  into Display & Connection.
- Shuffle photo batches without immediate repeats and prefetch the chosen next
  image, including across sparse pages. Preserve the current image while waiting.
- Replace the Micro illustration with a direct capture of the real device,
  preserving its configured shortcut icons.
- Pair Live Photos by embedded content identifiers, prepare bounded H.264/AAC
  clips on the NAS, and advance the slideshow after playback ends.
- Default video and Live Photo playback to muted, with an explicit sound toggle.
- Filter media by kind before pagination so a video selected alongside thousands
  of photos is immediately available; shuffle folder photos across all pages.
- Add real shell-worker regressions for typed media, shuffle bags, cross-page
  prefetch and empty categories, plus isolated Qt media/panel previews.

## 0.1.0 — 2026-10-24

- Initial public source release with 14 sensor faces and the current orthographic,
  pool, weather, lunar and speech-note interactions.
- Version-pinned local firmware builder, automatic brightness, idle dimming,
  scheduled screen-off and touch-wake handling.
- GPL-2.0-only Wi-Fi lock-order repair source and guarded one-boot trial tooling.
- Backup-aware installation, guarded rollback, privacy audit and CI checks.
- Optional independent NAS media service and local Apple Silicon speech bridge.

Vendor applications, modules, fonts, credentials and personal media are excluded.
