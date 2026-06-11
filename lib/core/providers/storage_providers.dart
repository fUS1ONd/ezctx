import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

/// Провайдер хранилища для Groq API-ключей (namespace: groq_api_keys_v1).
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageServiceImpl(
    storageKey: AppConstants.storageKeyApiKeys,
  ),
);

/// Провайдер хранилища для Deepgram API-ключей (namespace: deepgram_api_keys_v1).
/// Изолирован от Groq-хранилища через отдельный storageKey (T-10-03).
final deepgramSecureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageServiceImpl(
    storageKey: AppConstants.storageKeyDeepgramApiKeys,
  ),
);
