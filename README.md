# element_ai_bot
experiments creating bots for element/matrix chat

## Running on the Raspberry Pi as a service

The bot runs as a systemd service (`element-bot`) that starts on boot and restarts itself if it crashes.

### One-time setup (on the Pi)

1. Get the code. History was rewritten, so if there's an old clone on the Pi, move it aside and re-clone:
   ```
   git clone git@github.com:sdcharle/element_ai_bot.git
   cd element_ai_bot
   ```
2. Run the installer. It creates `element_bot/venv`, installs requirements, writes `/etc/systemd/system/element-bot.service`, enables it at boot, and creates `/etc/element-bot.env` from `deploy/element-bot.env.example`:
   ```
   sudo ./deploy/install_service.sh
   ```
   The service runs as whoever invoked `sudo`, from wherever the repo is cloned.
3. Fill in secrets (`MATRIX_PASSWORD`, `BOT_OPENAI_API_KEY`, and the `PARTICLE_*` values):
   ```
   sudo nano /etc/element-bot.env
   ```
   This file is root-only and lives outside the repo. Use `KEY=value` lines; multi-line values (e.g. a long `SYSTEM_PROMPT`) aren't supported here.
4. Start it:
   ```
   sudo systemctl start element-bot
   ```
5. Optional: reboot (`sudo reboot`) and confirm it comes back up on its own.

If you previously ran the bot with `nohup`, kill that process first (`pkill -f matrix_bot_ai.py`) so two bots aren't connected at once.

### Day to day

```
sudo systemctl status element-bot      # is it running?
journalctl -u element-bot -f           # follow logs
sudo systemctl restart element-bot     # after editing code or /etc/element-bot.env
sudo systemctl stop element-bot
sudo systemctl disable element-bot     # stop starting it on boot
```

To update: `git pull`, then `sudo ./deploy/install_service.sh` (safe to re-run; it won't touch your env file) or just `sudo systemctl restart element-bot` if requirements didn't change.
