// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $LogsTable extends Logs with TableInfo<$LogsTable, Log> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  @override
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minutesMeta = const VerificationMeta(
    'minutes',
  );
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
    'minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchaseTypeMeta = const VerificationMeta(
    'purchaseType',
  );
  @override
  late final GeneratedColumn<String> purchaseType = GeneratedColumn<String>(
    'purchase_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expGainedMeta = const VerificationMeta(
    'expGained',
  );
  @override
  late final GeneratedColumn<int> expGained = GeneratedColumn<int>(
    'exp_gained',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    action,
    kind,
    subtype,
    minutes,
    purchaseType,
    expGained,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Log> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    }
    if (data.containsKey('minutes')) {
      context.handle(
        _minutesMeta,
        minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta),
      );
    }
    if (data.containsKey('purchase_type')) {
      context.handle(
        _purchaseTypeMeta,
        purchaseType.isAcceptableOrUnknown(
          data['purchase_type']!,
          _purchaseTypeMeta,
        ),
      );
    }
    if (data.containsKey('exp_gained')) {
      context.handle(
        _expGainedMeta,
        expGained.isAcceptableOrUnknown(data['exp_gained']!, _expGainedMeta),
      );
    } else if (isInserting) {
      context.missing(_expGainedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Log map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Log(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      ),
      minutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes'],
      ),
      purchaseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_type'],
      ),
      expGained: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exp_gained'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LogsTable createAlias(String alias) {
    return $LogsTable(attachedDatabase, alias);
  }
}

class Log extends DataClass implements Insertable<Log> {
  final int id;
  final String action;
  final String kind;
  final String? subtype;
  final int? minutes;
  final String? purchaseType;
  final int expGained;
  final DateTime createdAt;
  const Log({
    required this.id,
    required this.action,
    required this.kind,
    this.subtype,
    this.minutes,
    this.purchaseType,
    required this.expGained,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || subtype != null) {
      map['subtype'] = Variable<String>(subtype);
    }
    if (!nullToAbsent || minutes != null) {
      map['minutes'] = Variable<int>(minutes);
    }
    if (!nullToAbsent || purchaseType != null) {
      map['purchase_type'] = Variable<String>(purchaseType);
    }
    map['exp_gained'] = Variable<int>(expGained);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LogsCompanion toCompanion(bool nullToAbsent) {
    return LogsCompanion(
      id: Value(id),
      action: Value(action),
      kind: Value(kind),
      subtype: subtype == null && nullToAbsent
          ? const Value.absent()
          : Value(subtype),
      minutes: minutes == null && nullToAbsent
          ? const Value.absent()
          : Value(minutes),
      purchaseType: purchaseType == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseType),
      expGained: Value(expGained),
      createdAt: Value(createdAt),
    );
  }

  factory Log.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Log(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      kind: serializer.fromJson<String>(json['kind']),
      subtype: serializer.fromJson<String?>(json['subtype']),
      minutes: serializer.fromJson<int?>(json['minutes']),
      purchaseType: serializer.fromJson<String?>(json['purchaseType']),
      expGained: serializer.fromJson<int>(json['expGained']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'kind': serializer.toJson<String>(kind),
      'subtype': serializer.toJson<String?>(subtype),
      'minutes': serializer.toJson<int?>(minutes),
      'purchaseType': serializer.toJson<String?>(purchaseType),
      'expGained': serializer.toJson<int>(expGained),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Log copyWith({
    int? id,
    String? action,
    String? kind,
    Value<String?> subtype = const Value.absent(),
    Value<int?> minutes = const Value.absent(),
    Value<String?> purchaseType = const Value.absent(),
    int? expGained,
    DateTime? createdAt,
  }) => Log(
    id: id ?? this.id,
    action: action ?? this.action,
    kind: kind ?? this.kind,
    subtype: subtype.present ? subtype.value : this.subtype,
    minutes: minutes.present ? minutes.value : this.minutes,
    purchaseType: purchaseType.present ? purchaseType.value : this.purchaseType,
    expGained: expGained ?? this.expGained,
    createdAt: createdAt ?? this.createdAt,
  );
  Log copyWithCompanion(LogsCompanion data) {
    return Log(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      kind: data.kind.present ? data.kind.value : this.kind,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      purchaseType: data.purchaseType.present
          ? data.purchaseType.value
          : this.purchaseType,
      expGained: data.expGained.present ? data.expGained.value : this.expGained,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Log(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('kind: $kind, ')
          ..write('subtype: $subtype, ')
          ..write('minutes: $minutes, ')
          ..write('purchaseType: $purchaseType, ')
          ..write('expGained: $expGained, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    action,
    kind,
    subtype,
    minutes,
    purchaseType,
    expGained,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Log &&
          other.id == this.id &&
          other.action == this.action &&
          other.kind == this.kind &&
          other.subtype == this.subtype &&
          other.minutes == this.minutes &&
          other.purchaseType == this.purchaseType &&
          other.expGained == this.expGained &&
          other.createdAt == this.createdAt);
}

class LogsCompanion extends UpdateCompanion<Log> {
  final Value<int> id;
  final Value<String> action;
  final Value<String> kind;
  final Value<String?> subtype;
  final Value<int?> minutes;
  final Value<String?> purchaseType;
  final Value<int> expGained;
  final Value<DateTime> createdAt;
  const LogsCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.kind = const Value.absent(),
    this.subtype = const Value.absent(),
    this.minutes = const Value.absent(),
    this.purchaseType = const Value.absent(),
    this.expGained = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LogsCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    required String kind,
    this.subtype = const Value.absent(),
    this.minutes = const Value.absent(),
    this.purchaseType = const Value.absent(),
    required int expGained,
    required DateTime createdAt,
  }) : action = Value(action),
       kind = Value(kind),
       expGained = Value(expGained),
       createdAt = Value(createdAt);
  static Insertable<Log> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<String>? kind,
    Expression<String>? subtype,
    Expression<int>? minutes,
    Expression<String>? purchaseType,
    Expression<int>? expGained,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (kind != null) 'kind': kind,
      if (subtype != null) 'subtype': subtype,
      if (minutes != null) 'minutes': minutes,
      if (purchaseType != null) 'purchase_type': purchaseType,
      if (expGained != null) 'exp_gained': expGained,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LogsCompanion copyWith({
    Value<int>? id,
    Value<String>? action,
    Value<String>? kind,
    Value<String?>? subtype,
    Value<int?>? minutes,
    Value<String?>? purchaseType,
    Value<int>? expGained,
    Value<DateTime>? createdAt,
  }) {
    return LogsCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      kind: kind ?? this.kind,
      subtype: subtype ?? this.subtype,
      minutes: minutes ?? this.minutes,
      purchaseType: purchaseType ?? this.purchaseType,
      expGained: expGained ?? this.expGained,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (purchaseType.present) {
      map['purchase_type'] = Variable<String>(purchaseType.value);
    }
    if (expGained.present) {
      map['exp_gained'] = Variable<int>(expGained.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogsCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('kind: $kind, ')
          ..write('subtype: $subtype, ')
          ..write('minutes: $minutes, ')
          ..write('purchaseType: $purchaseType, ')
          ..write('expGained: $expGained, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LogsTable logs = $LogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [logs];
}

typedef $$LogsTableCreateCompanionBuilder =
    LogsCompanion Function({
      Value<int> id,
      required String action,
      required String kind,
      Value<String?> subtype,
      Value<int?> minutes,
      Value<String?> purchaseType,
      required int expGained,
      required DateTime createdAt,
    });
typedef $$LogsTableUpdateCompanionBuilder =
    LogsCompanion Function({
      Value<int> id,
      Value<String> action,
      Value<String> kind,
      Value<String?> subtype,
      Value<int?> minutes,
      Value<String?> purchaseType,
      Value<int> expGained,
      Value<DateTime> createdAt,
    });

class $$LogsTableFilterComposer extends Composer<_$AppDatabase, $LogsTable> {
  $$LogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseType => $composableBuilder(
    column: $table.purchaseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expGained => $composableBuilder(
    column: $table.expGained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LogsTableOrderingComposer extends Composer<_$AppDatabase, $LogsTable> {
  $$LogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseType => $composableBuilder(
    column: $table.purchaseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expGained => $composableBuilder(
    column: $table.expGained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogsTable> {
  $$LogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<String> get purchaseType => $composableBuilder(
    column: $table.purchaseType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expGained =>
      $composableBuilder(column: $table.expGained, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogsTable,
          Log,
          $$LogsTableFilterComposer,
          $$LogsTableOrderingComposer,
          $$LogsTableAnnotationComposer,
          $$LogsTableCreateCompanionBuilder,
          $$LogsTableUpdateCompanionBuilder,
          (Log, BaseReferences<_$AppDatabase, $LogsTable, Log>),
          Log,
          PrefetchHooks Function()
        > {
  $$LogsTableTableManager(_$AppDatabase db, $LogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> subtype = const Value.absent(),
                Value<int?> minutes = const Value.absent(),
                Value<String?> purchaseType = const Value.absent(),
                Value<int> expGained = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LogsCompanion(
                id: id,
                action: action,
                kind: kind,
                subtype: subtype,
                minutes: minutes,
                purchaseType: purchaseType,
                expGained: expGained,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String action,
                required String kind,
                Value<String?> subtype = const Value.absent(),
                Value<int?> minutes = const Value.absent(),
                Value<String?> purchaseType = const Value.absent(),
                required int expGained,
                required DateTime createdAt,
              }) => LogsCompanion.insert(
                id: id,
                action: action,
                kind: kind,
                subtype: subtype,
                minutes: minutes,
                purchaseType: purchaseType,
                expGained: expGained,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogsTable,
      Log,
      $$LogsTableFilterComposer,
      $$LogsTableOrderingComposer,
      $$LogsTableAnnotationComposer,
      $$LogsTableCreateCompanionBuilder,
      $$LogsTableUpdateCompanionBuilder,
      (Log, BaseReferences<_$AppDatabase, $LogsTable, Log>),
      Log,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LogsTableTableManager get logs => $$LogsTableTableManager(_db, _db.logs);
}
