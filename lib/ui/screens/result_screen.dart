import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/clipboard_service.dart';

import '../../core/constants/design_tokens.dart';
import '../../features/transcription/result_args.dart';
import '../../features/transcription/transcript_writer.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_btn.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';

/// Ленивый список сегментов транскрипции.
/// Разбивает текст по [HH:MM:SS] маркерам и рендерит только видимые элементы.
class _TranscriptView extends StatefulWidget {
  const _TranscriptView({super.key, required this.text});
  final String text;

  @override
  State<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<_TranscriptView> {
  late List<String> _segments;

  @override
  void initState() {
    super.initState();
    _segments = _ResultScreenState._splitSegments(widget.text);
  }

  @override
  void didUpdateWidget(_TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пересчитываем сегменты при смене текста (переключатель plain/timestamp).
    if (oldWidget.text != widget.text) {
      _segments = _ResultScreenState._splitSegments(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _segments.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: SelectableText(
          _segments[i],
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

/// Экран результата транскрибации.
/// Отображает текст, кнопку «Скопировать» с визуальным feedback, сохраняет txt.
/// Переключатель «С метками / Без меток» (Bug-2): всегда виден; при отсутствии
/// таймкодов оба режима показывают одинаковый текст — это ожидаемое поведение.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ResultArgs? _args;
  bool _copied = false;
  String? _savedPath;

  /// Флаг защиты от повторного вызова _saveTranscripts (race condition при back+forward).
  bool _transcriptsSaved = false;

  /// true = показываем текст с таймкодами; false = plain text.
  /// Изначально true только если в результате есть таймкоды.
  bool _showTimestamps = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      final raw = ModalRoute.of(context)?.settings.arguments;
      if (raw is ResultArgs) {
        _args = raw;
        // Если таймкодов нет (single-shot plain), стартуем в plain-режиме.
        _showTimestamps = _hasTimestamps(raw.result.text);
        // OUT-02: автоматически сохраняем txt после открытия экрана
        _saveTranscripts();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        });
      }
    }
  }

  /// Проверяет, есть ли в тексте таймкоды вида [HH:MM:SS].
  static bool _hasTimestamps(String text) {
    return RegExp(r'\[\d{2}:\d{2}:\d{2}\]').hasMatch(text);
  }

  Future<void> _saveTranscripts() async {
    // Защита от повторного сохранения при быстром navigate-back+forward.
    if (_transcriptsSaved) return;
    _transcriptsSaved = true;
    try {
      // Сохраняем оба формата: plain (для LLM) и с таймкодами (для истории).
      final paths = await const TranscriptWriter().writeBoth(
        baseName: _args!.file.name,
        plainText: _args!.result.plainText,
        timestampedText: _args!.result.text,
      );
      // OUT-01: генерируем SRT если есть сегменты с таймкодами
      await const TranscriptWriter().writeSrt(
        baseName: _args!.file.name,
        segments: _args!.result.segments,
      );
      if (mounted) {
        // Показываем папку (не полный путь), так как файлов теперь несколько.
        final sep = paths.plainPath.lastIndexOf('/');
        final folderPath =
            sep > 0 ? paths.plainPath.substring(0, sep) : paths.plainPath;
        setState(() => _savedPath = folderPath);
      }
    } catch (e, st) {
      debugPrint('_saveTranscripts: $e\n$st');
    }
  }

  /// Возвращает текст в текущем режиме отображения (для копирования и показа).
  String get _currentText {
    final r = _args!.result;
    // Если тексты совпадают (single-shot или нет таймкодов) — всегда возвращаем text.
    if (r.text == r.plainText) return r.text;
    return _showTimestamps ? r.text : r.plainText;
  }

  /// Открывает системный диалог «Поделиться» с текстом расшифровки.
  Future<void> _onShareTap() async {
    if (_args == null) return;
    try {
      await Share.share(_currentText);
    } catch (e, st) {
      debugPrint('_onShareTap error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось поделиться. Попробуйте ещё раз.')),
      );
    }
  }

  Future<void> _onCopyTap() async {
    if (_args == null) return;
    // Используем ClipboardService (super_clipboard) — обходит Android Binder-лимит для длинных транскрипций.
    try {
      await ClipboardService.copyText(_currentText);
      if (!mounted) return;
      setState(() => _copied = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка копирования: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_args == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final file = _args!.file;
    final r = _args!.result;
    final formattedDate = _formatNow();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                // Шапка
                Row(
                  children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Назад',
                      onPressed: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      formattedDate,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Имя файла + метаданные
                Text(file.name, style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${file.sizeFormatted} · ${file.extension.toUpperCase()} · ${_formatDuration(r.duration)}',
                  style: AppTextStyles.mono,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Кнопка копирования с transition default → good
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: PrimaryButton(
                    key: ValueKey(_copied),
                    label: _copied ? 'Скопировано' : 'Скопировать',
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    variant: _copied
                        ? PrimaryButtonVariant.good
                        : PrimaryButtonVariant.accent,
                    onPressed: _onCopyTap,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // OUT-04: кнопка «Поделиться» — отправить расшифровку в другое приложение.
                Semantics(
                  label: 'Поделиться расшифровкой',
                  child: PrimaryButton(
                    label: 'Поделиться',
                    icon: Icons.share_outlined,
                    variant: PrimaryButtonVariant.accent,
                    onPressed: _onShareTap,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Переключатель формата (Bug-2): всегда виден.
                _buildFormatToggle(),
                const SizedBox(height: AppSpacing.sm),

                // Текст расшифровки — ленивый рендеринг по сегментам
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _TranscriptView(
                      // Ключ заставляет ListView перестроиться при смене режима.
                      key: ValueKey(_showTimestamps),
                      text: _currentText,
                    ),
                  ),
                ),

                // Путь к сохранённому файлу
                if (_savedPath != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    // _savedPath содержит путь к папке (два файла: plain + timestamped).
                    'Сохранено: $_savedPath',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Строит переключатель «С метками / Без меток».
  Widget _buildFormatToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Вид:',
          style: AppTextStyles.label.copyWith(color: AppColors.inkSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Используем ChoiceChip-пару для наглядного переключения.
        _FormatChip(
          label: 'С метками',
          selected: _showTimestamps,
          onTap: () => setState(() => _showTimestamps = true),
        ),
        const SizedBox(width: AppSpacing.xs),
        _FormatChip(
          label: 'Без меток',
          selected: !_showTimestamps,
          onTap: () => setState(() => _showTimestamps = false),
        ),
      ],
    );
  }

  /// Разбивает текст по маркерам [HH:MM:SS] на сегменты для ленивого рендеринга.
  static List<String> _splitSegments(String text) {
    final pattern = RegExp(r'(?=\[\d{2}:\d{2}:\d{2}\])');
    final parts = text.split(pattern);
    // Если маркеров нет — разбиваем по абзацам, иначе по 200 символов
    if (parts.length <= 1) {
      final paras = text.split('\n\n').where((s) => s.trim().isNotEmpty).toList();
      if (paras.length > 1) return paras;
      // Нет ни маркеров, ни абзацев — нарезаем по ~200 символов на строках
      final lines = text.split('\n');
      final chunks = <String>[];
      final buf = StringBuffer();
      for (final line in lines) {
        buf.writeln(line);
        if (buf.length >= 200) {
          chunks.add(buf.toString().trim());
          buf.clear();
        }
      }
      if (buf.isNotEmpty) chunks.add(buf.toString().trim());
      return chunks.isEmpty ? [text] : chunks;
    }
    return parts.where((s) => s.trim().isNotEmpty).toList();
  }

  String _formatNow() {
    final n = DateTime.now();
    final hh = n.hour.toString().padLeft(2, '0');
    final mm = n.minute.toString().padLeft(2, '0');
    return 'Сегодня · $hh:$mm';
  }

  /// Форматирует секунды в человекочитаемую строку.
  /// Для chunked-результата duration — сумма длительностей чанков.
  /// Примеры: 45.2 → «45с», 125.0 → «2мин 5с», 3725.0 → «1ч 2мин».
  String _formatDuration(double seconds) {
    final total = seconds.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}ч ${m}мин';
    if (m > 0) return '${m}мин ${s}с';
    return '${s}с';
  }
}

/// Минималистичный чип-переключатель для выбора формата отображения.
class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.inkDivider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.accent : AppColors.inkSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
