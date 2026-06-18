// ==========================================================
// layers/image_layer.dart
// PHASE-18 — CORE LAYER SYSTEM CONTRACT
// FILE 2 OF 2: IMAGE_LAYER
// ==========================================================
//
// PURPOSE: IMAGE_LAYER STORES ONLY IMAGE SOURCE DATA.
//          NO PROCESSING. NO FILTERING. NO RENDERING.
//
// TYPE LOCK: type = "image"  (immutable, fixed)
//
// MANDATORY STRUCTURE:
//   id, type, imagePath, position, size, transform,
//   crop (x, y, width, height),
//   fitMode (FILL | FIT | COVER),
//   state (visible, locked, opacity, zIndex)
//
// VALIDATION (HARD FAIL):
//   id empty              → LayerValidationError
//   imagePath empty       → LayerValidationError
//   width  <= 0           → LayerValidationError
//   height <= 0           → LayerValidationError
//   opacity invalid       → LayerValidationError
//   rotation invalid      → LayerValidationError
//   crop invalid values   → LayerValidationError
//
// EVENTS (MANDATORY — every change):
//   IMAGE_LAYER_CREATED
//   IMAGE_LAYER_UPDATED
//   IMAGE_LAYER_DELETED
//
// LIFECYCLE:
//   LayerEngine     → creates  (ImageLayer.create)
//   EditorController → modifies (copyWith only)
//   RenderEngine    → read only (toMap / fields)
//
// FORBIDDEN:
//   ✖ Image processing   ✖ Rendering      ✖ File system access
//   ✖ Network access     ✖ UI logic       ✖ AI logic
//   ✖ Engine calls
// ==========================================================

// ignore_for_file: constant_identifier_names

import 'text_layer.dart'
    show LayerValidationError, LayerPosition, LayerSize, LayerTransform, LayerState;

// ---------------------------------------------------------------------------
// ENUMERATIONS — contract-defined, no additions allowed
// ---------------------------------------------------------------------------

/// Image fit mode.
/// ENUM(FILL | FIT | COVER) — contract-fixed.
enum ImageFitMode { fill, fit, cover }

// ---------------------------------------------------------------------------
// EVENT TYPES — contract-defined global event system
// ---------------------------------------------------------------------------

/// All event types an [ImageLayer] may emit.
/// NO OTHER TYPE IS VALID.
enum ImageLayerEventType {
  IMAGE_LAYER_CREATED,
  IMAGE_LAYER_UPDATED,
  IMAGE_LAYER_DELETED,
}

// ---------------------------------------------------------------------------
// IMAGE LAYER EVENT — mandatory on every change
// ---------------------------------------------------------------------------

/// Event emitted on every [ImageLayer] state change.
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
class ImageLayerEvent {
  ImageLayerEvent({
    required this.eventId,
    required this.type,
    required this.layerId,
    required this.timestamp,
    this.payload,
  });

  final String              eventId;
  final ImageLayerEventType type;
  final String              layerId;
  final int                 timestamp;
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

  /// Builds an [ImageLayerEvent] with a generated eventId and current timestamp.
  factory ImageLayerEvent.now({
    required ImageLayerEventType  type,
    required String               layerId,
    Map<String, dynamic>?         payload,
  }) {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    return ImageLayerEvent(
      eventId:   '${type.name}_${layerId}_$ts',
      type:      type,
      layerId:   layerId,
      timestamp: ts,
      payload:   payload,
    );
  }
}

// ---------------------------------------------------------------------------
// CROP REGION — immutable value object
// ---------------------------------------------------------------------------

/// Crop rectangle applied to an [ImageLayer].
///
/// CONTRACT STRUCTURE: { x: NUMBER, y: NUMBER, width: NUMBER, height: NUMBER }
///
/// All values must be >= 0; width and height must be > 0.
class ImageCrop {
  const ImageCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  ImageCrop copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      ImageCrop(
        x:      x      ?? this.x,
        y:      y      ?? this.y,
        width:  width  ?? this.width,
        height: height ?? this.height,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'x':      x,
        'y':      y,
        'width':  width,
        'height': height,
      };

  factory ImageCrop.fromMap(Map<String, dynamic> m) => ImageCrop(
        x:      (m['x']      as num? ?? 0).toDouble(),
        y:      (m['y']      as num? ?? 0).toDouble(),
        width:  (m['width']  as num? ?? 0).toDouble(),
        height: (m['height'] as num? ?? 0).toDouble(),
      );

  /// Full-image crop (no cropping applied).
  factory ImageCrop.none({
    required double imageWidth,
    required double imageHeight,
  }) =>
      ImageCrop(x: 0, y: 0, width: imageWidth, height: imageHeight);

  @override
  String toString() =>
      'ImageCrop(x:$x, y:$y, width:$width, height:$height)';
}

// ---------------------------------------------------------------------------
// IMAGE LAYER — immutable pure data entity
// ---------------------------------------------------------------------------

/// Immutable data model for an image layer in Z-CANVAS.
///
/// TYPE LOCK: [type] is always `"image"` — this value is hard-coded
/// and may NEVER be changed by any caller.
///
/// LIFECYCLE (contract-enforced):
///   - Created by:  LayerEngine only (via [ImageLayer.create])
///   - Modified by: EditorController only (via [ImageLayer.copyWith])
///   - Read by:     RenderEngine (read-only, via [toMap] / fields)
///
/// EVENTS: Every factory / copyWith call returns an [ImageLayerEvent]
/// via the [lastEvent] field so LayerEngine can propagate it immediately.
///
/// FORBIDDEN:
///   ✖ Image processing   ✖ Rendering      ✖ File system
///   ✖ Network access     ✖ UI logic       ✖ AI logic
class ImageLayer {
  ImageLayer._({
    required this.id,
    required this.imagePath,
    required this.position,
    required this.size,
    required this.transform,
    required this.crop,
    required this.fitMode,
    required this.state,
    required this.lastEvent,
  });

  // ── Fixed type lock ────────────────────────────────────────────────────
  final String type = 'image';

  // ── Mandatory fields ───────────────────────────────────────────────────
  final String         id;
  final String         imagePath;   // path/URI — stored only, never processed
  final LayerPosition  position;
  final LayerSize      size;
  final LayerTransform transform;
  final ImageCrop      crop;
  final ImageFitMode   fitMode;
  final LayerState     state;

  /// The event produced by the most recent create/update/delete operation.
  /// LayerEngine MUST emit this event after every change.
  final ImageLayerEvent lastEvent;

  // -------------------------------------------------------------------------
  // FACTORY — creation entry point (LayerEngine only)
  // -------------------------------------------------------------------------

  /// Creates a validated [ImageLayer] and attaches an IMAGE_LAYER_CREATED event.
  ///
  /// Throws [LayerValidationError] on any contract violation.
  /// LayerEngine is the only caller of this factory.
  factory ImageLayer.create({
    required String         id,
    required String         imagePath,
    required LayerPosition  position,
    required LayerSize      size,
    required LayerTransform transform,
    required ImageCrop      crop,
    required ImageFitMode   fitMode,
    required LayerState     state,
  }) {
    _validate(
      id:        id,
      imagePath: imagePath,
      size:      size,
      transform: transform,
      crop:      crop,
      state:     state,
    );

    final ImageLayerEvent event = ImageLayerEvent.now(
      type:    ImageLayerEventType.IMAGE_LAYER_CREATED,
      layerId: id,
      payload: <String, dynamic>{'imagePath': imagePath},
    );

    return ImageLayer._(
      id:        id,
      imagePath: imagePath,
      position:  position,
      size:      size,
      transform: transform,
      crop:      crop,
      fitMode:   fitMode,
      state:     state,
      lastEvent: event,
    );
  }

  // -------------------------------------------------------------------------
  // COPY-WITH — modification entry point (EditorController only)
  // -------------------------------------------------------------------------

  /// Returns a new validated [ImageLayer] with updated fields.
  ///
  /// Attaches an IMAGE_LAYER_UPDATED event on every call.
  /// Only EditorController may call this method.
  ///
  /// Throws [LayerValidationError] if the resulting layer would be invalid.
  ImageLayer copyWith({
    String?         imagePath,
    LayerPosition?  position,
    LayerSize?      size,
    LayerTransform? transform,
    ImageCrop?      crop,
    ImageFitMode?   fitMode,
    LayerState?     state,
  }) {
    final String         nextPath      = imagePath ?? this.imagePath;
    final LayerPosition  nextPosition  = position  ?? this.position;
    final LayerSize      nextSize      = size      ?? this.size;
    final LayerTransform nextTransform = transform ?? this.transform;
    final ImageCrop      nextCrop      = crop      ?? this.crop;
    final ImageFitMode   nextFitMode   = fitMode   ?? this.fitMode;
    final LayerState     nextState     = state     ?? this.state;

    _validate(
      id:        id,
      imagePath: nextPath,
      size:      nextSize,
      transform: nextTransform,
      crop:      nextCrop,
      state:     nextState,
    );

    final ImageLayerEvent event = ImageLayerEvent.now(
      type:    ImageLayerEventType.IMAGE_LAYER_UPDATED,
      layerId: id,
      payload: toMap(),
    );

    return ImageLayer._(
      id:        id,
      imagePath: nextPath,
      position:  nextPosition,
      size:      nextSize,
      transform: nextTransform,
      crop:      nextCrop,
      fitMode:   nextFitMode,
      state:     nextState,
      lastEvent: event,
    );
  }

  // -------------------------------------------------------------------------
  // DELETION EVENT — EditorController signals LayerEngine to delete
  // -------------------------------------------------------------------------

  /// Returns the IMAGE_LAYER_DELETED event for this layer.
  ///
  /// Does NOT delete data itself — deletion is a LayerEngine operation
  /// authorised by EditorController only.
  ImageLayerEvent deletionEvent() {
    return ImageLayerEvent.now(
      type:    ImageLayerEventType.IMAGE_LAYER_DELETED,
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
        'imagePath': imagePath,
        'position':  position.toMap(),
        'size':      size.toMap(),
        'transform': transform.toMap(),
        'crop':      crop.toMap(),
        'fitMode':   fitMode.name.toUpperCase(),
        'state':     state.toMap(),
      };

  factory ImageLayer.fromMap(Map<String, dynamic> m) {
    final String fm = (m['fitMode'] as String? ?? 'FILL').toUpperCase();
    return ImageLayer.create(
      id:        m['id']        as String? ?? '',
      imagePath: m['imagePath'] as String? ?? '',
      position:  LayerPosition.fromMap(
          Map<String, dynamic>.from(m['position']  as Map? ?? {})),
      size:      LayerSize.fromMap(
          Map<String, dynamic>.from(m['size']      as Map? ?? {})),
      transform: LayerTransform.fromMap(
          Map<String, dynamic>.from(m['transform'] as Map? ?? {})),
      crop:      ImageCrop.fromMap(
          Map<String, dynamic>.from(m['crop']      as Map? ?? {})),
      fitMode:   ImageFitMode.values.firstWhere(
        (e) => e.name.toUpperCase() == fm,
        orElse:  () => ImageFitMode.fill,
      ),
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
  ///   id empty              → [LayerValidationError]
  ///   imagePath empty       → [LayerValidationError]
  ///   width  <= 0           → [LayerValidationError]
  ///   height <= 0           → [LayerValidationError]
  ///   opacity < 0 | > 100   → [LayerValidationError]
  ///   rotation ∉ 0–360      → [LayerValidationError]
  ///   crop invalid values   → [LayerValidationError]
  static void _validate({
    required String         id,
    required String         imagePath,
    required LayerSize      size,
    required LayerTransform transform,
    required ImageCrop      crop,
    required LayerState     state,
  }) {
    // id must not be empty
    if (id.trim().isEmpty) {
      throw const LayerValidationError('id', 'id must not be empty');
    }

    // imagePath must not be empty
    if (imagePath.trim().isEmpty) {
      throw const LayerValidationError(
          'imagePath', 'imagePath must not be empty');
    }

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

    // crop: x and y must be >= 0
    if (crop.x < 0) {
      throw LayerValidationError(
          'crop.x', 'crop.x must be >= 0, got ${crop.x}');
    }
    if (crop.y < 0) {
      throw LayerValidationError(
          'crop.y', 'crop.y must be >= 0, got ${crop.y}');
    }

    // crop: width and height must be > 0
    if (crop.width <= 0) {
      throw LayerValidationError(
          'crop.width', 'crop.width must be > 0, got ${crop.width}');
    }
    if (crop.height <= 0) {
      throw LayerValidationError(
          'crop.height', 'crop.height must be > 0, got ${crop.height}');
    }
  }

  // -------------------------------------------------------------------------
  // DEFAULT FACTORY — convenience for LayerEngine
  // -------------------------------------------------------------------------

  /// Creates an [ImageLayer] with safe defaults at a given position.
  ///
  /// LayerEngine uses this when no explicit crop or fitMode is provided.
  factory ImageLayer.defaults({
    required String id,
    required String imagePath,
    double x      = 0,
    double y      = 0,
    double width  = 300,
    double height = 200,
    int    zIndex = 0,
  }) {
    return ImageLayer.create(
      id:        id,
      imagePath: imagePath,
      position:  LayerPosition(x: x, y: y),
      size:      LayerSize(width: width, height: height),
      transform: const LayerTransform(rotation: 0),
      crop:      ImageCrop(x: 0, y: 0, width: width, height: height),
      fitMode:   ImageFitMode.cover,
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
      'ImageLayer(id: $id, imagePath: "$imagePath", fitMode: ${fitMode.name}, zIndex: ${state.zIndex})';
}

// ==========================================================
// END OF FILE — layers/image_layer.dart
// ==========================================================
