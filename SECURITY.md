# Security

This is an experimental device customization for an old Linux/Qt firmware.
Keep ADB and optional HTTPS providers on a trusted LAN. Do not forward their ports
from the Internet. Classic TCP ADB on this firmware is not Android 11 wireless
pairing and must not be treated as a secure public service.

Optional media and voice services require independent device credentials and
TLS certificate verification. Never reuse DSM, MacRemote admin or cloud tokens.
The media server binds an explicit RFC1918 address and exposes only selected
roots/files to one configured CGS2 device credential. Admin and playback credentials
are separate. Do not share the admin token or whole private service directory.

The voice path records only after a fresh explicit Start request. Stop ends capture
and lets the bounded buffered tail finish; leaving the face cancels the session.
Microphone PCM and recognized text are not written to persistent files or logs.
Temporary IPC text lives in RAM-backed `/tmp`; do not attach it to issue reports.

Before reporting an issue, remove device/network identifiers, credentials, album
links, media filenames, raw audio and recognized text. Report firmware hashes,
release version, sanitized error codes and reproduction steps. Report sensitive
vulnerabilities privately through the repository owner's GitHub profile rather
than a public issue.
