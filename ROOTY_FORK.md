# rooty Fork of maplibre_flutter

This is a minimally-modified fork of [maplibre_flutter](https://github.com/josxha/maplibre_flutter) maintained for the rooty project.

## Changes from Upstream

### v0.3.3+rooty.1 (Based on v0.3.3+1)

**Added**: Static MapView registry for cross-plugin access

**Files Modified**:
- `maplibre/android/src/main/kotlin/com/github/josxha/maplibre/MapLibrePlugin.kt` - Added `ConcurrentHashMap`-based static registry with `registerMapView()`, `getMapView()`, and `unregisterMapView()` methods
- `maplibre_ios/ios/maplibre_ios/Sources/maplibre_ios/MapLibreIosPlugin.swift` - Added weak reference registry with `NSLock` for thread-safe access

**Why**: Phase 1.2 of rooty requires high-frequency access to MapView's camera state for native matrix synchronization between MapLibre rendering and Flutter CustomPainter overlay. Flutter's plugin isolation prevents cross-plugin MapView access without this registry.

**Principle**: Minimal invasive approach
- ✅ Only add registry for native handle exposure
- ❌ No modification to rendering logic
- ✅ Maintains full compatibility with upstream API
- ✅ All changes are marked with `[Rooty]` comments for easy identification

## Technical Details

### Android Implementation

```kotlin
companion object {
    private val mapViewRegistry = ConcurrentHashMap<Int, MapView>()

    @JvmStatic
    fun registerMapView(id: Int, view: MapView)

    @JvmStatic
    fun getMapView(id: Int): MapView?

    @JvmStatic
    fun unregisterMapView(id: Int)
}
```

**Thread Safety**: Uses `ConcurrentHashMap` for lock-free concurrent access from multiple threads.

**ID Generation**: Typically `System.identityHashCode(mapView)` for stable unique identifiers.

### iOS Implementation

```swift
private static var mapViewRegistry: [Int: WeakMapViewRef] = [:]
private static var registryLock = NSLock()

private class WeakMapViewRef {
    weak var mapView: MLNMapView?
}

@objc public static func registerMapView(id: Int, mapView: MLNMapView)
@objc public static func getMapView(id: Int) -> MLNMapView?
@objc public static func unregisterMapView(id: Int)
```

**Memory Safety**: Uses `weak` references to prevent retain cycles. When MapView is deallocated, registry entry automatically becomes nil.

**Thread Safety**: Uses `NSLock` with defer pattern for safe concurrent access.

**ID Generation**: Typically `ObjectIdentifier(mapView).hashValue` for stable unique identifiers.

## Upstream Sync Strategy

This fork should be regularly synced with upstream to incorporate bug fixes and new features:

```bash
# Add upstream remote (one-time setup)
git remote add upstream https://github.com/josxha/maplibre_flutter.git

# Fetch upstream changes
git fetch upstream

# Merge upstream main into rooty branch
git checkout rooty-matrix-sync-api
git merge upstream/main

# Resolve conflicts (if any) focusing on preserving registry changes
# Priority: Preserve all code between "Rooty Fork Addition" comments
# Test thoroughly after merge
# Push updated fork
git push origin rooty-matrix-sync-api
```

## Usage in rooty

Add to `pubspec.yaml`:

```yaml
dependencies:
  maplibre:
    git:
      url: https://github.com/ChungTau/flutter-maplibre
      ref: v0.3.3+rooty.1
      path: maplibre
```

## Integration Example

From `rooty_map_engine`, access registered MapView:

**Android**:
```kotlin
import com.github.josxha.maplibre.MapLibrePlugin

val mapView = MapLibrePlugin.getMapView(mapViewId)
if (mapView != null) {
    // Access camera state, projection, etc.
    val cameraPosition = mapView.cameraPosition
}
```

**iOS**:
```swift
import maplibre_ios

if let mapView = MapLibreIosPlugin.getMapView(id: mapViewId) {
    // Access camera state
    let camera = mapView.camera
}
```

## Validation Test Results

**Phase 0 Validation** (2026-01-29):
- **Before Fork**: Test 1 (Android MapView Access) - FAIL
  - Error: `NoSuchMethodException: com.github.josxha.maplibre.MapLibrePlugin.getMapView[int]`
  - Decision: Fork Required

- **After Fork**: Test 1 should return PARTIAL_SUCCESS or SUCCESS
  - Method exists and is callable
  - MapView can be accessed from rooty_map_engine plugin

## Maintainer

Maintained by rooty project team (ChungTau).

**For upstream issues**: Report to [josxha/maplibre_flutter](https://github.com/josxha/maplibre_flutter/issues)

**For fork-specific issues**: Open issues in [ChungTau/flutter-maplibre](https://github.com/ChungTau/flutter-maplibre/issues) with `[rooty-fork]` tag

## License

Same as upstream: BSD-3-Clause (see [LICENSE](maplibre/LICENSE))

## Version History

- **v0.3.3+rooty.1** (2026-01-29)
  - Initial fork from maplibre_flutter v0.3.3+1
  - Added static MapView registry for Android (ConcurrentHashMap)
  - Added weak reference registry for iOS (NSLock)
  - Validated on Pixel 8 Pro (Android) - DPR 3.0
