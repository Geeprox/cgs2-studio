#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
cd "$(dirname "$0")/.."
mkdir -p .local/pycache
export PYTHONPYCACHEPREFIX="$PWD/.local/pycache"
python3 tests/test_install_transaction.py
python3 tests/test_loader.py
python3 tests/test_media_worker.py
python3 tests/test_release_audit.py
for test in tests/*.mjs tests/*.cjs;do node "$test";done
for file in device/*.sh device/S9* driver/*.sh integrations/voice/device/*.sh integrations/voice/device/S99*;do sh -n "$file";done
clang tests/test_origin.c -o .local/test-origin
.local/test-origin
python3 tools/build_media.py --output ".local/check-media-$$"
echo 'PASS source, transaction, UI behavior, loader and media relay checks'
