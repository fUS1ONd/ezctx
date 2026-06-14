import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

class GlassDropdownItem {
  const GlassDropdownItem({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

/// Стеклянный dropdown, появляющийся под кнопкой ⋮ с FadeTransition.
/// Тап вне меню закрывает его через прозрачный барьер.
class GlassDropdownMenu extends StatefulWidget {
  const GlassDropdownMenu({super.key, required this.items});

  final List<GlassDropdownItem> items;

  @override
  State<GlassDropdownMenu> createState() => _GlassDropdownMenuState();
}

class _GlassDropdownMenuState extends State<GlassDropdownMenu>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    final palette = context.palette;
    final box = context.findRenderObject()! as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(builder: (ctx) {
      final sw = MediaQuery.of(ctx).size.width;
      final right = sw - (pos.dx + size.width);
      final top = pos.dy + size.height + 4;
      return _buildOverlay(palette: palette, top: top, right: right);
    });
    Overlay.of(context).insert(_overlay!);
    _ctrl.forward(from: 0);
    setState(() {});
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  Widget _buildOverlay({
    required AppPalette palette,
    required double top,
    required double right,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        Positioned(
          top: top,
          right: right,
          child: FadeTransition(
            opacity: _opacity,
            // Material с прозрачным фоном даёт корректный DefaultTextStyle:
            // контент OverlayEntry лежит вне Scaffold, иначе Text жёлтый
            // с двойным подчёркиванием.
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 180),
                    decoration: BoxDecoration(
                      color: palette.glassBgDeep,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.glassRim, width: 0.5),
                      boxShadow: [palette.shadowDeep],
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.items
                            .map((item) => _itemTile(item, palette))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemTile(GlassDropdownItem item, AppPalette palette) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _close();
        item.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Text(
          item.label,
          style: AppTextStyles.body.copyWith(color: palette.ink1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: _overlay == null ? _open : _close,
        child: Center(
          child: Icon(Icons.more_vert, color: palette.ink2, size: 24),
        ),
      ),
    );
  }
}
