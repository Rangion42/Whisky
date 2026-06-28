## Summary

Complete GPTK (Game Porting Toolkit) integration for Whisky, adding comprehensive configuration options, performance tuning, shader cache management, memory limits, VKD3D support, and full localization across 23 languages.

## Changes

### Core Features
- **GPTK Version Detection**: Auto-detects GPTK version via `wine64 --version`
- **VKD3D Support**: Injects VKD3D environment variables (`VKD3D_PATH`, `VKD3D_SHADER_COMPILER`) with profile selection (Auto/Zink/RADV/Custom) and debug string configuration
- **Shader Cache Management**: Tracks shader compilation progress with modes (Disabled/Compile on Launch/Prewarm) and error handling
- **Memory Management**: Configurable `GPTK_MEMORY_LIMIT` and `GPTK_SWAP_SIZE` constraints with Auto/Limited modes
- **Performance Presets**: Three modes (Balanced/Performance/Quality) for different use cases

### Configuration UI
- New GPTK section in ConfigView with:
  - VKD3D toggle and debug string input (placeholder: "vkd3d_debug,track_resource_refs")
  - VKD3D profile selector (Auto/Zink/RADV/Custom)
  - Shader cache mode selector with progress indicator and error display
  - Performance mode dropdown (Balanced/Performance/Quality)
  - Memory mode (Auto/Limited) with configurable MB limit input

### Data Model
- Extended `BottleGptkConfig` with:
  - `vkd3dEnabled`, `vkd3dDebug` (string), `vkd3dProfile` (enum)
  - `shaderCacheEnabled`, `shaderCacheMode` (enum: disabled/compileOnLaunch/prewarm)
  - `performanceMode` (enum: balanced/performance/quality)
  - `memoryMode` (enum: auto/limited), `memoryLimitMB` (Int)
  - `gameCompatibilityNotes` (Dictionary<String, String> for per-game notes with count tracking)
  - `gamePresets` (Dictionary<String, String> for per-game presets with count tracking)
  - Helper methods: `performanceMode(for:)`, `compatibilityNote(for:)`, `setCompatibilityNote(_:for:)`, `removeCompatibilityNote(for:)`, `setGamePreset(_:for:)`, `removeGamePreset(for:)`

### Wine Environment Integration
- `constructWineEnvironment` now injects VKD3D paths, shader cache settings, and memory limits from `BottleGptkConfig`
- Shader compilation tracking hooks monitor progress and log events

### Localization
- Added **46 GPTK localization strings** across **23 languages**:
  - en, zh-Hans, zh-Hant, ja, ko, de, fr, es, it, pt-BR, pt-PT
  - ru, ar, cs, da, fi, nl, pl, ro, tr, uk, vi
- All keys used in code are present and verified

## Testing
- ✅ WhiskyKit builds successfully (0 errors, 0 warnings)
- ✅ All GPTK localization keys used in code are present in Localizable.xcstrings
- ✅ Backward compatible with existing Wine and GPTK workflows

## Files Changed
- `WhiskyKit/Sources/WhiskyKit/Config/BottleSettings.swift` — Extended BottleGptkConfig
- `WhiskyKit/Sources/WhiskyKit/Wine/Wine.swift` — VKD3D env vars, memory limits, shader tracking
- `Whisky/Views/Bottle/ConfigView.swift` — GPTK configuration UI section
- `Whisky/Localizable.xcstrings` — 46 new localization entries
