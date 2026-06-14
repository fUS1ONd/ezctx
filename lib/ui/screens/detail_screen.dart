import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/providers/history_provider.dart';
import '../../core/services/clipboard_service.dart';
import '../../core/utils/label_mappers.dart';
import '../../features/history/history_entry.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_confirm_dialog.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';

/// Аргументы маршрута routeHistoryDetail.
/// Передаются через Navigator.pushNamed(..., arguments: DetailArgs(...)).
class DetailArgs {
  const DetailArgs({required this.entry, this.searchTerm});

  final HistoryEntry entry;

  /// Поисковый запрос — если задан, совпадения в тексте будут подсвечены.
  final String? searchTerm;
}

/// Экран полного просмотра расшифровки с метаданными и действиями.
/// Открывается через [AppConstants.routeHistoryDetail] с аргументами [DetailArgs].
class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.entry, this.searchTerm});

  final HistoryEntry entry;

  /// Поисковый запрос для подсветки совпадений (BRWS-03).
  final String? searchTerm;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  /// Mutable-копия записи для optimistic UI (ACT-01, ACT-02, Pitfall 6).
  late HistoryEntry _currentEntry;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _scrollController = ScrollController();
    // Автоскролл к первому совпадению — только после первого рендера (Pitfall 3).
    if (widget.searchTerm?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstMatch());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Автоскролл к первому совпадению (D-09, Pattern 3) ──────────────────────

  void _scrollToFirstMatch() {
    final term = widget.searchTerm ?? '';
    final idx = _currentEntry.plainText.toLowerCase().indexOf(term.toLowerCase());
    if (idx < 0 || !_scrollController.hasClients) return;

    // Эвристика: ~60 символов на строку при fontSize 16 и ширине ~360px.
    const charsPerLine = 60;
    const lineHeight = 24.0; // fontSize 16 * lineHeight 1.5
    final approxLines = idx ~/ charsPerLine;
    final approxOffset = (approxLines * lineHeight).toDouble();

    _scrollController.animateTo(
      approxOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ── Действия ────────────────────────────────────────────────────────────────

  Future<void> _onCopyTap() async {
    try {
      await ClipboardService.copyText(_currentEntry.plainText);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка копирования: $e')),
      );
    }
  }

  Future<void> _onShareTap() async {
    try {
      await Share.share(_currentEntry.plainText);
    } catch (e, st) {
      debugPrint('_onShareTap error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось поделиться. Попробуйте ещё раз.')),
      );
    }
  }

  Future<void> _onDeleteTap() async {
    final confirmed = await GlassConfirmDialog.show(
      context,
      title: 'Удалить запись?',
      body: 'Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
    );

    if (!confirmed) return;

    // Захват repo ДО await — ref недоступен после dispose (Pitfall 4, T-03-04).
    final repo = ref.read(historyRepositoryProvider);
    try {
      await repo.remove(_currentEntry.id);
    } catch (e, st) {
      debugPrint('_onDeleteTap error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить')),
        );
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  /// Обработчик сохранения нового заголовка из [_InlineTitleWidget].
  Future<void> _onTitleSaved(String newTitle) async {
    // Захват repo ДО await (Pitfall 4, T-03-04).
    final repo = ref.read(historyRepositoryProvider);
    try {
      final updated = _currentEntry.copyWith(title: newTitle);
      await repo.update(updated);
      setState(() => _currentEntry = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить')),
        );
      }
    }
  }

  /// Обработчик тоггла избранного из [_FavoriteButton].
  Future<void> _onFavoriteTap() async {
    // Optimistic UI — переключаем немедленно (D-07 решение).
    final updated = _currentEntry.copyWith(isFavorite: !_currentEntry.isFavorite);
    setState(() => _currentEntry = updated);

    // Захват repo ДО await (Pitfall 4, T-03-04).
    final repo = ref.read(historyRepositoryProvider);
    try {
      await repo.update(updated);
    } catch (e) {
      // Откат при ошибке.
      setState(() => _currentEntry = _currentEntry.copyWith(
          isFavorite: !_currentEntry.isFavorite));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Основная прокручиваемая область с AppBar внутри CustomScrollView;
              // нижний бар — плавающая пилюля поверх скролла (Stack/Positioned).
              Expanded(
                child: Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // ── SliverAppBar ──────────────────────────────────────
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          leading: GlassIconBtn(
                            icon: Icons.arrow_back,
                            semanticLabel: 'Назад',
                            onPressed: () => Navigator.pop(context),
                          ),
                          leadingWidth:
                              AppSpacing.lg + AppSpacing.md + AppSpacing.xxl,
                          title: _InlineTitleWidget(
                            entry: _currentEntry,
                            onSave: _onTitleSaved,
                          ),
                          actions: [
                            _FavoriteButton(
                              isFavorite: _currentEntry.isFavorite,
                              onTap: _onFavoriteTap,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ),

                        // ── Metadata strip ──────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: _MetadataStrip(entry: _currentEntry),
                          ),
                        ),

                        // ── Полный текст расшифровки ────────────────────────────
                        // Нижний отступ увеличен (xxl*2), чтобы текст докручивался
                        // из-под плавающей пилюли _BottomBar.
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xxl * 2,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildHighlightedText(
                              _currentEntry.plainText,
                              widget.searchTerm,
                              palette,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Bottom bar — плавающая glass-пилюля поверх текста ──────
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomBar(
                        onCopy: _onCopyTap,
                        onShare: _onShareTap,
                        onDelete: _onDeleteTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Построение текста с подсветкой (D-10, BRWS-03, Pattern 2) ──────────────

  Widget _buildHighlightedText(
    String plainText,
    String? searchTerm,
    AppPalette palette,
  ) {
    // Пустой текст — плейсхолдер.
    if (plainText.isEmpty) {
      return Text(
        'Текст отсутствует',
        style: AppTextStyles.label.copyWith(color: palette.ink3),
        textAlign: TextAlign.center,
      );
    }

    // Без searchTerm — обычный SelectableText.
    if (searchTerm == null || searchTerm.isEmpty) {
      return SelectableText(
        plainText,
        style: AppTextStyles.body.copyWith(color: palette.ink2),
      );
    }

    // С searchTerm — подсветка совпадений accent+w700 (case-insensitive).
    final pattern = RegExp(RegExp.escape(searchTerm), caseSensitive: false);
    final parts = plainText.split(pattern);
    final matches = pattern.allMatches(plainText).toList();

    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: AppTextStyles.body.copyWith(color: palette.ink2),
        ));
      }
      if (i < matches.length) {
        // Сохраняем оригинальный регистр совпадения через match.group(0).
        spans.add(TextSpan(
          text: matches[i].group(0),
          style: AppTextStyles.body.copyWith(
            color: palette.accent,
            fontWeight: FontWeight.w700,
          ),
        ));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Приватные sub-виджеты
// ══════════════════════════════════════════════════════════════════════════════

/// Заголовок AppBar с поддержкой inline-редактирования (D-03, ACT-01, Pattern 5).
class _InlineTitleWidget extends StatefulWidget {
  const _InlineTitleWidget({
    required this.entry,
    required this.onSave,
  });

  final HistoryEntry entry;

  /// Коллбэк при сохранении нового заголовка (непустого и отличного от текущего).
  final Future<void> Function(String newTitle) onSave;

  @override
  State<_InlineTitleWidget> createState() => _InlineTitleWidgetState();
}

class _InlineTitleWidgetState extends State<_InlineTitleWidget> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.title);
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_InlineTitleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем текст контроллера при смене entry (optimistic update из родителя).
    if (!_editing && oldWidget.entry.title != widget.entry.title) {
      _ctrl.text = widget.entry.title;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _editing) _saveTitle();
  }

  void _enterEditMode() => setState(() {
        _editing = true;
        // Выставляем курсор в конец при входе в режим редактирования.
        _ctrl.selection =
            TextSelection.collapsed(offset: _ctrl.text.length);
      });

  void _saveTitle() {
    final newTitle = _ctrl.text.trim();
    // T-03-03: пустой/пробельный title → откат к оригиналу (V5 Input Validation).
    if (newTitle.isEmpty) {
      _ctrl.text = widget.entry.title;
      setState(() => _editing = false);
      return;
    }
    // Если title не изменился — просто выходим из режима.
    if (newTitle == widget.entry.title) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    widget.onSave(newTitle);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (!_editing) {
      return GestureDetector(
        onTap: _enterEditMode,
        child: Text(
          widget.entry.title,
          style: AppTextStyles.heading.copyWith(color: palette.ink1),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      autofocus: true,
      style: AppTextStyles.heading.copyWith(color: palette.ink1),
      decoration: const InputDecoration.collapsed(hintText: 'Введите название'),
      cursorColor: palette.accent,
      onSubmitted: (_) => _saveTitle(),
      onEditingComplete: _saveTitle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Кнопка-звезда для тоггла избранного (ACT-02).
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = isFavorite ? Icons.star : Icons.star_border;
    final color = isFavorite ? palette.accent : palette.ink3;
    final label = isFavorite ? 'Убрать из избранного' : 'В избранное';

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color, size: AppSpacing.lg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Полоска метаданных над текстом расшифровки (D-02).
class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Список метаданных: дата, длительность, провайдер, размер, язык.
    final chips = [
      (Icons.calendar_today_outlined, entry.relativeDate(now)),
      (Icons.timer_outlined, entry.durationFormatted),
      (Icons.mic_none_outlined, providerLabel(entry.provider)),
      (Icons.folder_outlined, entry.sizeFormatted),
      (Icons.language_outlined, languageLabel(entry.language)),
    ];

    return GlassCard(
      deep: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.md - AppSpacing.xs, // 12px
        runSpacing: AppSpacing.xs,
        children: chips
            .map((c) => _MetaChip(icon: c.$1, text: c.$2))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Один чип метаданных: иконка + текст (UI-SPEC §_MetadataStrip).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.md, color: palette.ink3),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTextStyles.label.copyWith(color: palette.ink2),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Нижняя панель действий: Copy, Share, Delete (D-01, ACT-03, ACT-04).
/// Плавающая liquid-glass «пилюля» — в одном языке с TabBar и плашкой таймера.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onCopy,
    required this.onShare,
    required this.onDelete,
  });

  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: GlassCard(
        deep: true,
        borderRadius: AppRadius.tile,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _BottomAction(
              icon: Icons.copy_all_outlined,
              label: 'Копировать',
              onTap: onCopy,
            ),
            _BottomAction(
              icon: Icons.share_outlined,
              label: 'Поделиться',
              onTap: onShare,
            ),
            _BottomAction(
              icon: Icons.delete_outline,
              label: 'Удалить',
              color: palette.bad,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Один элемент нижней панели: иконка + подпись.
/// Тап по всей ячейке (иконка, подпись и пустое пространство) вызывает [onTap].
class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveColor = color ?? palette.ink2;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label: label,
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: effectiveColor),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(color: effectiveColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
