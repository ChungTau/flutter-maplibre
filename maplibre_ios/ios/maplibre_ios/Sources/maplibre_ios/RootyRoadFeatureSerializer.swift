// [Rooty] Road feature FlatBuffer serializer.
//
// Serializes MLNFeature arrays (from featuresInSourceLayersWithIdentifiers)
// into FlatBuffer-encoded bytes for zero-copy deserialization in Rust.
//
// This avoids 20K+ geoJSONDictionary() calls and Dart object allocations
// by accessing MLNPolyline.coordinates directly and packing into FlatBuffers.
//
// Update the header file for this class like this:
// cd maplibre_ios/ios/maplibre_ios/Sources/maplibre_ios/
// ./gen_swift_headers.sh

import Foundation
import MapLibre

@objc(RootyRoadFeatureSerializer)
public class RootyRoadFeatureSerializer: NSObject {

    /// Serialize an NSArray of MLNFeature objects into FlatBuffer bytes.
    ///
    /// Only processes MLNPolylineFeature and MLNMultiPolylineFeature
    /// (i.e., LineString and MultiLineString geometries from the transportation layer).
    ///
    /// - Parameter features: NSArray from featuresInSourceLayersWithIdentifiers()
    /// - Returns: NSData containing FlatBuffer-encoded RoadFeaturePack
    @objc public static func serialize(_ features: NSArray) -> NSData {
        var builder = FlatBufferBuilder(initialSize: 1024 * 256)
        var featureOffsets: [FBOffset] = []

        for obj in features {
            guard let feature = obj as? (any MLNFeature) else { continue }

            let coords: [Double]
            if let polyline = feature as? MLNPolyline {
                // MLNPolylineFeature — single LineString
                coords = extractCoords(polyline)
            } else if let multi = feature as? MLNMultiPolyline {
                // MLNMultiPolylineFeature — concatenate all polylines
                var all: [Double] = []
                for polyline in multi.polylines {
                    all.append(contentsOf: extractCoords(polyline))
                }
                coords = all
            } else {
                continue // Skip points, polygons, etc.
            }

            // Need at least 2 coordinate pairs (4 doubles)
            guard coords.count >= 4 else { continue }

            let attrs = feature.attributes

            // Road class mapping
            let roadClassStr = attrs["class"] as? String ?? ""
            let isRamp = (attrs["ramp"] as? NSNumber)?.boolValue ?? false
            let roadClass = mapRoadClass(roadClassStr, isRamp: isRamp)

            // Structure type
            let brunnel = attrs["brunnel"] as? String ?? ""
            let structureType = mapStructureType(brunnel)

            // Z-level
            let zLevel = (attrs["layer"] as? NSNumber)?.int8Value ?? 0

            // OSM ID from feature identifier
            let osmId: UInt64
            if let num = feature.identifier as? NSNumber {
                osmId = num.uint64Value
            } else {
                osmId = 0
            }

            // Road reference
            let refId = attrs["ref"] as? String

            // Build FlatBuffer feature
            let coordsOffset = builder.createVector(coords)
            let refIdOffset = refId.map { builder.create(string: $0) }

            let featureOffset = rooty_road_RoadFeature.createRoadFeature(
                &builder,
                coordinatesVectorOffset: coordsOffset,
                roadClass: roadClass,
                structureType: structureType,
                zLevel: zLevel,
                osmId: osmId,
                refIdOffset: refIdOffset ?? FBOffset()
            )
            featureOffsets.append(featureOffset)
        }

        let featuresVector = builder.createVector(ofOffsets: featureOffsets)
        let pack = rooty_road_RoadFeaturePack.createRoadFeaturePack(
            &builder,
            featuresVectorOffset: featuresVector
        )
        builder.finish(offset: pack)

        return builder.data as NSData
    }

    // MARK: - Private Helpers

    /// Extract flattened [lng0, lat0, lng1, lat1, ...] from an MLNPolyline.
    /// Accesses the coordinate buffer directly — no JSON serialization.
    private static func extractCoords(_ polyline: MLNPolyline) -> [Double] {
        let count = Int(polyline.pointCount)
        guard count >= 2 else { return [] }

        let ptr = polyline.coordinates
        var result: [Double] = []
        result.reserveCapacity(count * 2)
        for i in 0..<count {
            result.append(ptr[i].longitude)
            result.append(ptr[i].latitude)
        }
        return result
    }

    /// Map OpenMapTiles class string to FlatBuffer enum.
    private static func mapRoadClass(_ classStr: String, isRamp: Bool) -> rooty_road_RoadClass {
        if isRamp { return .link }
        switch classStr {
        case "motorway": return .motorway
        case "trunk": return .trunk
        case "primary": return .primary
        case "secondary": return .secondary
        case "tertiary": return .tertiary
        case "service": return .service
        case "minor", "street", "residential": return .street
        case "link", "motorway_link", "trunk_link",
             "primary_link", "secondary_link", "tertiary_link":
            return .link
        case "path": return .path
        case "track": return .track
        default: return .unknown
        }
    }

    /// Map brunnel string to FlatBuffer enum.
    private static func mapStructureType(_ brunnel: String) -> rooty_road_StructureType {
        switch brunnel {
        case "bridge": return .bridge
        case "tunnel": return .tunnel
        default: return .road
        }
    }
}
