import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' show CameraController;

/// Custom gesture for 3d skin pack preview
/// This prevents scrollable ancestors (e.g [SingleChildScrollView], [ListView])
/// from intercepting vertical drag gestures intended for rotating a 3D model
class EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  EagerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager scale';
}

/// Unlike the default `CameraControls` widget from `flutter_scene`, this widget
/// Uses [EagerScaleGestureRecognizer] by default so that drags and pinches rotate
/// the 3D camera without being stolen by parent scroll views
/// Registers mouse wheel with [PointerSignalResolver] to zoom the camera
/// without scrolling the page
class InteractiveCameraControls extends StatefulWidget {
  const InteractiveCameraControls({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.autofocus = true,
    this.eager = true,
    this.onDoubleTap,
    this.onPointerDown,
  });

  final CameraController controller;
  final Widget child;
  final bool enabled;
  final bool autofocus;
  final bool eager;
  final VoidCallback? onDoubleTap;
  final PointerDownEventListener? onPointerDown;

  @override
  State<InteractiveCameraControls> createState() =>
      _InteractiveCameraControlsState();
}

class _InteractiveCameraControlsState extends State<InteractiveCameraControls> {
  double _lastScale = 1.0;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  CameraController get _controller => widget.controller;

  void _onScaleStart(ScaleStartDetails details) => _lastScale = 1.0;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enabled) return;
    if (details.pointerCount <= 1) {
      _controller.handleDragUpdate(details.focalPointDelta);
      return;
    }
    final scaleFactor = _lastScale == 0.0 ? 1.0 : details.scale / _lastScale;
    _lastScale = details.scale;
    _controller.handleScaleUpdate(scaleFactor, details.focalPointDelta);
  }

  void _onPointerDown(PointerDownEvent event) {
    widget.onPointerDown?.call(event);

    if (widget.onDoubleTap != null) {
      final now = DateTime.now();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < const Duration(milliseconds: 320) &&
          _lastTapPosition != null &&
          (event.position - _lastTapPosition!).distance < 24.0) {
        _lastTapTime = null;
        _lastTapPosition = null;
        widget.onDoubleTap!();
      } else {
        _lastTapTime = now;
        _lastTapPosition = event.position;
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enabled || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is PointerScrollEvent) {
        _controller.handleScroll(resolved.scrollDelta.dy);
      }
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    return _controller.handleKeyEvent(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) _controller.releaseInput();
  }

  @override
  Widget build(BuildContext context) {
    final gestureFactory = widget.eager
        ? <Type, GestureRecognizerFactory>{
            EagerScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  EagerScaleGestureRecognizer
                >(
                  () => EagerScaleGestureRecognizer(),
                  (recognizer) => recognizer
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate,
                ),
          }
        : <Type, GestureRecognizerFactory>{
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (recognizer) => recognizer
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate,
                ),
          };

    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      onFocusChange: _onFocusChange,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerSignal: _onPointerSignal,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.biggest.isFinite) {
              _controller.viewportSize = constraints.biggest;
            }
            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: gestureFactory,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
