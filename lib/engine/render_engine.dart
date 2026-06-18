import '../models/layer_model.dart';
import '../models/design_model.dart';

class RenderBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const RenderBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class RenderTransform {
  final double scaleX;
  final double scaleY;
  final double skewX;
  final double skewY;
  final double translateX;
  final double translateY;

  const RenderTransform({
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.skewX = 0.0,
    this.skewY = 0.0,
    this.translateX = 0.0,
    this.translateY = 0.0,
  });
}

class RenderInstruction {
  final String layerId;
  final String layerType;
  final int zIndex;
  final bool visibility;
  final bool locked;
  final RenderBounds bounds;
  final RenderBounds position;
  final double rotation;
  final double opacity;
  final RenderTransform transform;

  const RenderInstruction({
    required this.layerId,
    required this.layerType,
    required this.zIndex,
    required this.visibility,
    required this.locked,
    required this.bounds,
    required this.position,
    required this.rotation,
    required this.opacity,
    required this.transform,
  });
}

class CanvasBounds {
  final double width;
  final double height;
  final double originX;
  final double originY;

  const CanvasBounds({
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
  });
}

class RenderTree {
  final List<RenderInstruction> instructions;
  final CanvasBounds canvasBounds;
  final DateTime builtAt;

  const RenderTree({
    required this.instructions,
    required this.canvasBounds,
    required this.builtAt,
  });
}

class RenderEngine {
  RenderTree? _lastRenderTree;

  RenderTree? get lastRenderTree => _lastRenderTree;

  RenderTree buildRenderTree(List<LayerModel> layers, DesignModel? design) {
    final visible = getVisibleLayers(layers);
    final sorted = sortLayersByZIndex(visible);
    final instructions = prepareRenderInstructions(sorted);
    final bounds = calculateCanvasBounds(design);

    final tree = RenderTree(
      instructions: instructions,
      canvasBounds: bounds,
      builtAt: DateTime.now(),
    );

    _lastRenderTree = tree;
    return tree;
  }

  List<LayerModel> sortLayersByZIndex(List<LayerModel> layers) {
    final sorted = List<LayerModel>.from(layers);
    sorted.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  List<LayerModel> getVisibleLayers(List<LayerModel> layers) {
    return layers.where((layer) => layer.visible).toList();
  }

  CanvasBounds calculateCanvasBounds(DesignModel? design) {
    if (design == null) {
      return const CanvasBounds(
        width: 1920,
        height: 1080,
        originX: 0,
        originY: 0,
      );
    }

    return CanvasBounds(
      width: design.canvasWidth,
      height: design.canvasHeight,
      originX: design.canvasOriginX,
      originY: design.canvasOriginY,
    );
  }

  List<RenderInstruction> prepareRenderInstructions(List<LayerModel> sortedLayers) {
    return sortedLayers.map(_layerToInstruction).toList();
  }

  RenderInstruction _layerToInstruction(LayerModel layer) {
    return RenderInstruction(
      layerId: layer.id,
      layerType: layer.type,
      zIndex: layer.zIndex,
      visibility: layer.visible,
      locked: layer.locked,
      bounds: RenderBounds(
        x: layer.x,
        y: layer.y,
        width: layer.width,
        height: layer.height,
      ),
      position: RenderBounds(
        x: layer.x,
        y: layer.y,
        width: layer.width,
        height: layer.height,
      ),
      rotation: layer.rotation,
      opacity: layer.opacity,
      transform: RenderTransform(
        scaleX: layer.scaleX,
        scaleY: layer.scaleY,
        translateX: layer.x,
        translateY: layer.y,
      ),
    );
  }
}
