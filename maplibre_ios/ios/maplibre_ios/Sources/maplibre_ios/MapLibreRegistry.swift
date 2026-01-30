import Foundation
import MapLibre
import UIKit

// Update the header file for this class like this:
// cd maplibre_ios/ios/maplibre_ios/Sources/maplibre_ios/
// ./gen_swift_headers.sh

@objc(MapLibreRegistry)
public class MapLibreRegistry: NSObject {
    private static var mapRegistry: [Int64: AnyObject] = [:]
    private static var lock = NSLock()

    // Phase 2.5: Native MapView ID registry (native ID → MLNMapView)
    private static var mapViewByNativeId: [Int: AnyObject] = [:]

    // Method to get the map for a given viewId
    @objc public static func getMap(viewId: Int64) -> AnyObject? {
        lock.lock()
        defer { lock.unlock() }
        return mapRegistry[viewId]
    }

    // Method to add a map to the registry
    public static func addMap(viewId: Int64, map: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        mapRegistry[viewId] = map
    }

    // Method to remove a map to the registry
    public static func removeMap(viewId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        mapRegistry.removeValue(forKey: viewId)
    }

    // Phase 2.5: Get MapView by native ID
    @objc public static func getMapViewWithId(_ id: Int) -> AnyObject? {
        lock.lock()
        defer { lock.unlock() }
        return mapViewByNativeId[id]
    }

    // Phase 2.5: Register native MapView ID
    @objc public static func registerMapViewWithNativeId(_ id: Int, mapView: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        mapViewByNativeId[id] = mapView
        NSLog("[MapLibreRegistry] Registered native MapView ID: %d → %@", id, mapView)
    }

    // Phase 2.5: Unregister native MapView ID
    @objc public static func unregisterMapViewWithNativeId(_ id: Int) {
        lock.lock()
        defer { lock.unlock() }
        mapViewByNativeId.removeValue(forKey: id)
        NSLog("[MapLibreRegistry] Unregistered native MapView ID: %d", id)
    }

    // Warning: Storing Activity in a static field may lead to memory leaks.
    @objc public static var activity: AnyObject?

    // Warning: Storing Context in a static field may lead to memory leaks.
    @objc public static var context: AnyObject?
}
