#!/bin/bash
set -euo pipefail

# Only run in remote (web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo '{"async": true, "asyncTimeout": 600000}'

FLUTTER_VERSION="3.32.4"
FLUTTER_DIR="/home/user/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin"

if [ ! -f "$FLUTTER_BIN/flutter" ]; then
  echo "[session-start] Installing Flutter $FLUTTER_VERSION..."
  cd /home/user

  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o flutter.tar.xz

  tar xf flutter.tar.xz
  rm flutter.tar.xz
  echo "[session-start] Flutter extracted."
fi

export PATH="$FLUTTER_BIN:$PATH"

# Persist PATH for subsequent commands in this session
echo "export PATH=\"$FLUTTER_BIN:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"

cd "${CLAUDE_PROJECT_DIR:-/home/user/cal0appv2}"

echo "[session-start] Running flutter pub get..."
flutter pub get

echo "[session-start] Generating mocks via build_runner..."
dart run build_runner build --delete-conflicting-outputs

echo "[session-start] Done."
