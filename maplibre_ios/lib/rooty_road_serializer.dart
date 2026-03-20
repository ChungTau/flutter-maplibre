// [Rooty] Manual FFI binding for RootyRoadFeatureSerializer.
//
// This avoids regenerating maplibre_ffi.g.dart via ffigen.
// The Swift class RootyRoadFeatureSerializer has a single static method:
//   +[RootyRoadFeatureSerializer serialize:] → NSData
//
// Usage from Dart:
//   final nsData = RootyRoadFeatureSerializer.serialize(nsArray);

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:objective_c/objective_c.dart' as objc;

/// Dart FFI binding for the native Swift RootyRoadFeatureSerializer class.
///
/// Serializes an NSArray of MLNFeature objects into FlatBuffer bytes
/// for zero-copy deserialization in Rust.
class RootyRoadFeatureSerializer {
  RootyRoadFeatureSerializer._();

  static final _class =
      objc.getClass('RootyRoadFeatureSerializer');
  static final _sel = objc.registerName('serialize:');

  // ObjC msgSend: id Function(id, SEL, id)
  static final _msgSend = objc.msgSendPointer
      .cast<
          ffi.NativeFunction<
              ffi.Pointer<objc.ObjCObjectImpl> Function(
                ffi.Pointer<objc.ObjCObjectImpl>,
                ffi.Pointer<objc.ObjCSelector>,
                ffi.Pointer<objc.ObjCObjectImpl>,
              )>>()
      .asFunction<
          ffi.Pointer<objc.ObjCObjectImpl> Function(
            ffi.Pointer<objc.ObjCObjectImpl>,
            ffi.Pointer<objc.ObjCSelector>,
            ffi.Pointer<objc.ObjCObjectImpl>,
          )>();

  /// Serialize an NSArray of MLNFeature objects into FlatBuffer bytes.
  ///
  /// Returns null if serialization fails or produces empty data.
  static Uint8List? serialize(objc.NSArray features) {
    final retPtr = _msgSend(
      _class.ref.pointer,
      _sel,
      features.ref.pointer,
    );
    if (retPtr == ffi.nullptr) return null;

    final nsData = objc.NSData.fromPointer(retPtr, retain: true, release: true);
    final length = nsData.length;
    if (length == 0) return null;

    // Copy bytes to Dart-managed Uint8List.
    // The NSData is released after this scope, so we must copy.
    return Uint8List.fromList(
      nsData.bytes.cast<ffi.Uint8>().asTypedList(length),
    );
  }
}
