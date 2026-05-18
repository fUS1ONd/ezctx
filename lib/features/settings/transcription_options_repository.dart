import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../transcription/transcription_options.dart';

/// Сохраняет и загружает [TranscriptionOptions] из flutter_secure_storage.
class TranscriptionOptionsRepository {
  TranscriptionOptionsRepository({FlutterSecureStorage? storage})
      : _storage =
            storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  Future<TranscriptionOptions> load() async {
    try {
      final raw =
          await _storage.read(key: AppConstants.storageKeyTranscriptionOptions);
      if (raw == null || raw.isEmpty) return const TranscriptionOptions.defaults();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TranscriptionOptions.fromJson(json);
    } catch (_) {
      return const TranscriptionOptions.defaults();
    }
  }

  Future<void> save(TranscriptionOptions options) async {
    await _storage.write(
      key: AppConstants.storageKeyTranscriptionOptions,
      value: jsonEncode(options.toJson()),
    );
  }
}
