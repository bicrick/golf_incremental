# Sun/Moon Cycle Retarget — Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the sun and moon trace a readable arc over the **far end of the driving range** (down-range horizon), visible during dawn/day/dusk, with the moon high at night.

**Architecture:** Keep existing `DayNightPalette` orbit math (`celestial_angle`, `celestial_alpha`, `MOON_ORBIT_OFFSET`) but replace camera-lateral 3D direction with a **down-range arc** in world space. Position sprites at a fixed far `-Z` horizon line with elevation from `sin(angle)` and azimuth from `cos(angle)`. Fix a **timing mismatch** where the sun currently sets at ~t=60 while the dusk palette runs t=77–91.

**Tech stack:** Godot 4.7, GDScript, existing `RangeSkyDome` + `DayNightPalette`, headless `verify_day_night.gd`.

---

## Current state (why it feels invisible)

| Piece | Today | Problem |
|-------|-------|---------|
| Arc axis | Camera **right** × world up (`range_sky_dome.gd:112-118`) | Sun crosses left–right on screen, not along the fairway skyline |
| Sprite depth | `direction * 480` on camera-centered dome | No anchor to far end of range (`Z ≈ -300`) |
| Orbit timing | Visible arc = first 50% of 120s orbit (`day_night_palette.gd:163-169`) | Sun sets at **t≈60**; dusk palette is **t=77–91** with no visible sun |
| Dual domes | `SkyDome` (ortho) + `PerspectiveSkyDome` | Both use same broken direction logic |

---

## Target behavior

### Visual (ortho harvest view — primary)

- **Dawn (t≈13–24):** Sun **rises** low on the far horizon (top of frame), slightly off-center
- **Day (t≈24–77):** Sun tracks across the skyline, **highest** near mid-day (~t=50)
- **Dusk (t≈77–91):** Sun **sets** low on the far horizon — warm sky + visible disc
- **Night (t≈91–13):** Sun hidden; **moon** follows same path, offset by `MOON_ORBIT_OFFSET` (0.25), high at midnight

### Arc geometry (world space)

| Constant | Proposed value | Meaning |
|----------|----------------|---------|
| `CELESTIAL_HORIZON_Z` | `-RangeGrid.DEPTH_YARDS` (-300) | Far end of grass |
| `CELESTIAL_HORIZON_Y` | `8.0` | Low horizon height (tune in editor) |
| `CELESTIAL_ZENITH_Y` | `55.0` | Peak height above horizon |
| `CELESTIAL_HORIZON_HALF_WIDTH` | `35.0` | Sun travels ±35yd along X at far Z |

```gdscript
static func celestial_world_position(cycle_time: float, is_moon: bool) -> Vector3:
    var angle := celestial_angle(cycle_time, is_moon)
    var elevation := sin(angle)
    var along := cos(angle)
    return Vector3(
        along * CELESTIAL_HORIZON_HALF_WIDTH,
        lerpf(CELESTIAL_HORIZON_Y, CELESTIAL_ZENITH_Y, elevation),
        CELESTIAL_HORIZON_Z
    )
```

Sprites get `global_position = celestial_world_position(...)` each frame.

### Timing fix

Remap visible sun window to **dawn→dusk** (t=13–91):

```gdscript
const SUN_WINDOW_START := 13.0
const SUN_WINDOW_END := 91.0

static func _sun_orbit_progress(cycle_time: float) -> float:
    var t := fposmod(cycle_time, CYCLE_SEC)
    if t < SUN_WINDOW_START or t > SUN_WINDOW_END:
        return -1.0
    return (t - SUN_WINDOW_START) / (SUN_WINDOW_END - SUN_WINDOW_START)
```

Sun `celestial_angle` uses `_sun_orbit_progress` (0→1 maps PI→0). Moon keeps `_orbit_progress` + offset.

---

## Files to change

| File | Change |
|------|--------|
| `scripts/config/day_night_palette.gd` | Horizon constants, `celestial_world_position()`, sun window remapping |
| `scripts/visual/range_sky_dome.gd` | Global world positioning, `top_level` sprites, remove `_celestial_direction` |
| `tools/verify_day_night.gd` | Dusk visibility + far-horizon placement checks |
| `docs/design/02-world-and-range.md` | One bullet on down-range celestial arc |

---

## Tasks

### Task 1: Down-range world position helper

**Files:** `scripts/config/day_night_palette.gd`

- [ ] Add horizon + sun window constants
- [ ] Add `_sun_orbit_progress(cycle_time) -> float`
- [ ] Update `celestial_angle` for sun vs moon paths
- [ ] Add `celestial_world_position(cycle_time, is_moon) -> Vector3`
- [ ] Update `celestial_alpha` for sun window

### Task 2: Place sprites on world arc

**Files:** `scripts/visual/range_sky_dome.gd`

- [ ] `_update_celestial` uses `global_position = celestial_world_position(...)`
- [ ] `sprite.top_level = true` in `_make_celestial_sprite`
- [ ] Add `get_sun_world_position()` for tests
- [ ] Optional: bump `pixel_size` ~15% at low elevation

### Task 3: Verify timing + placement

**Files:** `tools/verify_day_night.gd`

- [ ] `t=84` dusk: sun alpha > 0.3
- [ ] `t=50` midday: sun alpha > 0.7, sun Z near `CELESTIAL_HORIZON_Z`
- [ ] `t=20` dawn / `t=84` dusk: sun Y below half zenith
- [ ] Run `verify_day_night.gd` → `day_night_ok=true`

### Task 4: Smoke + tune

- [ ] Headless smoke exit 0
- [ ] Editor scrub t=20, 50, 84, 110; tune Y/Z/width constants

### Task 5: Docs

- [ ] Bullet in `docs/design/02-world-and-range.md`

---

## Out of scope

- DirectionalLight3D rotation sync to sun disc
- Sky shader dusk horizon band
- World clouds
- Changing `CYCLE_SEC` or palette colors
