package com.github.josxha.maplibre

// if imports can't resolve:
// - remove all .idea/ folders
// - open example/android/build.gradle.kts as project
// - sync project to download dependencies

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.maplibre.android.location.permissions.PermissionsManager
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import java.util.concurrent.ConcurrentHashMap

/** MapLibrePlugin */
class MapLibrePlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        // ========== Rooty Fork Addition: Static MapView and MapLibreMap Registry ==========
        // Thread-safe registry for cross-plugin access
        // Required for rooty_map_engine Phase 1.2 Native Matrix Sync
        private val mapViewRegistry = ConcurrentHashMap<Int, MapView>()
        private val mapLibreMapRegistry = ConcurrentHashMap<Int, MapLibreMap>()

        /**
         * Register MapView and MapLibreMap instances for cross-plugin access
         *
         * @param id Unique identifier (typically hashCode of MapView)
         * @param view The MapView instance to register
         * @param map The MapLibreMap instance to register
         */
        @JvmStatic
        fun registerMapView(id: Int, view: MapView, map: MapLibreMap) {
            mapViewRegistry[id] = view
            mapLibreMapRegistry[id] = map
            android.util.Log.d("MapLibrePlugin", "[Rooty] Registered MapView and MapLibreMap with ID: $id")
        }

        /**
         * Retrieve a registered MapView by ID
         *
         * @param id The MapView identifier
         * @return The MapView instance, or null if not found
         */
        @JvmStatic
        fun getMapView(id: Int): MapView? {
            val view = mapViewRegistry[id]
            if (view == null) {
                android.util.Log.w("MapLibrePlugin", "[Rooty] MapView not found for ID: $id")
            }
            return view
        }

        /**
         * Retrieve a registered MapLibreMap by ID
         *
         * @param id The MapView identifier (same ID used for registration)
         * @return The MapLibreMap instance, or null if not found
         */
        @JvmStatic
        fun getMapLibreMap(id: Int): MapLibreMap? {
            val map = mapLibreMapRegistry[id]
            if (map == null) {
                android.util.Log.w("MapLibrePlugin", "[Rooty] MapLibreMap not found for ID: $id")
            }
            return map
        }

        /**
         * Unregister MapView and MapLibreMap instances
         *
         * @param id The MapView identifier
         */
        @JvmStatic
        fun unregisterMapView(id: Int) {
            mapViewRegistry.remove(id)
            mapLibreMapRegistry.remove(id)
            android.util.Log.d("MapLibrePlugin", "[Rooty] Unregistered MapView and MapLibreMap with ID: $id")
        }
        // ========== End Rooty Fork Addition ==========
    }

    private var permissionsManager: PermissionsManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding
            .platformViewRegistry
            .registerViewFactory(
                "plugins.flutter.io/maplibre",
                MapLibreMapFactory(),
            )
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        permissionsManager?.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )
        return true
    }
}

class MapLibreMapFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView = MapLibreRegistry.flutterApi!!.createPlatformView(viewId)
}
