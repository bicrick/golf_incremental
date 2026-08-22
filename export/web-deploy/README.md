# Range Rat — web deploy (golf.bicrick.com)

Static Godot 4.7 **non-threaded** web export. Hosted as a side site (same pattern as `resume.bicrick.com` / `gd.bicrick.com`), not inside the personal-website repo.

Vercel project (already linked locally under `export/web/.vercel`): **golf-incremental** in team `bicricks-projects`.

## Build

From the golf_incremental repo root:

```bash
./tools/export_web.sh
```

Output lands in `export/web/` (WASM, PCK, JS, HTML) plus `export/web/audio/*.ogg` (BGM streamed on demand).

Approximate sizes after export:
- `index.wasm` ~38 MB
- `index.pck` ~4.5 MB (music excluded)
- `audio/*.ogg` ~14 MB total (one track fetched at a time)
- Whole folder ~57 MB

## Deploy

```bash
cd export/web
npx vercel deploy --prod
```

Or `npm run deploy` from `export/web` after a fresh export (deploy scaffolding is copied in).

## One-time domain / DNS

1. Vercel project **golf-incremental** → Settings → Domains → add `golf.bicrick.com`
2. Squarespace DNS (bicrick.com): CNAME `golf` → `cname.vercel-dns.com`

Personal site only links here (`https://golf.bicrick.com`); it does not host the WASM/PCK.

## Local smoke

```bash
cd export/web && python3 -m http.server 8765
# open http://127.0.0.1:8765/
```

Manual checks:
- [ ] WASM load screen is black + Range Rat title wordmark (not the Godot robot or favicon golf ball)
- [ ] When load completes, black fades out and clouds fade in; logo stays in place
- [ ] Title screen (Range Rat) appears after WASM load
- [ ] Opening theme (`main-theme`) starts on load, then daytime order; first click only unlocks AudioContext if the browser blocked autoplay (does not pick a new track)
- [ ] BGM requests `audio/<track>.ogg` (Network tab) — not bundled in the PCK
- [ ] Saves / settings persist in browser storage
- [ ] Range 3D view and iso view both load

## Notes

- Threads are **off** (`variant/thread_support=false`) so SharedArrayBuffer / site-wide COOP+COEP are not required.
- Music WAVs stay out of the PCK; only OGG files under `audio/` are served.
