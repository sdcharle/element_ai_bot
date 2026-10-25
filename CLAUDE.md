# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Experimental Matrix/Element chat bot (a "meditation gong" timer bot). It listens in a Matrix room, sends each message to an LLM via OpenRouter (free-tier models), and if the model replies with timer JSON it schedules a timer that, on expiry, posts to the room and triggers a function on a Particle IoT device (the physical gong).

## Setup and running

All Python code lives under `element_bot/`:

```
cd element_bot
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python element_bot/matrix_bot_ai.py
```

In production it runs on a Raspberry Pi as the systemd service `element-bot`. `deploy/install_service.sh` generates the unit file and reads secrets from `/etc/element-bot.env` (template: `deploy/element-bot.env.example`). The README has the Pi setup steps. Logs go to `journalctl -u element-bot`. There is no test suite (`element_bot/tests/` is empty), no linter config, and no build step.

Standalone smoke-test scripts:
- `element_bot/element_bot/openai_test_only.py`: one synchronous OpenRouter call (optional model ID as argv[1])
- `element_bot/element_bot/particle_call_only.py`: calls the Particle device function directly

## Configuration (environment variables)

Required: `MATRIX_PASSWORD`, `OPENROUTER_API_KEY` (the bot raises at import time if either is missing).

Optional: `MATRIX_SERVER`, `MATRIX_USER`, `MATRIX_ROOM_ALIAS`, `OPENROUTER_MODELS` (comma-separated, tried in order; default is `DEFAULT_MODELS` in the bot), `SYSTEM_PROMPT`, `PARTICLE_DEVICE_ID`, `PARTICLE_ACCESS_TOKEN`, `PARTICLE_FUNCTION_NAME` (default `timerExpired`). If the Particle credentials are missing, the device call is skipped with a warning.

## Architecture (`matrix_bot_ai.py`)

Everything is in one module that uses module-level globals for state (the rate-limit/cooldown variables, `initial_sync_done`, `connection_timestamp`, `active_timers`).

- **Startup:** random 5–10s delay, then `login`, `join` the room alias, register `message_callback` (for `RoomMessageText`) and `sync_callback`, run an initial sync, post an "online" message, then `sync_forever`.
- **Ignoring history:** messages are dropped unless the initial sync has finished and `event.server_timestamp` is later than `connection_timestamp`. The bot also skips its own messages.
- **Timer protocol:** `SYSTEM_PROMPT` tells the model to reply with exactly `{"time":<seconds>}` for any timer or duration request. `message_callback` searches the reply for `\{\s*"time"\s*:\s*(\d+)\s*\}` (loose, since free models add code fences). On a match, `set_timer` creates an `asyncio` task that sleeps and then calls `timer_handler`. Any other reply is sent to the room as-is. If you change the prompt's output format, update this regex too.
- **Timer expiry:** `timer_handler` calls `call_particle_function()`, which makes a blocking `requests.post` to the Particle cloud API inside the event loop, then posts "Timer expired!" to the room. Timers live only in memory and are lost on restart.
- **Model fallback:** `try_models` walks `OPENROUTER_MODELS` in order and moves to the next model on 404 (model rotated out), 429, 5xx, timeouts, or an empty reply. 401/402 are raised immediately. The SDK's own retries are disabled (`max_retries=0`) so fallback is fast. OpenRouter rotates free models often, so expect to update `DEFAULT_MODELS`.
- **Rate limiting:** at least 3s plus up to 2s of jitter between calls, exponential backoff when every model is rate limited (5 retries), then a 60s cooldown during which the bot replies with a cooldown message instead of calling the API.

`call_particle_function` is duplicated between `matrix_bot_ai.py` and `particle_call_only.py`. Keep the two in sync, or have the script import it from the bot.
