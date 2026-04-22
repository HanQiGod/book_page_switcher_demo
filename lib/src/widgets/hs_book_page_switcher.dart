import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

const Curve _kBookTurnForwardCurve = Cubic(0.2, 0.76, 0.16, 1.0);
const Curve _kBookTurnRollbackCurve = Cubic(0.12, 0.7, 0.28, 1.0);

enum HsBookPageTurnDirection {
  next,
  previous,
}

enum _HsBookPageTurnSource {
  programmatic,
  gesture,
}

/// 翻书切页控制器
class HsBookPageController extends ChangeNotifier {
  _HsBookPageSwitcherState? _state;
  int _page = 0;

  /// 当前页下标
  int get page => _page;

  /// 当前是否已绑定到组件
  bool get hasClients => _state != null;

  void _attach(_HsBookPageSwitcherState state) {
    _state = state;
    _updatePage(state._currentIndex, notify: false);
  }

  void _detach(_HsBookPageSwitcherState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void _updatePage(int page, {bool notify = true}) {
    if (_page == page) return;
    _page = page;
    if (notify) {
      notifyListeners();
    }
  }

  /// 带动画切换到指定页
  Future<void> animateToPage(int page) async {
    await _state?._animateToPage(page);
  }

  /// 直接跳转到指定页
  void jumpToPage(int page) {
    _state?._jumpToPage(page);
  }

  /// 翻到下一页
  Future<void> nextPage() async {
    await _state?._stepPage(1);
  }

  /// 翻到上一页
  Future<void> previousPage() async {
    await _state?._stepPage(-1);
  }
}

/// 翻书切换页面组件
///
/// 通过单侧翻页、纸张背面和阴影层模拟翻书效果。
/// 按“微信读书、掌阅或者 Kindle 的卷页手感”的方式做了切页，带纸张背面、透视和阴影层，
/// 支持 nextPage、previousPage、animateToPage、jumpToPage、手势切页、循环翻页和页码回调。
class HsBookPageSwitcher extends StatefulWidget {
  const HsBookPageSwitcher({
    super.key,
    required this.children,
    this.controller,
    this.initialPage = 0,
    this.onPageChanged,
    this.enableGesture = true,
    this.enableLoop = false,
    this.duration = const Duration(milliseconds: 620),
    this.curve = Curves.easeInOutCubic,
    this.perspective = 0.0024,
    this.dragVelocityThreshold = 320,
    this.decoration,
    this.clipBehavior = Clip.antiAlias,
    this.paperBackColor = const Color(0xFFF5EFE4),
    this.shadowColor = const Color(0x3819120D),
  })  : assert(children.length > 0, 'children 不能为空'),
        assert(
          initialPage >= 0 && initialPage < children.length,
          'initialPage 超出 children 范围',
        ),
        assert(perspective > 0, 'perspective 必须大于 0'),
        assert(dragVelocityThreshold >= 0, 'dragVelocityThreshold 必须 >= 0');

  /// 页面列表
  final List<Widget> children;

  /// 外部控制器
  final HsBookPageController? controller;

  /// 默认显示页
  final int initialPage;

  /// 页变化回调
  final ValueChanged<int>? onPageChanged;

  /// 是否启用手势翻页
  final bool enableGesture;

  /// 是否允许循环翻页
  final bool enableLoop;

  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 透视强度
  final double perspective;

  /// 手势速度阈值
  final double dragVelocityThreshold;

  /// 外层装饰
  final Decoration? decoration;

  /// 裁剪行为
  final Clip clipBehavior;

  /// 纸张背面颜色
  final Color paperBackColor;

  /// 阴影颜色
  final Color shadowColor;

  @override
  State<HsBookPageSwitcher> createState() => _HsBookPageSwitcherState();
}

class _HsBookPageSwitcherState extends State<HsBookPageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late int _currentIndex;
  late int _previousIndex;
  int? _targetIndex;
  HsBookPageTurnDirection _direction = HsBookPageTurnDirection.next;
  bool _isDragging = false;
  Offset? _dragStartPosition;
  Size? _dragRegionSize;
  Offset? _currentDragPosition;
  Offset? _settleAnchorPosition;
  Offset? _lastDragPosition;
  Duration? _lastDragTimestamp;
  double _bendStrength = 0.42;
  _HsBookPageTurnSource _turnSource = _HsBookPageTurnSource.programmatic;

  bool get _hasActiveTurn => _targetIndex != null;

  double get _progress => _animationController.value;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _previousIndex = _currentIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant HsBookPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

    if (oldWidget.duration != widget.duration) {
      _animationController.duration = widget.duration;
    }

    if (_currentIndex >= widget.children.length) {
      _currentIndex = widget.children.length - 1;
      _previousIndex = _currentIndex;
      _targetIndex = null;
      _isDragging = false;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
      _animationController.stop();
      _animationController.value = 0;
      widget.controller?._updatePage(_currentIndex);
    }

    if (_targetIndex != null && _targetIndex! >= widget.children.length) {
      _targetIndex = null;
      _isDragging = false;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
      _animationController.stop();
      _animationController.value = 0;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _stepPage(int delta) async {
    final int? nextIndex = _resolvePageIndex(_currentIndex + delta);
    if (nextIndex == null) return;
    await _animateToPage(nextIndex);
  }

  Future<void> _animateToPage(int index) async {
    if (_hasActiveTurn) return;
    if (index < 0 || index >= widget.children.length) return;
    if (index == _currentIndex) return;

    setState(() {
      _previousIndex = _currentIndex;
      _targetIndex = index;
      _direction = _resolveDirection(index);
      _isDragging = false;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
    });

    _bendStrength = 0.34;
    _animationController.value = 0;
    final int baseDuration = widget.duration.inMilliseconds;
    await _animationController.animateTo(
      1,
      duration: Duration(
        milliseconds: math.max(180, (baseDuration * 0.92).round()),
      ),
      curve: _kBookTurnForwardCurve,
    );
    if (!mounted) return;
    _completeTurn();
  }

  void _jumpToPage(int index) {
    if (index < 0 || index >= widget.children.length) return;

    if (_hasActiveTurn) {
      _animationController.stop();
    }

    setState(() {
      _currentIndex = index;
      _previousIndex = index;
      _targetIndex = null;
      _isDragging = false;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
    });

    _bendStrength = 0.42;
    _animationController.value = 0;
    widget.controller?._updatePage(_currentIndex);
    widget.onPageChanged?.call(_currentIndex);
  }

  int? _resolvePageIndex(int index) {
    if (widget.children.length <= 1) return null;

    if (widget.enableLoop) {
      final int length = widget.children.length;
      return (index % length + length) % length;
    }

    if (index < 0 || index >= widget.children.length) {
      return null;
    }

    return index;
  }

  HsBookPageTurnDirection _resolveDirection(int targetIndex) {
    if (widget.enableLoop && widget.children.length > 1) {
      if (_currentIndex == 0 && targetIndex == widget.children.length - 1) {
        return HsBookPageTurnDirection.previous;
      }
      if (_currentIndex == widget.children.length - 1 && targetIndex == 0) {
        return HsBookPageTurnDirection.next;
      }
    }

    return targetIndex > _currentIndex
        ? HsBookPageTurnDirection.next
        : HsBookPageTurnDirection.previous;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.enableGesture || _hasActiveTurn) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Size? size = renderBox?.size;
    if (size == null || size.isEmpty) return;

    final HsBookPageTurnDirection? direction =
        _resolveCornerDirection(details.localPosition, size);
    if (direction == null) return;

    final int delta = direction == HsBookPageTurnDirection.next ? 1 : -1;
    final int? targetIndex = _resolvePageIndex(_currentIndex + delta);
    if (targetIndex == null) return;

    setState(() {
      _previousIndex = _currentIndex;
      _targetIndex = targetIndex;
      _direction = direction;
      _isDragging = true;
      _dragStartPosition = details.localPosition;
      _dragRegionSize = size;
      _currentDragPosition = details.localPosition;
      _settleAnchorPosition = details.localPosition;
      _turnSource = _HsBookPageTurnSource.gesture;
    });

    _lastDragPosition = details.localPosition;
    _lastDragTimestamp = details.sourceTimeStamp;
    _bendStrength = 0.92;
    _animationController.value = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragStartPosition == null || _dragRegionSize == null) {
      return;
    }

    final double progress = _calculateDragProgress(
      start: _dragStartPosition!,
      current: details.localPosition,
      size: _dragRegionSize!,
    );

    _bendStrength = _deriveBendStrength(
      current: details.localPosition,
      timestamp: details.sourceTimeStamp,
    );
    _currentDragPosition = details.localPosition;
    _animationController.value = progress;
  }

  Future<void> _handlePanEnd(DragEndDetails details) async {
    if (_isDragging) {
      final bool shouldComplete = _shouldCompleteDrag(
        details.velocity.pixelsPerSecond,
      );
      await _settleDraggedTurn(complete: shouldComplete);
      return;
    }

    _handleFlingNavigation(details);
  }

  void _handlePanCancel() {
    if (!_isDragging) return;
    _settleDraggedTurn(complete: false);
  }

  void _handleFlingNavigation(DragEndDetails details) {
    if (!widget.enableGesture || _hasActiveTurn) return;

    final double velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() < widget.dragVelocityThreshold) return;

    if (velocity < 0) {
      _stepPage(1);
    } else {
      _stepPage(-1);
    }
  }

  HsBookPageTurnDirection? _resolveCornerDirection(
    Offset localPosition,
    Size size,
  ) {
    final bool inBottomArea = localPosition.dy >= size.height * 0.56;
    final double nextTrigger =
        inBottomArea ? size.width * 0.6 : size.width * 0.74;
    final double previousTrigger =
        inBottomArea ? size.width * 0.4 : size.width * 0.26;

    if (localPosition.dx >= nextTrigger) {
      return HsBookPageTurnDirection.next;
    }

    if (localPosition.dx <= previousTrigger) {
      return HsBookPageTurnDirection.previous;
    }

    return null;
  }

  double _calculateDragProgress({
    required Offset start,
    required Offset current,
    required Size size,
  }) {
    final bool isNext = _direction == HsBookPageTurnDirection.next;
    final double horizontalDistance =
        isNext ? (start.dx - current.dx) : (current.dx - start.dx);
    final double verticalDistance = start.dy - current.dy;
    final double diagonalDistance = math.sqrt(
            (horizontalDistance * horizontalDistance) +
                (verticalDistance * verticalDistance)) /
        (size.shortestSide * 0.78);

    final double horizontalProgress =
        (horizontalDistance / (size.width * 0.48)).clamp(0, 1.2);
    final double verticalProgress =
        (verticalDistance / (size.height * 0.56)).clamp(0, 1.2);
    final double rawProgress = (horizontalProgress * 0.58 +
            verticalProgress * 0.16 +
            diagonalDistance * 0.26)
        .clamp(0, 1.16);

    return _applyDragDamping(
      rawProgress: rawProgress,
      horizontalProgress: horizontalProgress,
      current: current,
      size: size,
    );
  }

  double _applyDragDamping({
    required double rawProgress,
    required double horizontalProgress,
    required Offset current,
    required Size size,
  }) {
    final double clampedRaw = rawProgress.clamp(0.0, 1.0);
    final double overshoot = (rawProgress - 1).clamp(0.0, 0.16);
    final double verticalBias = (current.dy / size.height).clamp(0.0, 1.0);
    final double horizontalBias = horizontalProgress.clamp(0.0, 1.0);
    final double earlyStop = 0.37 + (0.025 * verticalBias);
    final double midSpan = 0.31 + (0.035 * horizontalBias);
    final double tailStart = earlyStop + midSpan;
    final double tailSpan = 0.17 + (0.025 * verticalBias);

    double dampedProgress;
    if (clampedRaw <= 0.36) {
      dampedProgress = clampedRaw * (1.03 + (0.04 * verticalBias));
    } else if (clampedRaw <= 0.78) {
      final double t = (clampedRaw - 0.36) / 0.42;
      dampedProgress = earlyStop + (Curves.easeOutCubic.transform(t) * midSpan);
    } else {
      final double t = (clampedRaw - 0.78) / 0.22;
      dampedProgress =
          tailStart + (Curves.easeOutCubic.transform(t) * tailSpan);
    }

    final double overshootGain =
        0.2 + (0.08 * horizontalBias) + (0.05 * verticalBias);
    return (dampedProgress + (overshoot * overshootGain)).clamp(0.0, 1.0);
  }

  bool _shouldCompleteDrag(Offset velocity) {
    final double directionVelocity = _direction == HsBookPageTurnDirection.next
        ? (-velocity.dx + (-velocity.dy * 0.72))
        : (velocity.dx + (-velocity.dy * 0.72));

    return _animationController.value >= 0.28 ||
        directionVelocity >= widget.dragVelocityThreshold;
  }

  Future<void> _settleDraggedTurn({required bool complete}) async {
    if (!_hasActiveTurn) return;

    final double currentProgress = _animationController.value;
    final int maxDuration = widget.duration.inMilliseconds;
    final int minDuration = math.min(100, maxDuration);
    final int rawDuration = (widget.duration.inMilliseconds *
            (complete ? (1 - currentProgress) : currentProgress))
        .round();
    final double settleFactor = complete ? 0.84 : 0.72;
    final Duration duration = Duration(
      milliseconds:
          (rawDuration * settleFactor).round().clamp(minDuration, maxDuration),
    );
    final Offset? settleAnchor = _currentDragPosition ?? _dragStartPosition;

    setState(() {
      _isDragging = false;
      _dragStartPosition = null;
      _dragRegionSize = null;
      _currentDragPosition = null;
      _settleAnchorPosition = settleAnchor;
    });

    _lastDragPosition = null;
    _lastDragTimestamp = null;

    if (complete) {
      await _animationController.animateTo(
        1,
        duration: duration,
        curve: _kBookTurnForwardCurve,
      );
      if (!mounted) return;
      _completeTurn();
      return;
    }

    await _animationController.animateBack(
      0,
      duration: duration,
      curve: _kBookTurnRollbackCurve,
    );
    if (!mounted) return;
    _cancelTurn();
  }

  void _completeTurn() {
    if (_targetIndex == null) return;

    setState(() {
      _currentIndex = _targetIndex!;
      _previousIndex = _currentIndex;
      _targetIndex = null;
      _isDragging = false;
      _dragStartPosition = null;
      _dragRegionSize = null;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
    });

    _bendStrength = 0.42;
    _animationController.value = 0;
    widget.controller?._updatePage(_currentIndex);
    widget.onPageChanged?.call(_currentIndex);
  }

  void _cancelTurn() {
    setState(() {
      _previousIndex = _currentIndex;
      _targetIndex = null;
      _isDragging = false;
      _dragStartPosition = null;
      _dragRegionSize = null;
      _currentDragPosition = null;
      _settleAnchorPosition = null;
      _turnSource = _HsBookPageTurnSource.programmatic;
    });

    _bendStrength = 0.42;
    _animationController.value = 0;
  }

  double _deriveBendStrength({
    required Offset current,
    required Duration? timestamp,
  }) {
    if (_lastDragPosition == null) {
      _lastDragPosition = current;
      _lastDragTimestamp = timestamp;
      return _bendStrength;
    }

    final double distance = (current - _lastDragPosition!).distance;
    final int dtMicros = timestamp != null && _lastDragTimestamp != null
        ? timestamp.inMicroseconds - _lastDragTimestamp!.inMicroseconds
        : 16000;
    final double safeDt = dtMicros <= 0 ? 16000 : dtMicros.toDouble();
    final double speed = distance / safeDt * Duration.microsecondsPerSecond;
    final double normalized = (1 - (speed / 1800)).clamp(0.0, 1.0);
    final double bendStrength = 0.28 + (normalized * 0.72);

    _lastDragPosition = current;
    _lastDragTimestamp = timestamp;

    return bendStrength;
  }

  double _resolveBendStrength(double progress) {
    if (_isDragging) return _bendStrength;

    final double relaxed = 0.34;
    return (_bendStrength + ((relaxed - _bendStrength) * progress * 0.75))
        .clamp(0.22, 1.0);
  }

  double _resolveWaveStrength(double progress, double bendStrength) {
    final double eased = Curves.easeOutSine.transform(progress);
    return ((0.3 + (0.7 * bendStrength)) * (0.44 + (0.56 * eased)))
        .clamp(0.18, 1.0);
  }

  Color _resolveWarmShadow(double amount) {
    return Color.lerp(widget.shadowColor, const Color(0xFF625447), amount)!;
  }

  Color _resolveWarmPaper(double amount) {
    return Color.lerp(widget.paperBackColor, const Color(0xFFFFFBF2), amount)!;
  }

  Widget _buildPaperAtmosphere({
    required Alignment edgeBegin,
    required Alignment edgeEnd,
    required double progress,
    required double shadowStrength,
    required double lightStrength,
  }) {
    final Color warmShadow = _resolveWarmShadow(0.56);
    final Color warmLight = _resolveWarmPaper(0.84);

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: edgeBegin,
            end: edgeEnd,
            colors: [
              warmShadow.withValues(
                alpha: shadowStrength * (0.32 + (0.68 * progress)),
              ),
              Colors.transparent,
              warmLight.withValues(
                alpha: lightStrength * (0.28 + (0.72 * progress)),
              ),
            ],
            stops: const [0.0, 0.28, 1.0],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                warmLight.withValues(alpha: lightStrength * 0.42),
                Colors.transparent,
                warmShadow.withValues(alpha: shadowStrength * 0.24),
              ],
              stops: const [0.0, 0.44, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperTexture({
    required HsBookPageTurnDirection direction,
    required double progress,
    double intensity = 1,
  }) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BookPaperTexturePainter(
          direction: direction,
          progress: progress,
          lightColor: _resolveWarmPaper(0.9),
          shadowColor: _resolveWarmShadow(0.58),
          intensity: intensity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Offset _resolveTurnAnchor(Size size, double progress) {
    final Offset? currentDragPosition = _currentDragPosition;
    if (currentDragPosition != null) {
      return _projectTurnAnchor(
        rawAnchor: currentDragPosition,
        size: size,
        progress: progress,
        isSettling: false,
      );
    }

    final Offset? settleAnchorPosition = _settleAnchorPosition;
    if (settleAnchorPosition != null) {
      return _projectTurnAnchor(
        rawAnchor: settleAnchorPosition,
        size: size,
        progress: progress,
        isSettling: true,
      );
    }

    final bool isNext = _direction == HsBookPageTurnDirection.next;
    return Offset(
      isNext ? size.width : 0,
      size.height *
          (_turnSource == _HsBookPageTurnSource.gesture ? 0.92 : 0.84),
    );
  }

  Offset _projectTurnAnchor({
    required Offset rawAnchor,
    required Size size,
    required double progress,
    required bool isSettling,
  }) {
    final bool isNext = _direction == HsBookPageTurnDirection.next;
    final double clampedX = rawAnchor.dx.clamp(0.0, size.width);
    final double clampedY = rawAnchor.dy.clamp(0.0, size.height);
    final double cornerX = isNext ? size.width : 0;
    final double cornerY = size.height * 0.96;
    final double settleProgress = Curves.easeOutCubic.transform(progress);
    final double horizontalLag = (isSettling ? 0.2 : 0.12) +
        ((isSettling ? 0.18 : 0.1) * settleProgress);
    final double verticalLag = (isSettling ? 0.3 : 0.16) +
        ((isSettling ? 0.18 : 0.12) * settleProgress);

    return Offset(
      lerpDouble(clampedX, cornerX, horizontalLag)!.clamp(0.0, size.width),
      lerpDouble(clampedY, cornerY, verticalLag)!.clamp(0.0, size.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,
      child: ClipRect(
        clipBehavior: widget.clipBehavior,
        child: DecoratedBox(
          decoration: widget.decoration ?? const BoxDecoration(),
          child: _hasActiveTurn
              ? AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) => _buildAnimatingPages(),
                )
              : _buildPage(widget.children[_currentIndex], _currentIndex),
        ),
      ),
    );
  }

  Widget _buildAnimatingPages() {
    final int targetIndex = _targetIndex!;
    final double progress = _progress;
    final double bendStrength = _resolveBendStrength(progress);
    final double waveStrength = _resolveWaveStrength(progress, bendStrength);
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        if (size.isEmpty) {
          return _buildPage(widget.children[_previousIndex], _previousIndex);
        }

        final _BookTurnGeometry geometry = _BookTurnGeometry.resolve(
          size: size,
          direction: _direction,
          progress: progress,
          bendStrength: bendStrength,
          waveStrength: waveStrength,
          anchor: _resolveTurnAnchor(size, progress),
          turnSource: _turnSource,
          isDragging: _isDragging,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildRevealPage(
                widget.children[targetIndex], targetIndex, geometry),
            _buildRevealShadow(geometry),
            _buildCurrentPageSurface(geometry),
            _buildFoldCrease(geometry),
            _buildTurningStrip(geometry),
          ],
        );
      },
    );
  }

  Widget _buildRevealPage(
    Widget child,
    int index,
    _BookTurnGeometry geometry,
  ) {
    final Alignment alignment =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Alignment edgeBegin =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Alignment edgeEnd =
        geometry.isNext ? Alignment.centerLeft : Alignment.centerRight;

    return Opacity(
      opacity: geometry.revealOpacity,
      child: Transform.scale(
        scale: geometry.revealScale,
        alignment: alignment,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPage(child, index),
            _buildPaperAtmosphere(
              edgeBegin: edgeBegin,
              edgeEnd: edgeEnd,
              progress: geometry.progress,
              shadowStrength: 0.11,
              lightStrength: 0.06,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealShadow(_BookTurnGeometry geometry) {
    final Alignment horizontalBegin =
        geometry.isNext ? Alignment.centerLeft : Alignment.centerRight;
    final Alignment horizontalEnd =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Color warmShadow = _resolveWarmShadow(0.72);
    final Color warmLight = _resolveWarmPaper(0.78);
    final _BookPageTurnClipper clipper = _BookPageTurnClipper(
      direction: geometry.direction,
      foldTopX: geometry.foldTopX,
      foldBottomX: geometry.foldBottomX,
      curveDepth: geometry.curveDepth,
      topCurveDepth: geometry.topCurveDepth,
      bottomCurveDepth: geometry.bottomCurveDepth,
      upperControlY: geometry.upperControlY,
      lowerControlY: geometry.lowerControlY,
      trailing: true,
    );

    return IgnorePointer(
      child: ClipPath(
        clipper: clipper,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: horizontalBegin,
                  end: horizontalEnd,
                  colors: [
                    warmShadow.withValues(
                      alpha: 0.14 + (0.12 * geometry.progress),
                    ),
                    warmShadow.withValues(
                      alpha: 0.05 + (0.05 * geometry.progress),
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.28, 0.82],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    warmLight.withValues(
                      alpha: 0.03 + (0.034 * geometry.progress),
                    ),
                    Colors.transparent,
                    warmShadow.withValues(
                      alpha: 0.018 + (0.022 * geometry.progress),
                    ),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
            CustomPaint(
              painter: _BookRevealFoldAuraPainter(
                direction: geometry.direction,
                foldTopX: geometry.foldTopX,
                foldBottomX: geometry.foldBottomX,
                topCurveDepth: geometry.topCurveDepth,
                bottomCurveDepth: geometry.bottomCurveDepth,
                upperControlY: geometry.upperControlY,
                lowerControlY: geometry.lowerControlY,
                progress: geometry.progress,
                shadowColor: warmShadow,
                highlightColor: warmLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPageSurface(_BookTurnGeometry geometry) {
    final Alignment begin =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Alignment end =
        geometry.isNext ? Alignment.centerLeft : Alignment.centerRight;
    final Color warmShadow = _resolveWarmShadow(0.62);

    return ClipPath(
      clipper: _BookPageTurnClipper(
        direction: geometry.direction,
        foldTopX: geometry.foldTopX,
        foldBottomX: geometry.foldBottomX,
        curveDepth: geometry.curveDepth,
        topCurveDepth: geometry.topCurveDepth,
        bottomCurveDepth: geometry.bottomCurveDepth,
        upperControlY: geometry.upperControlY,
        lowerControlY: geometry.lowerControlY,
        trailing: false,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPage(widget.children[_previousIndex], _previousIndex),
          _buildPaperAtmosphere(
            edgeBegin: begin,
            edgeEnd: end,
            progress: geometry.progress,
            shadowStrength: 0.07,
            lightStrength: 0.045,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    warmShadow.withValues(
                      alpha: 0.08 + (0.05 * geometry.progress),
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.14],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldCrease(_BookTurnGeometry geometry) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BookFoldCreasePainter(
          direction: geometry.direction,
          foldTopX: geometry.foldTopX,
          foldBottomX: geometry.foldBottomX,
          curveDepth: geometry.curveDepth,
          topCurveDepth: geometry.topCurveDepth,
          bottomCurveDepth: geometry.bottomCurveDepth,
          upperControlY: geometry.upperControlY,
          lowerControlY: geometry.lowerControlY,
          progress: geometry.progress,
          shadowColor: _resolveWarmShadow(0.68),
          highlightColor: _resolveWarmPaper(0.88),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildTurningStrip(_BookTurnGeometry geometry) {
    final bool showFrontFace = geometry.showFrontFace;

    return Positioned(
      left: geometry.stripStartX,
      top: 0,
      width: geometry.stripWidth,
      height: geometry.size.height,
      child: IgnorePointer(
        child: Transform.translate(
          offset: geometry.turnOffset,
          child: Transform(
            alignment:
                geometry.isNext ? Alignment.centerLeft : Alignment.centerRight,
            transform: _buildStripTransform(geometry),
            child: ClipPath(
              clipper: _BookPageTurnClipper(
                direction: geometry.direction,
                foldTopX: geometry.localFoldTopX,
                foldBottomX: geometry.localFoldBottomX,
                curveDepth: geometry.localCurveDepth,
                topCurveDepth: geometry.localTopCurveDepth,
                bottomCurveDepth: geometry.localBottomCurveDepth,
                upperControlY: geometry.upperControlY,
                lowerControlY: geometry.lowerControlY,
                trailing: true,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: geometry.size.width,
                    maxWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    maxHeight: geometry.size.height,
                    child: Transform.translate(
                      offset: Offset(-geometry.stripStartX, 0),
                      child: SizedBox(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        child: showFrontFace
                            ? _buildPage(
                                widget.children[_previousIndex],
                                _previousIndex,
                              )
                            : _buildPaperBack(geometry),
                      ),
                    ),
                  ),
                  _buildTurningStripOverlay(showFrontFace, geometry),
                  _buildTurningStripThickness(showFrontFace, geometry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Matrix4 _buildStripTransform(_BookTurnGeometry geometry) {
    return Matrix4.identity()
      ..setEntry(3, 2, widget.perspective * 1.04)
      ..rotateZ(geometry.turnAngleZ)
      ..rotateX(geometry.turnAngleX)
      ..rotateY(geometry.turnAngleY);
  }

  Widget _buildPaperBack(_BookTurnGeometry geometry) {
    final Alignment begin =
        geometry.isNext ? Alignment.centerLeft : Alignment.centerRight;
    final Alignment end =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Color warmLight = _resolveWarmPaper(0.92);
    final Color warmMid = _resolveWarmPaper(0.36);
    final Color warmShadow = _resolveWarmShadow(0.38);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            warmLight,
            warmMid,
            widget.paperBackColor,
            Color.lerp(widget.paperBackColor, warmShadow, 0.14)!,
          ],
          stops: const [0.0, 0.22, 0.7, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  warmLight.withValues(alpha: 0.08),
                  Colors.transparent,
                  warmShadow.withValues(alpha: 0.035),
                ],
                stops: const [0.0, 0.46, 1.0],
              ),
            ),
          ),
          _buildPaperTexture(
            direction: geometry.direction,
            progress: geometry.progress,
            intensity: 0.82,
          ),
        ],
      ),
    );
  }

  Widget _buildTurningStripOverlay(
    bool showFrontFace,
    _BookTurnGeometry geometry,
  ) {
    final Alignment horizontalBegin =
        geometry.isNext ? Alignment.centerLeft : Alignment.centerRight;
    final Alignment horizontalEnd =
        geometry.isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Alignment diagonalBegin =
        geometry.isNext ? Alignment.topLeft : Alignment.topRight;
    final Alignment diagonalEnd =
        geometry.isNext ? Alignment.bottomRight : Alignment.bottomLeft;
    final Color warmShadow = _resolveWarmShadow(0.64);
    final Color warmLight = _resolveWarmPaper(0.86);
    final Color warmMid = _resolveWarmPaper(0.54);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: horizontalBegin,
              end: horizontalEnd,
              colors: showFrontFace
                  ? [
                      warmShadow.withValues(
                        alpha: 0.18 + (0.12 * geometry.progress),
                      ),
                      warmLight.withValues(
                        alpha: 0.034 + (0.03 * geometry.progress),
                      ),
                      warmShadow.withValues(
                        alpha: 0.024 + (0.024 * geometry.progress),
                      ),
                    ]
                  : [
                      warmShadow.withValues(
                        alpha: 0.07 + (0.05 * geometry.progress),
                      ),
                      warmMid.withValues(
                        alpha: 0.09 + (0.06 * geometry.progress),
                      ),
                      warmShadow.withValues(
                        alpha: 0.016 + (0.018 * geometry.progress),
                      ),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        if (!showFrontFace)
          _buildPaperTexture(
            direction: geometry.direction,
            progress: geometry.progress,
            intensity: 0.68,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: diagonalBegin,
              end: diagonalEnd,
              colors: [
                warmLight.withValues(
                  alpha: 0.06 + (0.04 * geometry.progress),
                ),
                Colors.transparent,
                warmShadow.withValues(
                  alpha: 0.018 + (0.022 * geometry.progress),
                ),
              ],
              stops: const [0.0, 0.34, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTurningStripThickness(
    bool showFrontFace,
    _BookTurnGeometry geometry,
  ) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BookPageThicknessPainter(
          direction: geometry.direction,
          foldTopX: geometry.localFoldTopX,
          foldBottomX: geometry.localFoldBottomX,
          topCurveDepth: geometry.localTopCurveDepth,
          bottomCurveDepth: geometry.localBottomCurveDepth,
          upperControlY: geometry.upperControlY,
          lowerControlY: geometry.lowerControlY,
          edgeThickness: geometry.edgeThickness,
          edgeLift: geometry.edgeLift,
          progress: geometry.progress,
          showFrontFace: showFrontFace,
          paperColor: widget.paperBackColor,
          shadowColor: widget.shadowColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildPage(Widget child, int index) {
    return KeyedSubtree(
      key: ValueKey('hs-book-page-$index'),
      child: child,
    );
  }
}

class _BookTurnGeometry {
  const _BookTurnGeometry({
    required this.size,
    required this.direction,
    required this.progress,
    required this.foldTopX,
    required this.foldBottomX,
    required this.curveDepth,
    required this.stripStartX,
    required this.stripWidth,
    required this.localFoldTopX,
    required this.localFoldBottomX,
    required this.localCurveDepth,
    required this.topCurveDepth,
    required this.bottomCurveDepth,
    required this.localTopCurveDepth,
    required this.localBottomCurveDepth,
    required this.upperControlY,
    required this.lowerControlY,
    required this.edgeThickness,
    required this.edgeLift,
    required this.turnAngleY,
    required this.turnAngleZ,
    required this.turnAngleX,
    required this.turnOffset,
    required this.revealScale,
    required this.revealOpacity,
  });

  factory _BookTurnGeometry.resolve({
    required Size size,
    required HsBookPageTurnDirection direction,
    required double progress,
    required double bendStrength,
    required double waveStrength,
    required Offset anchor,
    required _HsBookPageTurnSource turnSource,
    required bool isDragging,
  }) {
    final bool isNext = direction == HsBookPageTurnDirection.next;
    final bool isGestureTurn = turnSource == _HsBookPageTurnSource.gesture;
    final double rawHorizontalPull = isNext
        ? ((size.width - anchor.dx) / size.width).clamp(0.0, 1.0)
        : (anchor.dx / size.width).clamp(0.0, 1.0);
    final double anchorPull = isGestureTurn
        ? rawHorizontalPull
        : ((progress * 0.78) + (rawHorizontalPull * 0.22)).clamp(0.0, 1.0);
    final double rawBottomBias = Curves.easeOutCubic
        .transform((anchor.dy / size.height).clamp(0.0, 1.0));
    final double bottomBias =
        isGestureTurn ? rawBottomBias : (0.72 + (rawBottomBias * 0.2));
    final double curlProgress =
        isGestureTurn ? math.max(progress, anchorPull) : progress;
    final double curlEased = isGestureTurn
        ? Curves.easeOutCubic.transform(curlProgress)
        : Curves.easeInOutCubic.transform(curlProgress);
    final double angleProgress = isGestureTurn
        ? ((curlProgress * 0.74) + (progress * 0.26)).clamp(0.0, 1.0)
        : Curves.easeInOutCubic.transform(progress);
    final double liftProgress = (isGestureTurn ? 0.18 : 0.14) +
        ((isGestureTurn ? 0.82 : 0.8) * curlEased);
    final double travel = size.width *
        ((isGestureTurn ? 0.024 : 0.02) +
            ((isGestureTurn ? 0.87 : 0.84) * curlEased));
    final double baseFoldX = isNext ? size.width - travel : travel;
    final double slant = size.width *
        ((isGestureTurn ? 0.055 : 0.046) +
            (0.058 * bendStrength) +
            ((isGestureTurn ? 0.022 : 0.016) * waveStrength) +
            ((isGestureTurn ? 0.034 : 0.022) * bottomBias)) *
        liftProgress;
    final double shoulder = size.width *
        ((isGestureTurn ? 0.008 : 0.012) +
            ((isGestureTurn ? 0.016 : 0.012) * waveStrength) +
            ((isGestureTurn ? 0.014 : 0.008) *
                (1 - bottomBias.clamp(0.0, 1.0)))) *
        liftProgress;
    double foldTopX = isNext ? baseFoldX + shoulder : baseFoldX - shoulder;
    double foldBottomX = isNext ? baseFoldX - slant : baseFoldX + slant;

    foldTopX = foldTopX.clamp(size.width * 0.06, size.width * 0.94);
    foldBottomX = foldBottomX.clamp(size.width * 0.02, size.width * 0.98);

    final double curveDepth = size.width *
        ((isGestureTurn ? 0.042 : 0.036) +
            (0.048 * bendStrength) +
            ((isGestureTurn ? 0.02 : 0.014) * waveStrength) +
            ((isGestureTurn ? 0.024 : 0.014) * bottomBias)) *
        liftProgress;
    final double upperControlY = size.height *
        ((isGestureTurn ? 0.12 : 0.16) +
            ((isGestureTurn ? 0.12 : 0.08) * (1 - bottomBias)));
    final double lowerControlY = size.height *
        ((isGestureTurn ? 0.68 : 0.74) +
            ((isGestureTurn ? 0.16 : 0.1) * bottomBias));
    final double topCurveDepth = curveDepth *
        ((isGestureTurn ? 0.72 : 0.66) -
                ((isGestureTurn ? 0.22 : 0.16) * bottomBias))
            .clamp(0.42, 0.72);
    final double bottomCurveDepth = curveDepth *
        ((isGestureTurn ? 0.18 : 0.14) +
                ((isGestureTurn ? 0.26 : 0.18) * bottomBias))
            .clamp(0.14, 0.44);
    final double edgeThickness = size.shortestSide *
        ((isGestureTurn ? 0.005 : 0.004) +
            (0.004 * curlEased) +
            ((isGestureTurn ? 0.003 : 0.002) * bottomBias));
    final double edgeLift = size.height *
        ((isGestureTurn ? 0.006 : 0.004) +
            ((isGestureTurn ? 0.012 : 0.008) * bottomBias));
    final double stripStartX = isNext ? math.min(foldTopX, foldBottomX) : 0;
    final double stripWidth =
        (isNext ? size.width - stripStartX : math.max(foldTopX, foldBottomX))
            .clamp(1.0, size.width);
    final double localFoldTopX =
        (isNext ? foldTopX - stripStartX : foldTopX).clamp(0.0, stripWidth);
    final double localFoldBottomX =
        (isNext ? foldBottomX - stripStartX : foldBottomX)
            .clamp(0.0, stripWidth);

    return _BookTurnGeometry(
      size: size,
      direction: direction,
      progress: progress,
      foldTopX: foldTopX,
      foldBottomX: foldBottomX,
      curveDepth: curveDepth,
      stripStartX: stripStartX,
      stripWidth: stripWidth,
      localFoldTopX: localFoldTopX,
      localFoldBottomX: localFoldBottomX,
      localCurveDepth: math.min(curveDepth, stripWidth * 0.92),
      topCurveDepth: topCurveDepth,
      bottomCurveDepth: bottomCurveDepth,
      localTopCurveDepth: math.min(topCurveDepth, stripWidth * 0.76),
      localBottomCurveDepth: math.min(bottomCurveDepth, stripWidth * 0.56),
      upperControlY: upperControlY,
      lowerControlY: lowerControlY,
      edgeThickness: edgeThickness,
      edgeLift: edgeLift,
      turnAngleY: (isNext ? -1 : 1) *
          math.pi *
          ((isGestureTurn ? 0.84 : 0.78) * angleProgress),
      turnAngleZ: (isNext ? 1 : -1) *
          ((isGestureTurn ? 0.01 : 0.006) + (0.038 * bendStrength)) *
          curlEased,
      turnAngleX: -((isGestureTurn ? 0.005 : 0.003) +
              (0.016 * bendStrength) +
              ((isGestureTurn ? 0.014 : 0.008) * bottomBias)) *
          curlEased,
      turnOffset: Offset(
        (isNext ? -1 : 1) *
            size.width *
            ((isGestureTurn ? 0.004 : 0.0025) + (0.012 * bendStrength)) *
            curlEased,
        -size.height *
            ((isGestureTurn ? 0.004 : 0.002) +
                (0.01 * bendStrength) +
                ((isGestureTurn ? 0.014 : 0.008) * bottomBias)) *
            curlEased,
      ),
      revealScale: (isGestureTurn ? 0.996 : 0.998) +
          ((isGestureTurn ? 0.004 : 0.002) * curlEased),
      revealOpacity: (isGestureTurn ? 0.95 : 0.97) +
          ((isGestureTurn ? 0.05 : 0.03) * curlEased),
    );
  }

  final Size size;
  final HsBookPageTurnDirection direction;
  final double progress;
  final double foldTopX;
  final double foldBottomX;
  final double curveDepth;
  final double stripStartX;
  final double stripWidth;
  final double localFoldTopX;
  final double localFoldBottomX;
  final double localCurveDepth;
  final double topCurveDepth;
  final double bottomCurveDepth;
  final double localTopCurveDepth;
  final double localBottomCurveDepth;
  final double upperControlY;
  final double lowerControlY;
  final double edgeThickness;
  final double edgeLift;
  final double turnAngleY;
  final double turnAngleZ;
  final double turnAngleX;
  final Offset turnOffset;
  final double revealScale;
  final double revealOpacity;

  bool get isNext => direction == HsBookPageTurnDirection.next;

  bool get showFrontFace => turnAngleY.abs() <= (math.pi / 2);
}

class _BookPageTurnClipper extends CustomClipper<Path> {
  const _BookPageTurnClipper({
    required this.direction,
    required this.foldTopX,
    required this.foldBottomX,
    required this.curveDepth,
    required this.topCurveDepth,
    required this.bottomCurveDepth,
    required this.upperControlY,
    required this.lowerControlY,
    required this.trailing,
  });

  final HsBookPageTurnDirection direction;
  final double foldTopX;
  final double foldBottomX;
  final double curveDepth;
  final double topCurveDepth;
  final double bottomCurveDepth;
  final double upperControlY;
  final double lowerControlY;
  final bool trailing;

  @override
  Path getClip(Size size) {
    return _buildPageTurnPath(
      size: size,
      direction: direction,
      foldTopX: foldTopX,
      foldBottomX: foldBottomX,
      curveDepth: curveDepth,
      topCurveDepth: topCurveDepth,
      bottomCurveDepth: bottomCurveDepth,
      upperControlY: upperControlY,
      lowerControlY: lowerControlY,
      trailing: trailing,
    );
  }

  @override
  bool shouldReclip(covariant _BookPageTurnClipper oldClipper) {
    return oldClipper.direction != direction ||
        oldClipper.foldTopX != foldTopX ||
        oldClipper.foldBottomX != foldBottomX ||
        oldClipper.curveDepth != curveDepth ||
        oldClipper.topCurveDepth != topCurveDepth ||
        oldClipper.bottomCurveDepth != bottomCurveDepth ||
        oldClipper.upperControlY != upperControlY ||
        oldClipper.lowerControlY != lowerControlY ||
        oldClipper.trailing != trailing;
  }
}

class _BookFoldCreasePainter extends CustomPainter {
  const _BookFoldCreasePainter({
    required this.direction,
    required this.foldTopX,
    required this.foldBottomX,
    required this.curveDepth,
    required this.topCurveDepth,
    required this.bottomCurveDepth,
    required this.upperControlY,
    required this.lowerControlY,
    required this.progress,
    required this.shadowColor,
    required this.highlightColor,
  });

  final HsBookPageTurnDirection direction;
  final double foldTopX;
  final double foldBottomX;
  final double curveDepth;
  final double topCurveDepth;
  final double bottomCurveDepth;
  final double upperControlY;
  final double lowerControlY;
  final double progress;
  final Color shadowColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Path foldPath = _buildFoldCurvePath(
      size: size,
      direction: direction,
      foldTopX: foldTopX,
      foldBottomX: foldBottomX,
      curveDepth: curveDepth,
      topCurveDepth: topCurveDepth,
      bottomCurveDepth: bottomCurveDepth,
      upperControlY: upperControlY,
      lowerControlY: lowerControlY,
    );
    final Alignment begin = direction == HsBookPageTurnDirection.next
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Alignment end = direction == HsBookPageTurnDirection.next
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final Paint shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.6 + (2.2 * progress)
      ..color = shadowColor.withValues(alpha: 0.1 + (0.08 * progress))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1 + (0.6 * progress)
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          highlightColor.withValues(alpha: 0.44 + (0.12 * progress)),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(foldPath, shadowPaint);
    canvas.drawPath(foldPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BookFoldCreasePainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.foldTopX != foldTopX ||
        oldDelegate.foldBottomX != foldBottomX ||
        oldDelegate.curveDepth != curveDepth ||
        oldDelegate.topCurveDepth != topCurveDepth ||
        oldDelegate.bottomCurveDepth != bottomCurveDepth ||
        oldDelegate.upperControlY != upperControlY ||
        oldDelegate.lowerControlY != lowerControlY ||
        oldDelegate.progress != progress ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}

class _BookRevealFoldAuraPainter extends CustomPainter {
  const _BookRevealFoldAuraPainter({
    required this.direction,
    required this.foldTopX,
    required this.foldBottomX,
    required this.topCurveDepth,
    required this.bottomCurveDepth,
    required this.upperControlY,
    required this.lowerControlY,
    required this.progress,
    required this.shadowColor,
    required this.highlightColor,
  });

  final HsBookPageTurnDirection direction;
  final double foldTopX;
  final double foldBottomX;
  final double topCurveDepth;
  final double bottomCurveDepth;
  final double upperControlY;
  final double lowerControlY;
  final double progress;
  final Color shadowColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bool isNext = direction == HsBookPageTurnDirection.next;
    final double directionSign = isNext ? 1 : -1;
    final double eased = Curves.easeOutCubic.transform(progress);
    final Path basePath = _buildFoldCurvePath(
      size: size,
      direction: direction,
      foldTopX: foldTopX,
      foldBottomX: foldBottomX,
      curveDepth: 0,
      topCurveDepth: topCurveDepth,
      bottomCurveDepth: bottomCurveDepth,
      upperControlY: upperControlY,
      lowerControlY: lowerControlY,
    );
    final Path shadowPath = basePath.shift(
      Offset(size.width * 0.018 * directionSign * eased, 0),
    );
    final Path highlightPath = basePath.shift(
      Offset(size.width * 0.008 * directionSign * eased, 0),
    );

    final Paint shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11 + (8 * eased)
      ..color = shadowColor.withValues(alpha: 0.05 + (0.07 * eased))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final Paint innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4 + (3 * eased)
      ..color = shadowColor.withValues(alpha: 0.035 + (0.05 * eased))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 + (1.2 * eased)
      ..shader = LinearGradient(
        begin: isNext ? Alignment.centerLeft : Alignment.centerRight,
        end: isNext ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          highlightColor.withValues(alpha: 0.12 + (0.08 * eased)),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final Offset cornerCenter = Offset(
      foldBottomX + (size.width * 0.028 * directionSign * eased),
      size.height - (size.height * 0.016),
    );
    final double cornerRadius = size.shortestSide * (0.04 + (0.018 * eased));
    final Paint cornerShadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          shadowColor.withValues(alpha: 0.05 + (0.06 * eased)),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: cornerCenter, radius: cornerRadius),
      );
    final Paint cornerHighlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          highlightColor.withValues(alpha: 0.06 + (0.05 * eased)),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: cornerCenter.translate(-directionSign * 2, -2),
          radius: cornerRadius * 0.72,
        ),
      );

    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(shadowPath, innerShadowPaint);
    canvas.drawPath(highlightPath, highlightPaint);
    canvas.drawCircle(cornerCenter, cornerRadius, cornerShadowPaint);
    canvas.drawCircle(cornerCenter, cornerRadius * 0.72, cornerHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BookRevealFoldAuraPainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.foldTopX != foldTopX ||
        oldDelegate.foldBottomX != foldBottomX ||
        oldDelegate.topCurveDepth != topCurveDepth ||
        oldDelegate.bottomCurveDepth != bottomCurveDepth ||
        oldDelegate.upperControlY != upperControlY ||
        oldDelegate.lowerControlY != lowerControlY ||
        oldDelegate.progress != progress ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}

class _BookPaperTexturePainter extends CustomPainter {
  const _BookPaperTexturePainter({
    required this.direction,
    required this.progress,
    required this.lightColor,
    required this.shadowColor,
    required this.intensity,
  });

  final HsBookPageTurnDirection direction;
  final double progress;
  final Color lightColor;
  final Color shadowColor;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final bool isNext = direction == HsBookPageTurnDirection.next;
    final double progressFactor = (0.46 + (0.54 * progress)) * intensity;
    final double longStrokeWidth = math.max(0.8, size.shortestSide * 0.0022);
    final double shortStrokeWidth = math.max(0.6, size.shortestSide * 0.0014);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = longStrokeWidth
      ..shader = LinearGradient(
        begin: isNext ? Alignment.centerLeft : Alignment.centerRight,
        end: isNext ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          lightColor.withValues(alpha: 0.04 * progressFactor),
          Colors.transparent,
          shadowColor.withValues(alpha: 0.024 * progressFactor),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    const List<double> yStops = [0.14, 0.22, 0.34, 0.47, 0.61, 0.76];
    for (int i = 0; i < yStops.length; i++) {
      final double y = size.height * yStops[i];
      final double sway = size.width * (0.012 + (0.004 * i)) * progressFactor;
      final double depth =
          size.height * (0.004 + (0.0015 * i)) * progressFactor;
      final double startX = size.width * (isNext ? 0.06 : 0.1);
      final double endX = size.width * (isNext ? 0.94 : 0.9);
      final Path path = Path()
        ..moveTo(startX, y)
        ..cubicTo(
          size.width * 0.28 + (isNext ? sway : -sway),
          y - depth,
          size.width * 0.68 + (isNext ? -sway : sway),
          y + depth,
          endX,
          y + (depth * 0.24),
        );
      canvas.drawPath(path, linePaint);
    }

    final Paint fiberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = shortStrokeWidth
      ..color = lightColor.withValues(alpha: 0.05 * progressFactor);
    final Paint fiberShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = shortStrokeWidth
      ..color = shadowColor.withValues(alpha: 0.024 * progressFactor);

    const List<Offset> fiberCenters = [
      Offset(0.18, 0.18),
      Offset(0.36, 0.3),
      Offset(0.7, 0.24),
      Offset(0.24, 0.56),
      Offset(0.62, 0.6),
      Offset(0.78, 0.78),
    ];

    for (int i = 0; i < fiberCenters.length; i++) {
      final Offset factor = fiberCenters[i];
      final double cx = size.width * (isNext ? factor.dx : (1 - factor.dx));
      final double cy = size.height * factor.dy;
      final double halfLength =
          size.shortestSide * (0.012 + (0.003 * (i % 3))) * progressFactor;
      canvas.drawLine(
        Offset(cx - halfLength, cy - (halfLength * 0.22)),
        Offset(cx + halfLength, cy + (halfLength * 0.22)),
        i.isEven ? fiberPaint : fiberShadowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BookPaperTexturePainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.progress != progress ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.intensity != intensity;
  }
}

class _BookPageThicknessPainter extends CustomPainter {
  const _BookPageThicknessPainter({
    required this.direction,
    required this.foldTopX,
    required this.foldBottomX,
    required this.topCurveDepth,
    required this.bottomCurveDepth,
    required this.upperControlY,
    required this.lowerControlY,
    required this.edgeThickness,
    required this.edgeLift,
    required this.progress,
    required this.showFrontFace,
    required this.paperColor,
    required this.shadowColor,
  });

  final HsBookPageTurnDirection direction;
  final double foldTopX;
  final double foldBottomX;
  final double topCurveDepth;
  final double bottomCurveDepth;
  final double upperControlY;
  final double lowerControlY;
  final double edgeThickness;
  final double edgeLift;
  final double progress;
  final bool showFrontFace;
  final Color paperColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bool isNext = direction == HsBookPageTurnDirection.next;
    final double directionSign = isNext ? 1 : -1;
    final Offset shift = Offset(directionSign * edgeThickness * 0.82, edgeLift);
    final Path edgePath = _buildFoldCurvePath(
      size: size,
      direction: direction,
      foldTopX: foldTopX,
      foldBottomX: foldBottomX,
      curveDepth: 0,
      topCurveDepth: topCurveDepth,
      bottomCurveDepth: bottomCurveDepth,
      upperControlY: upperControlY,
      lowerControlY: lowerControlY,
    ).shift(shift);

    final Alignment begin =
        isNext ? Alignment.centerLeft : Alignment.centerRight;
    final Alignment end = isNext ? Alignment.centerRight : Alignment.centerLeft;
    final Color warmShadow =
        Color.lerp(shadowColor, const Color(0xFF6A5A49), 0.64)!;
    final Color warmLight =
        Color.lerp(paperColor, const Color(0xFFFFFCF4), 0.86)!;
    final Color midColor = showFrontFace
        ? Color.lerp(warmLight, paperColor, 0.22)!
        : Color.lerp(paperColor, warmLight, 0.12)!;

    final Paint baseShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = edgeThickness * (1.2 + (0.38 * progress))
      ..color = warmShadow.withValues(alpha: 0.05 + (0.05 * progress))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    final Paint thicknessPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = edgeThickness * (0.72 + (0.22 * progress))
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Color.lerp(midColor, warmLight, 0.46)!,
          midColor,
          Color.lerp(paperColor, warmShadow, 0.16)!,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, edgeThickness * 0.22)
      ..color = warmLight.withValues(alpha: 0.34 + (0.12 * progress));

    final Offset cornerCenter = Offset(
      foldBottomX + (directionSign * edgeThickness * 0.54),
      size.height - (edgeLift * 0.18),
    );
    final double cornerRadius = edgeThickness * (0.9 + (0.42 * progress));
    final Paint cornerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          warmLight.withValues(alpha: 0.18 + (0.1 * progress)),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: cornerCenter, radius: cornerRadius),
      );

    canvas.drawPath(edgePath, baseShadowPaint);
    canvas.drawPath(edgePath, thicknessPaint);
    canvas.drawPath(edgePath, rimPaint);
    canvas.drawCircle(cornerCenter, cornerRadius, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _BookPageThicknessPainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.foldTopX != foldTopX ||
        oldDelegate.foldBottomX != foldBottomX ||
        oldDelegate.topCurveDepth != topCurveDepth ||
        oldDelegate.bottomCurveDepth != bottomCurveDepth ||
        oldDelegate.upperControlY != upperControlY ||
        oldDelegate.lowerControlY != lowerControlY ||
        oldDelegate.edgeThickness != edgeThickness ||
        oldDelegate.edgeLift != edgeLift ||
        oldDelegate.progress != progress ||
        oldDelegate.showFrontFace != showFrontFace ||
        oldDelegate.paperColor != paperColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

Path _buildPageTurnPath({
  required Size size,
  required HsBookPageTurnDirection direction,
  required double foldTopX,
  required double foldBottomX,
  required double curveDepth,
  required double topCurveDepth,
  required double bottomCurveDepth,
  required double upperControlY,
  required double lowerControlY,
  required bool trailing,
}) {
  final bool isNext = direction == HsBookPageTurnDirection.next;
  final Path path = Path();

  if (trailing) {
    if (isNext) {
      path
        ..moveTo(foldTopX, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(foldBottomX, size.height)
        ..cubicTo(
          foldBottomX + bottomCurveDepth,
          lowerControlY,
          foldTopX + topCurveDepth,
          upperControlY,
          foldTopX,
          0,
        )
        ..close();
      return path;
    }

    path
      ..moveTo(0, 0)
      ..lineTo(foldTopX, 0)
      ..cubicTo(
        foldTopX - topCurveDepth,
        upperControlY,
        foldBottomX - bottomCurveDepth,
        lowerControlY,
        foldBottomX,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  if (isNext) {
    path
      ..moveTo(0, 0)
      ..lineTo(foldTopX, 0)
      ..cubicTo(
        foldTopX + topCurveDepth,
        upperControlY,
        foldBottomX + bottomCurveDepth,
        lowerControlY,
        foldBottomX,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  path
    ..moveTo(foldTopX, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(foldBottomX, size.height)
    ..cubicTo(
      foldBottomX - bottomCurveDepth,
      lowerControlY,
      foldTopX - topCurveDepth,
      upperControlY,
      foldTopX,
      0,
    )
    ..close();
  return path;
}

Path _buildFoldCurvePath({
  required Size size,
  required HsBookPageTurnDirection direction,
  required double foldTopX,
  required double foldBottomX,
  required double curveDepth,
  required double topCurveDepth,
  required double bottomCurveDepth,
  required double upperControlY,
  required double lowerControlY,
}) {
  final bool isNext = direction == HsBookPageTurnDirection.next;

  return Path()
    ..moveTo(foldTopX, 0)
    ..cubicTo(
      isNext ? foldTopX + topCurveDepth : foldTopX - topCurveDepth,
      upperControlY,
      isNext ? foldBottomX + bottomCurveDepth : foldBottomX - bottomCurveDepth,
      lowerControlY,
      foldBottomX,
      size.height,
    );
}
