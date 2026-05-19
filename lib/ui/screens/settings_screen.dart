// SettingsScreen в стиле Liquid Glass — тема-aware версия.
// Изменения относительно предыдущей версии:
//  • Цвета берутся из `context.palette` (не из локального _C).
//  • Фон делегирован общему `GradientBackground` — корректен в обеих темах.
//  • Status-карточка, ряды, divider, OptionsSheet — все используют palette.
//
// Проводка та же: apiKeysProvider, themeModeProvider, transcriptionOptionsRepoProvider.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../features/transcription/transcription_options.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  TranscriptionOptions _options = const TranscriptionOptions.defaults();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final saved = await ref.read(transcriptionOptionsRepoProvider).load();
    if (mounted) setState(() => _options = saved);
  }

  Future<void> _saveOptions(TranscriptionOptions updated) async {
    setState(() => _options = updated);
    await ref.read(transcriptionOptionsRepoProvider).save(updated);
  }

  String _modelLabel(WhisperModel m) => switch (m) {
        WhisperModel.largeV3 => 'Whisper Large v3',
        WhisperModel.turbo => 'Whisper Turbo',
      };

  String _languageLabel(TranscriptionLanguage l) => switch (l) {
        TranscriptionLanguage.auto => 'Авто',
        TranscriptionLanguage.ru => 'Русский',
        TranscriptionLanguage.en => 'English',
        TranscriptionLanguage.de => 'Deutsch',
        TranscriptionLanguage.fr => 'Français',
        TranscriptionLanguage.es => 'Español',
        TranscriptionLanguage.uk => 'Українська',
        TranscriptionLanguage.zh => '中文',
        TranscriptionLanguage.ja => '日本語',
        TranscriptionLanguage.ko => '한국어',
        TranscriptionLanguage.ar => 'العربية',
      };

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Светлая',
        ThemeMode.dark => 'Тёмная',
        ThemeMode.system => 'Автоматически',
      };

  String _keyCountLabel(int count) {
    if (count == 0) return 'Нет ключей';
    if (count == 1) return '1 активен';
    return '$count активных';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final keysAsync = ref.watch(apiKeysProvider);
    final keyCount = keysAsync.maybeWhen(data: (k) => k.length, orElse: () => 0);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Настройки',
                  style: AppTextStyles.display.copyWith(color: palette.ink1),
                ),
              ),

              // Статус-карточка Groq (реактивная)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _StatusCard(
                  connected: keyCount > 0,
                  modelName: _options.model.apiValue,
                ),
              ),

              // ── Подключение ──
              const _SectionTitle('Подключение'),
              _Group(children: [
                _Row(
                  icon: _IconKind.key,
                  iconGradient: const [Color(0xFFFF8A4D), Color(0xFFFF5B3A)],
                  title: 'API-ключи',
                  detail: keysAsync.maybeWhen(
                    data: (_) => _keyCountLabel(keyCount),
                    loading: () => '...',
                    orElse: () => '—',
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppConstants.routeApiKeys,
                  ),
                ),
                _Row(
                  icon: _IconKind.wave,
                  iconGradient: const [Color(0xFF9AA6FF), Color(0xFF6A4ADF)],
                  title: 'Модель',
                  detail: _modelLabel(_options.model),
                  onTap: () => _pickOne<WhisperModel>(
                    title: 'Модель',
                    options: WhisperModel.values,
                    value: _options.model,
                    label: _modelLabel,
                    onChanged: (m) =>
                        _saveOptions(_options.copyWith(model: m)),
                  ),
                ),
                _Row(
                  icon: _IconKind.globe,
                  iconGradient: const [Color(0xFF5DD1B5), Color(0xFF2DB585)],
                  title: 'Язык распознавания',
                  detail: _languageLabel(_options.language),
                  isLast: true,
                  onTap: () => _pickOne<TranscriptionLanguage>(
                    title: 'Язык',
                    options: TranscriptionLanguage.values,
                    value: _options.language,
                    label: _languageLabel,
                    onChanged: (l) =>
                        _saveOptions(_options.copyWith(language: l)),
                  ),
                ),
              ]),

              // ── Приложение ──
              const _SectionTitle('Приложение'),
              _Group(children: [
                _Row(
                  icon: _IconKind.sun,
                  iconGradient: const [Color(0xFFFFE78A), Color(0xFFFFB74D)],
                  title: 'Внешний вид',
                  detail: _themeLabel(themeMode),
                  onTap: () => _pickOne<ThemeMode>(
                    title: 'Внешний вид',
                    options: const [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ],
                    value: themeMode,
                    label: _themeLabel,
                    onChanged: (m) =>
                        ref.read(themeModeProvider.notifier).setTheme(m),
                  ),
                ),
                _Row(
                  icon: _IconKind.bell,
                  iconGradient: const [Color(0xFFFF9AA6), Color(0xFFC93A8A)],
                  title: 'Уведомления',
                  detail: 'Скоро',
                  isLast: true,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOne<T>({
    required String title,
    required List<T> options,
    required T value,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OptionsSheet<T>(
        title: title,
        options: options,
        value: value,
        label: label,
        onPick: (v) {
          onChanged(v);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── Заголовок секции (small caps) ──────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: context.palette.ink3,
        ),
      ),
    );
  }
}

// ─── Контейнер группы строк ─────────────────────────────
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        borderRadius: 22,
        padding: EdgeInsets.zero,
        child: Column(children: children),
      ),
    );
  }
}

// ─── Одна строка-настройка ──────────────────────────────
class _Row extends StatelessWidget {
  final _IconKind icon;
  final List<Color> iconGradient;
  final String title;
  final String? detail;
  final bool isLast;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.detail,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      splashColor: palette.inkLine,
      highlightColor: palette.inkLine,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: iconGradient,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _IconPainter(kind: icon, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.16,
                  color: palette.ink1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (detail != null) ...[
              Text(
                detail!,
                style: TextStyle(fontSize: 15, color: palette.ink3),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: palette.ink3, size: 22),
              ],
            ],
          ]),
        ),
        if (!isLast)
          Positioned(
            left: 58,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 0.5,
              child: ColoredBox(color: palette.inkLine),
            ),
          ),
      ]),
    );
  }
}

// ─── Реактивная Status-карточка ─────────────────────────
class _StatusCard extends StatelessWidget {
  final bool connected;
  final String modelName;
  const _StatusCard({required this.connected, required this.modelName});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      borderRadius: 30,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppGradients.accent,
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected ? 'Подключено к Groq' : 'Нет API-ключа',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.ink1,
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: connected ? palette.good : palette.bad,
                ),
                const SizedBox(width: 6),
                Text(
                  connected ? modelName : 'Добавьте ключ для транскрибации',
                  style: TextStyle(fontSize: 13, color: palette.ink2),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Bottom-sheet выбора ────────────────────────────────
class _OptionsSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onPick;

  const _OptionsSheet({
    required this.title,
    required this.options,
    required this.value,
    required this.label,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          decoration: BoxDecoration(
            color: palette.glassBgDeep,
            border: Border(
              top: BorderSide(color: palette.glassRim, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.38,
                    color: palette.ink1,
                  ),
                ),
              ),
              for (final o in options)
                InkWell(
                  onTap: () => onPick(o),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 14),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          label(o),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: palette.ink1,
                          ),
                        ),
                      ),
                      if (o == value)
                        Icon(Icons.check_rounded,
                            color: palette.accent, size: 22),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Иконки в строках ───────────────────────────────────
enum _IconKind { key, wave, globe, sun, bell }

class _IconPainter extends CustomPainter {
  final _IconKind kind;
  final Color color;
  _IconPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case _IconKind.key:
        canvas.drawCircle(const Offset(8, 14), 4.5, stroke);
        final p = Path()
          ..moveTo(11.2, 11.5)
          ..lineTo(20, 3)
          ..moveTo(16.5, 6.5)
          ..lineTo(18.5, 8.5)
          ..moveTo(18, 5)
          ..lineTo(20, 7);
        canvas.drawPath(p, stroke);

      case _IconKind.wave:
        void bar(double x, double y1, double y2) {
          canvas.drawLine(Offset(x, y1), Offset(x, y2), stroke);
        }

        bar(3, 11, 13);
        bar(7, 8, 16);
        bar(11, 5, 19);
        bar(15, 8, 16);
        bar(19, 11, 13);

      case _IconKind.globe:
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), stroke);
        final r1 = Rect.fromCenter(
            center: const Offset(12, 12), width: 9, height: 18);
        canvas.drawArc(r1, 0, 6.2832, false, stroke);

      case _IconKind.sun:
        canvas.drawCircle(const Offset(12, 12), 4, stroke);
        const rays = [
          [12.0, 2.0, 12.0, 5.0],
          [12.0, 19.0, 12.0, 22.0],
          [22.0, 12.0, 19.0, 12.0],
          [5.0, 12.0, 2.0, 12.0],
          [19.0, 5.0, 17.0, 7.0],
          [7.0, 17.0, 5.0, 19.0],
          [19.0, 19.0, 17.0, 17.0],
          [7.0, 7.0, 5.0, 5.0],
        ];
        for (final r in rays) {
          canvas.drawLine(Offset(r[0], r[1]), Offset(r[2], r[3]), stroke);
        }

      case _IconKind.bell:
        final p = Path()
          ..moveTo(6, 17)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 17)
          ..lineTo(19.5, 19)
          ..lineTo(4.5, 19)
          ..close();
        canvas.drawPath(p, stroke);
        canvas.drawLine(const Offset(10.5, 21), const Offset(13.5, 21), stroke);
        canvas.drawLine(const Offset(12, 4), const Offset(12, 5.2), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.kind != kind || old.color != color;
}
