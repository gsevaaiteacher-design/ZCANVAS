import '../models/design_model.dart';
import '../models/layer_model.dart';

class RepositoryError {
  const RepositoryError({
    required this.code,
    required this.reason,
  });

  final String status = 'ERROR';
  final String code;
  final String reason;
  final String source = 'StorageEngine';

  Map<String, dynamic> toMap() => {
        'status': status,
        'code':   code,
        'reason': reason,
        'source': source,
      };

  @override
  String toString() => 'RepositoryError[$code]: $reason';
}

class RepositoryResult<T> {
  const RepositoryResult._success(this._data) : _error = null;
  const RepositoryResult._failure(this._error) : _data = null;

  final T? _data;
  final RepositoryError? _error;

  bool get isSuccess => _error == null;
  bool get isError   => _error != null;

  T                get data  => _data!;
  RepositoryError  get error => _error!;

  static RepositoryResult<T> success<T>(T value) =>
      RepositoryResult._success(value);

  static RepositoryResult<T> failure<T>(String code, String reason) =>
      RepositoryResult._failure(RepositoryError(code: code, reason: reason));
}

abstract class StorageEngine {
  Future<void>                  write(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> read(String key);
  Future<void>                  delete(String key);
  Future<List<Map<String, dynamic>>> readAll(String prefix);
}

class LayerRepository {
  LayerRepository({required StorageEngine storage}) : _storage = storage;

  final StorageEngine _storage;

  final Map<String, DesignModel> _cache = {};

  static const String _designPrefix = 'design:';
  static const String _layerPrefix  = 'layer:';

  Future<RepositoryResult<void>> saveDesign(DesignModel design) async {
    if (design.id.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }
    if (!design.isValid) {
      return RepositoryResult.failure('INVALID_MODEL', 'DesignModel failed validation');
    }

    try {
      final Map<String, dynamic> storageFormat = _toStorageFormat(design);
      await _storage.write('$_designPrefix${design.id}', storageFormat);
      _cache[design.id] = design;
      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('WRITE_FAILED', e.toString());
    }
  }

  Future<RepositoryResult<DesignModel>> loadDesign(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }

    if (_cache.containsKey(designId)) {
      return RepositoryResult.success(_cloneDesign(_cache[designId]!));
    }

    try {
      final Map<String, dynamic>? raw =
          await _storage.read('$_designPrefix$designId');

      if (raw == null) {
        return RepositoryResult.failure('NOT_FOUND', 'Design $designId not found');
      }

      final DesignModel design = _fromStorageFormat(raw);

      if (!design.isValid) {
        return RepositoryResult.failure(
            'CORRUPTED', 'Stored design failed schema validation');
      }

      _cache[designId] = design;
      return RepositoryResult.success(_cloneDesign(design));
    } catch (e) {
      return RepositoryResult.failure('READ_FAILED', e.toString());
    }
  }

  Future<RepositoryResult<void>> deleteDesign(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }

    try {
      await _storage.delete('$_designPrefix$designId');
      _cache.remove(designId);
      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('DELETE_FAILED', e.toString());
    }
  }

  Future<RepositoryResult<void>> updateLayer(
      String designId, LayerModel layer) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }
    if (!layer.isValid) {
      return RepositoryResult.failure(
          'INVALID_LAYER', 'LayerModel failed validation: id=${layer.id}');
    }

    try {
      await _storage.write(
          '$_layerPrefix$designId:${layer.id}', layer.toMap());

      if (_cache.containsKey(designId)) {
        final DesignModel cached = _cache[designId]!;
        final List<LayerModel> updated = cached.layers
            .map((l) => l.id == layer.id ? LayerModel.fromMap(layer.toMap()) : l)
            .toList();

        _cache[designId] = cached.copyWith(
          layers:    updated,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('UPDATE_FAILED', e.toString());
    }
  }

  Future<RepositoryResult<List<LayerModel>>> fetchAllLayers(
      String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }

    if (_cache.containsKey(designId)) {
      final List<LayerModel> layers = _cache[designId]!
          .layers
          .map((l) => LayerModel.fromMap(l.toMap()))
          .toList();
      return RepositoryResult.success(layers);
    }

    try {
      final List<Map<String, dynamic>> raws =
          await _storage.readAll('$_layerPrefix$designId:');

      if (raws.isEmpty) {
        return RepositoryResult.success(<LayerModel>[]);
      }

      final List<LayerModel> layers = [];
      for (int i = 0; i < raws.length; i++) {
        final LayerModel layer = LayerModel.fromMap(raws[i]);
        if (!layer.isValid) {
          return RepositoryResult.failure(
              'CORRUPTED', 'Layer at index $i failed schema validation');
        }
        layers.add(layer);
      }

      layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));
      return RepositoryResult.success(layers);
    } catch (e) {
      return RepositoryResult.failure('FETCH_FAILED', e.toString());
    }
  }

  Future<RepositoryResult<void>> clearCache(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('INVALID_ID', 'designId must not be empty');
    }
    _cache.remove(designId);
    return RepositoryResult.success(null);
  }

  Map<String, dynamic> _toStorageFormat(DesignModel design) {
    return Map<String, dynamic>.unmodifiable(design.toMap());
  }

  DesignModel _fromStorageFormat(Map<String, dynamic> raw) {
    return DesignModel.fromMap(Map<String, dynamic>.from(raw));
  }

  DesignModel _cloneDesign(DesignModel source) {
    return DesignModel.fromMap(source.toMap());
  }
}
