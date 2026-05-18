import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/groq_key_pool.dart';

/// Отображает статус одного API-ключа: зелёный «Активен» или красный «До HH:MM:SS».
///
/// Для заблокированных ключей запускает Timer.periodic(1s) — таймер обратного отсчёта.
/// Timer отменяется в dispose() чтобы избежать утечек (T-04-08).
class KeyStatusTile extends StatefulWidget {
  const KeyStatusTile({super.key, required this.status});

  final KeyStatus status;

  @override
  State<KeyStatusTile> createState() => _KeyStatusTileState();
}

class _KeyStatusTileState extends State<KeyStatusTile> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfBlocked();
  }

  @override
  void didUpdateWidget(KeyStatusTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пересоздаём таймер при смене типа статуса (Active↔Blocked)
    if (widget.status.runtimeType != oldWidget.status.runtimeType) {
      _timer?.cancel();
      _timer = null;
      _startTimerIfBlocked();
    }
  }

  @override
  void dispose() {
    // Обязательно отменяем таймер — иначе setState() после dispose() (T-04-08)
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfBlocked() {
    if (widget.status is BlockedKeyStatus) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Форматирует Duration в строку HH:MM:SS.
  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _activeBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: AppColors.good),
        const SizedBox(width: AppSpacing.xs),
        Text('Активен', style: AppTextStyles.label),
      ],
    );
  }

  Widget _blockedBadge(String countdown) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: AppColors.bad),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'До $countdown',
          style: AppTextStyles.label.copyWith(color: AppColors.bad),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    if (s is BlockedKeyStatus) {
      final remaining = s.blockedUntil.difference(DateTime.now());
      // Если блокировка истекла — показываем как активный
      if (remaining.isNegative) return _activeBadge();
      return _blockedBadge(_formatRemaining(remaining));
    }
    return _activeBadge();
  }
}
