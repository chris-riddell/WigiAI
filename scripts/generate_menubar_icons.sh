#!/bin/bash

# Wrapper script to generate menubar icons using the refactored Swift scripts
# This script compiles IconUtils.swift and generate_menubar_icon.swift together

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_BIN="/tmp/gen_menubar_icons_$$"

# Run from project root so relative paths work correctly
cd "$PROJECT_ROOT"

# Compile and run
swiftc "$SCRIPT_DIR/IconUtils.swift" "$SCRIPT_DIR/generate_menubar_icon.swift" -o "$TEMP_BIN" && "$TEMP_BIN"
EXIT_CODE=$?

# Clean up temporary binary
rm -f "$TEMP_BIN"

exit $EXIT_CODE
