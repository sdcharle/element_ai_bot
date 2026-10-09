#!/usr/bin/env bash
# Install element-bot as a systemd service that starts on boot.
# Run on the Pi from anywhere inside the repo:  sudo ./deploy/install_service.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

SERVICE_NAME=element-bot
RUN_USER="${SUDO_USER:-pi}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_DIR/element_bot"
VENV_DIR="$APP_DIR/venv"
ENV_FILE="/etc/$SERVICE_NAME.env"
UNIT_FILE="/etc/systemd/system/$SERVICE_NAME.service"

echo "Installing $SERVICE_NAME for user '$RUN_USER' from $APP_DIR"

# Virtualenv + dependencies, owned by the run user
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    sudo -u "$RUN_USER" python3 -m venv "$VENV_DIR"
fi
sudo -u "$RUN_USER" "$VENV_DIR/bin/pip" install --upgrade pip
sudo -u "$RUN_USER" "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt"

# Secrets file (never overwritten once it exists)
if [[ ! -f "$ENV_FILE" ]]; then
    install -m 600 -o root -g root "$REPO_DIR/deploy/element-bot.env.example" "$ENV_FILE"
    echo "Created $ENV_FILE -- fill in your secrets before starting the service."
    NEEDS_SECRETS=1
fi

cat > "$UNIT_FILE" <<UNIT
[Unit]
Description=Element/Matrix AI timer bot
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$VENV_DIR/bin/python -u $APP_DIR/element_bot/matrix_bot_ai.py
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

if [[ -n "${NEEDS_SECRETS:-}" ]]; then
    echo
    echo "Next: sudo nano $ENV_FILE   then   sudo systemctl start $SERVICE_NAME"
else
    systemctl restart "$SERVICE_NAME"
    systemctl --no-pager status "$SERVICE_NAME" || true
fi
