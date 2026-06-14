// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, Transcript> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<double> durationSec = GeneratedColumn<double>(
      'duration_sec', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _languageMeta =
      const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
      'language', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _plainPathMeta =
      const VerificationMeta('plainPath');
  @override
  late final GeneratedColumn<String> plainPath = GeneratedColumn<String>(
      'plain_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampedPathMeta =
      const VerificationMeta('timestampedPath');
  @override
  late final GeneratedColumn<String> timestampedPath = GeneratedColumn<String>(
      'timestamped_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plainTextMeta =
      const VerificationMeta('plainText');
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
      'plain_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fileName,
        sizeBytes,
        durationSec,
        language,
        title,
        provider,
        isFavorite,
        createdAt,
        plainPath,
        timestampedPath,
        plainText
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(Insertable<Transcript> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('language')) {
      context.handle(_languageMeta,
          language.isAcceptableOrUnknown(data['language']!, _languageMeta));
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('plain_path')) {
      context.handle(_plainPathMeta,
          plainPath.isAcceptableOrUnknown(data['plain_path']!, _plainPathMeta));
    } else if (isInserting) {
      context.missing(_plainPathMeta);
    }
    if (data.containsKey('timestamped_path')) {
      context.handle(
          _timestampedPathMeta,
          timestampedPath.isAcceptableOrUnknown(
              data['timestamped_path']!, _timestampedPathMeta));
    } else if (isInserting) {
      context.missing(_timestampedPathMeta);
    }
    if (data.containsKey('plain_text')) {
      context.handle(_plainTextMeta,
          plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta));
    } else if (isInserting) {
      context.missing(_plainTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transcript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transcript(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration_sec'])!,
      language: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      plainPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_path'])!,
      timestampedPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}timestamped_path'])!,
      plainText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_text'])!,
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class Transcript extends DataClass implements Insertable<Transcript> {
  final int id;
  final String fileName;
  final int sizeBytes;
  final double durationSec;
  final String language;
  final String title;
  final String provider;
  final bool isFavorite;
  final DateTime createdAt;
  final String plainPath;
  final String timestampedPath;
  final String plainText;
  const Transcript(
      {required this.id,
      required this.fileName,
      required this.sizeBytes,
      required this.durationSec,
      required this.language,
      required this.title,
      required this.provider,
      required this.isFavorite,
      required this.createdAt,
      required this.plainPath,
      required this.timestampedPath,
      required this.plainText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_name'] = Variable<String>(fileName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['duration_sec'] = Variable<double>(durationSec);
    map['language'] = Variable<String>(language);
    map['title'] = Variable<String>(title);
    map['provider'] = Variable<String>(provider);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['plain_path'] = Variable<String>(plainPath);
    map['timestamped_path'] = Variable<String>(timestampedPath);
    map['plain_text'] = Variable<String>(plainText);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      id: Value(id),
      fileName: Value(fileName),
      sizeBytes: Value(sizeBytes),
      durationSec: Value(durationSec),
      language: Value(language),
      title: Value(title),
      provider: Value(provider),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      plainPath: Value(plainPath),
      timestampedPath: Value(timestampedPath),
      plainText: Value(plainText),
    );
  }

  factory Transcript.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transcript(
      id: serializer.fromJson<int>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      durationSec: serializer.fromJson<double>(json['durationSec']),
      language: serializer.fromJson<String>(json['language']),
      title: serializer.fromJson<String>(json['title']),
      provider: serializer.fromJson<String>(json['provider']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      plainPath: serializer.fromJson<String>(json['plainPath']),
      timestampedPath: serializer.fromJson<String>(json['timestampedPath']),
      plainText: serializer.fromJson<String>(json['plainText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileName': serializer.toJson<String>(fileName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'durationSec': serializer.toJson<double>(durationSec),
      'language': serializer.toJson<String>(language),
      'title': serializer.toJson<String>(title),
      'provider': serializer.toJson<String>(provider),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'plainPath': serializer.toJson<String>(plainPath),
      'timestampedPath': serializer.toJson<String>(timestampedPath),
      'plainText': serializer.toJson<String>(plainText),
    };
  }

  Transcript copyWith(
          {int? id,
          String? fileName,
          int? sizeBytes,
          double? durationSec,
          String? language,
          String? title,
          String? provider,
          bool? isFavorite,
          DateTime? createdAt,
          String? plainPath,
          String? timestampedPath,
          String? plainText}) =>
      Transcript(
        id: id ?? this.id,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        durationSec: durationSec ?? this.durationSec,
        language: language ?? this.language,
        title: title ?? this.title,
        provider: provider ?? this.provider,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        plainPath: plainPath ?? this.plainPath,
        timestampedPath: timestampedPath ?? this.timestampedPath,
        plainText: plainText ?? this.plainText,
      );
  Transcript copyWithCompanion(TranscriptsCompanion data) {
    return Transcript(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      language: data.language.present ? data.language.value : this.language,
      title: data.title.present ? data.title.value : this.title,
      provider: data.provider.present ? data.provider.value : this.provider,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      plainPath: data.plainPath.present ? data.plainPath.value : this.plainPath,
      timestampedPath: data.timestampedPath.present
          ? data.timestampedPath.value
          : this.timestampedPath,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transcript(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('durationSec: $durationSec, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('provider: $provider, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('plainPath: $plainPath, ')
          ..write('timestampedPath: $timestampedPath, ')
          ..write('plainText: $plainText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      fileName,
      sizeBytes,
      durationSec,
      language,
      title,
      provider,
      isFavorite,
      createdAt,
      plainPath,
      timestampedPath,
      plainText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.sizeBytes == this.sizeBytes &&
          other.durationSec == this.durationSec &&
          other.language == this.language &&
          other.title == this.title &&
          other.provider == this.provider &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.plainPath == this.plainPath &&
          other.timestampedPath == this.timestampedPath &&
          other.plainText == this.plainText);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<int> id;
  final Value<String> fileName;
  final Value<int> sizeBytes;
  final Value<double> durationSec;
  final Value<String> language;
  final Value<String> title;
  final Value<String> provider;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<String> plainPath;
  final Value<String> timestampedPath;
  final Value<String> plainText;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    this.provider = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.plainPath = const Value.absent(),
    this.timestampedPath = const Value.absent(),
    this.plainText = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    this.id = const Value.absent(),
    required String fileName,
    required int sizeBytes,
    required double durationSec,
    required String language,
    required String title,
    required String provider,
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    required String plainPath,
    required String timestampedPath,
    required String plainText,
  })  : fileName = Value(fileName),
        sizeBytes = Value(sizeBytes),
        durationSec = Value(durationSec),
        language = Value(language),
        title = Value(title),
        provider = Value(provider),
        createdAt = Value(createdAt),
        plainPath = Value(plainPath),
        timestampedPath = Value(timestampedPath),
        plainText = Value(plainText);
  static Insertable<Transcript> custom({
    Expression<int>? id,
    Expression<String>? fileName,
    Expression<int>? sizeBytes,
    Expression<double>? durationSec,
    Expression<String>? language,
    Expression<String>? title,
    Expression<String>? provider,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<String>? plainPath,
    Expression<String>? timestampedPath,
    Expression<String>? plainText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (durationSec != null) 'duration_sec': durationSec,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (provider != null) 'provider': provider,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (plainPath != null) 'plain_path': plainPath,
      if (timestampedPath != null) 'timestamped_path': timestampedPath,
      if (plainText != null) 'plain_text': plainText,
    });
  }

  TranscriptsCompanion copyWith(
      {Value<int>? id,
      Value<String>? fileName,
      Value<int>? sizeBytes,
      Value<double>? durationSec,
      Value<String>? language,
      Value<String>? title,
      Value<String>? provider,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<String>? plainPath,
      Value<String>? timestampedPath,
      Value<String>? plainText}) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationSec: durationSec ?? this.durationSec,
      language: language ?? this.language,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      plainPath: plainPath ?? this.plainPath,
      timestampedPath: timestampedPath ?? this.timestampedPath,
      plainText: plainText ?? this.plainText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<double>(durationSec.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (plainPath.present) {
      map['plain_path'] = Variable<String>(plainPath.value);
    }
    if (timestampedPath.present) {
      map['timestamped_path'] = Variable<String>(timestampedPath.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('durationSec: $durationSec, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('provider: $provider, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('plainPath: $plainPath, ')
          ..write('timestampedPath: $timestampedPath, ')
          ..write('plainText: $plainText')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final Index idxTranscriptsCreatedAt = Index('idx_transcripts_created_at',
      'CREATE INDEX idx_transcripts_created_at ON transcripts (created_at)');
  late final Index idxTranscriptsProvider = Index('idx_transcripts_provider',
      'CREATE INDEX idx_transcripts_provider ON transcripts (provider)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [transcripts, idxTranscriptsCreatedAt, idxTranscriptsProvider];
}

typedef $$TranscriptsTableCreateCompanionBuilder = TranscriptsCompanion
    Function({
  Value<int> id,
  required String fileName,
  required int sizeBytes,
  required double durationSec,
  required String language,
  required String title,
  required String provider,
  Value<bool> isFavorite,
  required DateTime createdAt,
  required String plainPath,
  required String timestampedPath,
  required String plainText,
});
typedef $$TranscriptsTableUpdateCompanionBuilder = TranscriptsCompanion
    Function({
  Value<int> id,
  Value<String> fileName,
  Value<int> sizeBytes,
  Value<double> durationSec,
  Value<String> language,
  Value<String> title,
  Value<String> provider,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<String> plainPath,
  Value<String> timestampedPath,
  Value<String> plainText,
});

class $$TranscriptsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainPath => $composableBuilder(
      column: $table.plainPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timestampedPath => $composableBuilder(
      column: $table.timestampedPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnFilters(column));
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainPath => $composableBuilder(
      column: $table.plainPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timestampedPath => $composableBuilder(
      column: $table.timestampedPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnOrderings(column));
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get plainPath =>
      $composableBuilder(column: $table.plainPath, builder: (column) => column);

  GeneratedColumn<String> get timestampedPath => $composableBuilder(
      column: $table.timestampedPath, builder: (column) => column);

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);
}

class $$TranscriptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TranscriptsTable,
    Transcript,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (Transcript, BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript>),
    Transcript,
    PrefetchHooks Function()> {
  $$TranscriptsTableTableManager(_$AppDatabase db, $TranscriptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<double> durationSec = const Value.absent(),
            Value<String> language = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> plainPath = const Value.absent(),
            Value<String> timestampedPath = const Value.absent(),
            Value<String> plainText = const Value.absent(),
          }) =>
              TranscriptsCompanion(
            id: id,
            fileName: fileName,
            sizeBytes: sizeBytes,
            durationSec: durationSec,
            language: language,
            title: title,
            provider: provider,
            isFavorite: isFavorite,
            createdAt: createdAt,
            plainPath: plainPath,
            timestampedPath: timestampedPath,
            plainText: plainText,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String fileName,
            required int sizeBytes,
            required double durationSec,
            required String language,
            required String title,
            required String provider,
            Value<bool> isFavorite = const Value.absent(),
            required DateTime createdAt,
            required String plainPath,
            required String timestampedPath,
            required String plainText,
          }) =>
              TranscriptsCompanion.insert(
            id: id,
            fileName: fileName,
            sizeBytes: sizeBytes,
            durationSec: durationSec,
            language: language,
            title: title,
            provider: provider,
            isFavorite: isFavorite,
            createdAt: createdAt,
            plainPath: plainPath,
            timestampedPath: timestampedPath,
            plainText: plainText,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TranscriptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TranscriptsTable,
    Transcript,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (Transcript, BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript>),
    Transcript,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
}
