import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  Future<void> _load() async {
    final raw = await _storage.read(key: AppConstants.storageKeyThemeMode);
    state = _fromString(raw);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _storage.write(
      key: AppConstants.storageKeyThemeMode,
      value: _toString(mode),
    );
  }

  static ThemeMode _fromString(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _toString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
