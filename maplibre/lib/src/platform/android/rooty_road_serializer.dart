// [Rooty] Manual JNI binding for RootyRoadFeatureSerializer.
//
// This avoids regenerating jni.g.dart via jnigen.
// The Kotlin object RootyRoadFeatureSerializer has a single static method:
//   fun serialize(features: List<Feature>): ByteArray
//
// Usage from Dart:
//   final bytes = RootyRoadFeatureSerializer.serialize(jFeatureList);

// ignore_for_file: invalid_use_of_internal_member

import 'dart:typed_data';

import 'package:jni/_internal.dart' as jni;
import 'package:jni/jni.dart' as jni;

/// Dart JNI binding for the native Kotlin RootyRoadFeatureSerializer class.
///
/// Serializes a JList<Feature> into FlatBuffer bytes
/// for zero-copy deserialization in Rust.
class RootyRoadFeatureSerializer {
  RootyRoadFeatureSerializer._();

  static final _class = jni.JClass.forName(
    r'com/github/josxha/maplibre/RootyRoadFeatureSerializer',
  );

  // byte[] serialize(List<Feature> features)
  // JNI signature: (Ljava/util/List;)[B
  static final _id_serialize = _class.staticMethodId(
    r'serialize',
    r'(Ljava/util/List;)[B',
  );

  static final _serialize = jni.ProtectedJniExtensions.lookup<
              jni.NativeFunction<
                  jni.JniResult Function(
                jni.Pointer<jni.Void>,
                jni.JMethodIDPtr,
                jni.VarArgs<(jni.Pointer<jni.Void>,)>,
              )>>('globalEnv_CallStaticObjectMethod')
          .asFunction<
              jni.JniResult Function(
            jni.Pointer<jni.Void>,
            jni.JMethodIDPtr,
            jni.Pointer<jni.Void>,
          )>();

  /// Serialize a JList of Feature objects into FlatBuffer bytes.
  ///
  /// Returns null if serialization fails or produces empty data.
  static Uint8List? serialize(jni.JList<jni.JObject> features) {
    final result = _serialize(
      _class.reference.pointer,
      _id_serialize as jni.JMethodIDPtr,
      features.reference.pointer,
    );

    // Unwrap JniResult → JByteArray (nullable)
    final jByteArray = result.object<jni.JByteArray?>(
      const jni.$JByteArray$NullableType$(),
    );
    if (jByteArray == null) return null;

    final length = jByteArray.length;
    if (length == 0) {
      jByteArray.release();
      return null;
    }

    // Copy bytes to Dart-managed Uint8List.
    // getRange returns Int8List backed by malloc'd native memory (auto-freed).
    final int8List = jByteArray.getRange(0, length);
    jByteArray.release();

    // Zero-copy reinterpret: signed Int8 → unsigned Uint8 (same bytes)
    return int8List.buffer.asUint8List(
      int8List.offsetInBytes,
      int8List.lengthInBytes,
    );
  }
}
