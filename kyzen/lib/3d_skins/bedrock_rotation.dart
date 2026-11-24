import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// Converts Bedrock Euler rotations [rx, ry, rz] in degrees into
/// flutter_scene camera-space [vm.Quaternion].
///
/// Bedrock entity geometry coordinate system mapped to Flutter Scene:
/// - `-X` is character's right, `+X` is character's left
/// - `+Y` is Up, `-Y` is Down
/// - `-Z` is Front, `+Z` is Back (negated: `Z_cam = -Z_bedrock`)
///
/// Sign convention:
/// - Pitch (X): `+X` tilts down/forward -> positive rotation around camera X
///   (both flares a back-hung cape outward and pitches a head down).
/// - Yaw (Y): `+Y` turns right -> negative rotation around camera Y.
/// - Roll (Z): `+Z` tilts right -> negative rotation around camera Z.
///
/// Euler order is X-then-Y-then-Z, i.e. `R = Rz * Ry * Rx`
/// (rightmost quaternion applies first).
vm.Quaternion bedrockEulerToQuaternion(List<double> rotDeg) {
  const degToRad = math.pi / 180.0;
  final qx = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), rotDeg[0] * degToRad);
  final qy = vm.Quaternion.axisAngle(
    vm.Vector3(0, 1, 0),
    -rotDeg[1] * degToRad,
  );
  final qz = vm.Quaternion.axisAngle(
    vm.Vector3(0, 0, 1),
    -rotDeg[2] * degToRad,
  );
  return qz * qy * qx;
}
