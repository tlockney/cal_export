#!/bin/sh
set -eu

REPO="tlockney/cal_export"
INSTALL_DIR="${HOME}/.local/bin"
VAR_DIR="${HOME}/.local/var"
BINARY="cal_export"
ASSET="cal_export-macos-arm64.tar.gz"
PLIST_NAME="local.cal_export.plist"
PLIST_URL="https://raw.githubusercontent.com/${REPO}/main/${PLIST_NAME}"
AGENT_DIR="${HOME}/Library/LaunchAgents"
AGENT_PLIST="${AGENT_DIR}/${PLIST_NAME}"

# Verify macOS ARM
OS="$(uname -s)"
ARCH="$(uname -m)"
if [ "$OS" != "Darwin" ] || [ "$ARCH" != "arm64" ]; then
  echo "Error: this binary requires macOS on Apple Silicon (arm64)." >&2
  echo "Detected: ${OS} ${ARCH}" >&2
  exit 1
fi

LATEST_URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading latest release..."
curl -fSL -o "${TMPDIR}/${ASSET}" "$LATEST_URL"

echo "Extracting..."
tar xzf "${TMPDIR}/${ASSET}" -C "$TMPDIR"

echo "Installing to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
chmod +x "${INSTALL_DIR}/${BINARY}"

echo "Installed ${BINARY} to ${INSTALL_DIR}/${BINARY}"

# Set up launchd agent
echo ""
echo "Downloading plist template..."
curl -fSL -o "${TMPDIR}/${PLIST_NAME}" "$PLIST_URL"

echo "Configuring launch agent..."
mkdir -p "$VAR_DIR"
mkdir -p "$AGENT_DIR"
sed "s|/Users/YOURUSER|${HOME}|g" "${TMPDIR}/${PLIST_NAME}" > "$AGENT_PLIST"

launchctl unload "$AGENT_PLIST" 2>/dev/null || true
launchctl load "$AGENT_PLIST"
echo "Launch agent installed and loaded."

echo ""
echo "To grant Calendar access, run once manually:"
echo "  ${INSTALL_DIR}/${BINARY} --days 1"
echo "macOS will prompt for permission. After approval, the agent will work automatically."

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "Note: ${INSTALL_DIR} is not in your PATH."
  echo "Add it with:  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
