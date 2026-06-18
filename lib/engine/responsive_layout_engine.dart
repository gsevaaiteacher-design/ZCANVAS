// ==========================================================
// engines/responsive_layout_engine.dart
// PHASE-20 — RESPONSIVE LAYOUT ENGINE CONTRACT
// ==========================================================
//
// SYSTEM ROLE: PURE MATHEMATICAL TRANSFORMATION ENGINE ONLY.
//
// PURPOSE:
//   Convert fixed canvas layout into device-adapted layout.
//
// SYSTEM POSITION:
//   EditorController
//       ↓
//   engines/responsive_layout_engine.dart
//       ↓
//   RenderEngine
//       ↓
//   Canvas
//
// CALLING RULE: ONLY RenderEngine may call this engine.
//
// CORE RESPONSIBILITIES (ONE JOB):
//   ✔ Detect device breakpoint
//   ✔ Calculate scaleFactor  → MIN(sw/cw, sh/ch)
//   ✔ Calculate offsetX/Y   → centered fit
//   ✔ Transform all layers  → new copies, never mutate
//   ✔ Produce responsive snapshot
//
// FORBIDDEN:
//   ✘ Modify layers permanently   ✘ Access storage engine
//   ✘ Call AI engine              ✘ Call template engine
//   ✘ Modify EditorController     ✘ Render canvas
//   ✘ Store any data
//
// IMMUTABILITY RULE:
//   Input is READ-ONLY. Output is NEW OBJECT COPY.
//   NO mutation of original data.
// ==========================================================

// ---------------------------------------------------------------------------
// BREAKPOINTS — fixed, no custom values allowed
// ---------------------------------------------------------------------------

/// Device breakpoint classification.
///
/// CONTRACT-FIXED thresholds:
///   width < 600            → mobile
///   600 <= width <= 1024   → tablet
///   width > 1024           → desktop
enum DeviceBreakpoint { mobile, tablet, desktop }

// ---------------------------------------------------------------------------
// INPUT TYPES — read-only data carriers
// ---------------------------------------------------------------------------

/// Canvas dimensions provided in the design snapshot.
///
/// Fields are final — this object is never modified by the engine.
class DesignCanvas {
  const DesignCanvas({
    required this.width,
    required this.height,
    required this.ratio,
  });

  final double width;
  final double height;
  final String ratio;   // e.g. "16:9"

  factory DesignCanvas.fromMap(Map<String, dynamic> m) => DesignCanvas(
        width:  (m['width']  as num? ?? 0).toDouble(),
        height: (m['height'] as num? ?? 0).toDouble(),
        ratio:  m['ratio']   as String? ?? '',
      );
}

/// Device screen information provided in the design snapshot.
///
/// Fields are final — never modified by the engine.
class DeviceInfo {
  const DeviceInfo({
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.orientation,
  });

  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;
  final String orientation;  // "portrait" | "landscape"

  factory DeviceInfo.fromMap(Map<String, dynamic> m) => DeviceInfo(
        screenWidth:  (m['screenWidth']  as num? ?? 0).toDouble(),
        screenHeight: (m['screenHeight'] as num? ?? 0).toDouble(),
        pixelRatio:   (m['pixelRatio']   as num? ?? 1).toDouble(),
        orientation:  m['orientation']   as String? ?? 'portrait',
      );
}

/// A single layer model as received in the design snapshot.
///
/// The engine reads these fields and produces new [TransformedLayer] copies.
/// Original data is NEVER mutated.
class DesignLayer {
  const DesignLayer({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.opacity,
    required this.zIndex,
    this.extra = const <String, dynamic>{},
  });

  final String              id;
  final String              type;
  final double              x;
  final double              y;
  final double              width;
  final double              height;
  final double              rotation;  // UNCHANGED by transform
  final double              opacity;   // UNCHANGED by transform
  final int                 zIndex;    // UNCHANGED by transform
  final Map<String, dynamic> extra;    // pass-through (text, imagePath, style…)

  factory DesignLayer.fromMap(Map<String, dynamic> m) {
    // Pull the known numeric fields; everything else goes to extra.
    final Set<String> known = {'id','type','x','y','width','height','rotation','opacity','zIndex'};
    final Map<String, dynamic> rest = Map<String, dynamic>.fromEntries(
      m.entries.where((e) => !known.contains(e.key)),
    );
    return DesignLayer(
      id:       m['id']       as String? ?? '',
      type:     m['type']     as String? ?? '',
      x:        (m['x']       as num? ?? 0).toDouble(),
      y:        (m['y']       as num? ?? 0).toDouble(),
      width:    (m['width']   as num? ?? 0).toDouble(),
      height:   (m['height']  as num? ?? 0).toDouble(),
      rotation: (m['rotation'] as num? ?? 0).toDouble(),
      opacity:  (m['opacity'] as num? ?? 100).toDouble(),
      zIndex:   (m['zIndex']  as num? ?? 0).toInt(),
      extra:    Map<String, dynamic>.unmodifiable(rest),
    );
  }
}

/// Full design snapshot passed into [ResponsiveLayoutEngine.transform].
///
/// Read-only input contract:
/// {
///   canvas: { width, height, ratio },
///   device: { screenWidth, screenHeight, pixelRatio, orientation },
///   layers: ARRAY<LAYER_MODEL>
/// }
class DesignSnapshot {
  const DesignSnapshot({
    required this.canvas,
    required this.device,
    required this.layers,
  });

  final DesignCanvas       canvas;
  final DeviceInfo         device;
  final List<DesignLayer>  layers;

  factory DesignSnapshot.fromMap(Map<String, dynamic> m) {
    final List<dynamic> rawLayers = m['layers'] as List<dynamic>? ?? [];
    return DesignSnapshot(
      canvas: DesignCanvas.fromMap(
          Map<String, dynamic>.from(m['canvas'] as Map? ?? {})),
      device: DeviceInfo.fromMap(
          Map<String, dynamic>.from(m['device'] as Map? ?? {})),
      layers: rawLayers
          .map((e) => DesignLayer.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// OUTPUT TYPES — new object copies, never references to input objects
// ---------------------------------------------------------------------------

/// A layer after responsive transformation has been applied.
///
/// CONTRACT TRANSFORMATION RULE:
///   newX      = originalX * scaleFactor + offsetX
///   newY      = originalY * scaleFactor + offsetY
///   newWidth  = originalWidth  * scaleFactor
///   newHeight = originalHeight * scaleFactor
///   rotation  = UNCHANGED
///   opacity   = UNCHANGED
///   zIndex    = UNCHANGED
class TransformedLayer {
  const TransformedLayer({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.opacity,
    required this.zIndex,
    required this.extra,
  });

  final String               id;
  final String               type;
  final double               x;        // newX  = originalX * scale + offsetX
  final double               y;        // newY  = originalY * scale + offsetY
  final double               width;    // newW  = originalW * scale
  final double               height;   // newH  = originalH * scale
  final double               rotation; // UNCHANGED
  final double               opacity;  // UNCHANGED
  final int                  zIndex;   // UNCHANGED
  final Map<String, dynamic> extra;    // pass-through from DesignLayer

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id':       id,
        'type':     type,
        'x':        x,
        'y':        y,
        'width':    width,
        'height':   height,
        'rotation': rotation,
        'opacity':  opacity,
        'zIndex':   zIndex,
        ...extra,
      };
}

/// Scaled canvas dimensions in the responsive snapshot.
class ScaledCanvas {
  const ScaledCanvas({
    required this.width,
    required this.height,
    required this.ratio,
  });

  final double width;
  final double height;
  final String ratio;

  Map<String, dynamic> toMap() =>
      <String, dynamic>{'width': width, 'height': height, 'ratio': ratio};
}

/// Successful responsive snapshot output.
///
/// CONTRACT OUTPUT:
/// {
///   scaledCanvas:       OBJECT,
///   transformedLayers:  ARRAY<LAYER_MODEL>,
///   scaleFactor:        NUMBER,
///   offsetX:            NUMBER,
///   offsetY:            NUMBER
/// }
class ResponsiveSnapshot {
  const ResponsiveSnapshot({
    required this.scaledCanvas,
    required this.transformedLayers,
    required this.scaleFactor,
    required this.offsetX,
    required this.offsetY,
    required this.breakpoint,
  });

  final ScaledCanvas          scaledCanvas;
  final List<TransformedLayer> transformedLayers;
  final double                scaleFactor;
  final double                offsetX;
  final double                offsetY;
  final DeviceBreakpoint      breakpoint;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'scaledCanvas':      scaledCanvas.toMap(),
        'transformedLayers': transformedLayers.map((l) => l.toMap()).toList(),
        'scaleFactor':       scaleFactor,
        'offsetX':           offsetX,
        'offsetY':           offsetY,
        'breakpoint':        breakpoint.name,
      };
}

/// Error result returned when input validation fails.
///
/// CONTRACT ERROR OUTPUT:
/// { status: "ERROR", reason: STRING, fallback: "NO_TRANSFORM" }
///
/// NO SILENT FAILURE — every invalid input produces this object.
class ResponsiveLayoutError {
  const ResponsiveLayoutError(this.reason);

  final String status   = 'ERROR';
  final String reason;
  final String fallback = 'NO_TRANSFORM';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'status':   status,
        'reason':   reason,
        'fallback': fallback,
      };

  @override
  String toString() => 'ResponsiveLayoutError[$reason]';
}

/// Union result type — either a [ResponsiveSnapshot] or a [ResponsiveLayoutError].
///
/// Callers (RenderEngine only) must check [isError] before using [snapshot].
class LayoutResult {
  const LayoutResult._snapshot(this._snapshot) : _error = null;
  const LayoutResult._error(this._error)       : _snapshot = null;

  final ResponsiveSnapshot?   _snapshot;
  final ResponsiveLayoutError? _error;

  bool get isError    => _error    != null;
  bool get isSuccess  => _snapshot != null;

  ResponsiveSnapshot   get snapshot => _snapshot!;
  ResponsiveLayoutError get error   => _error!;

  Map<String, dynamic> toMap() =>
      isError ? _error!.toMap() : _snapshot!.toMap();
}

// ---------------------------------------------------------------------------
// RESPONSIVE LAYOUT ENGINE
// ---------------------------------------------------------------------------

/// Pure mathematical transform engine for Z-CANVAS responsive layout.
///
/// ─── CALLING RULE ────────────────────────────────────────────────────────
/// ONLY [RenderEngine] is permitted to call [transform].
/// No other file may call this engine directly.
///
/// ─── IMMUTABILITY RULE ───────────────────────────────────────────────────
/// Input [DesignSnapshot] is READ-ONLY.
/// Output [LayoutResult] is a NEW OBJECT — no input data is mutated.
///
/// ─── ZERO SIDE EFFECTS ───────────────────────────────────────────────────
/// This engine holds NO state, performs NO I/O, and has NO dependencies
/// outside pure Dart mathematics.
///
/// ─── FORBIDDEN ───────────────────────────────────────────────────────────
///   ✘ Storage     ✘ AI engine       ✘ Template engine
///   ✘ Rendering   ✘ EditorController ✘ Data persistence
abstract final class ResponsiveLayoutEngine {
  ResponsiveLayoutEngine._(); // non-instantiable — static API only

  // -------------------------------------------------------------------------
  // PUBLIC API — called by RenderEngine only
  // -------------------------------------------------------------------------

  /// Transforms [snapshot] into a fully responsive [LayoutResult].
  ///
  /// Returns [LayoutResult] wrapping either:
  ///   • [ResponsiveSnapshot] on success
  ///   • [ResponsiveLayoutError] on validation failure
  ///
  /// This method is pure and deterministic:
  ///   same input → always same output.
  static LayoutResult transform(DesignSnapshot snapshot) {
    // ── Validate input ──────────────────────────────────────────────────
    final ResponsiveLayoutError? validationError =
        _validateInput(snapshot);
    if (validationError != null) {
      return LayoutResult._error(validationError);
    }

    final DesignCanvas canvas = snapshot.canvas;
    final DeviceInfo   device = snapshot.device;

    // ── Step 1: Detect breakpoint ───────────────────────────────────────
    final DeviceBreakpoint breakpoint =
        _classifyBreakpoint(device.screenWidth);

    // ── Step 2: Calculate scaleFactor ───────────────────────────────────
    //
    // CONTRACT FORMULA (FINAL — NO MODIFICATION ALLOWED):
    //   scaleFactor = MIN(screenWidth / canvasWidth, screenHeight / canvasHeight)
    final double scaleFactor = _calculateScaleFactor(
      screenWidth:  device.screenWidth,
      screenHeight: device.screenHeight,
      canvasWidth:  canvas.width,
      canvasHeight: canvas.height,
    );

    // ── Step 3: Calculate offsets ───────────────────────────────────────
    //
    // CONTRACT FORMULA (CENTER FIT ONLY — NO OTHER LOGIC ALLOWED):
    //   offsetX = (screenWidth  - (canvasWidth  * scaleFactor)) / 2
    //   offsetY = (screenHeight - (canvasHeight * scaleFactor)) / 2
    final double offsetX = _calculateOffsetX(
      screenWidth:  device.screenWidth,
      canvasWidth:  canvas.width,
      scaleFactor:  scaleFactor,
    );
    final double offsetY = _calculateOffsetY(
      screenHeight: device.screenHeight,
      canvasHeight: canvas.height,
      scaleFactor:  scaleFactor,
    );

    // ── Step 4: Scale canvas ────────────────────────────────────────────
    final ScaledCanvas scaledCanvas = ScaledCanvas(
      width:  canvas.width  * scaleFactor,
      height: canvas.height * scaleFactor,
      ratio:  canvas.ratio,
    );

    // ── Step 5: Transform all layers ────────────────────────────────────
    //
    // CONTRACT TRANSFORMATION RULE (per layer):
    //   newX      = originalX * scaleFactor + offsetX
    //   newY      = originalY * scaleFactor + offsetY
    //   newWidth  = originalWidth  * scaleFactor
    //   newHeight = originalHeight * scaleFactor
    //   rotation, opacity, zIndex = UNCHANGED
    final List<TransformedLayer> transformedLayers = snapshot.layers
        .map((layer) => _transformLayer(layer, scaleFactor, offsetX, offsetY))
        .toList(growable: false);

    return LayoutResult._snapshot(
      ResponsiveSnapshot(
        scaledCanvas:      scaledCanvas,
        transformedLayers: transformedLayers,
        scaleFactor:       scaleFactor,
        offsetX:           offsetX,
        offsetY:           offsetY,
        breakpoint:        breakpoint,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BREAKPOINT CLASSIFICATION — fixed thresholds only
  // -------------------------------------------------------------------------

  /// Classifies [screenWidth] into a [DeviceBreakpoint].
  ///
  /// CONTRACT RULE (FIXED — NO CUSTOM BREAKPOINTS ALLOWED):
  ///   < 600        → mobile
  ///   600 – 1024   → tablet
  ///   > 1024       → desktop
  static DeviceBreakpoint _classifyBreakpoint(double screenWidth) {
    if (screenWidth < 600)   return DeviceBreakpoint.mobile;
    if (screenWidth <= 1024) return DeviceBreakpoint.tablet;
    return DeviceBreakpoint.desktop;
  }

  // -------------------------------------------------------------------------
  // SCALE FACTOR — contract formula, final, no modification allowed
  // -------------------------------------------------------------------------

  /// scaleFactor = MIN(screenWidth / canvasWidth, screenHeight / canvasHeight)
  static double _calculateScaleFactor({
    required double screenWidth,
    required double screenHeight,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final double scaleX = screenWidth  / canvasWidth;
    final double scaleY = screenHeight / canvasHeight;
    return scaleX < scaleY ? scaleX : scaleY;   // MIN(scaleX, scaleY)
  }

  // -------------------------------------------------------------------------
  // OFFSET CALCULATION — center-fit only, no other logic allowed
  // -------------------------------------------------------------------------

  /// offsetX = (screenWidth - (canvasWidth * scaleFactor)) / 2
  static double _calculateOffsetX({
    required double screenWidth,
    required double canvasWidth,
    required double scaleFactor,
  }) =>
      (screenWidth - (canvasWidth * scaleFactor)) / 2.0;

  /// offsetY = (screenHeight - (canvasHeight * scaleFactor)) / 2
  static double _calculateOffsetY({
    required double screenHeight,
    required double canvasHeight,
    required double scaleFactor,
  }) =>
      (screenHeight - (canvasHeight * scaleFactor)) / 2.0;

  // -------------------------------------------------------------------------
  // LAYER TRANSFORMATION — new object, original NEVER mutated
  // -------------------------------------------------------------------------

  /// Produces a new [TransformedLayer] from [layer] using the contract formula.
  ///
  /// Original [layer] is READ-ONLY — no field is modified.
  static TransformedLayer _transformLayer(
    DesignLayer layer,
    double      scaleFactor,
    double      offsetX,
    double      offsetY,
  ) {
    return TransformedLayer(
      id:       layer.id,
      type:     layer.type,
      x:        layer.x      * scaleFactor + offsetX,   // newX
      y:        layer.y      * scaleFactor + offsetY,   // newY
      width:    layer.width  * scaleFactor,              // newWidth
      height:   layer.height * scaleFactor,              // newHeight
      rotation: layer.rotation,   // UNCHANGED
      opacity:  layer.opacity,    // UNCHANGED
      zIndex:   layer.zIndex,     // UNCHANGED
      extra:    Map<String, dynamic>.unmodifiable(layer.extra),
    );
  }

  // -------------------------------------------------------------------------
  // INPUT VALIDATION — hard block, no silent failure
  // -------------------------------------------------------------------------

  /// Validates [snapshot] against the contract's hard-block rules.
  ///
  /// Returns null on success; returns [ResponsiveLayoutError] on failure.
  ///
  /// CONTRACT REJECTION RULES:
  ///   canvas.width  == 0      → error
  ///   canvas.height == 0      → error
  ///   device.screenWidth  <= 0 → error
  ///   device.screenHeight <= 0 → error
  ///   any layer with invalid structure → error
  ///   missing device info     → error
  static ResponsiveLayoutError? _validateInput(DesignSnapshot snapshot) {
    final DesignCanvas canvas = snapshot.canvas;
    final DeviceInfo   device = snapshot.device;

    if (canvas.width == 0) {
      return const ResponsiveLayoutError('canvas.width must not be 0');
    }
    if (canvas.height == 0) {
      return const ResponsiveLayoutError('canvas.height must not be 0');
    }
    if (device.screenWidth <= 0) {
      return const ResponsiveLayoutError('device.screenWidth must be > 0');
    }
    if (device.screenHeight <= 0) {
      return const ResponsiveLayoutError('device.screenHeight must be > 0');
    }

    // Validate each layer — reject if id or type is missing
    for (int i = 0; i < snapshot.layers.length; i++) {
      final DesignLayer layer = snapshot.layers[i];
      if (layer.id.trim().isEmpty) {
        return ResponsiveLayoutError(
            'layers[$i].id must not be empty');
      }
      if (layer.type.trim().isEmpty) {
        return ResponsiveLayoutError(
            'layers[$i].type must not be empty');
      }
      if (layer.width <= 0) {
        return ResponsiveLayoutError(
            'layers[$i].width must be > 0');
      }
      if (layer.height <= 0) {
        return ResponsiveLayoutError(
            'layers[$i].height must be > 0');
      }
    }

    return null; // valid
  }

  // -------------------------------------------------------------------------
  // CONVENIENCE — public helper for RenderEngine
  // -------------------------------------------------------------------------

  /// Transforms a raw [Map] snapshot directly.
  ///
  /// Convenience wrapper around [transform] for callers that work with raw maps.
  /// Only [RenderEngine] is permitted to call this.
  static LayoutResult transformFromMap(Map<String, dynamic> raw) {
    try {
      final DesignSnapshot snapshot = DesignSnapshot.fromMap(raw);
      return transform(snapshot);
    } catch (e) {
      return LayoutResult._error(
        ResponsiveLayoutError('Failed to parse design snapshot: $e'),
      );
    }
  }

  /// Returns the [DeviceBreakpoint] for a given [screenWidth] without a full transform.
  ///
  /// Utility for RenderEngine to branch on breakpoint before calling [transform].
  static DeviceBreakpoint breakpointFor(double screenWidth) =>
      _classifyBreakpoint(screenWidth);
}

// ==========================================================
// END OF FILE — engines/responsive_layout_engine.dart
// ==========================================================
