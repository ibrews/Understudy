# Test Fixtures

Known-good JSON shapes for the `Envelope` wire format, generated from Swift 5.10's `JSONEncoder`. Use these as round-trip test inputs for Android and any future clients.

- `cue-*.json` — one file per `Cue` case
- `netmsg-*.json` — one file per `NetMessage` case

Each file contains a single line of JSON (the raw bytes a Swift peer would send), uncompressed and with keys **not** sorted (Swift's default ordering may vary; sort on read). Float precision is whatever Swift emits.
