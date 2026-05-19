import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/providers/history_provider.dart';
import '../../features/history/history_entry.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

/// Экран истории. Подписан на `historyProvider` — обновится сам, как только
/// репозиторий получит реальные данные.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(historyProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'История',
                      style: AppTextStyles.display.copyWith(
                          color: palette.ink1, fontSize: 30),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: asyncEntries.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (entries) => entries.isEmpty
                      ? const _EmptyHistory()
                      : _HistoryList(entries: entries),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});
  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _HistoryTile(entry: entries[i], now: now),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.now});
  final HistoryEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: AppGradients.accent,
            ),
            child:
                const Icon(Icons.audiotrack, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading
                      .copyWith(color: palette.ink1, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.relativeDate(now)}  ·  ${entry.sizeFormatted}  ·  ${entry.durationFormatted}',
                  style: AppTextStyles.label.copyWith(color: palette.ink2),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8, right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              color: palette.inkLine,
            ),
            child: Text(
              entry.language.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05,
                color: palette.ink2,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.ink3, size: 22),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: palette.inkLine,
              ),
              child: Icon(Icons.history,
                  size: 32, color: palette.ink3),
            ),
            const SizedBox(height: 14),
            Text('Расшифровок пока нет',
                style: AppTextStyles.heading.copyWith(color: palette.ink1)),
            const SizedBox(height: 6),
            Text(
              'Готовые транскрипции появятся здесь автоматически после первой обработки.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body
                  .copyWith(color: palette.ink2, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Не удалось загрузить историю: $message',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.bad),
        ),
      ),
    );
  }
}
