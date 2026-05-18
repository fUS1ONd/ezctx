/// Состояния отдельного чанка в процессе транскрибации.
/// Используются в [ChunkedTranscriptionController] для отображения прогресса каждого чанка.
sealed class ChunkState {
  final int index;
  final String label;
  const ChunkState({required this.index, required this.label});
}

/// Чанк ожидает своей очереди (семафор занят).
class ChunkWaiting extends ChunkState {
  const ChunkWaiting(int index)
      : super(index: index, label: 'Часть ${index + 1}: ожидание');
}

/// Чанк загружается в Groq API.
class ChunkUploading extends ChunkState {
  const ChunkUploading(int index)
      : super(index: index, label: 'Часть ${index + 1}: загрузка...');
}

/// Чанк успешно транскрибирован.
class ChunkDone extends ChunkState {
  final String text;
  const ChunkDone(int index, {required this.text})
      : super(index: index, label: 'Часть ${index + 1}: готово');
}

/// Чанк повторяет запрос после ошибки (экспоненциальный backoff).
///
/// [maxAttempts] по умолчанию 10 — совпадает с maxAttempts в ChunkedTranscriptionController.
class ChunkRetrying extends ChunkState {
  final int attempt;
  final int maxAttempts;
  const ChunkRetrying(int index, {required this.attempt, this.maxAttempts = 10})
      : super(
          index: index,
          label: 'Часть ${index + 1}: повтор $attempt/$maxAttempts...',
        );
}

/// Чанк завершился ошибкой после всех попыток.
class ChunkFailed extends ChunkState {
  final String error;
  const ChunkFailed(int index, {required this.error})
      : super(index: index, label: 'Часть ${index + 1}: ошибка');
}

/// Чанк ожидает свободного ключа из пула (все ключи временно заблокированы).
class ChunkWaitingForKey extends ChunkState {
  const ChunkWaitingForKey(int index)
      : super(index: index, label: 'Часть ${index + 1}: ожидание ключа...');
}
