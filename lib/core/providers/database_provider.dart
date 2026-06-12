import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Синглтон-провайдер базы данных drift.
/// Создаёт AppDatabase при первом обращении, закрывает при dispose ProviderScope.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Drift требует явного закрытия соединения при уничтожении провайдера.
  ref.onDispose(db.close);
  return db;
});
