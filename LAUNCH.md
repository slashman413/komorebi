# LAUNCH — the road to first revenue

This file is the single source of truth for shipping Komorebi to a paying platform.
Everything **automatable** is already wired in the repo. What remains are steps only the
**account owner** can perform (creating accounts, paying fees, verifying identity). They are
marked 🔒 and cannot be done by an agent.

## Now live automatically (once enabled)

| Asset | How | Status |
|-------|-----|--------|
| CI (build + test + export) | `.github/workflows/ci.yml` | runs on every push |
| Landing page (JS breathing orb) | `.github/workflows/pages.yml` → GitHub Pages | needs Pages enabled once (below) |
| itch.io auto-deploy on `v*` tag | `.github/workflows/release.yml` → butler | needs `BUTLER_API_KEY` secret (below) |
| Store copy (itch + Steam) | `store/` | done, copy-paste ready |

## Owner checklist to first dollar

### 1. Turn on the landing page (2 min, free)
🔒 Repo **Settings → Pages → Source: "GitHub Actions"**. The next push deploys
`web/` to `https://slashman413.github.io/komorebi/`. Share that link — the playable
4-7-8 orb is the top-of-funnel hook.

### 2. Ship the free demo on itch.io (the realistic first revenue, ~15 min)
1. 🔒 Create the project page **`slashman413/komorebi`** at https://itch.io/game/new
   (paste `store/itch-page.md`; enable **pay-what-you-want**, suggested $5).
2. 🔒 Generate an API key: https://itch.io/user/settings/api-keys
3. 🔒 Add it as a repo secret **`BUTLER_API_KEY`** (Settings → Secrets and variables → Actions).
4. Tag a release — auto-publishes Linux + Windows to itch:
   ```bash
   git tag v0.1.0-demo && git push origin v0.1.0-demo
   ```
   (`release.yml` exports both platforms and `butler push`es them. No key = it skips cleanly.)

> itch.io is the fastest honest path to revenue: free to list, PWYW earns from day one, no
> $100 gate, and it feeds Steam wishlists.

### 3. Set up Steam for the paid release (bigger, slower)
1. 🔒 Pay the **$100 Steam Direct** fee and complete identity/bank/tax verification at
   https://partner.steamgames.com (one-time, per app; recoupable after $1,000 in sales).
2. 🔒 Create the app, get the numeric **appid**.
3. Replace `APPID` with the real appid in **two** places (already stubbed):
   - `src/level/vertical_slice.gd` — the "Wishlist on Steam" button
   - `web/index.html` — `STEAM_APPID`
4. 🔒 Fill the store page from `store/steam-store-copy.md`, upload capsule art + trailer
   (see `store/press-kit.md` asset checklist), submit for review.

### 4. Drive traffic (repeatable, mostly automatable)
- Post the breathing-orb GIF + landing link to r/godot, r/IndieDev, Bluesky, Mastodon.
- The wishlist funnel: landing page → itch demo → Steam wishlist.

## What blocks full autonomy (be honest)
An agent **cannot**: create platform accounts, pass identity/KYC, pay the Steam fee, or make
the human decision that the game is finished and priced. Those four gates are the reason
"fully automated until revenue" stops at this checklist. Everything up to them is done.

## Product gap before it's genuinely worth paying for
The build is a strong vertical slice / demo-alpha, not a finished game. Before a *paid* 1.0:
more climb content, an arc/ending, art pass, and a real trailer. The **free itch demo can and
should ship now** — it earns PWYW tips and builds the wishlist while the full game grows.
