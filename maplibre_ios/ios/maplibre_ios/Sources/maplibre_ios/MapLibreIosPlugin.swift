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
    /// - Parameter id: The MapView identifier (Flutter viewId)
    /// - Returns: The MLNMapView instance, or nil if not found or deallocated
    /// Note: Explicit ObjC selector to avoid conflict with getMapViewByNativeId
    @objc(getMapViewById:)
    public static func getMapView(id: Int) -> MLNMapView? {
        registryLock.lock()
        defer { registryLock.unlock() }

        let mapView = mapViewRegistry[id]?.mapView
        if mapView == nil {
            NSLog("[Rooty] MapLibreIosPlugin: MapView not found or deallocated for ID: \(id)")
        }
        return mapView
    }

    /// Phase 2.5: Get MapView by native ID
    ///
    /// This method delegates to MapLibreRegistry which stores MapViews by their native hash ID.
    /// Required for rooty_map_engine Phase 2.5A Binary GeoJSON optimization.
    /// Note: We explicitly set ObjC selector to "getMapViewWithId:" for RootyMapEnginePlugin
    ///
    /// - Parameter nativeId: The native MapView ID (from mapView.hash)
    /// - Returns: MLNMapView instance if found, nil otherwise
    @objc(getMapViewWithId:)
    public static func getMapViewByNativeId(_ nativeId: Int) -> AnyObject? {
        return MapLibreRegistry.getMapViewWithId(nativeId)
    }

    /// Unregister a MapView instance
    ///
    /// - Parameter id: The MapView identifier (viewId)
    @objc public static func unregisterMapView(id: Int) {
        registryLock.lock()
        defer { registryLock.unlock() }

        mapViewRegistry.removeValue(forKey: id)
        NSLog("[Rooty] MapLibreIosPlugin: Unregisterered MapView for viewId: \(id)")
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
