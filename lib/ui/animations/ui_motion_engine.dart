// ==================================================
// Z-CANVAS — PHASE-12 UI MOTION ENGINE
// ui/animations/ui_motion_engine.dart
//
// PRIMARY ROLE: VISUAL EXPERIENCE & MOTION SYSTEM
// PURE VISUAL ONLY — NO STATE CHANGES — NO LOGIC — NO ENGINE ACCESS
// ==================================================

import 'package:flutter/material.dart';

// ==================================================
// MOTION CONSTANTS
// Centralised durations and curves for the entire Z-CANVAS motion system.
// All animation parameters are sourced from here — never hard-coded inline.
// ==================================================

class ZMotionDuration {
  ZMotionDuration._();

  static const Duration instant    = Duration(milliseconds: 80);
  static const Duration fast       = Duration(milliseconds: 150);
  static const Duration normal     = Duration(milliseconds: 250);
  static const Duration moderate   = Duration(milliseconds: 350);
  static const Duration slow       = Duration(milliseconds: 500);
  static const Duration verySlow   = Duration(milliseconds: 700);
  static const Duration pageEnter  = Duration(milliseconds: 400);
  static const Duration panelSlide = Duration(milliseconds: 320);
}

class ZMotionCurve {
  ZMotionCurve._();

  static const Curve standard     = Curves.easeInOut;
  static const Curve enter        = Curves.easeOut;
  static const Curve exit         = Curves.easeIn;
  static const Curve spring       = Curves.elasticOut;
  static const Curve decelerate   = Curves.decelerate;
  static const Curve sharp        = Curves.easeInOutCubic;
  static const Curve overshoot    = Curves.elasticOut;
  static const Curve tapFeedback  = Curves.easeInOut;
}

// ==================================================
// FADE ANIMATIONS
// Wrap any widget in ZFadeIn / ZFadeOut / ZFadeTransition for opacity-only
// animation. No state logic; purely declarative visual wrappers.
// ==================================================

/// Fades a child in over [duration] with an optional [delay].
class ZFadeIn extends StatefulWidget {
  const ZFadeIn({
    super.key,
    required this.child,
    this.duration = ZMotionDuration.normal,
    this.delay    = Duration.zero,
    this.curve    = ZMotionCurve.enter,
  });

  final Widget   child;
  final Duration duration;
  final Duration delay;
  final Curve    curve;

  @override
  State<ZFadeIn> createState() => _ZFadeInState();
}

class _ZFadeInState extends State<ZFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: widget.curve);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

// ----------

/// Fades a child out. Useful for dismiss / remove animations.
class ZFadeOut extends StatefulWidget {
  const ZFadeOut({
    super.key,
    required this.child,
    this.duration = ZMotionDuration.normal,
    this.curve    = ZMotionCurve.exit,
  });

  final Widget   child;
  final Duration duration;
  final Curve    curve;

  @override
  State<ZFadeOut> createState() => _ZFadeOutState();
}

class _ZFadeOutState extends State<ZFadeOut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration,
        value: 1.0);
    _opacity = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

// ----------

/// Driven fade that tracks an external [AnimationController].
/// Use inside custom transitions where you already own the controller.
class ZFadeTransition extends StatelessWidget {
  const ZFadeTransition({
    super.key,
    required this.animation,
    required this.child,
    this.curve = ZMotionCurve.standard,
  });

  final Animation<double> animation;
  final Widget            child;
  final Curve             curve;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: curve),
        child: child,
      );
}

// ==================================================
// SLIDE ANIMATIONS
// Directional entrance / exit slides. No layout side-effects; uses
// SlideTransition which does not affect surrounding widgets.
// ==================================================

enum ZSlideDirection { fromBottom, fromTop, fromLeft, fromRight }

Offset _slideBeginOffset(ZSlideDirection dir) => switch (dir) {
      ZSlideDirection.fromBottom => const Offset(0.0, 0.2),
      ZSlideDirection.fromTop    => const Offset(0.0, -0.2),
      ZSlideDirection.fromLeft   => const Offset(-0.2, 0.0),
      ZSlideDirection.fromRight  => const Offset(0.2, 0.0),
    };

/// Slides a child in from [direction] combined with a fade.
class ZSlideIn extends StatefulWidget {
  const ZSlideIn({
    super.key,
    required this.child,
    this.direction = ZSlideDirection.fromBottom,
    this.duration  = ZMotionDuration.moderate,
    this.delay     = Duration.zero,
    this.curve     = ZMotionCurve.enter,
  });

  final Widget          child;
  final ZSlideDirection direction;
  final Duration        duration;
  final Duration        delay;
  final Curve           curve;

  @override
  State<ZSlideIn> createState() => _ZSlideInState();
}

class _ZSlideInState extends State<ZSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _slide   = Tween<Offset>(begin: _slideBeginOffset(widget.direction),
                              end: Offset.zero).animate(curved);
    _opacity = curved;

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _opacity, child: widget.child),
      );
}

// ==================================================
// SCALE ANIMATIONS
// Pop-in / pop-out for cards, dialogs, tooltips.
// ==================================================

/// Scales a child from [beginScale] → 1.0 with optional fade.
class ZScaleIn extends StatefulWidget {
  const ZScaleIn({
    super.key,
    required this.child,
    this.beginScale  = 0.85,
    this.duration    = ZMotionDuration.normal,
    this.delay       = Duration.zero,
    this.curve       = ZMotionCurve.spring,
    this.withFade    = true,
  });

  final Widget  child;
  final double  beginScale;
  final Duration duration;
  final Duration delay;
  final Curve   curve;
  final bool    withFade;

  @override
  State<ZScaleIn> createState() => _ZScaleInState();
}

class _ZScaleInState extends State<ZScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _scale   = Tween<double>(begin: widget.beginScale, end: 1.0).animate(curved);
    _opacity = widget.withFade
        ? Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: _ctrl, curve: ZMotionCurve.enter))
        : const AlwaysStoppedAnimation(1.0);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

// ==================================================
// PAGE TRANSITION ANIMATIONS
// Drop-in route transition builders. Use with PageRouteBuilder or
// GoRouter's CustomTransitionPage — never inside business logic.
// ==================================================

/// A slide-fade page transition (default Z-CANVAS page enter/exit).
class ZPageSlideTransition extends PageRouteBuilder<dynamic> {
  ZPageSlideTransition({
    required super.pageBuilder,
    this.direction = ZSlideDirection.fromRight,
    super.transitionDuration = ZMotionDuration.pageEnter,
    super.reverseTransitionDuration = ZMotionDuration.moderate,
  }) : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              _buildSlideTransition(animation, secondaryAnimation, child,
                  direction),
        );

  final ZSlideDirection direction;
}

Widget _buildSlideTransition(
  Animation<double>    animation,
  Animation<double>    secondaryAnimation,
  Widget               child,
  ZSlideDirection      direction,
) {
  final slide = Tween<Offset>(
    begin: _slideBeginOffset(direction),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: ZMotionCurve.enter));

  final fade = CurvedAnimation(parent: animation, curve: ZMotionCurve.enter);

  return FadeTransition(
    opacity: fade,
    child: SlideTransition(position: slide, child: child),
  );
}

// ----------

/// Reusable static helper — returns a pre-built [PageTransitionsTheme] entry
/// so you can attach Z-CANVAS transitions globally in ThemeData.
class ZPageTransitionTheme {
  ZPageTransitionTheme._();

  /// Supply to ThemeData.pageTransitionsTheme:
  ///
  /// ```dart
  /// pageTransitionsTheme: PageTransitionsTheme(
  ///   builders: {
  ///     TargetPlatform.android: ZPageTransitionTheme.builder,
  ///     TargetPlatform.iOS:     ZPageTransitionTheme.builder,
  ///   },
  /// )
  /// ```
  static const PageTransitionsBuilder builder = _ZPageTransitionsBuilder();
}

class _ZPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ZPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>       route,
    BuildContext       context,
    Animation<double>  animation,
    Animation<double>  secondaryAnimation,
    Widget             child,
  ) =>
      _buildSlideTransition(
          animation, secondaryAnimation, child, ZSlideDirection.fromRight);
}

// ==================================================
// PANEL OPEN / CLOSE ANIMATIONS
// Side panels, bottom sheets, property panels — all share these wrappers.
// ==================================================

/// Animates a panel sliding in from the [side] with an opacity crossfade.
class ZPanelSlideIn extends StatefulWidget {
  const ZPanelSlideIn({
    super.key,
    required this.child,
    this.side     = ZSlideDirection.fromRight,
    this.duration = ZMotionDuration.panelSlide,
    this.curve    = ZMotionCurve.decelerate,
  });

  final Widget          child;
  final ZSlideDirection side;
  final Duration        duration;
  final Curve           curve;

  @override
  State<ZPanelSlideIn> createState() => _ZPanelSlideInState();
}

class _ZPanelSlideInState extends State<ZPanelSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _slide   = Tween<Offset>(begin: _slideBeginOffset(widget.side),
                              end: Offset.zero).animate(curved);
    _opacity = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: ZMotionCurve.enter));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _opacity, child: widget.child),
      );
}

// ----------

/// Animated panel wrapper that toggles open/closed when [isOpen] changes.
/// Drives a width or height expansion from 0 → [expandedSize].
class ZPanelToggle extends StatefulWidget {
  const ZPanelToggle({
    super.key,
    required this.child,
    required this.isOpen,
    required this.expandedSize,
    this.axis     = Axis.horizontal,
    this.duration = ZMotionDuration.panelSlide,
    this.curve    = ZMotionCurve.sharp,
  });

  final Widget   child;
  final bool     isOpen;
  final double   expandedSize;
  final Axis     axis;
  final Duration duration;
  final Curve    curve;

  @override
  State<ZPanelToggle> createState() => _ZPanelToggleState();
}

class _ZPanelToggleState extends State<ZPanelToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _size;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _size = CurvedAnimation(parent: _ctrl, curve: widget.curve);
  }

  @override
  void didUpdateWidget(ZPanelToggle old) {
    super.didUpdateWidget(old);
    if (old.isOpen != widget.isOpen) {
      widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _size,
        child: widget.child,
        builder: (context, child) {
          final current = _size.value * widget.expandedSize;
          return SizedBox(
            width:  widget.axis == Axis.horizontal ? current : null,
            height: widget.axis == Axis.vertical   ? current : null,
            child: ClipRect(child: child),
          );
        },
      );
}

// ==================================================
// BUTTON TAP FEEDBACK ANIMATIONS
// Purely visual press effect. No callbacks modified; no state touched.
// ==================================================

/// Wraps any widget with a visual press-scale effect on tap.
/// Pass the [onTap] callback through here — the wrapper only adds visual
/// feedback and then calls the provided callback unchanged.
class ZTapFeedback extends StatefulWidget {
  const ZTapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.94,
    this.duration    = ZMotionDuration.fast,
    this.curve       = ZMotionCurve.tapFeedback,
  });

  final Widget       child;
  final VoidCallback? onTap;
  final double       scaleFactor;
  final Duration     duration;
  final Curve        curve;

  @override
  State<ZTapFeedback> createState() => _ZTapFeedbackState();
}

class _ZTapFeedbackState extends State<ZTapFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _ctrl.forward();
  void _handleTapUp(TapUpDetails _)     { _ctrl.reverse(); widget.onTap?.call(); }
  void _handleTapCancel()               => _ctrl.reverse();

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown:   _handleTapDown,
        onTapUp:     _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior:    HitTestBehavior.opaque,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

// ==================================================
// MICRO-INTERACTIONS
// Hover shimmer, focus ring pulse, and press-state overlay.
// These are all visual-only and fully decoupled from app state.
// ==================================================

/// Animated hover effect — scales up slightly on mouse enter.
/// On non-hover platforms the widget renders without change.
class ZHoverScale extends StatefulWidget {
  const ZHoverScale({
    super.key,
    required this.child,
    this.hoverScale = 1.03,
    this.duration   = ZMotionDuration.fast,
    this.curve      = ZMotionCurve.standard,
  });

  final Widget  child;
  final double  hoverScale;
  final Duration duration;
  final Curve   curve;

  @override
  State<ZHoverScale> createState() => _ZHoverScaleState();
}

class _ZHoverScaleState extends State<ZHoverScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.hoverScale).animate(
      CurvedAnimation(parent: _ctrl, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _ctrl.forward(),
        onExit:  (_) => _ctrl.reverse(),
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

// ----------

/// Pulses a border/glow around a widget when it gains keyboard focus.
class ZFocusPulse extends StatefulWidget {
  const ZFocusPulse({
    super.key,
    required this.child,
    this.focusNode,
    this.glowColor,
    this.duration = ZMotionDuration.moderate,
  });

  final Widget     child;
  final FocusNode? focusNode;
  final Color?     glowColor;
  final Duration   duration;

  @override
  State<ZFocusPulse> createState() => _ZFocusPulseState();
}

class _ZFocusPulseState extends State<ZFocusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _glow;
  FocusNode?                     _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: ZMotionCurve.standard),
    );
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    _node.hasFocus ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _ownNode?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = (widget.glowColor ??
            Theme.of(context).colorScheme.primary)
        .withOpacity(0.35);

    return AnimatedBuilder(
      animation: _glow,
      child: widget.child,
      builder: (ctx, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color:       color.withOpacity(color.opacity * _glow.value),
              blurRadius:  12 * _glow.value,
              spreadRadius: 2 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ----------

/// Shimmer loading placeholder — looping brightness sweep.
class ZShimmer extends StatefulWidget {
  const ZShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<ZShimmer> createState() => _ZShimmerState();
}

class _ZShimmerState extends State<ZShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base      = widget.baseColor      ??
        Theme.of(context).colorScheme.surfaceVariant;
    final highlight = widget.highlightColor ??
        Theme.of(context).colorScheme.surface;

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (ctx, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: const Alignment(-1.5, 0),
          end:   const Alignment(1.5, 0),
          colors: [base, highlight, base],
          stops: [
            (_ctrl.value - 0.3).clamp(0.0, 1.0),
            _ctrl.value.clamp(0.0, 1.0),
            (_ctrl.value + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

// ==================================================
// STAGGERED LIST ANIMATION
// Applies a cascade delay to a list of children so items animate in
// one after another. Pure visual; children are identical in function.
// ==================================================

/// Renders [children] each delayed by [staggerDelay] × index.
class ZStaggeredList extends StatelessWidget {
  const ZStaggeredList({
    super.key,
    required this.children,
    this.staggerDelay  = const Duration(milliseconds: 60),
    this.entryDuration = ZMotionDuration.moderate,
    this.direction     = ZSlideDirection.fromBottom,
  });

  final List<Widget>  children;
  final Duration      staggerDelay;
  final Duration      entryDuration;
  final ZSlideDirection direction;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++)
            ZSlideIn(
              direction: direction,
              duration:  entryDuration,
              delay:     staggerDelay * i,
              child:     children[i],
            ),
        ],
      );
}

// ==================================================
// CANVAS OVERLAY ANIMATIONS
// Visual-only overlays for the Z-CANVAS editor surface.
// These animate purely presentational chrome — no canvas data is touched.
// ==================================================

/// Crossfades between two widgets; used for toolbar/panel overlay swaps.
class ZOverlayCrossfade extends StatelessWidget {
  const ZOverlayCrossfade({
    super.key,
    required this.firstChild,
    required this.secondChild,
    required this.showFirst,
    this.duration = ZMotionDuration.normal,
  });

  final Widget firstChild;
  final Widget secondChild;
  final bool   showFirst;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
        firstChild:   firstChild,
        secondChild:  secondChild,
        crossFadeState: showFirst
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        duration: duration,
        firstCurve:  ZMotionCurve.enter,
        secondCurve: ZMotionCurve.enter,
        sizeCurve:   ZMotionCurve.standard,
      );
}

// ----------

/// Animated visibility wrapper with fade + scale pop.
class ZAnimatedVisibility extends StatelessWidget {
  const ZAnimatedVisibility({
    super.key,
    required this.child,
    required this.visible,
    this.duration = ZMotionDuration.normal,
    this.curve    = ZMotionCurve.standard,
  });

  final Widget   child;
  final bool     visible;
  final Duration duration;
  final Curve    curve;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: curve,
        child: AnimatedScale(
          scale:    visible ? 1.0 : 0.92,
          duration: duration,
          curve:    curve,
          child:    child,
        ),
      );
}

// ==================================================
// FUTURE EXTENSION PLACEHOLDERS
// Visual-only stubs for upcoming Z-CANVAS UI modules.
// No execution enabled. Purely structural markers.
// ==================================================

/// [PLACEHOLDER] Voice input button animation shell.
/// Will animate a microphone pulse when voice mode is active.
class ZVoiceInputButtonPlaceholder extends StatelessWidget {
  const ZVoiceInputButtonPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

/// [PLACEHOLDER] AI Copilot floating bubble animation shell.
class ZAICopilotBubblePlaceholder extends StatelessWidget {
  const ZAICopilotBubblePlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

/// [PLACEHOLDER] Plugin marketplace panel slide-in shell.
class ZPluginMarketplacePanelPlaceholder extends StatelessWidget {
  const ZPluginMarketplacePanelPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

/// [PLACEHOLDER] Automation dashboard overlay shell.
class ZAutomationDashboardPlaceholder extends StatelessWidget {
  const ZAutomationDashboardPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

/// [PLACEHOLDER] Reward / gamification celebration animation shell.
class ZRewardCelebrationPlaceholder extends StatelessWidget {
  const ZRewardCelebrationPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

/// [PLACEHOLDER] Advanced analytics panel animation shell.
class ZAnalyticsPanelPlaceholder extends StatelessWidget {
  const ZAnalyticsPanelPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(); // stub — wired in future phase
}

// ==================================================
// END OF ui/animations/ui_motion_engine.dart
// Z-CANVAS — PHASE-12 — PURE VISUAL MOTION ENGINE
// Powered by Zynquar
// ==================================================
