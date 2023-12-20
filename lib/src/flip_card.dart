library flip_card;

import 'dart:async';
import 'package:flutter/material.dart';

import 'flip_card_transition.dart';
import 'flip_card_controller.dart';

enum CardSide {
  front,
  back;

  /// Return [CardSide] associated with the [AnimationStatus]
  factory CardSide.fromAnimationStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.reverse:
        return CardSide.front;
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        return CardSide.back;
    }
  }

  /// Return the opposite of the this [CardSide]
  CardSide get opposite {
    switch (this) {
      case CardSide.front:
        return CardSide.back;
      case CardSide.back:
        return CardSide.front;
    }
  }
}

enum Fill { none, front, back }

extension on TickerFuture {
  /// Wait until ticker completes or an error is thrown
  Future<void> get complete {
    final completer = Completer();
    void thunk(value) {
      completer.complete();
    }

    orCancel.then(thunk, onError: thunk);
    return completer.future;
  }
}

/// A widget that provides a flip card animation.
/// It could be used for hiding and showing details of a product.
///
/// To control the card programmatically,
/// you can pass a [controller] when creating the card.
///
/// ## Example
///
/// ```dart
/// FlipCard(
///   fill: Fill.fillBack,
///   direction: FlipDirection.HORIZONTAL, // default
///   initialSide: CardSide.front, // The side to initially display.
///   front: Container(
///     child: Text('Front'),
///   ),
///   back: Container(
///     child: Text('Back'),
///   ),
/// )
/// ```
class FlipCard extends StatefulWidget {
  const FlipCard({
    Key? key,
    required this.back,
    this.duration = const Duration(milliseconds: 500),
    this.onFlip,
    this.onFlipDone,
    this.direction = Axis.horizontal,
    this.controller,
    this.flipOnTouch = true,
    this.alignment = Alignment.center,
    this.fill = Fill.none,
    this.initialSide = CardSide.front,
    this.autoFlipDuration,
  }) : super(key: key);

  final CardSide initialSide;
  final Alignment alignment;
  final Duration? autoFlipDuration;
  final Widget back;
  final FlipCardController? controller;
  final Axis direction;
  final Fill fill;
  final bool flipOnTouch;
  final VoidCallback? onFlip;
  final void Function(CardSide side)? onFlipDone;
  final Duration duration;

  @override
  State<StatefulWidget> createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.duration != oldWidget.duration) {
      controller.duration = widget.duration;
    }

    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller?.state == this) {
        oldWidget.controller?.state = null;
      }

      widget.controller?.state = this;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      value: widget.initialSide == CardSide.front ? 0.0 : 1.0,
      duration: widget.duration,
      vsync: this,
    );

    widget.controller?.state = this;

    if (widget.autoFlipDuration != null) {
      Future.delayed(widget.autoFlipDuration!, flip);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    widget.controller?.state = null;
    super.dispose();
  }

  Future<void> flip([CardSide? targetSide]) async {
    if (!mounted) return;
    widget.onFlip?.call();

    targetSide ??= getOppositeSide();

    switch (targetSide) {
      case CardSide.front:
        await controller.reverse().complete;
        break;
      case CardSide.back:
        await controller.forward().complete;
        break;
    }

    widget.onFlipDone?.call(targetSide);
  }

  void flipWithoutAnimation([CardSide? targetSide]) {
    controller.stop();
    widget.onFlip?.call();

    targetSide ??= getOppositeSide();

    switch (targetSide) {
      case CardSide.front:
        controller.value = 0.0;
        break;
      case CardSide.back:
        controller.value = 1.0;
        break;
    }

    widget.onFlipDone?.call(targetSide);
  }

  CardSide getOppositeSide() {
    return CardSide.fromAnimationStatus(controller.status).opposite;
  }

  Future<void> skew(double target, {Duration? duration, Curve? curve}) async {
    assert(0 <= target && target <= 1);

    if (target > controller.value) {
      await controller
          .animateTo(
            target,
            duration: duration,
            curve: curve ?? Curves.linear,
          )
          .complete;
    } else {
      await controller
          .animateBack(
            target,
            duration: duration,
            curve: curve ?? Curves.linear,
          )
          .complete;
    }
  }

  Future<void> hint({
    double target = 0.2,
    Duration? duration,
    Curve curveTo = Curves.easeInOut,
    Curve curveBack = Curves.easeInOut,
  }) async {
    if (controller.status != AnimationStatus.dismissed) return;

    duration = duration ?? controller.duration!;
    final halfDuration =
        Duration(milliseconds: (duration.inMilliseconds / 2).round());

    try {
      await controller
          .animateTo(
            target,
            duration: halfDuration,
            curve: curveTo,
          )
          .complete;
    } finally {
      await controller
          .animateBack(
            0,
            duration: halfDuration,
            curve: curveBack,
          )
          .complete;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = FlipCardTransition(
      back: widget.back,
      animation: controller,
      direction: widget.direction,
      fill: widget.fill,
      alignment: widget.alignment,
    );

    if (widget.flipOnTouch) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: flip,
        child: child,
      );
    }

    return child;
  }

}
