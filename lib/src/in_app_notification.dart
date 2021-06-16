import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_notification/src/size_listenable_container.dart';

@visibleForTesting
const notificationShowingDuration = Duration(milliseconds: 350);

/// A widget for display foreground notification.
///
/// It is mainly intended to be inserted in the `builder` of [WidgetsApp].
///
/// {@tool snippet}
/// Usage example:
///
/// ```dart
/// return MaterialApp(
///   home: Home(),
///   builder: (context, child) => AlertNotification(
///     safeAreaPadding: MediaQuery.of(context).viewPadding,
///     child: child,
///   ),
/// );
/// ```
/// {@end-tool}
class InAppNotification extends StatefulWidget {
  /// Creates an in-app notification system.
  ///
  /// The [safeAreaPadding] must not be null.
  const InAppNotification({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  static FutureOr<void> show({
    required Widget child,
    required BuildContext context,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 10),
    Curve curve = Curves.ease,
  }) =>
      context.findAncestorStateOfType<InAppNotificationState>()?.show(
            child: child,
            context: context,
            onTap: onTap,
            duration: duration,
            curve: curve,
          );

  @override
  InAppNotificationState createState() => InAppNotificationState();
}

class InAppNotificationState extends State<InAppNotification>
    with SingleTickerProviderStateMixin {
  VoidCallback? _onTap;
  Timer? _timer;
  double _dragDistance = 0.0;

  OverlayEntry? _overlay;
  late CurvedAnimation _animation;

  double get _currentPosition =>
      _animation.value * _notificationSize.height + _dragDistance;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: notificationShowingDuration)
        ..addListener(_updateNotification);

  Size _notificationSize = Size.zero;
  Completer<Size> _notificationSizeCompleter = Completer();

  @override
  void initState() {
    _animation = CurvedAnimation(parent: _controller, curve: Curves.ease);
    super.initState();
  }

  void _updateNotification() {
    _overlay?.markNeedsBuild();
  }

  /// Shows specified Widget as notification.
  ///
  /// [child] is required, this will be displayed as notification body.
  ///
  /// Showing and hiding notifications is managed by animation,
  /// and the process is as follows.
  ///
  /// 1. Execute this method, start animation.
  /// 2. Then the notification appear, it will stay at specified [duration].
  /// 3. After the [duration] has elapsed,
  ///    play the animation in reverse and dispose the notification.
  Future<void> show({
    required Widget child,
    required BuildContext context,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 10),
    Curve curve = Curves.ease,
  }) async {
    await dismiss();

    _dragDistance = 0.0;
    _onTap = onTap;
    _animation = CurvedAnimation(parent: _controller, curve: curve);

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).size.height - _currentPosition,
        left: 0,
        right: 0,
        child: SizeListenableContainer(
          onSizeChanged: (size) => _notificationSizeCompleter.complete(size),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTapNotification,
            onTapDown: (_) => _onTapDown(),
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: (_) => _onVerticalDragEnd(),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );

    Navigator.of(context).overlay?.insert(_overlay!);
    _notificationSize = await _notificationSizeCompleter.future;

    _controller.forward(from: 0.0);

    if (duration.inMicroseconds == 0) return;
    _timer = Timer(duration, () => dismiss());
  }

  Future dismiss() async {
    _timer?.cancel();

    if (_controller.status == AnimationStatus.completed) {
      await _controller.reverse();
    }

    _overlay?.remove();
    _overlay = null;
    _notificationSizeCompleter = Completer();
  }

  void _onTapNotification() {
    if (_onTap == null) return;

    dismiss();
    _onTap!();
  }

  void _onTapDown() {
    _timer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // _dragDistance =
    //     (_dragDistance + details.delta.dy).clamp(_initialPosition, 0.0);
  }

  void _onVerticalDragEnd() {
    // final percentage = 1.0 - _currentPosition.abs() / _initialPosition.abs();
    // if (percentage >= 0.4) {
    //   if (_dragDistance == 0.0) return;
    //   setState(() {
    //     _dragDistance = 0.0;
    //   });
    //   _controller?.forward(from: percentage);
    // } else {
    //   dismiss(from: percentage);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
