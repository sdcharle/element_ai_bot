# element_ai_bot
experiments creating bots for element/matrix chat

## AI models: OpenRouter free tier

The bot sends chat messages to free models on [OpenRouter](https://openrouter.ai), which provides an OpenAI-compatible API. Free models cost nothing per token, but OpenRouter adds and removes them often, so the bot keeps a list and tries each one in order. If a model is gone (404), rate limited, down, or returns nothing, the bot moves to the next one.

### What you need to do

1. **Create an account** at https://openrouter.ai (email or GitHub). You don't need a credit card.
2. **Create an API key** at https://openrouter.ai/keys. Put it in `/etc/element-bot.env` as `OPENROUTER_API_KEY=sk-or-...`.
3. **Allow free model endpoints in your privacy settings** at https://openrouter.ai/settings/privacy. Many free providers log or train on prompts, and if your settings exclude them, every free model fails with `404 No endpoints found matching your data policy`. Don't send anything private to the bot.
4. **Know the limits.** Free models allow 20 requests/minute and **50 requests/day** across all free models. That's enough for a gong timer. If you need more, buying $10 of credits once raises the limit to 1,000/day permanently, even after the credits are spent. Keep your balance at $0 or above, because a negative balance makes even free models return `402`.
5. **Smoke-test the key** (from `element_bot/`, with the venv active):
   ```
   OPENROUTER_API_KEY=sk-or-... python element_bot/openai_test_only.py
   OPENROUTER_API_KEY=sk-or-... python element_bot/openai_test_only.py nvidia/nemotron-3-super-120b-a12b:free   # test a specific model
   ```

### When models get rotated out

The default list is `DEFAULT_MODELS` in `element_bot/element_bot/matrix_bot_ai.py`. The last entry, `openrouter/free`, is OpenRouter's own router that picks any free model that's currently available, so it acts as a catch-all. When the bot falls back, it writes a warning to the logs (`journalctl -u element-bot | grep -i model`). If you keep seeing a model fail with HTTP 404, it has been removed.

To change the list without editing code, add a comma-separated line to `/etc/element-bot.env` and restart the service:
```
OPENROUTER_MODELS=google/gemma-4-31b-it:free,nvidia/nemotron-3-super-120b-a12b:free,openrouter/free
```
For current free models, see https://openrouter.ai/models?max_price=0 or run:
```
curl -s https://openrouter.ai/api/v1/models | python3 -c "import json,sys; [print(m['id']) for m in json.load(sys.stdin)['data'] if m['id'].endswith(':free')]"
```
Small instruction-following chat models work best. The bot needs a model that replies with exactly `{"time":900}` when someone asks for a timer. Avoid coding-only, vision-only, and "content-safety" models.

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
3. Fill in secrets (`MATRIX_PASSWORD`, `OPENROUTER_API_KEY` from the section below, and the `PARTICLE_*` values):
   ```
   sudo nano /etc/element-bot.env
   ```
   This file is root-only and lives outside the repo. Use `KEY=value` lines; multi-line values (e.g. a long `SYSTEM_PROMPT`) aren't supported here.
4. Start it:
   ```
   sudo systemctl start element-bot
   ```
5. Optional: reboot (`sudo reboot`) and confirm it comes back up on its own.

If you're upgrading from the OpenAI version, `/etc/element-bot.env` won't be overwritten, so edit it yourself: rename `BOT_OPENAI_API_KEY` to `OPENROUTER_API_KEY` (with the new key), delete any `OPENAI_MODEL` line, then `git pull` and `sudo systemctl restart element-bot`. You don't need to reinstall requirements.

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
