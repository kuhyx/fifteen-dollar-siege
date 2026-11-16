#!/bin/bash

# ============================================================================
# One palette: no colour literal anywhere but src/ui/palette.gd. Flags in
# src/ and tools/ (*.gd, *.gdshader):
#   Color(0.2, ...)  Color8(...)  Color("#abc")  Color.WHITE (named colours)
#   "#rrggbb" strings  and a vec3/vec4 of plain numbers in a colour line of a shader.
# Use a `Palette.X` constant (a frozen design-system token or a mix of two),
# add one to palette.gd when a new colour is really needed.
#   scripts/check_palette.sh
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly PALETTE_FILE="src/ui/palette.gd"
readonly LITERAL='Color8?\(\s*[-0-9.]|Color\("|Color\.html|Color\.[A-Z]|"#[0-9A-Fa-f]{3,8}"|(COLOR|color|tint)[^;]*vec[34]\(\s*[0-9.]+\s*,\s*[0-9.]+\s*,\s*[0-9.]+'

main() {
    local hits
    hits="$(cd "$REPO_ROOT" && grep -rnE --include='*.gd' --include='*.gdshader' \
        "$LITERAL" src tools | grep -v "^$PALETTE_FILE:" || true)"
    if [[ -n "$hits" ]]; then
        echo "palette: colour literals outside $PALETTE_FILE:" >&2
        head -30 <<<"$hits" >&2
        exit 1
    fi
    echo "palette: no colour literal outside $PALETTE_FILE"
}

main "$@"
