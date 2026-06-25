# Whisky → CrossOver 26 Feature Parity Plan

## Current State Analysis

### What Whisky Already Has
| Feature | Status |
|---------|--------|
| Bottle creation (name, Windows version, path) | ✅ |
| Bottle sidebar with search/filter | ✅ |
| Wine version (bundled, single version) | ✅ (but hardcoded) |
| Windows version picker (XP–11) | ✅ |
| Build version override | ✅ |
| Retina mode toggle | ✅ |
| DPI configuration | ✅ |
| Enhanced sync (none/esync/msync) | ✅ |
| AVX toggle (macOS 15+) | ✅ |
| DXVK toggle + async + HUD | ✅ |
| Metal HUD / Metal Trace / DXR | ✅ |
| Pinned programs | ✅ |
| Program args + locale | ✅ |
| Environment variables per program | ✅ |
| Process viewer (kill) | ✅ (disabled in UI) |
| Winetricks UI | ✅ |
| Control Panel / regedit / winecfg | ✅ |
| WhiskyWine installer | ✅ |
| Update checks | ✅ |
| File open handling (drag-drop) | ✅ |

### What CrossOver 26 Has That Whisky Lacks (by priority)

| # | Feature | Impact | Effort |
|---|---------|--------|--------|
| 1 | **D3DMetal (Game Porting Toolkit) toggle** | High — modern games need this | Medium |
| 2 | **Wine version selection per bottle** | High — CX26 ships Wine 11, Whisky ships Wine 7 | High |
| 3 | **Per-application settings overrides** | High — CX lets you override DXVK, DXVK-HUD, env vars, sync per app | Medium |
| 4 | **Bottle templates (Steam, Epic, GOG)** | Medium — pre-configured bottles save setup time | Medium |
| 5 | **Bottle cloning** | Medium — copy a working bottle without reinstalling | Low |
| 6 | **Bottle export/import** | Medium — share bottles or backup | Low |
| 7 | **Compatibility database UI** | Medium — show game ratings, known issues, recommended settings | High |
| 8 | **Per-app blocklist/allowlist** | Low — CX has more granular access control | Low |
| 9 | **32-bit bottle detection/warnings** | Low — CX warns about 32-bit limitations | Low |
| 10 | **Real-time performance monitor (FPS/GPU)** | Medium — overlay-style HUD | High |
| 11 | **Better error messages + troubleshooting links** | Low — user-facing polish | Low |
| 12 | **Steam integration (launch games with Steam overlay)** | Medium — big user request | High |
| 13 | **Auto-update Wine/DXVK per bottle** | Medium — keep bottles current | High |
| 14 | **Crash reporting** | Low — send crash logs to developers | Medium |
| 15 | **Bottle health check / diagnostics** | Low — detect broken bottles | Medium |

---

## Implementation Plan

### Phase 1: Core Bottle Enhancements (Week 1-2)

#### 1.1 D3DMetal Toggle (BottleSettings + ConfigView)

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift` — add `d3dmEnabled: Bool`
- `WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift` — add D3DM env var in `environmentVariables()`
- `Whisky/Views/Bottle/ConfigView.swift` — add D3DM toggle to Metal section

**Changes:**
```swift
// BottleSettings.swift — add to BottleMetalConfig:
var d3dmEnabled: Bool = false

// In environmentVariables():
if d3dmEnabled {
    wineEnv.updateValue("1", forKey: "D3DMetal")
}
```

Add a toggle in the Metal section of ConfigView with info text explaining D3DM vs DXVK differences.

#### 1.2 Per-Application Settings Overrides (ProgramSettings + ProgramView)

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/ProgramSettings.swift` — add per-app DXVK, DXVK-HUD, sync, env var overrides
- `Whisky/Views/Programs/ProgramView.swift` — add per-app setting controls

**Changes:**
```swift
// ProgramSettings.swift — add new structs:
public struct ProgramDXVKOverride: Codable {
    var dxvkOverride: Bool?      // nil = use bottle default
    var dxvkAsyncOverride: Bool?
    var dxvkHudOverride: DXVKHUD?
}

public struct ProgramSyncOverride: Codable {
    var syncOverride: EnhancedSync?  // nil = use bottle default
}

public struct ProgramEnvOverride: Codable {
    var customEnvVars: [String: String] = [:]
}
```

In `ProgramView`, add a "Use bottle defaults" toggle for each setting, and when disabled, show the override controls.

#### 1.3 Bottle Cloning

**Files to modify:**
- `Whisky/View Models/BottleVM.swift` — add `cloneBottle()` method
- `Whisky/Views/Bottle/BottleListEntry.swift` — add clone menu item

**Changes:**
```swift
// BottleVM.swift
func cloneBottle(source: Bottle, cloneName: String) -> URL? {
    let cloneDir = source.url.deletingLastPathComponent()
        .appending(path: "\(source.settings.name) (Clone)")
    // Copy directory recursively
    // Create new Bottle object
    // Add to bottles list
}
```

Add a right-click/context menu on `BottleListEntry` with "Clone Bottle" option.

#### 1.4 Bottle Export/Import

**Files to modify:**
- `Whisky/View Models/BottleVM.swift` — add `exportBottle()` and `importBottle()`
- `Whisky/Views/Bottle/BottleListEntry.swift` — add export/import menu items

**Changes:**
- Export: create a `.whiskybottle` zip archive of the bottle directory + metadata
- Import: unzip to bottle directory, register with BottleVM

---

### Phase 2: Bottle Templates & Wizard (Week 3)

#### 2.1 Bottle Templates

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift` — add `templateType` enum
- `Whisky/Views/Bottle/BottleCreationView.swift` — add template picker
- `WhiskyKit/Sources/WhiskyKit/Whisky/Bottle.swift` — add template-specific init logic

**Template types:**
```swift
public enum BottleTemplate: String, CaseIterable, Codable {
    case blank
    case steam
    case epicGames
    case gog
    case battleNet
    case riotGames
}
```

Each template pre-configures:
- **Steam**: DXVK off (Steam overlay needs wined3d), specific env vars for Steam
- **Epic Games**: DXVK on, EGS-specific env vars
- **GOG**: DXVK on, GOG Galaxy env vars
- **BattleNet**: DXVK on, BattleNet-specific fixes
- **Riot Games**: DXVK off (anti-cheat sensitive), specific config

#### 2.2 Enhanced Setup Wizard

**Files to modify:**
- `Whisky/Views/Setup/SetupView.swift` — add template selection step
- `Whisky/Views/Setup/WelcomeView.swift` — update copy

---

### Phase 3: Wine Version Management (Week 4-5)

#### 3.1 Wine Version Selection Per Bottle

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift` — Wine version is already stored, just need UI
- `Whisky/Views/Bottle/ConfigView.swift` — add Wine version picker
- `WhiskyKit/Sources/WhiskyKit/WhiskyWine/WhiskyWineInstaller.swift` — support multiple Wine versions

**Key changes:**
- Store Wine version in BottleSettings (already done — `wineVersion: SemanticVersion`)
- UI to select from installed Wine versions
- Support downloading different Wine versions (Wine 7, Wine 8, Wine 9, Wine 11)
- Each bottle can have its own Wine binary

**WhiskyWineInstaller.swift changes:**
```swift
// Support multiple Wine installations
static let wineVersionsDir = WhiskyWineInstaller.baseFolder.appending(path: "WineVersions")

static func installWine(version: SemanticVersion) async throws
static func uninstallWine(version: SemanticVersion)
static func listInstalledWineVersions() -> [SemanticVersion]
```

---

### Phase 4: UI Polish & Quality of Life (Week 6-7)

#### 4.1 Bottle Health Check / Diagnostics

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/Bottle.swift` — add `diagnose()` method
- `Whisky/Views/Bottle/BottleListEntry.swift` — show health indicator
- `Whisky/Views/Programs/ProgramView.swift` — add diagnostics button

**Diagnostics checks:**
- Wine binary exists
- drive_c exists and is accessible
- Registry is valid
- DXVK DLLs are present (if enabled)
- 32-bit vs 64-bit detection
- Common missing DLL warnings

#### 4.2 Better Error Messages

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Wine/Wine.swift` — add error categories with troubleshooting URLs
- All error throw sites — replace generic errors with structured errors

```swift
enum WineError: LocalizedError {
    case wineNotFound
    case dxvkNotEnabled
    case dxvkDllsMissing
    case regeditFailed(reason: String)
    case processCrashed(exitCode: Int)
    
    var errorDescription: String?
    var recoverySuggestion: String?
    var troubleshootingURL: URL?
}
```

#### 4.3 32-Bit Bottle Detection

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Whisky/Bottle.swift` — add `is32Bit` property
- `Whisky/Views/Bottle/BottleListEntry.swift` — show warning icon

```swift
// Check PE headers of executables in drive_c
var is32Bit: Bool {
    // Scan for 32-bit PE files
}
```

#### 4.4 Real-Time Performance Monitor

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Wine/Wine.swift` — add FPS counter via DXVK HUD polling
- `Whisky/Views/Programs/ProgramView.swift` — add performance overlay toggle

This is the most complex feature. Options:
1. **Simple**: Parse DXVK HUD output for FPS (already partially supported via DXVK_HUD)
2. **Medium**: Use Metal HUD frame capture data
3. **Complex**: Build a proper overlay using Metal Performance Shaders

Recommend starting with option 1.

---

### Phase 5: Advanced Features (Week 8+)

#### 5.1 Steam Integration

**Files to modify:**
- `Whisky/Views/Setup/SetupView.swift` — add Steam detection
- `WhiskyKit/Sources/WhiskyKit/Whisky/Bottle.swift` — add Steam-specific bottle setup
- `Whisky/Views/Programs/ProgramsView.swift` — detect Steam library games

**Changes:**
- Detect Steam installation on macOS
- Offer to install Windows Steam in a new bottle
- Auto-detect Steam library games
- Launch games with Steam overlay enabled

#### 5.2 Compatibility Database UI

**Files to modify:**
- `Whisky/Views/Programs/ProgramsView.swift` — show compatibility badge
- `Whisky/Views/Programs/ProgramView.swift` — show compatibility info panel

This requires a data source. Options:
1. **AppGameWiki API** — scrape AppleGamingWiki for game data
2. **ProtonDB API** — use ProtonDB ratings (adapted for macOS)
3. **Local database** — ship a curated list of popular games

#### 5.3 Crash Reporting

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/Wine/Wine.swift` — capture crash dumps
- `Whisky/Views/Programs/ProgramView.swift` — show crash report option

#### 5.4 Auto-Update Wine/DXVK Per Bottle

**Files to modify:**
- `WhiskyKit/Sources/WhiskyKit/WhiskyWine/WhiskyWineInstaller.swift` — add update check per version
- `Whisky/Views/Settings/SettingsView.swift` — add auto-update toggle

---

## File-by-File Change Summary

### Must Change (Phase 1)
| File | Change |
|------|--------|
| `WhiskyKit/.../BottleSettings.swift` | Add `d3dmEnabled`, per-app override structs |
| `WhiskyKit/.../Wine.swift` | Add D3DM env var, WineError enum |
| `Whisky/Views/Bottle/ConfigView.swift` | Add D3DM toggle, Wine version picker |
| `Whisky/Views/Programs/ProgramView.swift` | Add per-app setting overrides |
| `Whisky/View Models/BottleVM.swift` | Add clone/export/import methods |
| `Whisky/Views/Bottle/BottleListEntry.swift` | Add clone/export/import context menu |
| `Whisky/Views/Bottle/BottleCreationView.swift` | Add template picker |
| `WhiskyKit/.../WhiskyWineInstaller.swift` | Support multiple Wine versions |

### Should Change (Phase 2-3)
| File | Change |
|------|--------|
| `Whisky/Views/Setup/SetupView.swift` | Enhanced wizard |
| `Whisky/Views/ContentView.swift` | Bottle health indicators |
| `WhiskyKit/.../Bottle.swift` | Diagnose method, 32-bit detection |
| `Whisky/Views/Programs/ProgramsView.swift` | Compatibility badges |

### Nice to Have (Phase 4-5)
| File | Change |
|------|--------|
| `Whisky/Views/Programs/ProgramView.swift` | Performance monitor |
| `Whisky/Views/Settings/SettingsView.swift` | Auto-update toggle |
| `Whisky/AppDelegate.swift` | Crash reporting |

---

## Non-Goals (Out of Scope)

These CrossOver features are NOT feasible for Whisky and should be explicitly excluded:

1. **CrossOver's bespoke Wine patches** — CX has custom Wine patches developed by CodeWeavers engineers. Whisky uses vanilla Wine builds.
2. **CrossOver's compatibility database backend** — CX has a server-side database of millions of test results. Whisky can only show community-sourced ratings.
3. **Official anti-cheat bypass** — CX has partnerships with anti-cheat vendors. Whisky cannot replicate this.
4. **CrossOver's licensing/activation** — not applicable to open-source Whisky.
5. **CrossOver's Windows installer** — CX has a Windows version. Whisky is macOS-only.

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Multiple Wine versions increase disk usage | Only download versions when user selects them; share common files |
| Per-app settings increase plist complexity | Use nested Codable structs with default nil = "use bottle default" |
| D3DMetal may conflict with DXVK | Show warning when both are enabled; document in UI |
| Bottle templates may not work for all users | Make templates opt-in; "blank" template always available |
| Compatibility database may be stale | Mark as community-sourced; allow user submissions |

---

## Testing Strategy

1. **Unit tests**: BottleSettings encoding/decoding with new fields
2. **Integration tests**: Clone bottle → verify all files copied; export/import round-trip
3. **UI tests**: Template selection → verify bottle config; per-app overrides → verify env vars
4. **Manual testing**: Test D3DMetal toggle with a known D3DM game; test Wine version switching
5. **Compatibility testing**: Test each template with its target platform

---

## Migration Path for Existing Bottles

1. **Existing bottles keep their current Wine version** — no forced upgrades
2. **New fields in BottleSettings default to sensible values** — `d3dmEnabled = false`, overrides = nil
3. **Bottle file version bump** — existing bottles get migrated on first open
4. **Templates are opt-in** — existing bottles remain unchanged
