import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/providers/history_provider.dart';
import '../../core/services/clipboard_service.dart';
import '../../features/history/filter_notifier.dart';
import '../../features/history/filter_spec.dart';
import '../../features/history/history_entry.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_confirm_dialog.dart';
import '../widgets/gradient_background.dart';
import '../widgets/long_press_bottom_sheet.dart';
import '../widgets/primary_button.dart';
import 'detail_screen.dart';

/// Парсит строку сниппета с маркерами FTS5 «» в стилизованный RichText.
/// Нормальный текст: palette.ink2, w400. Выделенный: palette.accent, w700.
/// Публичная функция — используется в widget-тестах (Task 3).
///
/// CR-06: маркеры \x02 (STX) и \x03 (ETX) — управляющие символы, не встречаются
/// в тексте расшифровок. Ранее использовались «», которые ложно подсвечивали
/// натуральные цитаты в русском тексте.
///
/// Алгоритм: split по \x02, затем каждая часть начиная с 1-й разбивается по \x03
/// на (выделено, обычный).
Widget buildSnippet(String snippet, AppPalette palette) {
  final spans = <TextSpan>[];

  TextStyle normal() => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: palette.ink2,
        height: 1.4,
      );
  TextStyle highlight() => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: palette.accent,
        height: 1.4,
      );

  final outer = snippet.split('\x02');
  for (var i = 0; i < outer.length; i++) {
    if (i == 0) {
      // Часть до первого \x02: всегда обычный текст.
      if (outer[i].isNotEmpty) spans.add(TextSpan(text: outer[i], style: normal()));
    } else {
      // Часть после \x02: до \x03 — выделено, после \x03 — обычный текст.
      final inner = outer[i].split('\x03');
      if (inner[0].isNotEmpty) spans.add(TextSpan(text: inner[0], style: highlight()));
      if (inner.length > 1 && inner[1].isNotEmpty) {
        spans.add(TextSpan(text: inner[1], style: normal()));
      }
    }
  }

  return RichText(
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(children: spans),
  );
}

/// Экран истории. ConsumerStatefulWidget — управляет контроллером поиска,
/// скролла и пагинацией (BRWS-02). Подписан на searchResultsProvider.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  // Guard против накопления offset: loadMore вызывается однократно до следующего рендера.
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Подгружаем следующую страницу при приближении к концу списка (BRWS-02).
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Вызывает loadMore при приближении к концу скролла на 300px (BRWS-02).
  /// Guard _isLoadingMore предотвращает дублирующие вызовы за один кадр.
  /// Guard reachedEnd (фикс #1): если уже отображено меньше записей, чем
  /// запрошено всеми загруженными страницами (pageCount * pageSize) — данных
  /// больше нет, loadMore() не вызывается (иначе offset рос бы бесконечно).
  void _onScroll() {
    if (_isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final spec = ref.read(filterNotifierProvider);
      final pageCount = spec.offset ~/ spec.pageSize + 1;
      final entries = ref.read(searchResultsProvider).valueOrNull ?? const [];
      if (entries.length < pageCount * spec.pageSize) return;
      _isLoadingMore = true;
      ref.read(filterNotifierProvider.notifier).loadMore();
      // Сбрасываем флаг после следующего кадра, чтобы данные успели прийти.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isLoadingMore = false;
      });
    }
  }

  /// Деструктивное удаление всей истории с подтверждением (ACT-04, T-03-09).
  Future<void> _onClearAll() async {
    // Захват repo ДО await — ref недоступен после dispose (CR-01, T-03-08).
    final repo = ref.read(historyRepositoryProvider);
    final confirmed = await GlassConfirmDialog.show(
      context,
      title: 'Очистить историю?',
      body: 'Все записи будут удалены безвозвратно.',
      confirmLabel: 'Очистить',
    );
    if (!confirmed) return;
    await repo.clear();
  }

  /// Открывает bottom sheet с действиями над записью по long-press (D-06, T-03-08).
  void _showLongPressSheet(BuildContext ctx, WidgetRef widgetRef, HistoryEntry entry) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LongPressBottomSheet(
        entry: entry,
        onFavoriteToggle: () async {
          // Захват repo ДО await (T-03-08). try/catch — CR-05: Future иначе discarded без фидбека.
          final repo = widgetRef.read(historyRepositoryProvider);
          try {
            await repo.update(entry.copyWith(isFavorite: !entry.isFavorite));
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Не удалось сохранить')),
              );
            }
          }
        },
        onCopy: () async {
          try {
            await ClipboardService.copyText(entry.plainText);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Ошибка копирования: $e')),
              );
            }
          }
        },
        onShare: () async {
          try {
            await Share.share(entry.plainText);
          } catch (e, st) {
            debugPrint('share error: $e\n$st');
          }
        },
        onDelete: () async {
          // Захват repo ДО await — widgetRef недоступен после dispose (CR-02, T-03-08).
          final repo = widgetRef.read(historyRepositoryProvider);
          final confirmed = await GlassConfirmDialog.show(
            ctx,
            title: 'Удалить запись?',
            body: 'Это действие нельзя отменить.',
            confirmLabel: 'Удалить',
          );
          if (!confirmed) return;
          await repo.remove(entry.id);
        },
      ),
    );
  }

  /// Открывает bottom sheet с расширенными фильтрами (UI-SPEC §4).
  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FiltersSheet(
        initialSpec: ref.read(filterNotifierProvider),
        onApply: (dateRange, languages, providers) {
          ref
              .read(filterNotifierProvider.notifier)
              .applySheetFilters(
                dateRange: dateRange,
                languages: languages,
                providers: providers,
              );
        },
        onReset: () {
          // Сбрасываем только поля sheet (дата/язык/провайдер), не трогаем чипы (D-06).
          ref.read(filterNotifierProvider.notifier).applySheetFilters(
            dateRange: null,
            languages: const {},
            providers: const {},
          );
        },
        loadLanguages: () => ref.read(historyRepositoryProvider).distinctLanguages(),
        loadProviders: () => ref.read(historyRepositoryProvider).distinctProviders(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся на реактивный поток результатов с фильтрами (SRCH-01..03).
    final asyncEntries = ref.watch(searchResultsProvider);
    final spec = ref.watch(filterNotifierProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Заголовок «История» + overflow-меню «Очистить историю» (ACT-04, Pitfall 7).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'История',
                      style: AppTextStyles.display.copyWith(
                          color: palette.ink1, fontSize: 30),
                    ),
                    const Spacer(),
                    // Overflow-меню: «Очистить историю» (D-07 Claude's Discretion).
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: palette.ink2),
                      tooltip: 'Дополнительно',
                      onSelected: (value) {
                        if (value == 'clear') _onClearAll();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem<String>(
                          value: 'clear',
                          child: Text('Очистить историю'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Строка поиска (UI-SPEC §1): всегда видна, hint, trailing X.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GlassCard(
                  flat: true,
                  borderRadius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: palette.ink3, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: AppTextStyles.body
                              .copyWith(color: palette.ink1),
                          decoration: InputDecoration(
                            hintText: 'Поиск по расшифровкам',
                            hintStyle: AppTextStyles.body
                                .copyWith(color: palette.ink3),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10),
                          ),
                          // Вызов setSearch — debounce 250 мс выполняется в FilterNotifier (не здесь — Pitfall).
                          onChanged: (value) {
                            ref
                                .read(filterNotifierProvider.notifier)
                                .setSearch(value);
                          },
                        ),
                      ),
                      // Кнопка очистки — видна только при непустом тексте (SRCH-03).
                      if (spec.searchTerm.isNotEmpty ||
                          _searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            ref
                                .read(filterNotifierProvider.notifier)
                                .setSearch('');
                          },
                          child: Icon(Icons.close_rounded,
                              color: palette.ink2, size: 20),
                        ),
                    ],
                  ),
                ),
              ),

              // Ряд чипов + кнопка фильтров (UI-SPEC §2–3).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Чипы длительности (radio-группа, D-04).
                            _FilterChip(
                              label: '< 10 мин',
                              isActive: spec.durationPreset ==
                                  DurationPreset.short,
                              onTap: () => ref
                                  .read(filterNotifierProvider.notifier)
                                  .setDurationPreset(
                                    spec.durationPreset ==
                                            DurationPreset.short
                                        ? null
                                        : DurationPreset.short,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '10–60 мин',
                              isActive: spec.durationPreset ==
                                  DurationPreset.medium,
                              onTap: () => ref
                                  .read(filterNotifierProvider.notifier)
                                  .setDurationPreset(
                                    spec.durationPreset ==
                                            DurationPreset.medium
                                        ? null
                                        : DurationPreset.medium,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '> 1 ч',
                              isActive: spec.durationPreset ==
                                  DurationPreset.long,
                              onTap: () => ref
                                  .read(filterNotifierProvider.notifier)
                                  .setDurationPreset(
                                    spec.durationPreset ==
                                            DurationPreset.long
                                        ? null
                                        : DurationPreset.long,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            // Тоггл «Сегодня» (D-05).
                            _FilterChip(
                              label: 'Сегодня',
                              isActive: spec.todayOnly,
                              onTap: () => ref
                                  .read(filterNotifierProvider.notifier)
                                  .setTodayOnly(!spec.todayOnly),
                            ),
                            const SizedBox(width: 8),
                            // Тоггл «★ Избранное» (D-05).
                            _FilterChip(
                              label: '★ Избранное',
                              isActive: spec.favoriteOnly,
                              onTap: () => ref
                                  .read(filterNotifierProvider.notifier)
                                  .setFavoriteOnly(!spec.favoriteOnly),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Кнопка расширенных фильтров с бейджем (UI-SPEC §3).
                    _FilterIconButton(
                      activeCount: spec.activeSheetFilterCount,
                      onPressed: _showFiltersSheet,
                    ),
                  ],
                ),
              ),

              // Основное содержимое экрана.
              Expanded(
                child: asyncEntries.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (entries) {
                    // D-09: «Ничего не найдено» при активных фильтрах/поиске без результатов.
                    if (entries.isEmpty &&
                        (spec.searchTerm.isNotEmpty ||
                            spec.hasActiveFilters)) {
                      return _EmptyNoResults(
                        onReset: () {
                          _searchController.clear();
                          ref
                              .read(filterNotifierProvider.notifier)
                              .resetAll();
                        },
                      );
                    }
                    if (entries.isEmpty) return const _EmptyHistory();
                    return _HistoryList(
                      entries: entries,
                      scrollController: _scrollController,
                      widgetRef: ref,
                      spec: spec,
                      onLongPress: _showLongPressSheet,
                    );
                  },
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

/// Кнопка-иконка фильтров с бейджем-счётчиком активных полей (UI-SPEC §3).
class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isActive = activeCount > 0;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Кнопка-иконка настроек фильтров.
          IconButton(
            tooltip: 'Фильтры',
            onPressed: onPressed,
            icon: Icon(
              Icons.tune_rounded,
              // Accent цвет иконки при наличии активных фильтров (UI-SPEC §3).
              color: isActive ? palette.accent : palette.ink2,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          // Бейдж-счётчик активных фильтров (показывается при count > 0).
          if (isActive)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Кастомный чип-фильтр с поддержкой активного/неактивного состояния (UI-SPEC §2).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            // Активный: полупрозрачный accent, неактивный: glassBgFlat (UI-SPEC §2).
            color: isActive
                ? palette.accent.withValues(alpha: 0.12)
                : palette.glassBgFlat,
            border: Border.all(
              color: isActive ? palette.accent : palette.glassRim,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? palette.accent : palette.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Список записей истории с поддержкой ленивой пагинации (BRWS-02),
/// свайп-удаления (D-05) и long-press bottom sheet (D-06).
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.scrollController,
    required this.widgetRef,
    required this.spec,
    required this.onLongPress,
  });

  final List<HistoryEntry> entries;
  final ScrollController scrollController;

  /// ref из ConsumerStatefulWidget — нужен для Dismissible.onDismissed и навигации.
  final WidgetRef widgetRef;

  /// Текущий FilterSpec — для прокидывания searchTerm в DetailArgs.
  final FilterSpec spec;

  /// Колбэк long-press: открывает LongPressBottomSheet (D-06).
  final void Function(BuildContext, WidgetRef, HistoryEntry) onLongPress;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final palette = context.palette;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final entry = entries[i];

        return Dismissible(
          // Уникальный ключ по id — обязателен (T-03-10, Pitfall 4).
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          // Красный фон со значком удаления (UI-SPEC §Swipe-Dismiss).
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: palette.bad,
            child: const Icon(Icons.delete_outline,
                color: Colors.white, size: 24),
          ),
          onDismissed: (direction) async {
            // Захват repo и messenger ДО await: после await list rebuild снимает ctx с дерева
            // и ctx.mounted == false → SnackBar не показался бы (CR-03, T-03-08).
            final repo = widgetRef.read(historyRepositoryProvider);
            final messenger = ScaffoldMessenger.of(ctx);
            final errorBg = ctx.palette.bad;
            try {
              await repo.remove(entry.id);
            } catch (e) {
              // При ошибке drift восстановит запись через watch() (Pitfall 1, T-03-07).
              messenger.showSnackBar(
                SnackBar(
                  content: const Text(
                    'Не удалось удалить',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: errorBg,
                  behavior: SnackBarBehavior.floating,
                  shape: const StadiumBorder(),
                  width: 210,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              );
            }
          },
          child: GestureDetector(
            // Long-press → bottom sheet с действиями (D-06).
            onLongPress: () => onLongPress(ctx, widgetRef, entry),
            // Тап → переход на detail-экран с searchTerm (BRWS-03).
            onTap: () {
              Navigator.pushNamed(
                ctx,
                AppConstants.routeHistoryDetail,
                arguments: DetailArgs(
                  entry: entry,
                  // Прокидываем searchTerm только если он непустой (D-08).
                  searchTerm: spec.searchTerm.isEmpty ? null : spec.searchTerm,
                ),
              );
            },
            child: _HistoryTile(entry: entry, now: now),
          ),
        );
      },
    );
  }
}

/// Карточка записи в списке истории. При активном поиске показывает
/// сниппет с подсветкой совпадения (BRWS-01, D-08).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.now});

  final HistoryEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GlassCard(
      flat: true,
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Иконка-аватар с акцентным градиентом.
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
                // Заголовок записи.
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading
                      .copyWith(color: palette.ink1, fontSize: 15),
                ),
                const SizedBox(height: 2),
                // Мета-строка: дата · размер · длительность.
                Text(
                  '${entry.relativeDate(now)}  ·  ${entry.sizeFormatted}  ·  ${entry.durationFormatted}',
                  style: AppTextStyles.label.copyWith(color: palette.ink2),
                ),
                // Сниппет с подсветкой — только при активном поиске с совпадением (D-08, BRWS-01).
                if (entry.snippet != null) ...[
                  const SizedBox(height: 4),
                  buildSnippet(entry.snippet!, palette),
                ],
              ],
            ),
          ),
          // Языковый пилл.
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

/// Заглушка «Ничего не найдено» — активны фильтры/поиск, но результатов нет (D-09).
/// Отличается от _EmptyHistory: другой icon, текст и кнопка сброса.
class _EmptyNoResults extends StatelessWidget {
  const _EmptyNoResults({required this.onReset});

  final VoidCallback onReset;

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
              child: Icon(Icons.search_off_rounded,
                  size: 32, color: palette.ink3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: AppTextStyles.heading.copyWith(color: palette.ink1),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить запрос или сбросить фильтры.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: palette.ink2),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onReset,
              child: Text(
                'Сбросить фильтры',
                style: TextStyle(color: palette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Заглушка «История пуста» — нет ни одной расшифровки (BRWS-04).
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
              child: Icon(Icons.history, size: 32, color: palette.ink3),
            ),
            const SizedBox(height: 14),
            Text('Расшифровок пока нет',
                style:
                    AppTextStyles.heading.copyWith(color: palette.ink1)),
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

/// Состояние ошибки загрузки истории.
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
          style: AppTextStyles.body.copyWith(color: context.palette.bad),
        ),
      ),
    );
  }
}

/// Bottom sheet расширенных фильтров (UI-SPEC §4).
/// Glassmorphism-паттерн из settings_screen.dart.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.initialSpec,
    required this.onApply,
    required this.onReset,
    required this.loadLanguages,
    required this.loadProviders,
  });

  final FilterSpec initialSpec;
  final void Function(DateTimeRange? dateRange, Set<String> languages,
      Set<String> providers) onApply;
  final VoidCallback onReset;
  // Callback-функции вместо ссылки на репозиторий — всегда читают свежий экземпляр (WR-05).
  final Future<List<String>> Function() loadLanguages;
  final Future<List<String>> Function() loadProviders;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  // Локальное состояние sheet — инициализируется из текущего FilterSpec (D-06).
  DateTimeRange? _selectedDateRange;
  late Set<String> _selectedLanguages;
  late Set<String> _selectedProviders;

  // Динамические значения из БД (D-07) — загружаются один раз при инициализации.
  List<String> _languages = [];
  List<String> _providers = [];

  @override
  void initState() {
    super.initState();
    // Синхронизируем локальное состояние с текущим FilterSpec (D-06).
    _selectedDateRange = widget.initialSpec.dateRange;
    _selectedLanguages = Set.from(widget.initialSpec.languages);
    _selectedProviders = Set.from(widget.initialSpec.providers);
    // Загружаем distinct-значения из БД один раз при открытии sheet (Pitfall «DISTINCT при rebuild»).
    _loadDistinctValues();
  }

  /// Загружает доступные языки и провайдеры из истории (D-07).
  Future<void> _loadDistinctValues() async {
    final langs = await widget.loadLanguages();
    final provs = await widget.loadProviders();
    if (mounted) {
      setState(() {
        _languages = langs;
        _providers = provs;
      });
    }
  }

  /// Открывает системный DateRangePicker для выбора периода.
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      saveText: 'Применить',
      helpText: 'Выберите период',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDateRange = picked);
    }
  }

  /// Форматирует диапазон дат для отображения в кнопке выбора периода.
  String _formatDateRange(DateTimeRange range) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${fmt(range.start)} – ${fmt(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: palette.glassBgDeep,
            border: Border(
              top: BorderSide(color: palette.glassRim, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DragHandle — визуальный индикатор для свайпа вниз.
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: palette.ink3,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),

                // Заголовок + кнопка «Сбросить всё».
                Row(
                  children: [
                    Text(
                      'Фильтры',
                      style: AppTextStyles.heading.copyWith(
                        color: palette.ink1,
                        fontSize: 19,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Сбрасываем только поля sheet — чипы остаются (D-06).
                        setState(() {
                          _selectedDateRange = null;
                          _selectedLanguages = {};
                          _selectedProviders = {};
                        });
                        widget.onReset();
                      },
                      child: Text(
                        'Сбросить всё',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ],
                ),

                Divider(color: palette.glassRim, height: 20),

                // Секция «ПЕРИОД».
                _SectionLabel(label: 'ПЕРИОД'),
                const SizedBox(height: 8),
                // Кнопка выбора диапазона дат через showDateRangePicker.
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: palette.glassBgFlat,
                      border: Border.all(
                        color: _selectedDateRange != null
                            ? palette.accent
                            : palette.glassRim,
                        width: _selectedDateRange != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 18,
                            color: _selectedDateRange != null
                                ? palette.accent
                                : palette.ink3),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDateRange != null
                              ? _formatDateRange(_selectedDateRange!)
                              : 'Выбрать период',
                          style: AppTextStyles.body.copyWith(
                            color: _selectedDateRange != null
                                ? palette.ink1
                                : palette.ink3,
                          ),
                        ),
                        const Spacer(),
                        // Кнопка сброса диапазона дат.
                        if (_selectedDateRange != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDateRange = null),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: palette.ink3),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Секция «ЯЗЫК» — динамические значения из БД (D-07).
                _SectionLabel(label: 'ЯЗЫК'),
                const SizedBox(height: 8),
                if (_languages.isEmpty)
                  Text(
                    'Нет данных',
                    style:
                        AppTextStyles.label.copyWith(color: palette.ink3),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _languages
                        .map((lang) => _FilterChip(
                              label: lang,
                              isActive:
                                  _selectedLanguages.contains(lang),
                              onTap: () {
                                setState(() {
                                  if (_selectedLanguages.contains(lang)) {
                                    _selectedLanguages =
                                        Set.from(_selectedLanguages)
                                          ..remove(lang);
                                  } else {
                                    _selectedLanguages =
                                        Set.from(_selectedLanguages)
                                          ..add(lang);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),

                const SizedBox(height: 20),

                // Секция «ПРОВАЙДЕР» — динамические значения из БД (D-07).
                _SectionLabel(label: 'ПРОВАЙДЕР'),
                const SizedBox(height: 8),
                if (_providers.isEmpty)
                  Text(
                    'Нет данных',
                    style:
                        AppTextStyles.label.copyWith(color: palette.ink3),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _providers
                        .map((prov) => _FilterChip(
                              label: prov,
                              isActive:
                                  _selectedProviders.contains(prov),
                              onTap: () {
                                setState(() {
                                  if (_selectedProviders.contains(prov)) {
                                    _selectedProviders =
                                        Set.from(_selectedProviders)
                                          ..remove(prov);
                                  } else {
                                    _selectedProviders =
                                        Set.from(_selectedProviders)
                                          ..add(prov);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),

                const SizedBox(height: 24),

                // Кнопка «Применить фильтры» (PrimaryButton, D-06).
                PrimaryButton(
                  label: 'Применить фильтры',
                  onPressed: () {
                    // Передаём результат в FilterNotifier и закрываем sheet.
                    widget.onApply(
                      _selectedDateRange,
                      Set.from(_selectedLanguages),
                      Set.from(_selectedProviders),
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок секции в bottom sheet (ALL CAPS, letterSpacing 1.2, UI-SPEC §4).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      label,
      style: AppTextStyles.label.copyWith(
        color: palette.ink3,
        letterSpacing: 1.2,
      ),
    );
  }
}
