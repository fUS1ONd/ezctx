import 'package:flutter/material.dart';

import 'ui/app.dart';

// Точка входа приложения: запускает корневой виджет EzCtxApp.
void main() async {
  // Необходимо перед любыми async-вызовами (flutter_secure_storage, path_provider).
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EzCtxApp());
}
