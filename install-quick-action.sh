#!/bin/bash
# Folder Tagger — compatibility alias.
# The right-click Quick Action and the watcher are now installed together by
# install.sh. This wrapper just forwards to it.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/install.sh" "$@"
