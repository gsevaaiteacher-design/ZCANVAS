// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// ExportEngine — Phase-3 Export Authority
// ============================================================
// OWNS: export validation, export data preparation, export
//       metadata generation.
// MUST NOT: save files, modify DesignModel, LayerModel,
//           LayerEngine, HistoryEngine, StorageEngine,
//           EditorController, or RenderEngine.
// DEPENDS ON: DesignModel, LayerModel, render-ready structures.
// ============================================================

import '../../models/design_model.dart';
import '../../models/layer_model.dart';
import '../../engines/render_engine.dart';

// ── Supported export types ────────────────────────────────────
enum ExportType {
  png,
  jpg,
  pdf,
}

// ── Export request ────────────────────────────────────────────
class ExportRequest {
  final String exportId;
  final String designId;
  final ExportType exportType;
  final DateTime requestedAt;
  final double requestedQuality;
  final double requestedScale;

  const ExportRequest({
    required this.exportId,
    required this.designId,
    required this.exportType,
    required this.requestedAt,
    required this.requestedQuality,
    required this.requestedScale,
  });
}

// ── Export metadata ───────────────────────────────────────────
class ExportMetadata {
  final double canvasWidth;
  final double canvasHeight;
  final int visibleLayerCount;
  final int totalLayerCount;
  final ExportType exportFormat;
  final DateTime generatedAt;

  const ExportMetadata({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.visibleLayerCount,
    required this.totalLayerCount,
    required this.exportFormat,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'visibleLayerCount': visibleLayerCount,
        'totalLayerCount': totalLayerCount,
        'exportFormat': exportFormat.name,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

// ── Export result ─────────────────────────────────────────────
class ExportResult {
  final String exportId;
  final bool success;
  final ExportType exportType;
  final DateTime generatedAt;
  final List<String> warnings;
  final List<String> errors;
  final ExportMetadata? metadata;
  final ExportData? data;

  const ExportResult({
    required this.exportId,
    required this.success,
    required this.exportType,
    required this.generatedAt,
    this.warnings = const [],
    this.errors = const [],
    this.metadata,
    this.data,
  });

  factory ExportResult.failure({
    required String exportId,
    required ExportType exportType,
    required List<String> errors,
    List<String> warnings = const [],
  }) {
    return ExportResult(
      exportId: exportId,
      success: false,
      exportType: exportType,
      generatedAt: DateTime.now().toUtc(),
      errors: errors,
      warnings: warnings,
    );
  }
}

// ── Export data (render-ready output — no file IO performed) ──
// Consumers are responsible for writing bytes to disk/cloud.
class ExportData {
  final ExportType format;
  final List<LayerExportInstruction> layerInstructions;
  final CanvasExportBounds canvasBounds;
  final ExportSettings settings;

  const ExportData({
    required this.format,
    required this.layerInstructions,
    required this.canvasBounds,
    required this.settings,
  });
}

class CanvasExportBounds {
  final double width;
  final double height;
  final double originX;
  final double originY;
  final double scaledWidth;
  final double scaledHeight;

  const CanvasExportBounds({
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
    required this.scaledWidth,
    required this.scaledHeight,
  });
}

class ExportSettings {
  final double quality;
  final double scale;
  final ExportType format;

  const ExportSettings({
    required this.quality,
    required this.scale,
    required this.format,
  });
}

// ── Layer-level export instruction ───────────────────────────
// Derived from RenderInstruction — read-only projection.
class LayerExportInstruction {
  final String layerId;
  final String layerType;
  final int zIndex;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final double scaleX;
  final double scaleY;
  final bool locked;
  final Map<String, dynamic> properties;

  const LayerExportInstruction({
    required this.layerId,
    required this.layerType,
    required this.zIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.opacity,
    required this.scaleX,
    required this.scaleY,
    required this.locked,
    required this.properties,
  });
}

// ── Validation pipeline result ────────────────────────────────
class _ExportValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const _ExportValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const _ExportValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── ExportEngine ──────────────────────────────────────────────
class ExportEngine {
  // ── Quality & scale constraints ─────────────────────────────
  static const double _minQuality = 0.0;
  static const double _maxQuality = 1.0;
  static const double _defaultQuality = 1.0;
  static const double _minScale = 0.1;
  static const double _maxScale = 8.0;
  static const double _defaultScale = 1.0;

  // ── Public export entry points ───────────────────────────────

  /// Prepare PNG export data. Does NOT write bytes to disk.
  ExportResult exportPNG(DesignModel design, ExportRequest request) {
    return _runExport(design, request, ExportType.png);
  }

  /// Prepare JPG export data. Does NOT write bytes to disk.
  ExportResult exportJPG(DesignModel design, ExportRequest request) {
    return _runExport(design, request, ExportType.jpg);
  }

  /// Prepare PDF export data. Does NOT write bytes to disk.
  ExportResult exportPDF(DesignModel design, ExportRequest request) {
    return _runExport(design, request, ExportType.pdf);
  }

  // ── Core export pipeline ─────────────────────────────────────

  ExportResult _runExport(
      DesignModel design, ExportRequest request, ExportType resolvedType) {
    try {
      // 1. Validate design + request through the full pipeline.
      final validation =
          validateDesignForExport(design, request, resolvedType);
      if (!validation.valid) {
        return ExportResult.failure(
          exportId: request.exportId,
          exportType: resolvedType,
          errors: validation.errors,
          warnings: validation.warnings,
        );
      }

      // 2. Normalize settings (clamp within permitted bounds).
      final settings = _normalizeSettings(request, resolvedType);

      // 3. Prepare render-ready export data — read-only, no state change.
      final exportData = prepareExportData(design, settings);

      // 4. Generate metadata.
      final metadata = generateExportMetadata(design, resolvedType);

      return ExportResult(
        exportId: request.exportId,
        success: true,
        exportType: resolvedType,
        generatedAt: DateTime.now().toUtc(),
        warnings: validation.warnings,
        errors: const [],
        metadata: metadata,
        data: exportData,
      );
    } catch (e) {
      // Failure law: any exception must produce a failure result;
      // no state is modified and no domain object is mutated.
      return ExportResult.failure(
        exportId: request.exportId,
        exportType: resolvedType,
        errors: ['Unexpected error during export: $e'],
      );
    }
  }

  // ── Validation pipeline ───────────────────────────────────────
  // Matches contract order:
  //   DESIGN → DESIGN ID → CANVAS → LAYERS → EXPORT TYPE → SETTINGS

  _ExportValidationResult validateDesignForExport(
      DesignModel design, ExportRequest request, ExportType exportType) {
    final errors = <String>[];
    final warnings = <String>[];

    // Step 1 — VALIDATE DESIGN
    if (design.id.trim().isEmpty) {
      errors.add('DesignModel.id must not be empty.');
    }

    // Step 2 — VALIDATE DESIGN ID
    if (request.designId.trim().isEmpty) {
      errors.add('ExportRequest.designId must not be empty.');
    } else if (design.id != request.designId) {
      errors.add(
          'ExportRequest.designId "${request.designId}" does not match '
          'DesignModel.id "${design.id}".');
    }

    // Step 3 — VALIDATE CANVAS
    if (design.canvasWidth <= 0) {
      errors.add(
          'DesignModel.canvasWidth must be > 0 (got ${design.canvasWidth}).');
    }
    if (design.canvasHeight <= 0) {
      errors.add(
          'DesignModel.canvasHeight must be > 0 '
          '(got ${design.canvasHeight}).');
    }

    // Step 4 — VALIDATE LAYERS
    if (design.layers.isEmpty) {
      warnings.add('Design has no layers; export will produce a blank canvas.');
    } else {
      final visibleCount =
          design.layers.where((l) => l.visible).length;
      if (visibleCount == 0) {
        warnings.add(
            'No visible layers found; export will produce a blank canvas.');
      }
      for (final layer in design.layers) {
        if (layer.id.trim().isEmpty) {
          errors.add('A layer has an empty id — export aborted.');
        }
      }
    }

    // Step 5 — VALIDATE EXPORT TYPE
    if (request.exportType != exportType) {
      errors.add(
          'ExportRequest.exportType (${request.exportType.name}) does not '
          'match the called export method (${exportType.name}).');
    }

    // Step 6 — VALIDATE EXPORT SETTINGS
    if (request.requestedQuality < _minQuality ||
        request.requestedQuality > _maxQuality) {
      errors.add(
          'requestedQuality must be in [$_minQuality, $_maxQuality] '
          '(got ${request.requestedQuality}).');
    }
    if (request.requestedScale < _minScale ||
        request.requestedScale > _maxScale) {
      errors.add(
          'requestedScale must be in [$_minScale, $_maxScale] '
          '(got ${request.requestedScale}).');
    }
    if (request.exportId.trim().isEmpty) {
      errors.add('ExportRequest.exportId must not be empty.');
    }

    // JPG-specific: quality below 0.5 is lossy enough to warn.
    if (exportType == ExportType.jpg && request.requestedQuality < 0.5) {
      warnings.add(
          'JPG quality ${request.requestedQuality} is very low; '
          'output may be visually degraded.');
    }

    if (errors.isEmpty) {
      return _ExportValidationResult.ok(warnings: warnings);
    }
    return _ExportValidationResult.fail(errors, warnings: warnings);
  }

  // ── Prepare export data ───────────────────────────────────────

  ExportData prepareExportData(DesignModel design, ExportSettings settings) {
    // Only include visible layers, ordered by zIndex.
    // zIndex is the sole authoritative ordering system.
    final visibleLayers = design.layers
        .where((l) => l.visible)
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final instructions = visibleLayers
        .map((l) => _layerToExportInstruction(l, settings.scale))
        .toList();

    final scaledWidth = design.canvasWidth * settings.scale;
    final scaledHeight = design.canvasHeight * settings.scale;

    final canvasBounds = CanvasExportBounds(
      width: design.canvasWidth,
      height: design.canvasHeight,
      originX: design.canvasOriginX,
      originY: design.canvasOriginY,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
    );

    return ExportData(
      format: settings.format,
      layerInstructions: instructions,
      canvasBounds: canvasBounds,
      settings: settings,
    );
  }

  LayerExportInstruction _layerToExportInstruction(
      LayerModel layer, double scale) {
    // All spatial values are scaled; logical values (rotation, opacity,
    // zIndex, locked, properties) are passed through unchanged.
    return LayerExportInstruction(
      layerId: layer.id,
      layerType: layer.type,
      zIndex: layer.zIndex,
      x: layer.x * scale,
      y: layer.y * scale,
      width: layer.width * scale,
      height: layer.height * scale,
      rotation: layer.rotation,
      opacity: layer.opacity,
      scaleX: layer.scaleX * scale,
      scaleY: layer.scaleY * scale,
      locked: layer.locked,
      properties: Map<String, dynamic>.unmodifiable(layer.properties),
    );
  }

  // ── Metadata generation ───────────────────────────────────────

  ExportMetadata generateExportMetadata(
      DesignModel design, ExportType exportType) {
    final totalCount = design.layers.length;
    final visibleCount = design.layers.where((l) => l.visible).length;

    return ExportMetadata(
      canvasWidth: design.canvasWidth,
      canvasHeight: design.canvasHeight,
      visibleLayerCount: visibleCount,
      totalLayerCount: totalCount,
      exportFormat: exportType,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  // ── Settings normalization ────────────────────────────────────

  ExportSettings _normalizeSettings(ExportRequest request, ExportType type) {
    final quality =
        request.requestedQuality.clamp(_minQuality, _maxQuality);
    final scale = request.requestedScale.clamp(_minScale, _maxScale);

    // PDF does not use raster quality — force to 1.0.
    final normalizedQuality = type == ExportType.pdf ? _defaultQuality : quality;
    final normalizedScale =
        scale <= 0 ? _defaultScale : scale;

    return ExportSettings(
      quality: normalizedQuality,
      scale: normalizedScale,
      format: type,
    );
  }

  // ── Convenience factory for ExportRequest ─────────────────────
  // Provides a standard request with safe defaults.
  static ExportRequest buildRequest({
    required String exportId,
    required String designId,
    required ExportType exportType,
    double quality = _defaultQuality,
    double scale = _defaultScale,
  }) {
    return ExportRequest(
      exportId: exportId,
      designId: designId,
      exportType: exportType,
      requestedAt: DateTime.now().toUtc(),
      requestedQuality: quality.clamp(_minQuality, _maxQuality),
      requestedScale: scale.clamp(_minScale, _maxScale),
    );
  }
}
