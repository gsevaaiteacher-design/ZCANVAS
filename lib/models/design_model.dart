import 'dart:convert';

import 'layer_model.dart';

bool _layerListsEqual(List<LayerModel> a, List<LayerModel> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ============================================================
// CanvasModel
// ============================================================

class CanvasModel {
  final double width;
  final double height;
  final double ratio;
  final String backgroundColor;

  CanvasModel({
    required double width,
    required double height,
    required double ratio,
    required this.backgroundColor,
  })  : width = _validateDimension(width, 'width'),
        height = _validateDimension(height, 'height'),
        ratio = _validateRatio(ratio);

  static double _validateDimension(double value, String field) {
    if (value <= 0) {
      throw ArgumentError('Canvas $field must be > 0. Got: $value');
    }
    return value;
  }

  static double _validateRatio(double ratio) {
    if (ratio <= 0) {
      throw ArgumentError('Canvas ratio must be > 0. Got: $ratio');
    }
    return ratio;
  }

  CanvasModel copyWith({
    double? width,
    double? height,
    double? ratio,
    String? backgroundColor,
  }) {
    return CanvasModel(
      width: width ?? this.width,
      height: height ?? this.height,
      ratio: ratio ?? this.ratio,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'ratio': ratio,
      'backgroundColor': backgroundColor,
    };
  }

  factory CanvasModel.fromJson(Map<String, dynamic> json) {
    return CanvasModel(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      ratio: (json['ratio'] as num).toDouble(),
      backgroundColor: json['backgroundColor'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasModel) return false;
    return width == other.width &&
        height == other.height &&
        ratio == other.ratio &&
        backgroundColor == other.backgroundColor;
  }

  @override
  int get hashCode => Object.hash(width, height, ratio, backgroundColor);

  @override
  String toString() {
    return 'CanvasModel('
        'width: $width, '
        'height: $height, '
        'ratio: $ratio, '
        'backgroundColor: $backgroundColor'
        ')';
  }
}

// ============================================================
// DesignMetadata
// ============================================================

class DesignMetadata {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? templateId;
  final String language;
  final String category;

  const DesignMetadata({
    required this.createdAt,
    required this.updatedAt,
    this.templateId,
    required this.language,
    required this.category,
  });

  DesignMetadata copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? templateId = _metaSentinel,
    String? language,
    String? category,
  }) {
    return DesignMetadata(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      templateId: identical(templateId, _metaSentinel)
          ? this.templateId
          : templateId as String?,
      language: language ?? this.language,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'templateId': templateId,
      'language': language,
      'category': category,
    };
  }

  factory DesignMetadata.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt == null) {
      throw ArgumentError('DesignMetadata createdAt must not be null.');
    }
    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt == null) {
      throw ArgumentError('DesignMetadata updatedAt must not be null.');
    }
    return DesignMetadata(
      createdAt: DateTime.parse(rawCreatedAt as String),
      updatedAt: DateTime.parse(rawUpdatedAt as String),
      templateId: json['templateId'] as String?,
      language: json['language'] as String,
      category: json['category'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DesignMetadata) return false;
    return createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        templateId == other.templateId &&
        language == other.language &&
        category == other.category;
  }

  @override
  int get hashCode =>
      Object.hash(createdAt, updatedAt, templateId, language, category);

  @override
  String toString() {
    return 'DesignMetadata('
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'templateId: $templateId, '
        'language: $language, '
        'category: $category'
        ')';
  }
}

const Object _metaSentinel = Object();

// ============================================================
// DesignModel
// ============================================================

class DesignModel {
  final String designId;
  final String schemaVersion;
  final String editorVersion;
  final String templateVersion;
  final int revision;
  final int lastSavedRevision;
  final CanvasModel canvas;
  final List<LayerModel> layers;
  final DesignMetadata metadata;

  DesignModel({
    required String designId,
    required this.schemaVersion,
    required this.editorVersion,
    required this.templateVersion,
    required int revision,
    required int lastSavedRevision,
    required this.canvas,
    required List<LayerModel> layers,
    required this.metadata,
  })  : designId = _validateDesignId(designId),
        revision = _validateRevision(revision, 'revision'),
        lastSavedRevision =
            _validateRevision(lastSavedRevision, 'lastSavedRevision'),
        layers = List.unmodifiable(layers);

  static String _validateDesignId(String designId) {
    if (designId.isEmpty) {
      throw ArgumentError('DesignModel designId must not be empty.');
    }
    return designId;
  }

  static int _validateRevision(int value, String field) {
    if (value < 0) {
      throw ArgumentError(
          'DesignModel $field must be >= 0. Got: $value');
    }
    return value;
  }

  DesignModel copyWith({
    String? designId,
    String? schemaVersion,
    String? editorVersion,
    String? templateVersion,
    int? revision,
    int? lastSavedRevision,
    CanvasModel? canvas,
    List<LayerModel>? layers,
    DesignMetadata? metadata,
  }) {
    return DesignModel(
      designId: designId ?? this.designId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      editorVersion: editorVersion ?? this.editorVersion,
      templateVersion: templateVersion ?? this.templateVersion,
      revision: revision ?? this.revision,
      lastSavedRevision: lastSavedRevision ?? this.lastSavedRevision,
      canvas: canvas ?? this.canvas,
      layers: layers ?? List<LayerModel>.from(this.layers),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'designId': designId,
      'schemaVersion': schemaVersion,
      'editorVersion': editorVersion,
      'templateVersion': templateVersion,
      'revision': revision,
      'lastSavedRevision': lastSavedRevision,
      'canvas': canvas.toJson(),
      'layers': layers.map((l) => l.toJson()).toList(),
      'metadata': metadata.toJson(),
    };
  }

  factory DesignModel.fromJson(Map<String, dynamic> json) {
    final rawDesignId = json['designId'];
    if (rawDesignId == null) {
      throw ArgumentError('DesignModel designId must not be null.');
    }

    final rawCanvas = json['canvas'];
    if (rawCanvas == null) {
      throw ArgumentError('DesignModel canvas must not be null.');
    }

    final rawLayers = json['layers'];
    if (rawLayers == null) {
      throw ArgumentError('DesignModel layers must not be null.');
    }
    if (rawLayers is! List) {
      throw ArgumentError(
          'DesignModel layers must be a List. Got: ${rawLayers.runtimeType}');
    }

    final rawMetadata = json['metadata'];
    if (rawMetadata == null) {
      throw ArgumentError('DesignModel metadata must not be null.');
    }

    final List<LayerModel> layers = (rawLayers as List)
        .map((e) => LayerModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DesignModel(
      designId: rawDesignId as String,
      schemaVersion: json['schemaVersion'] as String,
      editorVersion: json['editorVersion'] as String,
      templateVersion: json['templateVersion'] as String,
      revision: json['revision'] as int,
      lastSavedRevision: json['lastSavedRevision'] as int,
      canvas: CanvasModel.fromJson(rawCanvas as Map<String, dynamic>),
      layers: layers,
      metadata:
          DesignMetadata.fromJson(rawMetadata as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DesignModel) return false;
    return designId == other.designId &&
        schemaVersion == other.schemaVersion &&
        editorVersion == other.editorVersion &&
        templateVersion == other.templateVersion &&
        revision == other.revision &&
        lastSavedRevision == other.lastSavedRevision &&
        canvas == other.canvas &&
        _layerListsEqual(layers, other.layers) &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      designId,
      schemaVersion,
      editorVersion,
      templateVersion,
      revision,
      lastSavedRevision,
      canvas,
      Object.hashAll(layers),
      metadata,
    ]);
  }

  @override
  String toString() {
    return 'DesignModel('
        'designId: $designId, '
        'schemaVersion: $schemaVersion, '
        'editorVersion: $editorVersion, '
        'templateVersion: $templateVersion, '
        'revision: $revision, '
        'lastSavedRevision: $lastSavedRevision, '
        'layers: ${layers.length} layer(s)'
        ')';
  }
}
