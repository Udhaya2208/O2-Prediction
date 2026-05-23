import 'package:flutter/material.dart';

/// Re-usable animated widget that rebuilds on every animation tick.
/// Named differently from Flutter's built-in AnimatedBuilder to avoid conflicts.
class PulseAnimatedWidget extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const PulseAnimatedWidget({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
