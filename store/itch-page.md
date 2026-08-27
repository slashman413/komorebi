# itch.io page — Komorebi (exact publish config)

This is the copy-paste config for the itch.io project. Everything below maps to a
field in **itch.io → Dashboard → Create/Edit project**.

**Project URL:** `slashman413.itch.io/komorebi`
**Title:** `Komorebi`
**Project type:** `Downloadable` (the HTML build is embedded as a playable upload — see Uploads)
**Classification:** `Games`
**Kind of project:** `HTML` (so the web build can play in the browser; desktop zips still download)
**Release status:** `Prototype / Demo`

## Pricing — Pay What You Want (this is the money-maker, and it is free to publish)
- Pricing model: **"$X or more" → No minimum (Pay what you want)**
- **Minimum price: $0.00** (anyone can download for free)
- **Suggested price: $3.00 USD** (recommended — low enough to feel like a tip, high
  enough to anchor above $0; raise later if conversion is healthy)
- itch.io revenue share: set the slider to whatever you like — **0% to itch is allowed**.
  Publishing costs nothing up-front. (See runbook.)

## Tags (itch "Tags" field — max 10)
`relaxing`, `meditative`, `atmospheric`, `singleplayer`, `controller`, `mindfulness`,
`cozy`, `short`, `godot`, `mouse` — plus set **Genre: `Simulation`** and a secondary
of `Adventure`.

## Tagline (the "Short description or tagline" field, one line)
Breathe with the mountain. A meditative climb paced by 4-7-8 breathing.

## Long description (page body)

Komorebi (木漏れ日 — sunlight filtering through leaves) is a game about slowing down.

There is a mountain, and there is your breath. You do not climb by reflex; you climb by
rhythm. Each inhale steadies your hands, each held breath settles you, each long exhale
finds the next hold. The 4-7-8 breathing pattern — four seconds in, seven held, eight out —
is not a meter on the screen. It is the pulse of the whole world: the light, the sound, and,
on a controller that supports it, a gentle haptic tide under your fingers.

As you settle into the rhythm, the mountain's ecology and soundscape shift around you.

**Features**
- A guided 4-7-8 breathing loop at the heart of every moment
- Contemplative, low-pressure mountain climbing — no fail states, no timers racing you
- One authoritative clock driving visuals, procedural audio, and haptics in perfect sync
- Play in your **browser**, or download for **Windows** and **Linux**
- Controller-friendly (breath-synced haptics on supported pads); full keyboard support

**This is a free demo.** The full experience is in development.

### ☕ Support the game
Komorebi is free — pay what you want, including nothing. If it gave you a calmer minute
and you'd like to fund the full game, you can tip me directly on Ko-fi (no fees, 100% goes
to development):

**→ https://ko-fi.com/ytstories0413**

Every tip literally funds the next stretch of mountain. Thank you. 🏔️

## Uploads (what butler pushes — do NOT upload by hand once the API key is set)
The `Release to itch.io` GitHub Action pushes three channels on every `v*` tag:

| Channel  | Contents                              | itch upload setting                          |
|----------|---------------------------------------|----------------------------------------------|
| `html`   | HTML5 web build (`index.html` at root)| tick **"This file will be played in the browser"** |
| `windows`| `komorebi.exe` + `komorebi.pck`       | tick **Windows** platform                    |
| `linux`  | `komorebi.x86_64` + `komorebi.pck`    | tick **Linux** platform                      |

After the first push, open each upload once in the itch editor and set the checkboxes
above (butler uploads the bytes; the platform/browser flags are a one-time UI toggle).
For the `html` upload also set **Embed options → Manually set size** to roughly
**1280 × 720**, and enable **"Fullscreen button"**.

## Links block (on the page)
- Play in browser (free): also mirrored at https://slashman413.github.io/komorebi/play/
- Support (Ko-fi): https://ko-fi.com/ytstories0413
- Source / devlog: https://github.com/slashman413/komorebi

> Note: Steam publishing is **parked** (the $100 Steam Direct fee was declined). Do not
> reference a Steam wishlist on the itch page until/unless that changes.
