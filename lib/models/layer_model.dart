import 'dart:convert';

const Object _sentinel = Object();

bool _tagsEqual(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _customDataEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  return jsonEncode(a) == jsonEncode(b);
}

enum LayerType {
  background,
  image,
  text,
  icon,
  shape,
  sticker,
  logo,
  frame,
  overlay;

  static LayerType fromString(String value) {
    return LayerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown layer type: "$value".'),
    );
  }

  String toJson() => name;
}

class LayerModel {
  final String id;
  final LayerType type;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double opacity;
  final bool visible;
  final bool locked;
  final int zIndex;
  final String? parentId;
  final String? groupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? source;
  final String? templateId;
  final List<String> tags;
  final Map<String, dynamic> customData;

  LayerModel({
    required String id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required double width,
    required double height,
    required double rotation,
    required this.scaleX,
    required this.scaleY,
    required double opacity,
    required this.visible,
    required this.locked,
    required this.zIndex,
    this.parentId,
    this.groupId,
    required this.createdAt,
    required this.updatedAt,
    this.source,
    this.templateId,
    required List<String> tags,
    required Map<String, dynamic> customData,
  })  : id = _validateId(id),
        width = _validateWidth(width),
        height = _validateHeight(height),
        rotation = _validateRotation(rotation),
        opacity = _validateOpacity(opacity),
        tags = List.unmodifiable(tags),
        customData = Map.unmodifiable(_validateCustomData(customData));

  static String _validateId(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Layer id must not be empty.');
    }
    return id;
  }

  static double _validateWidth(double width) {
    if (width < 0) {
      throw ArgumentError('Layer width must be >= 0. Got: $width');
    }
    return width;
  }

  static double _validateHeight(double height) {
    if (height < 0) {
      throw ArgumentError('Layer height must be >= 0. Got: $height');
    }
    return height;
  }

  static double _validateRotation(double rotation) {
    if (rotation < 0 || rotation > 360) {
      throw ArgumentError(
          'Layer rotation must be in range 0–360. Got: $rotation');
    }
    return rotation;
  }

  static double _validateOpacity(double opacity) {
    if (opacity < 0 || opacity > 100) {
      throw ArgumentError(
          'Layer opacity must be in range 0–100. Got: $opacity');
    }
    return opacity;
  }

  static Map<String, dynamic> _validateCustomData(
      Map<String, dynamic> customData) {
    try {
      jsonEncode(customData);
    } catch (_) {
      throw ArgumentError(
          'customData must be fully JSON serializable. '
          'No object, function, or UI references are allowed.');
    }
    return customData;
  }

  LayerModel copyWith({
    String? id,
    LayerType? type,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? opacity,
    bool? visible,
    bool? locked,
    int? zIndex,
    Object? parentId = _sentinel,
    Object? groupId = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? source = _sentinel,
    Object? templateId = _sentinel,
    List<String>? tags,
    Map<String, dynamic>? customData,
  }) {
    return LayerModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      opacity: opacity ?? this.opacity,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      zIndex: zIndex ?? this.zIndex,
      parentId:
          identical(parentId, _sentinel) ? this.parentId : parentId as String?,
      groupId:
          identical(groupId, _sentinel) ? this.groupId : groupId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: identical(source, _sentinel) ? this.source : source as String?,
      templateId: identical(templateId, _sentinel)
          ? this.templateId
          : templateId as String?,
      tags: tags ?? List<String>.from(this.tags),
      customData: customData ?? Map<String, dynamic>.from(this.customData),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toJson(),
      'name': name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'opacity': opacity,
      'visible': visible,
      'locked': locked,
      'zIndex': zIndex,
      'parentId': parentId,
      'groupId': groupId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'source': source,
      'templateId': templateId,
      'tags': List<String>.from(tags),
      'customData': Map<String, dynamic>.from(customData),
    };
  }

  factory LayerModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (rawId == null) {
      throw ArgumentError('Layer id must not be null.');
    }

    final rawType = json['type'];
    if (rawType == null) {
      throw ArgumentError('Layer type must not be null.');
    }

    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt == null) {
      throw ArgumentError('Layer createdAt must not be null.');
    }

    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt == null) {
      throw ArgumentError('Layer updatedAt must not be null.');
    }

    final rawTags = json['tags'];
    final List<String> tags =
        rawTags == null ? const [] : List<String>.from(rawTags as List);

    final rawCustomData = json['customData'];
    final Map<String, dynamic> customData = rawCustomData == null
        ? const {}
        : Map<String, dynamic>.from(rawCustomData as Map);

    return LayerModel(
      id: rawId as String,
      type: LayerType.fromString(rawType as String),
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
      scaleX: (json['scaleX'] as num).toDouble(),
      scaleY: (json['scaleY'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      visible: json['visible'] as bool,
      locked: json['locked'] as bool,
      zIndex: json['zIndex'] as int,
      parentId: json['parentId'] as String?,
      groupId: json['groupId'] as String?,
      createdAt: DateTime.parse(rawCreatedAt as String),
      updatedAt: DateTime.parse(rawUpdatedAt as String),
      source: json['source'] as String?,
      templateId: json['templateId'] as String?,
      tags: tags,
      customData: customData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LayerModel) return false;
    return id == other.id &&
        type == other.type &&
        name == other.name &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height &&
        rotation == other.rotation &&
        scaleX == other.scaleX &&
        scaleY == other.scaleY &&
        opacity == other.opacity &&
        visible == other.visible &&
        locked == other.locked &&
        zIndex == other.zIndex &&
        parentId == other.parentId &&
        groupId == other.groupId &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        source == other.source &&
        templateId == other.templateId &&
        _tagsEqual(tags, other.tags) &&
        _customDataEqual(customData, other.customData);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      type,
      name,
      x,
      y,
      width,
      height,
      rotation,
      scaleX,
      scaleY,
      opacity,
      visible,
      locked,
      zIndex,
      parentId,
      groupId,
      createdAt,
      updatedAt,
      source,
      templateId,
      Object.hashAll(tags),
      jsonEncode(customData),
    ]);
  }

  @override
  String toString() {
    return 'LayerModel('
        'id: $id, '
        'type: ${type.name}, '
        'name: $name, '
        'x: $x, '
        'y: $y, '
        'width: $width, '
        'height: $height, '
        'rotation: $rotation, '
        'scaleX: $scaleX, '
        'scaleY: $scaleY, '
        'opacity: $opacity, '
        'visible: $visible, '
        'locked: $locked, '
        'zIndex: $zIndex'
        ')';
  }
}
