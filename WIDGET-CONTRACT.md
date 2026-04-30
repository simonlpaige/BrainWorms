# open-brain widget contract

A widget is glue between three files. Adding a new one means touching all
three. This doc exists so future-you (or future Larry) doesn't have to
reverse-engineer the linkage.

## The three files

| file | role |
|---|---|
| `~/larry-rust/cron.toml` (or `cron.d/<id>.toml`) | **Producer.** A Larry cron job that runs on a schedule, calls tools, and ends with a `write_file` to `openbrain/data/<id>.json`. |
| `~/openbrain/widgets.json` | **Registry.** Tells the dashboard the widget exists, what file to fetch, what `kind` of renderer to use, refresh cadence. |
| `~/openbrain/index.html` | **Renderer.** Has a `render<Kind>()` function registered in the `RENDERERS` table that turns the JSON into DOM. |

## Step-by-step: add a widget

### 1. Pick a slug

Kebab-case, ascii, ≤ 40 chars. Used as the cron `id`, the JSON filename, and
the widget `id`. e.g. `stripe-mrr-trend`.

### 2. Write the producer cron

Drop a file at `~/larry-rust/cron.d/<slug>.toml`. **One** `[[job]]` entry:

```toml
[[job]]
id          = "<slug>"
name        = "<Human title>"
enabled     = true
schedule    = "every 1h"           # or 5-field cron
tz          = "America/Chicago"
kind        = "prompt"             # or "shell" if no LLM reasoning needed
deliver     = "none"               # widget producers don't telegram
timeout_s   = 600
body = """
<prompt body — must end with a write_file call to
 /c/Users/simon/openbrain/data/<slug>.json producing the agreed JSON shape.
 The CRITICAL line: write_file BEFORE final response, or the body is wasted.>
"""
```

Then `POST /api/cron/reload` — the daemon picks up the new file without restart.

### 3. Pick a renderer kind

Existing renderers in `index.html` (look for `const RENDERERS = { ... }`):

| kind | shape expected in JSON |
|---|---|
| `feed` | `{ items: [{title, url?, source?, why?, suggested_action?, ts?}] }` — generic feed, supports per-item Q/✓ buttons |
| `category-bars` | `{ categories: [{name, minutes, sessions?, top_topics?}], total_minutes?, window_days? }` |
| `contact-list` | `{ businesses: [{name, prospects: [{name, last_touch, heat, suggested_action}]}] }` |
| `outreach-detail` | `{ summary?, prospects: [{name, role?, org?, email?, last_touch?, notes?, suggested_action?}] }` |
| `topology` | `{ nodes: [{id, label, group, learning?, x, y}], edges: [{from, to}] }` — SVG map |
| `memory-map` | `{ longterm_chars, longterm_lines, proposed_count, daily_files: [...], categories: {...} }` |
| `security` | `{ findings: [{severity, kind, location, preview?, suggested_fix?}], counts: {...} }` |
| `host-audit` | `{ disk: {free_gb, used_gb, free_pct}, updates_pending, auto_services_not_running, flags: [...] }` |
| `scout-followups` | `{ items: [{title, source_title?, source_url?, action_type, est_effort_minutes?, body?, prerequisites?, first_step?}] }` |

If your shape fits one of these, set `kind` to that. Otherwise: write a new
renderer (step 5 below).

### 4. Register in `widgets.json`

Append to the `widgets` array:

```json
{
  "id": "<slug>",
  "title": "<Human title>",
  "url": "data/<slug>.json",
  "kind": "<one of the renderer kinds>",
  "refresh_s": 120,
  "produced_by": "<slug> cron"
}
```

The dashboard re-fetches `widgets.json` each tick, so the new panel appears
within `min(refresh_s)` seconds. No reload needed.

### 5. (only if you need a new renderer) write a `render<Kind>()` function

Add to `index.html` before the `RENDERERS` table:

```js
function renderMyKind(data, widgetId) {
  const wrap = el('div');
  // ... build DOM via el() helper. Use textContent for any user-supplied data;
  //     never innerHTML for dynamic content (XSS).
  return wrap;
}
```

Then add `'<kind>': renderMyKind,` to `RENDERERS`. Also pick a default
panel size in `defaultLayoutFor` if it should be larger than the standard
460×320 (e.g. `topology` is 980×760).

## Auth + paths

Producer crons that write to `openbrain/data/` need:
- The exact path `C:/Users/simon/openbrain/data/<slug>.json` in the
  `write_file` call. Both Git-Bash style (`/c/...`) and Windows style
  (`C:/...`) work — `tools.rs::normalize_input_path` handles both.
- `~/openbrain/data/` to be in `[tools].write_file_allowed_paths` in
  `~/larry-rust/config.toml` (it is).

Dashboard writes (e.g. modifying `widgets.json` from `+ widget`) need:
- `~/openbrain/widgets.json` in the same allow-list (it is, as a file-mode
  rule — no false-allow on `widgets.json.bak`).

## What NOT to do

- **Don't put the JSON shape spec only in the cron prompt.** It also belongs
  on this page. Otherwise an agent fixing the renderer can't know what to
  render without reading the prompt.
- **Don't `innerHTML` user-supplied content.** Always `textContent` or DOM
  helpers. The hook will (correctly) refuse the file write.
- **Don't telegram every cron run.** Producer crons should `deliver = "none"`.
  Telegram is for things the user actually wants pushed; the dashboard is
  for everything else.
- **Don't make a new renderer kind when an existing one fits.** The five
  built-ins cover most shapes. Reach for `feed` first.
