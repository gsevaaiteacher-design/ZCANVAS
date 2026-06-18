// ==========================================================
// widgets/canvas_widget.dart
// PHASE-17 — ZERO GAP WIDGET ARCHITECTURE CONTRACT
// FILE 1 OF 4: canvas_widget.dart
// ==========================================================
//
// PURPOSE (FIXED): DISPLAY ONLY FINAL RENDER OUTPUT.
//
// INPUTS (FIXED):
//   renderSnapshot  — immutable: { layers, canvas, selection }
//   selectionState  — { selectedLayerId: STRING | NULL }
//
// OUTPUT EVENTS (ONLY THESE 3):
//   USER_DRAG  → payload "{x:number, y:number}"
//   USER_TAP   → payload "{x:number, y:number}"
//   USER_ZOOM  → payload "{scale:number}"
//
// ALL EVENTS CALL: EditorController.sendCommand(COMMAND)
//
// ALLOWED STATE ONLY:
//   UI_STATE = { hover: BOOLEAN, animation: BOOLEAN }
//
// FORBIDDEN:
//   ✖ MODIFY LAYERS       ✖ CREATE LAYERS     ✖ DELETE LAYERS
//   ✖ CALL ENGINE         ✖ STORE ANY STATE   ✖ COMPUTE LAYOUT
//   ✖ DIRECT ENGINE ACCESS
//
// COMMUNICATION FLOW:
//   CanvasWidget
//       → EditorController.sendCommand()
//       → ENGINE LAYER
//       → RenderEngine
//       → Canvas
// ==========================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../controllers/editor_controller.dart';

// ---------------------------------------------------------------------------
// COMMAND — Global command format (strict, from contract)
// ---------------------------------------------------------------------------

/// Strict command structure as defined by the PHASE-17 contract.
///
/// COMMAND {
///   type: STRING_ENUM,
///   payload: STRING_OR_JSON_STRING,
///   target: STRING,
///   timestamp: INTEGER
/// }
///
/// NO OTHER FORMAT IS VALID.
@immutable
class CanvasCommand {
  const CanvasCommand({
    required this.type,
    required this.payload,
    required this.target,
    required this.timestamp,
  });

  final String type;
  final String payload;
  final String target;
  final int timestamp;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type,
        'payload': payload,
        'target': target,
        'timestamp': timestamp,
      };
}

// ---------------------------------------------------------------------------
// RENDER SNAPSHOT — immutable input type
// ---------------------------------------------------------------------------

/// Immutable render snapshot delivered by EditorController.
///
/// Structure (contract-defined):
/// {
///   layers:    ARRAY<LAYER_OBJECT>,
///   canvas:    OBJECT,
///   selection: OBJECT
/// }
///
/// This class is READ-ONLY. CanvasWidget NEVER modifies its contents.
@immutable
class RenderSnapshot {
  const RenderSnapshot({
    required this.layers,
    required this.canvas,
    required this.selection,
  });

  final List<Map<String, dynamic>> layers;
  final Map<String, dynamic> canvas;
  final Map<String, dynamic> selection;

  /// Constructs a [RenderSnapshot] from an immutable JSON map.
  factory RenderSnapshot.fromMap(Map<String, dynamic> map) {
    return RenderSnapshot(
      layers: List<Map<String, dynamic>>.from(
        (map['layers'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => Map<String, dynamic>.from(e as Map)),
      ),
      canvas: Map<String, dynamic>.from(map['canvas'] as Map? ?? <String, dynamic>{}),
      selection: Map<String, dynamic>.from(map['selection'] as Map? ?? <String, dynamic>{}),
    );
  }

  /// Returns an empty snapshot used before first render arrives.
  factory RenderSnapshot.empty() {
    return const RenderSnapshot(
      layers: <Map<String, dynamic>>[],
      canvas: <String, dynamic>{},
      selection: <String, dynamic>{},
    );
  }
}

// ---------------------------------------------------------------------------
// SELECTION STATE — immutable input type
// ---------------------------------------------------------------------------

/// Selection state delivered alongside [RenderSnapshot].
///
/// Structure: { selectedLayerId: STRING | NULL }
///
/// READ-ONLY. CanvasWidget NEVER modifies selection.
@immutable
class CanvasSelectionState {
  const CanvasSelectionState({required this.selectedLayerId});

  final String? selectedLayerId;

  factory CanvasSelectionState.fromMap(Map<String, dynamic> map) {
    return CanvasSelectionState(
      selectedLayerId: map['selectedLayerId'] as String?,
    );
  }

  factory CanvasSelectionState.none() {
    return const CanvasSelectionState(selectedLayerId: null);
  }
}

// ---------------------------------------------------------------------------
// CANVAS WIDGET
// ---------------------------------------------------------------------------

/// Pure visual render surface for Z-CANVAS.
///
/// RESPONSIBILITIES (fixed by contract):
///   ✔ Display [renderSnapshot] received from EditorController.
///   ✔ Forward USER_DRAG, USER_TAP, USER_ZOOM gestures as commands
///     to [EditorController.sendCommand].
///
/// FORBIDDEN (hard block):
///   ✖ Engine access       ✖ State mutation      ✖ Layout computation
///   ✖ Layer modification  ✖ Data storage        ✖ Rendering decisions
///
/// All gestures are converted to the contract-defined COMMAND format
/// and sent exclusively via [EditorController.sendCommand].
class CanvasWidget extends StatefulWidget {
  const CanvasWidget({
    super.key,
    required this.renderSnapshot,
    required this.selectionState,
    required this.editorController,
  });

  /// Immutable render output from EditorController.
  /// CONTRACT TYPE: { layers: ARRAY, canvas: OBJECT, selection: OBJECT }
  final RenderSnapshot renderSnapshot;

  /// Current selection from EditorController.
  /// CONTRACT TYPE: { selectedLayerId: STRING | NULL }
  final CanvasSelectionState selectionState;

  /// EditorController — the ONLY channel for commands.
  /// CanvasWidget NEVER accesses engines directly.
  final EditorController editorController;

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget>
    with SingleTickerProviderStateMixin {
  // -------------------------------------------------------------------------
  // ALLOWED STATE ONLY: UI_STATE = { hover: BOOLEAN, animation: BOOLEAN }
  // NO OTHER STATE IS ALLOWED.
  // -------------------------------------------------------------------------

  bool _hover = false;
  bool _animation = false;

  // Animation controller is a UI concern only — drives _animation flag.
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addStatusListener((AnimationStatus status) {
        final bool running = status == AnimationStatus.forward ||
            status == AnimationStatus.reverse;
        if (_animation != running) {
          setState(() => _animation = running);
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // COMMAND FACTORY — builds strict PHASE-17 COMMAND objects
  // -------------------------------------------------------------------------

  /// Builds a USER_DRAG command.
  /// payload = "{x:number, y:number}"
  CanvasCommand _buildDragCommand(double x, double y) {
    return CanvasCommand(
      type: 'USER_DRAG',
      payload: jsonEncode(<String, double>{'x': x, 'y': y}),
      target: 'EDITOR',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Builds a USER_TAP command.
  /// payload = "{x:number, y:number}"
  CanvasCommand _buildTapCommand(double x, double y) {
    return CanvasCommand(
      type: 'USER_TAP',
      payload: jsonEncode(<String, double>{'x': x, 'y': y}),
      target: 'EDITOR',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Builds a USER_ZOOM command.
  /// payload = "{scale:number}"
  CanvasCommand _buildZoomCommand(double scale) {
    return CanvasCommand(
      type: 'USER_ZOOM',
      payload: jsonEncode(<String, double>{'scale': scale}),
      target: 'EDITOR',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // -------------------------------------------------------------------------
  // GESTURE HANDLERS — convert gestures to commands, no local logic
  // -------------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    widget.editorController.sendCommand(
      _buildTapCommand(
        details.localPosition.dx,
        details.localPosition.dy,
      ),
    );
    _animationController.forward(from: 0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    widget.editorController.sendCommand(
      _buildDragCommand(
        details.localPosition.dx,
        details.localPosition.dy,
      ),
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    widget.editorController.sendCommand(
      _buildZoomCommand(details.scale),
    );
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _hover ? SystemMouseCursors.precise : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onPanUpdate: _onPanUpdate,
        onScaleUpdate: _onScaleUpdate,
        child: ClipRect(
          child: CustomPaint(
            painter: _CanvasSnapshotPainter(
              snapshot: widget.renderSnapshot,
              selectionState: widget.selectionState,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CANVAS SNAPSHOT PAINTER
// ---------------------------------------------------------------------------

/// Renders the [RenderSnapshot] to the Flutter canvas.
///
/// RESPONSIBILITIES (fixed):
///   ✔ Paint snapshot layers in z-index order.
///   ✔ Paint selection indicator when a layer is selected.
///
/// FORBIDDEN:
///   ✖ Engine access   ✖ State mutation   ✖ Layout decisions
///   ✖ Gesture logic   ✖ Business logic
///
/// This painter receives data — it does NOT produce or transform it.
class _CanvasSnapshotPainter extends CustomPainter {
  const _CanvasSnapshotPainter({
    required this.snapshot,
    required this.selectionState,
  });

  final RenderSnapshot snapshot;
  final CanvasSelectionState selectionState;

  @override
  void paint(Canvas canvas, Size size) {
    // ------------------------------------------------------------------
    // 1. Render canvas background from snapshot.canvas
    // ------------------------------------------------------------------
    final Color bgColor = _resolveColor(
      snapshot.canvas['backgroundColor'] as String?,
      defaultColor: const Color(0xFF1A1A1A),
    );

    final double canvasWidth =
        (snapshot.canvas['width'] as num? ?? size.width).toDouble();
    final double canvasHeight =
        (snapshot.canvas['height'] as num? ?? size.height).toDouble();

    final Rect canvasRect = Rect.fromLTWH(0, 0, canvasWidth, canvasHeight);

    canvas.drawRect(
      canvasRect,
      Paint()..color = bgColor,
    );

    // Subtle canvas border — visual only, not a layout decision.
    canvas.drawRect(
      canvasRect,
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ------------------------------------------------------------------
    // 2. Render layers in ascending z-index order.
    //    Painter reads layer data but NEVER modifies it.
    // ------------------------------------------------------------------
    final List<Map<String, dynamic>> sorted =
        List<Map<String, dynamic>>.from(snapshot.layers)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final int za = (a['zIndex'] as num? ?? 0).toInt();
            final int zb = (b['zIndex'] as num? ?? 0).toInt();
            return za.compareTo(zb);
          });

    for (final Map<String, dynamic> layer in sorted) {
      final bool visible = layer['visible'] as bool? ?? true;
      if (!visible) continue;
      _paintLayer(canvas, size, layer);
    }

    // ------------------------------------------------------------------
    // 3. Paint selection indicator (display only — no selection logic).
    // ------------------------------------------------------------------
    if (selectionState.selectedLayerId != null) {
      _paintSelectionIndicator(canvas, sorted, selectionState.selectedLayerId!);
    }
  }

  // -------------------------------------------------------------------------
  // LAYER RENDERING — display only, no layer modification
  // -------------------------------------------------------------------------

  void _paintLayer(
    Canvas canvas,
    Size size,
    Map<String, dynamic> layer,
  ) {
    final String type = layer['type'] as String? ?? '';
    final double x = (layer['x'] as num? ?? 0).toDouble();
    final double y = (layer['y'] as num? ?? 0).toDouble();
    final double w = (layer['width'] as num? ?? 100).toDouble();
    final double h = (layer['height'] as num? ?? 100).toDouble();
    final Rect rect = Rect.fromLTWH(x, y, w, h);

    switch (type) {
      case 'background':
        _paintBackground(canvas, rect, layer);
      case 'image':
        _paintImagePlaceholder(canvas, rect, layer);
      case 'text':
        _paintText(canvas, rect, layer);
      case 'icon':
        _paintIconPlaceholder(canvas, rect, layer);
      case 'shape':
        _paintShape(canvas, rect, layer);
      default:
        _paintUnknownLayer(canvas, rect);
    }
  }

  void _paintBackground(Canvas canvas, Rect rect, Map<String, dynamic> layer) {
    final Color color = _resolveColor(
      layer['color'] as String?,
      defaultColor: const Color(0xFF2A2A2A),
    );
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _paintImagePlaceholder(
      Canvas canvas, Rect rect, Map<String, dynamic> layer) {
    // Image layers display a placeholder until the RenderEngine provides
    // the actual image bits. This painter does NOT load images — that
    // is RenderEngine's responsibility.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF2C2C2E),
    );

    final Paint crossPaint = Paint()
      ..color = const Color(0xFF48484A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(rect.topLeft, rect.bottomRight, crossPaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, crossPaint);
    canvas.drawRect(rect, crossPaint);
  }

  void _paintText(Canvas canvas, Rect rect, Map<String, dynamic> layer) {
    final String content = layer['content'] as String? ?? '';
    final double fontSize =
        (layer['fontSize'] as num? ?? 14).toDouble();
    final Color color = _resolveColor(
      layer['color'] as String?,
      defaultColor: const Color(0xFFFFFFFF),
    );

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: layer['fontFamily'] as String? ?? 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: rect.width);

    tp.paint(canvas, rect.topLeft);
  }

  void _paintIconPlaceholder(
      Canvas canvas, Rect rect, Map<String, dynamic> layer) {
    final Color color = _resolveColor(
      layer['color'] as String?,
      defaultColor: const Color(0xFF6C63FF),
    );

    canvas.drawCircle(
      rect.center,
      (rect.shortestSide / 2).clamp(4.0, 32.0),
      Paint()..color = color.withOpacity(0.3),
    );
    canvas.drawCircle(
      rect.center,
      (rect.shortestSide / 2).clamp(4.0, 32.0),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintShape(Canvas canvas, Rect rect, Map<String, dynamic> layer) {
    final Color fill = _resolveColor(
      layer['fillColor'] as String?,
      defaultColor: const Color(0xFF6C63FF),
    );
    final Color stroke = _resolveColor(
      layer['strokeColor'] as String?,
      defaultColor: const Color(0xFF9C8FFF),
    );
    final double strokeWidth =
        (layer['strokeWidth'] as num? ?? 1.0).toDouble();
    final String shape = layer['shape'] as String? ?? 'rect';

    final Paint fillPaint = Paint()..color = fill;
    final Paint strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (shape == 'ellipse') {
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        strokePaint,
      );
    }
  }

  void _paintUnknownLayer(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF3A3A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _paintSelectionIndicator(
    Canvas canvas,
    List<Map<String, dynamic>> layers,
    String selectedLayerId,
  ) {
    final Map<String, dynamic>? selectedLayer = layers
        .where((Map<String, dynamic> l) => l['id'] == selectedLayerId)
        .firstOrNull;

    if (selectedLayer == null) return;

    final double x = (selectedLayer['x'] as num? ?? 0).toDouble();
    final double y = (selectedLayer['y'] as num? ?? 0).toDouble();
    final double w = (selectedLayer['width'] as num? ?? 100).toDouble();
    final double h = (selectedLayer['height'] as num? ?? 100).toDouble();

    const double margin = 3.0;
    final Rect selRect = Rect.fromLTWH(
      x - margin,
      y - margin,
      w + margin * 2,
      h + margin * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(selRect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0xFF6C63FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    const double handleSize = 6.0;
    final Paint handlePaint = Paint()..color = const Color(0xFF6C63FF);

    for (final Offset corner in <Offset>[
      selRect.topLeft,
      selRect.topRight,
      selRect.bottomLeft,
      selRect.bottomRight,
    ]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: corner,
          width: handleSize,
          height: handleSize,
        ),
        handlePaint,
      );
    }
  }

  // -------------------------------------------------------------------------
  // COLOR HELPER — display utility only
  // -------------------------------------------------------------------------

  Color _resolveColor(String? hex, {required Color defaultColor}) {
    if (hex == null || hex.isEmpty) return defaultColor;
    try {
      final String sanitised = hex.replaceAll('#', '');
      final String padded =
          sanitised.length == 6 ? 'FF$sanitised' : sanitised;
      return Color(int.parse(padded, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasSnapshotPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.selectionState != selectionState;
  }
}

// ==========================================================
// END OF FILE — widgets/canvas_widget.dart
// ==========================================================
