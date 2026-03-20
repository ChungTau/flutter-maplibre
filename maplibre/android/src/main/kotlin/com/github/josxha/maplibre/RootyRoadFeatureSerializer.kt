// [Rooty] Road feature FlatBuffer serializer for Android.
//
// Serializes List<Feature> (from VectorSource.querySourceFeatures)
// into FlatBuffer-encoded bytes for zero-copy deserialization in Rust.
//
// This avoids 20K+ Feature.toJson() JNI calls and Dart object allocations
// by iterating features inside the JVM and packing into FlatBuffers.

package com.github.josxha.maplibre

import com.google.flatbuffers.FlatBufferBuilder
import org.maplibre.geojson.Feature
import org.maplibre.geojson.LineString
import org.maplibre.geojson.MultiLineString
import org.maplibre.geojson.Point
import rooty.road.RoadClass
import rooty.road.RoadFeature
import rooty.road.RoadFeaturePack
import rooty.road.StructureType

/**
 * Serializes MapLibre Feature objects into FlatBuffer bytes.
 *
 * Called from Dart via JNI on every camera idle event.
 * All iteration happens inside the JVM — only a single byte[]
 * crosses the JNI boundary.
 */
object RootyRoadFeatureSerializer {

    /**
     * Serialize a list of MapLibre Features into FlatBuffer bytes.
     *
     * Only processes LineString and MultiLineString geometries
     * (i.e., road features from the transportation layer).
     *
     * @param features List<Feature> from VectorSource.querySourceFeatures()
     * @return ByteArray containing FlatBuffer-encoded RoadFeaturePack
     */
    @JvmStatic
    fun serialize(features: List<Feature>): ByteArray {
        val builder = FlatBufferBuilder(256 * 1024)
        val offsets = mutableListOf<Int>()

        for (feature in features) {
            val geom = feature.geometry() ?: continue

            val coords: DoubleArray = when (geom) {
                is LineString -> flattenLineString(geom)
                is MultiLineString -> flattenMultiLineString(geom)
                else -> continue
            }

            // Need at least 2 coordinate pairs (4 doubles)
            if (coords.size < 4) continue

            val props = feature.properties()

            // Road class mapping
            val classStr = props?.get("class")?.let {
                if (it.isJsonPrimitive) it.asString else null
            } ?: ""
            val isRamp = props?.get("ramp")?.let {
                if (it.isJsonPrimitive) {
                    try { it.asInt == 1 } catch (_: Exception) {
                        try { it.asBoolean } catch (_: Exception) { false }
                    }
                } else false
            } ?: false
            val roadClass = mapRoadClass(classStr, isRamp)

            // Structure type
            val brunnel = props?.get("brunnel")?.let {
                if (it.isJsonPrimitive) it.asString else null
            } ?: ""
            val structureType = mapStructureType(brunnel)

            // Z-level
            val zLevel: Byte = props?.get("layer")?.let {
                if (it.isJsonPrimitive) {
                    try { it.asInt.toByte() } catch (_: Exception) { 0 }
                } else null
            } ?: 0

            // OSM ID from feature identifier
            val osmId: Long = feature.id()?.toLongOrNull() ?: 0L

            // Road reference
            val refStr = props?.get("ref")?.let {
                if (it.isJsonPrimitive) it.asString else null
            }

            // Build FlatBuffer feature
            val coordsOffset = RoadFeature.createCoordinatesVector(builder, coords)
            val refOffset = if (refStr != null) builder.createString(refStr) else 0

            offsets.add(
                RoadFeature.createRoadFeature(
                    builder,
                    coordsOffset,
                    roadClass,
                    structureType,
                    zLevel,
                    osmId,
                    refOffset,
                ),
            )
        }

        val featuresVector = RoadFeaturePack.createFeaturesVector(
            builder,
            offsets.toIntArray(),
        )
        val pack = RoadFeaturePack.createRoadFeaturePack(builder, featuresVector)
        builder.finish(pack)

        return builder.sizedByteArray()
    }

    // ========== Private Helpers ==========

    /**
     * Extract flattened [lng0, lat0, lng1, lat1, ...] from a LineString.
     */
    private fun flattenLineString(ls: LineString): DoubleArray {
        val points: List<Point> = ls.coordinates()
        val result = DoubleArray(points.size * 2)
        for (i in points.indices) {
            result[i * 2] = points[i].longitude()
            result[i * 2 + 1] = points[i].latitude()
        }
        return result
    }

    /**
     * Extract flattened coordinates from a MultiLineString,
     * concatenating all line segments.
     */
    private fun flattenMultiLineString(mls: MultiLineString): DoubleArray {
        val lineStrings: List<LineString> = mls.lineStrings()
        var totalPoints = 0
        for (ls in lineStrings) {
            totalPoints += ls.coordinates().size
        }
        val result = DoubleArray(totalPoints * 2)
        var idx = 0
        for (ls in lineStrings) {
            for (point in ls.coordinates()) {
                result[idx++] = point.longitude()
                result[idx++] = point.latitude()
            }
        }
        return result
    }

    /**
     * Map OpenMapTiles class string to FlatBuffer RoadClass enum.
     */
    private fun mapRoadClass(classStr: String, isRamp: Boolean): Byte {
        if (isRamp) return RoadClass.Link
        return when (classStr) {
            "motorway" -> RoadClass.Motorway
            "trunk" -> RoadClass.Trunk
            "primary" -> RoadClass.Primary
            "secondary" -> RoadClass.Secondary
            "tertiary" -> RoadClass.Tertiary
            "service" -> RoadClass.Service
            "minor", "street", "residential" -> RoadClass.Street
            "link", "motorway_link", "trunk_link",
            "primary_link", "secondary_link", "tertiary_link",
            -> RoadClass.Link
            "path" -> RoadClass.Path
            "track" -> RoadClass.Track
            else -> RoadClass.Unknown
        }
    }

    /**
     * Map brunnel string to FlatBuffer StructureType enum.
     */
    private fun mapStructureType(brunnel: String): Byte {
        return when (brunnel) {
            "bridge" -> StructureType.Bridge
            "tunnel" -> StructureType.Tunnel
            else -> StructureType.Road
        }
    }
}
