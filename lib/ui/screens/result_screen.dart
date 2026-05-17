import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const _TranscriptView({required this.text});
  final String text;

  @override
  State<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<_TranscriptView> {
  late final List<String> _segments;

  @override
  void initState() {
    super.initState();
    _segments = _ResultScreenState._splitSegments(widget.text);
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
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ResultArgs? _args;
  bool _copied = false;
  String? _savedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      final raw = ModalRoute.of(context)?.settings.arguments;
      if (raw is ResultArgs) {
        _args = raw;
        // OUT-02: автоматически сохраняем txt после открытия экрана
        _saveTranscriptTxt();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
        });
      }
    }
  }

  Future<void> _saveTranscriptTxt() async {
    try {
      final path = await const TranscriptWriter().writeTxt(
        baseName: _args!.file.name,
        text: _args!.result.text,
      );
      if (mounted) setState(() => _savedPath = path);
    } catch (_) {
      // тихо — UI не блокируется ошибкой записи
    }
  }

  Future<void> _onCopyTap() async {
    if (_args == null) return;
    await Clipboard.setData(ClipboardData(text: _args!.result.text));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
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
                const SizedBox(height: AppSpacing.lg),

                // Текст расшифровки — ленивый рендеринг по сегментам
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _TranscriptView(text: r.text),
                  ),
                ),

                // Путь к сохранённому файлу
                if (_savedPath != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
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
