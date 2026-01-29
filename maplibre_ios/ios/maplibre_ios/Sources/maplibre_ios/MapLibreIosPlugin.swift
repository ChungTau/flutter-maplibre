import Flutter
import MapLibre
import UIKit

@objc(MapLibreIosPlugin)
public class MapLibreIosPlugin: NSObject, FlutterPlugin {
    // ========== Rooty Fork Addition: Static MapView Registry ==========
    // Thread-safe weak reference registry for cross-plugin access
    // Required for rooty_map_engine Phase 1.2 Native Matrix Sync
    private static var mapViewRegistry: [Int: WeakMapViewRef] = [:]
    private static var registryLock = NSLock()

    /// Weak wrapper to prevent retain cycles
    private class WeakMapViewRef {
        weak var mapView: MLNMapView?
        init(_ mapView: MLNMapView) {
            self.mapView = mapView
        }
    }

    /// Register a MapView instance for cross-plugin access
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically ObjectIdentifier(mapView).hashValue)
    ///   - mapView: The MLNMapView instance to register
    @objc public static func registerMapView(id: Int, mapView: MLNMapView) {
        registryLock.lock()
        defer { registryLock.unlock() }

        mapViewRegistry[id] = WeakMapViewRef(mapView)
        NSLog("[Rooty] MapLibreIosPlugin: Registered MapView with ID: \(id)")
    }

    /// Retrieve a registered MapView by ID
    ///
    /// - Parameter id: The MapView identifier
    /// - Returns: The MLNMapView instance, or nil if not found or deallocated
    @objc public static func getMapView(id: Int) -> MLNMapView? {
        registryLock.lock()
        defer { registryLock.unlock() }

        let mapView = mapViewRegistry[id]?.mapView
        if mapView == nil {
            NSLog("[Rooty] MapLibreIosPlugin: MapView not found or deallocated for ID: \(id)")
        }
        return mapView
    }

    /// Unregister a MapView instance
    ///
    /// - Parameter id: The MapView identifier
    @objc public static func unregisterMapView(id: Int) {
        registryLock.lock()
        defer { registryLock.unlock() }

        mapViewRegistry.removeValue(forKey: id)
        NSLog("[Rooty] MapLibreIosPlugin: Unregistered MapView with ID: \(id)")
    }

    /// Get ObjectIdentifier hash for MapView registered with given viewId
    ///
    /// - Parameter viewId: The Flutter platform view ID
    /// - Returns: ObjectIdentifier hash code, or 0 if not found
    @objc public static func getMapViewIdForViewId(viewId: Int64) -> Int {
        guard let mapView = MapLibreRegistry.getMap(viewId: viewId) as? MLNMapView else {
            NSLog("[Rooty] MapLibreIosPlugin: No MapView found for viewId: \(viewId)")
            return 0
        }
        let mapViewId = ObjectIdentifier(mapView).hashValue
        NSLog("[Rooty] MapLibreIosPlugin: ViewId \(viewId) -> MapViewId \(mapViewId)")
        return mapViewId
    }
    // ========== End Rooty Fork Addition ==========

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "maplibre_ios", binaryMessenger: registrar.messenger()
        )
        let instance = MapLibreIosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // register MapLibre view factory
        let factory = MapLibreViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "plugins.flutter.io/maplibre")

        // setup OfflineManager
        OfflineManager(messenger: registrar.messenger())
    }

    public func handle(_: FlutterMethodCall, result _: @escaping FlutterResult) {}
}
