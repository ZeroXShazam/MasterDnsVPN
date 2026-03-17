#!/usr/bin/env bash
# MasterDnsVPN one-liner installer
# Usage:
#   From source (client/dev):  curl -sSL https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/install.sh | bash
#   Server (Linux, prebuilt):  curl -sSL https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/install.sh | sudo bash -s -- server

set -euo pipefail
IFS=$'\n\t'

REPO_URL="${REPO_URL:-https://github.com/masterking32/MasterDnsVPN}"
RAW_URL="${RAW_URL:-https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/MasterDnsVPN}"
MODE="${1:-}"
MODE_LC="$(echo "$MODE" | tr '[:upper:]' '[:lower:]')"

log_info() { echo "[MasterDnsVPN] $*"; }
log_err() { echo "[MasterDnsVPN] ERROR: $*" >&2; exit 1; }

# --- From source: clone, venv, pip, configs ---
do_install_source() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log_info "Using existing repo: $INSTALL_DIR"
    cd "$INSTALL_DIR" || log_err "Cannot cd to $INSTALL_DIR"
    git pull --quiet 2>/dev/null || true
  else
    log_info "Cloning into $INSTALL_DIR ..."
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" || log_err "Clone failed (is git installed?)"
    cd "$INSTALL_DIR" || log_err "Cannot cd to $INSTALL_DIR"
  fi

  if [[ ! -f "requirements.txt" ]]; then
    log_err "requirements.txt not found. Bad clone?"
  fi

  if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    if [[ ! -d ".venv" ]]; then
      log_info "Creating virtualenv .venv ..."
      python3 -m venv .venv || log_err "python3 -m venv failed (install python3-venv?)"
    fi
    log_info "Activating .venv and installing dependencies ..."
    # shellcheck disable=SC1091
    source .venv/bin/activate
  fi

  pip install -q -r requirements.txt || log_err "pip install failed"

  for pair in "server_config.toml.simple:server_config.toml" "client_config.toml.simple:client_config.toml" "client_resolvers.simple.txt:client_resolvers.txt"; do
    src="${pair%%:*}"
    dst="${pair##*:}"
    if [[ -f "$src" && ! -f "$dst" ]]; then
      cp -n "$src" "$dst"
      log_info "Created $dst from $src"
    fi
  done

  echo ""
  echo "  MasterDnsVPN installed from source at: $INSTALL_DIR"
  echo "  Run client:  cd $INSTALL_DIR && source .venv/bin/activate && python client.py"
  echo "  Run server:  cd $INSTALL_DIR && source .venv/bin/activate && python server.py"
  echo "  Edit config: client_config.toml, client_resolvers.txt, server_config.toml"
}

# --- Server: run existing Linux server installer (prebuilt binary + systemd) ---
do_install_server() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    log_err "Server installer is for Linux only. Use mode 'client' or no argument for from-source install."
  fi
  if [[ "${EUID:-}" -ne 0 ]]; then
    log_err "Server install must be run as root. Use: curl ... | sudo bash -s -- server"
  fi

  SERVER_DIR="${SERVER_INSTALL_DIR:-/opt/MasterDnsVPN}"
  mkdir -p "$SERVER_DIR"
  cd "$SERVER_DIR" || log_err "Cannot create or access $SERVER_DIR"

  log_info "Downloading and running server installer in $SERVER_DIR ..."
  curl -fLsS "$RAW_URL/server_linux_install.sh" -o server_linux_install.sh || log_err "Download of server_linux_install.sh failed"
  chmod +x server_linux_install.sh
  exec bash server_linux_install.sh
}

case "$MODE_LC" in
  server)
    do_install_server
    ;;
  client|source|"")
    do_install_source
    ;;
  *)
    echo "Usage: $0 [client|server]"
    echo "  client (default) - install from source: clone, venv, pip, configs"
    echo "  server           - Linux only, run prebuilt server installer (requires sudo)"
    exit 1
    ;;
esac
