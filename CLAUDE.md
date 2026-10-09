# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Experimental Matrix/Element chat bot (a "meditation gong" timer bot). It listens in a Matrix room, sends each message to OpenAI, and if the model replies with timer JSON it schedules a timer that, on expiry, posts to the room and triggers a function on a Particle IoT device (the physical gong).

## Setup and running

All Python code lives under `element_bot/`:

```
cd element_bot
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python element_bot/matrix_bot_ai.py
```

It has typically been run in the background with `nohup`, which writes the large `nohup.out` files. There is no test suite (`element_bot/tests/` is empty), no linter config, and no build step.

Standalone smoke-test scripts:
- `element_bot/element_bot/openai_test_only.py`: one synchronous OpenAI call
- `element_bot/element_bot/particle_call_only.py`: calls the Particle device function directly

## Configuration (environment variables)

Required: `MATRIX_PASSWORD`, `BOT_OPENAI_API_KEY` (the bot raises at import time if either is missing).

Optional: `MATRIX_SERVER`, `MATRIX_USER`, `MATRIX_ROOM_ALIAS`, `OPENAI_MODEL` (default `gpt-4.1-nano`), `SYSTEM_PROMPT`, `PARTICLE_DEVICE_ID`, `PARTICLE_ACCESS_TOKEN`, `PARTICLE_FUNCTION_NAME` (default `timerExpired`). If the Particle credentials are missing, the device call is skipped with a warning.

## Architecture (`matrix_bot_ai.py`)

Everything is in one module that uses module-level globals for state (the rate-limit/cooldown variables, `initial_sync_done`, `connection_timestamp`, `active_timers`).

- **Startup:** random 5–10s delay, then `login`, `join` the room alias, register `message_callback` (for `RoomMessageText`) and `sync_callback`, run an initial sync, post an "online" message, then `sync_forever`.
- **Ignoring history:** messages are dropped unless the initial sync has finished and `event.server_timestamp` is later than `connection_timestamp`. The bot also skips its own messages.
- **Timer protocol:** `SYSTEM_PROMPT` tells the model to reply with exactly `{"time":<seconds>}` for any timer or duration request. `message_callback` checks the reply against `^\s*{"time":(\d+)}\s*$`. On a match, `set_timer` creates an `asyncio` task that sleeps and then calls `timer_handler`. Any other reply is sent to the room as-is. If you change the prompt's output format, update this regex too.
- **Timer expiry:** `timer_handler` calls `call_particle_function()`, which makes a blocking `requests.post` to the Particle cloud API inside the event loop, then posts "Timer expired!" to the room. Timers live only in memory and are lost on restart.
- **OpenAI rate limiting:** at least 3s plus up to 2s of jitter between calls, exponential backoff on `RateLimitError` (5 retries), then a 60s cooldown during which the bot replies with a cooldown message instead of calling the API.

`call_particle_function` is duplicated between `matrix_bot_ai.py` and `particle_call_only.py`. Keep the two in sync, or have the script import it from the bot.
