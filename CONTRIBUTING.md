# Contributing

Run `python3 tools/check_release.py` and `./tools/check.sh` before sending a change.
Tests requiring your own firmware are separate; see [validation](docs/VALIDATION.md).

Keep base sensor faces usable without any optional backend. New animations must
pause when hidden or asleep, and new input paths must release touch ownership.
Do not persist audio/transcriptions or replay remote control commands after a
reconnect. Keep diagnostics bounded and free of credentials or personal content.

Do not commit vendor binaries, extracted QML, fonts from a device, production
configuration, private album links, screenshots containing personal content, or
models/recordings. Put local inputs, build products and receipts in `.local/`.
Kernel repair additions use GPL-2.0-only; authored user-space additions use MIT.
