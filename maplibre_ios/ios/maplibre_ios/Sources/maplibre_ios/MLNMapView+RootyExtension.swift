//
// MLNMapView+RootyExtension.swift
// maplibre_ios
//
// Phase 2.0: Expose mbgl::Map pointer for native direct update
// This extension provides unsafe access to MapLibre's internal C++ core.
//
// CRITICAL SAFETY WARNINGS:
// 1. The returned pointer is ONLY valid while the MLNMapView exists
// 2. Use-after-free will crash if called after MapView deallocation
// 3. Caller MUST register/unregister pointer for validation
// 4. All operations must be scheduled on MapLibre's render thread
//

import Foundation
import MapLibre

extension MLNMapView {
    /// Returns a pointer to the internal mbgl::Map C++ object.
    ///
    /// **Phase 2.0: Native Direct Update**
    ///
    /// This method exposes the internal C++ core for direct GeoJSON updates,
    /// bypassing Platform Channels for sub-frame latency.
    ///
    /// ## Safety
    /// - **CRITICAL**: Pointer is INVALID after MapView is deallocated
    /// - Must call `rooty_register_map_pointer()` immediately after obtaining
    /// - Must call `rooty_unregister_map_pointer()` before dispose()
    /// - Never access from background threads (use mbgl::Scheduler::schedule())
    ///
    /// ## Implementation Details
    /// This uses unsafe pointer arithmetic to access the private `_mbglMap`
    /// member of MLNMapView. The offset is determined empirically based on
    /// the MapLibre iOS SDK version.
    ///
    /// **Fragility Warning**: This will break if:
    /// - MapLibre iOS SDK changes MLNMapView internal layout
    /// - Compiler changes struct padding/alignment
    /// - iOS version changes Objective-C runtime behavior
    ///
    /// ## Returns
    /// - UnsafeRawPointer to mbgl::Map (C++ object)
    /// - nil if unable to extract pointer
    ///
    /// ## Example Usage (from Swift)
    /// ```swift
    /// if let mapPtr = mapView.getMBGLMapPointer() {
    ///     rooty_register_map_pointer(mapPtr)
    ///     // ... use pointer for FFI calls
    ///     // Later, before dispose:
    ///     rooty_unregister_map_pointer(mapPtr)
    /// }
    /// ```
    @objc public func getMBGLMapPointer() -> UnsafeRawPointer? {
        // APPROACH 1: Try to access via KVC (Key-Value Coding)
        // This is safer but may not work if _mbglMap is not KVC-compliant
        if let mbglMapWrapper = self.value(forKey: "mbglMap") {
            // mbglMapWrapper is likely a Swift/ObjC wrapper around std::unique_ptr<mbgl::Map>
            // We need to extract the raw pointer from unique_ptr
            
            // Use Mirror API to inspect the wrapper object
            let mirror = Mirror(reflecting: mbglMapWrapper)
            print("[Rooty] MLNMapView+Extension: mbglMap wrapper type: \(type(of: mbglMapWrapper))")
            print("[Rooty] MLNMapView+Extension: Mirror children count: \(mirror.children.count)")
            
            for (label, value) in mirror.children {
                print("[Rooty] MLNMapView+Extension: Child - label: \(label ?? "nil"), type: \(type(of: value))")
            }
            
            // Try to extract pointer using unsafeBitCast
            // WARNING: This is EXTREMELY fragile and may crash
            // let rawPtr = unsafeBitCast(mbglMapWrapper, to: UnsafeRawPointer.self)
            // return rawPtr
        }
        
        // APPROACH 2: Use Objective-C runtime to get ivar offset
        // This is more reliable for Objective-C objects
        #if DEBUG
        print("[Rooty] MLNMapView+Extension: Attempting to extract mbgl::Map pointer via runtime introspection")
        #endif
        
        var ivarCount: UInt32 = 0
        guard let ivars = class_copyIvarList(type(of: self), &ivarCount) else {
            print("[Rooty] MLNMapView+Extension: ERROR - Failed to get ivar list")
            return nil
        }
        
        defer { free(ivars) }
        
        // Search for _mbglMap ivar
        for i in 0..<Int(ivarCount) {
            let ivar = ivars[i]
            if let ivarName = ivar_getName(ivar),
               let nameString = String(utf8String: ivarName) {
                
                #if DEBUG
                print("[Rooty] MLNMapView+Extension: Found ivar: \(nameString)")
                #endif
                
                // Look for _mbglMap or mbglMap
                if nameString == "_mbglMap" || nameString == "mbglMap" {
                    let offset = ivar_getOffset(ivar)
                    
                    #if DEBUG
                    print("[Rooty] MLNMapView+Extension: Found _mbglMap ivar at offset: \(offset)")
                    #endif
                    
                    // Get pointer to self
                    let selfPtr = Unmanaged.passUnretained(self).toOpaque()
                    
                    // Calculate ivar address
                    let ivarPtr = selfPtr.advanced(by: offset)
                    
                    // The ivar is likely std::unique_ptr<mbgl::Map>
                    // unique_ptr layout: just a raw pointer (8 bytes on 64-bit)
                    let mbglMapPtrPtr = ivarPtr.assumingMemoryBound(to: UnsafeRawPointer?.self)
                    let mbglMapPtr = mbglMapPtrPtr.pointee
                    
                    if let mbglMapPtr = mbglMapPtr {
                        // Use String interpolation instead of NSLog to avoid variadic function issue
                        let ptrAddress = String(format: "%p", mbglMapPtr)
                        print("[Rooty] MLNMapView+Extension: Successfully extracted mbgl::Map pointer: \(ptrAddress)")
                        return mbglMapPtr
                    } else {
                        print("[Rooty] MLNMapView+Extension: ERROR - mbgl::Map pointer is nil")
                        return nil
                    }
                }
            }
        }
        
        print("[Rooty] MLNMapView+Extension: ERROR - _mbglMap ivar not found")
        return nil
    }
}
