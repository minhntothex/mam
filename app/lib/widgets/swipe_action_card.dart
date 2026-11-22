import 'package:material_ui/material_ui.dart';

class SwipeActionItem {
  const SwipeActionItem({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
}

/// Horizontal swipe-left reveal container for bill cards.
///
/// Works with both mobile touch drag and desktop mouse/trackpad drag, snaps
/// smoothly to reveal right-aligned action buttons, and closes cleanly when
/// another card opens or when the open card itself is tapped.
class SwipeActionCard extends StatefulWidget {
  const SwipeActionCard({
    super.key,
    required this.child,
    required this.actions,
    required this.isOpen,
    required this.onOpenChanged,
    this.actionWidth = 78,
    this.borderRadius = 14,
  });

  final Widget child;
  final List<SwipeActionItem> actions;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final double actionWidth;
  final double borderRadius;

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  double _dragExtent = 0;
  double _animStart = 0;
  double _animEnd = 0;

  double get _maxExtent => widget.actions.length * widget.actionWidth;

  @override
  void initState() {
    super.initState();
    _dragExtent = widget.isOpen ? -_maxExtent : 0;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          final t = Curves.easeOutCubic.transform(_anim.value);
          _dragExtent = _animStart + (_animEnd - _animStart) * t;
        });
      });
  }

  @override
  void didUpdateWidget(covariant SwipeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _animateTo(widget.isOpen ? -_maxExtent : 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _anim.stop();
    _animStart = _dragExtent;
    _animEnd = target;
    _anim.forward(from: 0);
  }

  void _onDragStart(DragStartDetails details) {
    _anim.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_dragExtent + details.delta.dx).clamp(-_maxExtent, 0.0);
    if (next != _dragExtent) {
      setState(() => _dragExtent = next);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        velocity < -260 || (velocity <= 260 && _dragExtent.abs() > _maxExtent * 0.35);
    _animateTo(shouldOpen ? -_maxExtent : 0);
    if (shouldOpen != widget.isOpen) {
      widget.onOpenChanged(shouldOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = _maxExtent;
    final radius = BorderRadius.circular(widget.borderRadius);
    final showActions = _dragExtent < -0.5;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          if (showActions)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: maxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in widget.actions)
                        Expanded(
                          child: Material(
                            color: action.backgroundColor,
                            child: InkWell(
                              onTap: () {
                                _animateTo(0);
                                widget.onOpenChanged(false);
                                action.onTap();
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    action.icon,
                                    size: 20,
                                    color: action.foregroundColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    action.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: action.foregroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: widget.isOpen
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _animateTo(0);
                        widget.onOpenChanged(false);
                      },
                      child: AbsorbPointer(child: widget.child),
                    )
                  : widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
