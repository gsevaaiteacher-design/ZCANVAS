// ==========================================================
// layers/text_layer.dart
// PHASE-18 — CORE LAYER SYSTEM CONTRACT
// FILE 1 OF 2: TEXT_LAYER
// ==========================================================
//
// PURPOSE: PURE DATA ENTITY FOR TEXT RENDERING.
//
// TYPE LOCK: type = "text"  (immutable, fixed)
//
// MANDATORY STRUCTURE:
//   id, type, text, position, size, transform,
//   style (fontFamily, fontSize, fontWeight, color, textAlign),
//   state (visible, locked, opacity, zIndex)
//
// VALIDATION (HARD FAIL):
//   id empty            → LayerValidationError
//   text null           → LayerValidationError
//   width  <= 0         → LayerValidationError
//   height <= 0         → LayerValidationError
//   opacity < 0 | > 100 → LayerValidationError
//   rotation ∉ 0–360    → LayerValidationError
//   invalid HEX color   → LayerValidationError
//
// EVENTS (MANDATORY — every change):
//   TEXT_LAYER_CREATED
//   TEXT_LAYER_UPDATED
//   TEXT_LAYER_DELETED
//
// LIFECYCLE:
//   LayerEngine   → creates
//   EditorController → only authority to request modification / deletion
//   RenderEngine  → read only
//
// FORBIDDEN:
//   ✖ Rendering logic   ✖ UI logic      ✖ Engine calls
//   ✖ Storage access    ✖ AI interaction
// ==========================================================

// ignore_for_file: constant_identifier_names

/// Validation failure thrown when a [TextLayer] field fails a contract rule.
///
/// Callers (LayerEngine) must catch this and abort layer creation/update.
/// The application must never hold a [TextLayer] in an invalid state.
class LayerValidationError implements Exception {
  const LayerValidationError(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() =>
      'LayerValidationError[$field]: $reason';
}

// ---------------------------------------------------------------------------
// ENUMERATIONS — contract-defined, no additions allowed
// ---------------------------------------------------------------------------

/// Font weight options for a [TextLayer].
/// ENUM(NORMAL | BOLD | LIGHT) — contract-fixed.
enum TextLayerFontWeight { normal, bold, light }

/// Text alignment options for a [TextLayer].
/// ENUM(LEFT | CENTER | RIGHT) — contract-fixed.
enum TextLayerAlign { left, center, right }

// ---------------------------------------------------------------------------
// EVENT TYPES — contract-defined global event system
// ---------------------------------------------------------------------------

/// All event types a [TextLayer] may emit.
/// NO OTHER TYPE IS VALID.
enum TextLayerEventType {
  TEXT_LAYER_CREATED,
  TEXT_LAYER_UPDATED,
  TEXT_LAYER_DELETED,
}

// ---------------------------------------------------------------------------
// LAYER EVENT — mandatory on every change
// ---------------------------------------------------------------------------

/// Event emitted by the layer system on every [TextLayer] state change.
///
/// CONTRACT STRUCTURE:
/// {
///   eventId:   STRING,
///   type:      STRING,
///   layerId:   STRING,
///   timestamp: INTEGER,
///   source:    "LayerEngine"
/// }
///
/// NO EVENT = INVALID STATE UPDATE (contract rule).
class TextLayerEvent {
  TextLayerEvent({
    required this.eventId,
    required this.type,
    required this.layerId,
    required this.timestamp,
    this.payload,
  });

  final String             eventId;
  final TextLayerEventType type;
  final String             layerId;
  final int                timestamp;
  final Map<String, dynamic>? payload;

  /// Source is fixed by contract.
  final String source = 'LayerEngine';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'eventId':   eventId,
        'type':      type.name,
        'layerId':   layerId,
        'timestamp': timestamp,
        'source':    source,
        if (payload != null) 'payload': payload,
      };

  /// Builds a [TextLayerEvent] with a generated eventId and current timestamp.
  factory TextLayerEvent.now({
    required TextLayerEventType type,
    required String layerId,
    Map<String, dynamic>? payload,
  }) {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    return TextLayerEvent(
      eventId:   '${type.name}_${layerId}_$ts',
      type:      type,
      layerId:   layerId,
      timestamp: ts,
      payload:   payload,
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-STRUCTURES — all immutable value objects
// ---------------------------------------------------------------------------

/// { x: NUMBER, y: NUMBER }
class LayerPosition {
  const LayerPosition({required this.x, required this.y});

  final double x;
  final double y;

  LayerPosition copyWith({double? x, double? y}) =>
      LayerPosition(x: x ?? this.x, y: y ?? this.y);

  Map<String, dynamic> toMap() => <String, dynamic>{'x': x, 'y': y};

  factory LayerPosition.fromMap(Map<String, dynamic> m) => LayerPosition(
        x: (m['x'] as num? ?? 0).toDouble(),
        y: (m['y'] as num? ?? 0).toDouble(),
      );
}

/// { width: NUMBER, height: NUMBER }
class LayerSize {
  const LayerSize({required this.width, required this.height});

  final double width;
  final double height;

  LayerSize copyWith({double? width, double? height}) =>
      LayerSize(width: width ?? this.width, height: height ?? this.height);

  Map<String, dynamic> toMap() =>
      <String, dynamic>{'width': width, 'height': height};

  factory LayerSize.fromMap(Map<String, dynamic> m) => LayerSize(
        width:  (m['width']  as num? ?? 100).toDouble(),
        height: (m['height'] as num? ?? 100).toDouble(),
      );
}

/// { rotation: NUMBER (0-360) }
class LayerTransform {
  const LayerTransform({required this.rotation});

  final double rotation;

  LayerTransform copyWith({double? rotation}) =>
      LayerTransform(rotation: rotation ?? this.rotation);

  Map<String, dynamic> toMap() =>
      <String, dynamic>{'rotation': rotation};

  factory LayerTransform.fromMap(Map<String, dynamic> m) =>
      LayerTransform(rotation: (m['rotation'] as num? ?? 0).toDouble());
}

/// Text style sub-structure.
/// {
///   fontFamily: STRING,
///   fontSize:   NUMBER,
///   fontWeight: ENUM(NORMAL|BOLD|LIGHT),
///   color:      HEX_STRING,
///   textAlign:  ENUM(LEFT|CENTER|RIGHT)
/// }
class TextLayerStyle {
  const TextLayerStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
    required this.textAlign,
  });

  final String              fontFamily;
  final double              fontSize;
  final TextLayerFontWeight fontWeight;
  final String              color;      // hex e.g. "#FFFFFF"
  final TextLayerAlign      textAlign;

  TextLayerStyle copyWith({
    String?              fontFamily,
    double?              fontSize,
    TextLayerFontWeight? fontWeight,
    String?              color,
    TextLayerAlign?      textAlign,
  }) =>
      TextLayerStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize:   fontSize   ?? this.fontSize,
        fontWeight: fontWeight ?? this.fontWeight,
        color:      color      ?? this.color,
        textAlign:  textAlign  ?? this.textAlign,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'fontFamily': fontFamily,
        'fontSize':   fontSize,
        'fontWeight': fontWeight.name.toUpperCase(),
        'color':      color,
        'textAlign':  textAlign.name.toUpperCase(),
      };

  factory TextLayerStyle.fromMap(Map<String, dynamic> m) {
    final String fw = (m['fontWeight'] as String? ?? 'NORMAL').toUpperCase();
    final String ta = (m['textAlign']  as String? ?? 'LEFT').toUpperCase();
    return TextLayerStyle(
      fontFamily: m['fontFamily'] as String? ?? 'Inter',
      fontSize:   (m['fontSize']  as num?   ?? 16).toDouble(),
      fontWeight: TextLayerFontWeight.values.firstWhere(
        (e) => e.name.toUpperCase() == fw,
        orElse: () => TextLayerFontWeight.normal,
      ),
      color:     m['color']    as String? ?? '#FFFFFF',
      textAlign: TextLayerAlign.values.firstWhere(
        (e) => e.name.toUpperCase() == ta,
        orElse: () => TextLayerAlign.left,
      ),
    );
  }

  factory TextLayerStyle.defaults() => const TextLayerStyle(
        fontFamily: 'Inter',
        fontSize:   16,
        fontWeight: TextLayerFontWeight.normal,
        color:      '#FFFFFF',
        textAlign:  TextLayerAlign.left,
      );
}

/// Runtime display state.
/// { visible: BOOLEAN, locked: BOOLEAN, opacity: NUMBER(0-100), zIndex: INTEGER }
class LayerState {
  const LayerState({
    required this.visible,
    required this.locked,
    required this.opacity,
    required this.zIndex,
  });

  final bool   visible;
  final bool   locked;
  final double opacity;  // 0–100
  final int    zIndex;

  LayerState copyWith({
    bool?   visible,
    bool?   locked,
    double? opacity,
    int?    zIndex,
  }) =>
      LayerState(
        visible: visible ?? this.visible,
        locked:  locked  ?? this.locked,
        opacity: opacity ?? this.opacity,
        zIndex:  zIndex  ?? this.zIndex,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'visible': visible,
        'locked':  locked,
        'opacity': opacity,
        'zIndex':  zIndex,
      };

  factory LayerState.fromMap(Map<String, dynamic> m) => LayerState(
        visible: m['visible'] as bool?  ?? true,
        locked:  m['locked']  as bool?  ?? false,
        opacity: (m['opacity'] as num?  ?? 100).toDouble(),
        zIndex:  (m['zIndex']  as num?  ?? 0).toInt(),
      );

  factory LayerState.defaults() => const LayerState(
        visible: true,
        locked:  false,
        opacity: 100,
        zIndex:  0,
      );
}

// ---------------------------------------------------------------------------
// TEXT LAYER — immutable pure data entity
// ---------------------------------------------------------------------------

/// Immutable data model for a text layer in Z-CANVAS.
///
/// TYPE LOCK: [type] is always `"text"` — this value is hard-coded
/// and may NEVER be changed by any caller.
///
/// LIFECYCLE (contract-enforced):
///   - Created by:  LayerEngine only (via [TextLayer.create])
///   - Modified by: EditorController only (via [TextLayer.copyWith])
///   - Read by:     RenderEngine (read-only)
///
/// EVENTS: Every factory / copyWith call returns a [TextLayerEvent]
/// via the [lastEvent] field so LayerEngine can propagate it.
///
/// FORBIDDEN:
///   ✖ UI code    ✖ Engine calls    ✖ Storage    ✖ Rendering    ✖ AI
class TextLayer {
  TextLayer._({
    required this.id,
    required this.text,
    required this.position,
    required this.size,
    required this.transform,
    required this.style,
    required this.state,
    required this.lastEvent,
  });

  // ── Fixed type lock ────────────────────────────────────────────────────
  final String type = 'text';

  // ── Mandatory fields ───────────────────────────────────────────────────
  final String         id;
  final String         text;
  final LayerPosition  position;
  final LayerSize      size;
  final LayerTransform transform;
  final TextLayerStyle style;
  final LayerState     state;

  /// The event produced by the most recent create/update/delete operation.
  /// LayerEngine MUST emit this event after every change.
  final TextLayerEvent lastEvent;

  // -------------------------------------------------------------------------
  // FACTORY — creation entry point (LayerEngine only)
  // -------------------------------------------------------------------------

  /// Creates a validated [TextLayer] and attaches a TEXT_LAYER_CREATED event.
  ///
  /// Throws [LayerValidationError] on any contract violation.
  /// LayerEngine is the only caller of this factory.
  factory TextLayer.create({
    required String         id,
    required String         text,
    required LayerPosition  position,
    required LayerSize      size,
    required LayerTransform transform,
    required TextLayerStyle style,
    required LayerState     state,
  }) {
    _validate(
      id:        id,
      text:      text,
      size:      size,
      transform: transform,
      style:     style,
      state:     state,
    );

    final TextLayerEvent event = TextLayerEvent.now(
      type:    TextLayerEventType.TEXT_LAYER_CREATED,
      layerId: id,
      payload: <String, dynamic>{'text': text},
    );

    return TextLayer._(
      id:        id,
      text:      text,
      position:  position,
      size:      size,
      transform: transform,
      style:     style,
      state:     state,
      lastEvent: event,
    );
  }

  // -------------------------------------------------------------------------
  // COPY-WITH — modification entry point (EditorController only)
  // -------------------------------------------------------------------------

  /// Returns a new validated [TextLayer] with updated fields.
  ///
  /// Attaches a TEXT_LAYER_UPDATED event on every call.
  /// Only EditorController may call this method.
  ///
  /// Throws [LayerValidationError] if the resulting layer would be invalid.
  TextLayer copyWith({
    String?         text,
    LayerPosition?  position,
    LayerSize?      size,
    LayerTransform? transform,
    TextLayerStyle? style,
    LayerState?     state,
  }) {
    final String         nextText      = text      ?? this.text;
    final LayerPosition  nextPosition  = position  ?? this.position;
    final LayerSize      nextSize      = size      ?? this.size;
    final LayerTransform nextTransform = transform ?? this.transform;
    final TextLayerStyle nextStyle     = style     ?? this.style;
    final LayerState     nextState     = state     ?? this.state;

    _validate(
      id:        id,
      text:      nextText,
      size:      nextSize,
      transform: nextTransform,
      style:     nextStyle,
      state:     nextState,
    );

    final TextLayerEvent event = TextLayerEvent.now(
      type:    TextLayerEventType.TEXT_LAYER_UPDATED,
      layerId: id,
      payload: toMap()..['text'] = nextText,
    );

    return TextLayer._(
      id:        id,
      text:      nextText,
      position:  nextPosition,
      size:      nextSize,
      transform: nextTransform,
      style:     nextStyle,
      state:     nextState,
      lastEvent: event,
    );
  }

  // -------------------------------------------------------------------------
  // DELETION EVENT — EditorController signals LayerEngine to delete
  // -------------------------------------------------------------------------

  /// Returns the TEXT_LAYER_DELETED event for this layer.
  ///
  /// Does NOT delete data itself — deletion is a LayerEngine operation
  /// authorised by EditorController only.
  /// This method produces the mandatory event that must accompany deletion.
  TextLayerEvent deletionEvent() {
    return TextLayerEvent.now(
      type:    TextLayerEventType.TEXT_LAYER_DELETED,
      layerId: id,
      payload: <String, dynamic>{'deletedId': id},
    );
  }

  // -------------------------------------------------------------------------
  // SERIALIZATION — JSON round-trip
  // -------------------------------------------------------------------------

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id':        id,
        'type':      type,
        'text':      text,
        'position':  position.toMap(),
        'size':      size.toMap(),
        'transform': transform.toMap(),
        'style':     style.toMap(),
        'state':     state.toMap(),
      };

  factory TextLayer.fromMap(Map<String, dynamic> m) {
    return TextLayer.create(
      id:        m['id']   as String? ?? '',
      text:      m['text'] as String? ?? '',
      position:  LayerPosition.fromMap(
          Map<String, dynamic>.from(m['position']  as Map? ?? {})),
      size:      LayerSize.fromMap(
          Map<String, dynamic>.from(m['size']      as Map? ?? {})),
      transform: LayerTransform.fromMap(
          Map<String, dynamic>.from(m['transform'] as Map? ?? {})),
      style:     TextLayerStyle.fromMap(
          Map<String, dynamic>.from(m['style']     as Map? ?? {})),
      state:     LayerState.fromMap(
          Map<String, dynamic>.from(m['state']     as Map? ?? {})),
    );
  }

  // -------------------------------------------------------------------------
  // VALIDATION — contract-defined hard-fail rules
  // -------------------------------------------------------------------------

  /// Validates all contract fields.
  ///
  /// REJECT IF:
  ///   id empty                 → [LayerValidationError]
  ///   text null / empty        → [LayerValidationError]
  ///   width  <= 0              → [LayerValidationError]
  ///   height <= 0              → [LayerValidationError]
  ///   opacity < 0 | > 100      → [LayerValidationError]
  ///   rotation ∉ 0–360         → [LayerValidationError]
  ///   invalid HEX color        → [LayerValidationError]
  static void _validate({
    required String         id,
    required String         text,
    required LayerSize      size,
    required LayerTransform transform,
    required TextLayerStyle style,
    required LayerState     state,
  }) {
    // id must not be empty
    if (id.trim().isEmpty) {
      throw const LayerValidationError('id', 'id must not be empty');
    }

    // text must not be null (already non-nullable in Dart, but must not be empty string if that's required — contract says "text null" reject only, so we check null-equivalent)
    // CONTRACT: "text null" → reject. Empty string is allowed.
    // Dart guarantees non-null, so this is already satisfied by the type system.

    // width > 0
    if (size.width <= 0) {
      throw LayerValidationError(
          'size.width', 'width must be > 0, got ${size.width}');
    }

    // height > 0
    if (size.height <= 0) {
      throw LayerValidationError(
          'size.height', 'height must be > 0, got ${size.height}');
    }

    // opacity 0–100
    if (state.opacity < 0 || state.opacity > 100) {
      throw LayerValidationError(
          'state.opacity',
          'opacity must be 0–100, got ${state.opacity}');
    }

    // rotation 0–360
    if (transform.rotation < 0 || transform.rotation > 360) {
      throw LayerValidationError(
          'transform.rotation',
          'rotation must be 0–360, got ${transform.rotation}');
    }

    // valid HEX color
    if (!_isValidHex(style.color)) {
      throw LayerValidationError(
          'style.color',
          'invalid HEX color: ${style.color}');
    }
  }

  /// Returns true if [hex] is a valid CSS hex colour string.
  ///
  /// Accepts: #RGB, #RRGGBB, #RRGGBBAA (with or without leading #).
  static bool _isValidHex(String hex) {
    final String cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
    if (cleaned.isEmpty) return false;
    final RegExp hexPattern = RegExp(r'^[0-9A-Fa-f]{3}$|^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$');
    return hexPattern.hasMatch(cleaned);
  }

  // -------------------------------------------------------------------------
  // DEFAULT FACTORY — convenience for LayerEngine
  // -------------------------------------------------------------------------

  /// Creates a [TextLayer] with safe defaults at a given position.
  ///
  /// LayerEngine uses this when no explicit style is provided.
  factory TextLayer.defaults({
    required String id,
    String text = 'Text',
    double x = 0,
    double y = 0,
    int zIndex = 0,
  }) {
    return TextLayer.create(
      id:        id,
      text:      text,
      position:  LayerPosition(x: x, y: y),
      size:      const LayerSize(width: 200, height: 60),
      transform: const LayerTransform(rotation: 0),
      style:     TextLayerStyle.defaults(),
      state:     LayerState(
        visible: true,
        locked:  false,
        opacity: 100,
        zIndex:  zIndex,
      ),
    );
  }

  @override
  String toString() =>
      'TextLayer(id: $id, text: "$text", zIndex: ${state.zIndex})';
}

// ==========================================================
// END OF FILE — layers/text_layer.dart
// ==========================================================
