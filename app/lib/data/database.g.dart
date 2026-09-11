// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RealmsTable extends Realms with TableInfo<$RealmsTable, RealmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RealmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNativeMeta = const VerificationMeta(
    'nameNative',
  );
  @override
  late final GeneratedColumn<String> nameNative = GeneratedColumn<String>(
    'name_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _normKeyValueMeta = const VerificationMeta(
    'normKeyValue',
  );
  @override
  late final GeneratedColumn<String> normKeyValue = GeneratedColumn<String>(
    'norm_key_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> contexts =
      GeneratedColumn<String>(
        'contexts',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($RealmsTable.$convertercontexts);
  static const VerificationMeta _selectedMeta = const VerificationMeta(
    'selected',
  );
  @override
  late final GeneratedColumn<bool> selected = GeneratedColumn<bool>(
    'selected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("selected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasMaterialMeta = const VerificationMeta(
    'hasMaterial',
  );
  @override
  late final GeneratedColumn<bool> hasMaterial = GeneratedColumn<bool>(
    'has_material',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_material" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNative,
    normKeyValue,
    importance,
    confidence,
    contexts,
    selected,
    hasMaterial,
    createdAt,
    unlocked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'realms';
  @override
  VerificationContext validateIntegrity(
    Insertable<RealmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_native')) {
      context.handle(
        _nameNativeMeta,
        nameNative.isAcceptableOrUnknown(data['name_native']!, _nameNativeMeta),
      );
    }
    if (data.containsKey('norm_key_value')) {
      context.handle(
        _normKeyValueMeta,
        normKeyValue.isAcceptableOrUnknown(
          data['norm_key_value']!,
          _normKeyValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normKeyValueMeta);
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('selected')) {
      context.handle(
        _selectedMeta,
        selected.isAcceptableOrUnknown(data['selected']!, _selectedMeta),
      );
    }
    if (data.containsKey('has_material')) {
      context.handle(
        _hasMaterialMeta,
        hasMaterial.isAcceptableOrUnknown(
          data['has_material']!,
          _hasMaterialMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RealmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RealmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_native'],
      )!,
      normKeyValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}norm_key_value'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}importance'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      contexts: $RealmsTable.$convertercontexts.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}contexts'],
        )!,
      ),
      selected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}selected'],
      )!,
      hasMaterial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_material'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
    );
  }

  @override
  $RealmsTable createAlias(String alias) {
    return $RealmsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertercontexts =
      const StringListConverter();
}

class RealmRow extends DataClass implements Insertable<RealmRow> {
  final String id;
  final String name;
  final String nameNative;
  final String normKeyValue;
  final int importance;
  final double confidence;
  final List<String> contexts;
  final bool selected;
  final bool hasMaterial;
  final int createdAt;
  final bool unlocked;
  const RealmRow({
    required this.id,
    required this.name,
    required this.nameNative,
    required this.normKeyValue,
    required this.importance,
    required this.confidence,
    required this.contexts,
    required this.selected,
    required this.hasMaterial,
    required this.createdAt,
    required this.unlocked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['name_native'] = Variable<String>(nameNative);
    map['norm_key_value'] = Variable<String>(normKeyValue);
    map['importance'] = Variable<int>(importance);
    map['confidence'] = Variable<double>(confidence);
    {
      map['contexts'] = Variable<String>(
        $RealmsTable.$convertercontexts.toSql(contexts),
      );
    }
    map['selected'] = Variable<bool>(selected);
    map['has_material'] = Variable<bool>(hasMaterial);
    map['created_at'] = Variable<int>(createdAt);
    map['unlocked'] = Variable<bool>(unlocked);
    return map;
  }

  RealmsCompanion toCompanion(bool nullToAbsent) {
    return RealmsCompanion(
      id: Value(id),
      name: Value(name),
      nameNative: Value(nameNative),
      normKeyValue: Value(normKeyValue),
      importance: Value(importance),
      confidence: Value(confidence),
      contexts: Value(contexts),
      selected: Value(selected),
      hasMaterial: Value(hasMaterial),
      createdAt: Value(createdAt),
      unlocked: Value(unlocked),
    );
  }

  factory RealmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RealmRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNative: serializer.fromJson<String>(json['nameNative']),
      normKeyValue: serializer.fromJson<String>(json['normKeyValue']),
      importance: serializer.fromJson<int>(json['importance']),
      confidence: serializer.fromJson<double>(json['confidence']),
      contexts: serializer.fromJson<List<String>>(json['contexts']),
      selected: serializer.fromJson<bool>(json['selected']),
      hasMaterial: serializer.fromJson<bool>(json['hasMaterial']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'nameNative': serializer.toJson<String>(nameNative),
      'normKeyValue': serializer.toJson<String>(normKeyValue),
      'importance': serializer.toJson<int>(importance),
      'confidence': serializer.toJson<double>(confidence),
      'contexts': serializer.toJson<List<String>>(contexts),
      'selected': serializer.toJson<bool>(selected),
      'hasMaterial': serializer.toJson<bool>(hasMaterial),
      'createdAt': serializer.toJson<int>(createdAt),
      'unlocked': serializer.toJson<bool>(unlocked),
    };
  }

  RealmRow copyWith({
    String? id,
    String? name,
    String? nameNative,
    String? normKeyValue,
    int? importance,
    double? confidence,
    List<String>? contexts,
    bool? selected,
    bool? hasMaterial,
    int? createdAt,
    bool? unlocked,
  }) => RealmRow(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNative: nameNative ?? this.nameNative,
    normKeyValue: normKeyValue ?? this.normKeyValue,
    importance: importance ?? this.importance,
    confidence: confidence ?? this.confidence,
    contexts: contexts ?? this.contexts,
    selected: selected ?? this.selected,
    hasMaterial: hasMaterial ?? this.hasMaterial,
    createdAt: createdAt ?? this.createdAt,
    unlocked: unlocked ?? this.unlocked,
  );
  RealmRow copyWithCompanion(RealmsCompanion data) {
    return RealmRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNative: data.nameNative.present
          ? data.nameNative.value
          : this.nameNative,
      normKeyValue: data.normKeyValue.present
          ? data.normKeyValue.value
          : this.normKeyValue,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      contexts: data.contexts.present ? data.contexts.value : this.contexts,
      selected: data.selected.present ? data.selected.value : this.selected,
      hasMaterial: data.hasMaterial.present
          ? data.hasMaterial.value
          : this.hasMaterial,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RealmRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNative: $nameNative, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('importance: $importance, ')
          ..write('confidence: $confidence, ')
          ..write('contexts: $contexts, ')
          ..write('selected: $selected, ')
          ..write('hasMaterial: $hasMaterial, ')
          ..write('createdAt: $createdAt, ')
          ..write('unlocked: $unlocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameNative,
    normKeyValue,
    importance,
    confidence,
    contexts,
    selected,
    hasMaterial,
    createdAt,
    unlocked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RealmRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNative == this.nameNative &&
          other.normKeyValue == this.normKeyValue &&
          other.importance == this.importance &&
          other.confidence == this.confidence &&
          other.contexts == this.contexts &&
          other.selected == this.selected &&
          other.hasMaterial == this.hasMaterial &&
          other.createdAt == this.createdAt &&
          other.unlocked == this.unlocked);
}

class RealmsCompanion extends UpdateCompanion<RealmRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nameNative;
  final Value<String> normKeyValue;
  final Value<int> importance;
  final Value<double> confidence;
  final Value<List<String>> contexts;
  final Value<bool> selected;
  final Value<bool> hasMaterial;
  final Value<int> createdAt;
  final Value<bool> unlocked;
  final Value<int> rowid;
  const RealmsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNative = const Value.absent(),
    this.normKeyValue = const Value.absent(),
    this.importance = const Value.absent(),
    this.confidence = const Value.absent(),
    this.contexts = const Value.absent(),
    this.selected = const Value.absent(),
    this.hasMaterial = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RealmsCompanion.insert({
    required String id,
    required String name,
    this.nameNative = const Value.absent(),
    required String normKeyValue,
    this.importance = const Value.absent(),
    this.confidence = const Value.absent(),
    this.contexts = const Value.absent(),
    this.selected = const Value.absent(),
    this.hasMaterial = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normKeyValue = Value(normKeyValue);
  static Insertable<RealmRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nameNative,
    Expression<String>? normKeyValue,
    Expression<int>? importance,
    Expression<double>? confidence,
    Expression<String>? contexts,
    Expression<bool>? selected,
    Expression<bool>? hasMaterial,
    Expression<int>? createdAt,
    Expression<bool>? unlocked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNative != null) 'name_native': nameNative,
      if (normKeyValue != null) 'norm_key_value': normKeyValue,
      if (importance != null) 'importance': importance,
      if (confidence != null) 'confidence': confidence,
      if (contexts != null) 'contexts': contexts,
      if (selected != null) 'selected': selected,
      if (hasMaterial != null) 'has_material': hasMaterial,
      if (createdAt != null) 'created_at': createdAt,
      if (unlocked != null) 'unlocked': unlocked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RealmsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nameNative,
    Value<String>? normKeyValue,
    Value<int>? importance,
    Value<double>? confidence,
    Value<List<String>>? contexts,
    Value<bool>? selected,
    Value<bool>? hasMaterial,
    Value<int>? createdAt,
    Value<bool>? unlocked,
    Value<int>? rowid,
  }) {
    return RealmsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNative: nameNative ?? this.nameNative,
      normKeyValue: normKeyValue ?? this.normKeyValue,
      importance: importance ?? this.importance,
      confidence: confidence ?? this.confidence,
      contexts: contexts ?? this.contexts,
      selected: selected ?? this.selected,
      hasMaterial: hasMaterial ?? this.hasMaterial,
      createdAt: createdAt ?? this.createdAt,
      unlocked: unlocked ?? this.unlocked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNative.present) {
      map['name_native'] = Variable<String>(nameNative.value);
    }
    if (normKeyValue.present) {
      map['norm_key_value'] = Variable<String>(normKeyValue.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (contexts.present) {
      map['contexts'] = Variable<String>(
        $RealmsTable.$convertercontexts.toSql(contexts.value),
      );
    }
    if (selected.present) {
      map['selected'] = Variable<bool>(selected.value);
    }
    if (hasMaterial.present) {
      map['has_material'] = Variable<bool>(hasMaterial.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RealmsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNative: $nameNative, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('importance: $importance, ')
          ..write('confidence: $confidence, ')
          ..write('contexts: $contexts, ')
          ..write('selected: $selected, ')
          ..write('hasMaterial: $hasMaterial, ')
          ..write('createdAt: $createdAt, ')
          ..write('unlocked: $unlocked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScenesTable extends Scenes with TableInfo<$ScenesTable, SceneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScenesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleNativeMeta = const VerificationMeta(
    'titleNative',
  );
  @override
  late final GeneratedColumn<String> titleNative = GeneratedColumn<String>(
    'title_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _situationMeta = const VerificationMeta(
    'situation',
  );
  @override
  late final GeneratedColumn<String> situation = GeneratedColumn<String>(
    'situation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _settingNativeMeta = const VerificationMeta(
    'settingNative',
  );
  @override
  late final GeneratedColumn<String> settingNative = GeneratedColumn<String>(
    'setting_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _windowMsMeta = const VerificationMeta(
    'windowMs',
  );
  @override
  late final GeneratedColumn<int> windowMs = GeneratedColumn<int>(
    'window_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(sc.defaultWindowMs),
  );
  static const VerificationMeta _turnsMeta = const VerificationMeta('turns');
  @override
  late final GeneratedColumn<String> turns = GeneratedColumn<String>(
    'turns',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ai'),
  );
  static const VerificationMeta _realmIdMeta = const VerificationMeta(
    'realmId',
  );
  @override
  late final GeneratedColumn<String> realmId = GeneratedColumn<String>(
    'realm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _disabledMeta = const VerificationMeta(
    'disabled',
  );
  @override
  late final GeneratedColumn<bool> disabled = GeneratedColumn<bool>(
    'disabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("disabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    titleNative,
    situation,
    settingNative,
    windowMs,
    turns,
    source,
    realmId,
    createdAt,
    disabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SceneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_native')) {
      context.handle(
        _titleNativeMeta,
        titleNative.isAcceptableOrUnknown(
          data['title_native']!,
          _titleNativeMeta,
        ),
      );
    }
    if (data.containsKey('situation')) {
      context.handle(
        _situationMeta,
        situation.isAcceptableOrUnknown(data['situation']!, _situationMeta),
      );
    }
    if (data.containsKey('setting_native')) {
      context.handle(
        _settingNativeMeta,
        settingNative.isAcceptableOrUnknown(
          data['setting_native']!,
          _settingNativeMeta,
        ),
      );
    }
    if (data.containsKey('window_ms')) {
      context.handle(
        _windowMsMeta,
        windowMs.isAcceptableOrUnknown(data['window_ms']!, _windowMsMeta),
      );
    }
    if (data.containsKey('turns')) {
      context.handle(
        _turnsMeta,
        turns.isAcceptableOrUnknown(data['turns']!, _turnsMeta),
      );
    } else if (isInserting) {
      context.missing(_turnsMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('realm_id')) {
      context.handle(
        _realmIdMeta,
        realmId.isAcceptableOrUnknown(data['realm_id']!, _realmIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('disabled')) {
      context.handle(
        _disabledMeta,
        disabled.isAcceptableOrUnknown(data['disabled']!, _disabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SceneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SceneRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_native'],
      )!,
      situation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}situation'],
      )!,
      settingNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_native'],
      )!,
      windowMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_ms'],
      )!,
      turns: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turns'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      realmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realm_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      disabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disabled'],
      )!,
    );
  }

  @override
  $ScenesTable createAlias(String alias) {
    return $ScenesTable(attachedDatabase, alias);
  }
}

class SceneRow extends DataClass implements Insertable<SceneRow> {
  final String id;
  final String title;
  final String titleNative;

  /// The situation inside a field — "meetings" inside "work". What opens as
  /// the ladder is climbed.
  final String situation;
  final String settingNative;

  /// How long the reply window stays open here. Carried per conversation
  /// because the gap between turns is part of what is being practised.
  final int windowMs;
  final String turns;

  /// 'ai' for conversations the learner's own AI made. Built-ins never sit
  /// here — they ship with the app.
  final String source;
  final String? realmId;
  final int createdAt;
  final bool disabled;
  const SceneRow({
    required this.id,
    required this.title,
    required this.titleNative,
    required this.situation,
    required this.settingNative,
    required this.windowMs,
    required this.turns,
    required this.source,
    this.realmId,
    required this.createdAt,
    required this.disabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['title_native'] = Variable<String>(titleNative);
    map['situation'] = Variable<String>(situation);
    map['setting_native'] = Variable<String>(settingNative);
    map['window_ms'] = Variable<int>(windowMs);
    map['turns'] = Variable<String>(turns);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || realmId != null) {
      map['realm_id'] = Variable<String>(realmId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['disabled'] = Variable<bool>(disabled);
    return map;
  }

  ScenesCompanion toCompanion(bool nullToAbsent) {
    return ScenesCompanion(
      id: Value(id),
      title: Value(title),
      titleNative: Value(titleNative),
      situation: Value(situation),
      settingNative: Value(settingNative),
      windowMs: Value(windowMs),
      turns: Value(turns),
      source: Value(source),
      realmId: realmId == null && nullToAbsent
          ? const Value.absent()
          : Value(realmId),
      createdAt: Value(createdAt),
      disabled: Value(disabled),
    );
  }

  factory SceneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SceneRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      titleNative: serializer.fromJson<String>(json['titleNative']),
      situation: serializer.fromJson<String>(json['situation']),
      settingNative: serializer.fromJson<String>(json['settingNative']),
      windowMs: serializer.fromJson<int>(json['windowMs']),
      turns: serializer.fromJson<String>(json['turns']),
      source: serializer.fromJson<String>(json['source']),
      realmId: serializer.fromJson<String?>(json['realmId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      disabled: serializer.fromJson<bool>(json['disabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'titleNative': serializer.toJson<String>(titleNative),
      'situation': serializer.toJson<String>(situation),
      'settingNative': serializer.toJson<String>(settingNative),
      'windowMs': serializer.toJson<int>(windowMs),
      'turns': serializer.toJson<String>(turns),
      'source': serializer.toJson<String>(source),
      'realmId': serializer.toJson<String?>(realmId),
      'createdAt': serializer.toJson<int>(createdAt),
      'disabled': serializer.toJson<bool>(disabled),
    };
  }

  SceneRow copyWith({
    String? id,
    String? title,
    String? titleNative,
    String? situation,
    String? settingNative,
    int? windowMs,
    String? turns,
    String? source,
    Value<String?> realmId = const Value.absent(),
    int? createdAt,
    bool? disabled,
  }) => SceneRow(
    id: id ?? this.id,
    title: title ?? this.title,
    titleNative: titleNative ?? this.titleNative,
    situation: situation ?? this.situation,
    settingNative: settingNative ?? this.settingNative,
    windowMs: windowMs ?? this.windowMs,
    turns: turns ?? this.turns,
    source: source ?? this.source,
    realmId: realmId.present ? realmId.value : this.realmId,
    createdAt: createdAt ?? this.createdAt,
    disabled: disabled ?? this.disabled,
  );
  SceneRow copyWithCompanion(ScenesCompanion data) {
    return SceneRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      titleNative: data.titleNative.present
          ? data.titleNative.value
          : this.titleNative,
      situation: data.situation.present ? data.situation.value : this.situation,
      settingNative: data.settingNative.present
          ? data.settingNative.value
          : this.settingNative,
      windowMs: data.windowMs.present ? data.windowMs.value : this.windowMs,
      turns: data.turns.present ? data.turns.value : this.turns,
      source: data.source.present ? data.source.value : this.source,
      realmId: data.realmId.present ? data.realmId.value : this.realmId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      disabled: data.disabled.present ? data.disabled.value : this.disabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SceneRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleNative: $titleNative, ')
          ..write('situation: $situation, ')
          ..write('settingNative: $settingNative, ')
          ..write('windowMs: $windowMs, ')
          ..write('turns: $turns, ')
          ..write('source: $source, ')
          ..write('realmId: $realmId, ')
          ..write('createdAt: $createdAt, ')
          ..write('disabled: $disabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleNative,
    situation,
    settingNative,
    windowMs,
    turns,
    source,
    realmId,
    createdAt,
    disabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SceneRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.titleNative == this.titleNative &&
          other.situation == this.situation &&
          other.settingNative == this.settingNative &&
          other.windowMs == this.windowMs &&
          other.turns == this.turns &&
          other.source == this.source &&
          other.realmId == this.realmId &&
          other.createdAt == this.createdAt &&
          other.disabled == this.disabled);
}

class ScenesCompanion extends UpdateCompanion<SceneRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> titleNative;
  final Value<String> situation;
  final Value<String> settingNative;
  final Value<int> windowMs;
  final Value<String> turns;
  final Value<String> source;
  final Value<String?> realmId;
  final Value<int> createdAt;
  final Value<bool> disabled;
  final Value<int> rowid;
  const ScenesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.situation = const Value.absent(),
    this.settingNative = const Value.absent(),
    this.windowMs = const Value.absent(),
    this.turns = const Value.absent(),
    this.source = const Value.absent(),
    this.realmId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScenesCompanion.insert({
    required String id,
    required String title,
    this.titleNative = const Value.absent(),
    this.situation = const Value.absent(),
    this.settingNative = const Value.absent(),
    this.windowMs = const Value.absent(),
    required String turns,
    this.source = const Value.absent(),
    this.realmId = const Value.absent(),
    required int createdAt,
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       turns = Value(turns),
       createdAt = Value(createdAt);
  static Insertable<SceneRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? titleNative,
    Expression<String>? situation,
    Expression<String>? settingNative,
    Expression<int>? windowMs,
    Expression<String>? turns,
    Expression<String>? source,
    Expression<String>? realmId,
    Expression<int>? createdAt,
    Expression<bool>? disabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (titleNative != null) 'title_native': titleNative,
      if (situation != null) 'situation': situation,
      if (settingNative != null) 'setting_native': settingNative,
      if (windowMs != null) 'window_ms': windowMs,
      if (turns != null) 'turns': turns,
      if (source != null) 'source': source,
      if (realmId != null) 'realm_id': realmId,
      if (createdAt != null) 'created_at': createdAt,
      if (disabled != null) 'disabled': disabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScenesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? titleNative,
    Value<String>? situation,
    Value<String>? settingNative,
    Value<int>? windowMs,
    Value<String>? turns,
    Value<String>? source,
    Value<String?>? realmId,
    Value<int>? createdAt,
    Value<bool>? disabled,
    Value<int>? rowid,
  }) {
    return ScenesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      titleNative: titleNative ?? this.titleNative,
      situation: situation ?? this.situation,
      settingNative: settingNative ?? this.settingNative,
      windowMs: windowMs ?? this.windowMs,
      turns: turns ?? this.turns,
      source: source ?? this.source,
      realmId: realmId ?? this.realmId,
      createdAt: createdAt ?? this.createdAt,
      disabled: disabled ?? this.disabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleNative.present) {
      map['title_native'] = Variable<String>(titleNative.value);
    }
    if (situation.present) {
      map['situation'] = Variable<String>(situation.value);
    }
    if (settingNative.present) {
      map['setting_native'] = Variable<String>(settingNative.value);
    }
    if (windowMs.present) {
      map['window_ms'] = Variable<int>(windowMs.value);
    }
    if (turns.present) {
      map['turns'] = Variable<String>(turns.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (realmId.present) {
      map['realm_id'] = Variable<String>(realmId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (disabled.present) {
      map['disabled'] = Variable<bool>(disabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScenesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleNative: $titleNative, ')
          ..write('situation: $situation, ')
          ..write('settingNative: $settingNative, ')
          ..write('windowMs: $windowMs, ')
          ..write('turns: $turns, ')
          ..write('source: $source, ')
          ..write('realmId: $realmId, ')
          ..write('createdAt: $createdAt, ')
          ..write('disabled: $disabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SceneResultsTable extends SceneResults
    with TableInfo<$SceneResultsTable, TurnResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SceneResultsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<String> sceneId = GeneratedColumn<String>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnMeta = const VerificationMeta('turn');
  @override
  late final GeneratedColumn<int> turn = GeneratedColumn<int>(
    'turn',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _missedSlotMeta = const VerificationMeta(
    'missedSlot',
  );
  @override
  late final GeneratedColumn<String> missedSlot = GeneratedColumn<String>(
    'missed_slot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inWindowMeta = const VerificationMeta(
    'inWindow',
  );
  @override
  late final GeneratedColumn<bool> inWindow = GeneratedColumn<bool>(
    'in_window',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_window" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _reviewMeta = const VerificationMeta('review');
  @override
  late final GeneratedColumn<bool> review = GeneratedColumn<bool>(
    'review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sceneId,
    turn,
    correct,
    missedSlot,
    inWindow,
    review,
    day,
    at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scene_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<TurnResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('turn')) {
      context.handle(
        _turnMeta,
        turn.isAcceptableOrUnknown(data['turn']!, _turnMeta),
      );
    } else if (isInserting) {
      context.missing(_turnMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('missed_slot')) {
      context.handle(
        _missedSlotMeta,
        missedSlot.isAcceptableOrUnknown(data['missed_slot']!, _missedSlotMeta),
      );
    }
    if (data.containsKey('in_window')) {
      context.handle(
        _inWindowMeta,
        inWindow.isAcceptableOrUnknown(data['in_window']!, _inWindowMeta),
      );
    }
    if (data.containsKey('review')) {
      context.handle(
        _reviewMeta,
        review.isAcceptableOrUnknown(data['review']!, _reviewMeta),
      );
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TurnResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TurnResultRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_id'],
      )!,
      turn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      missedSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}missed_slot'],
      ),
      inWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_window'],
      )!,
      review: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}review'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $SceneResultsTable createAlias(String alias) {
    return $SceneResultsTable(attachedDatabase, alias);
  }
}

class TurnResultRow extends DataClass implements Insertable<TurnResultRow> {
  final int id;
  final String sceneId;
  final int turn;
  final bool correct;

  /// For a missed multiFact turn: the fact that was dropped, so the same
  /// weakness can be found again.
  final String? missedSlot;

  /// Answered inside the window, without waiting to be told again. Keeping up
  /// at conversation speed is only claimed when this is true.
  final bool inWindow;

  /// Came up as a review rather than inside its conversation.
  final bool review;
  final String day;
  final int at;
  const TurnResultRow({
    required this.id,
    required this.sceneId,
    required this.turn,
    required this.correct,
    this.missedSlot,
    required this.inWindow,
    required this.review,
    required this.day,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scene_id'] = Variable<String>(sceneId);
    map['turn'] = Variable<int>(turn);
    map['correct'] = Variable<bool>(correct);
    if (!nullToAbsent || missedSlot != null) {
      map['missed_slot'] = Variable<String>(missedSlot);
    }
    map['in_window'] = Variable<bool>(inWindow);
    map['review'] = Variable<bool>(review);
    map['day'] = Variable<String>(day);
    map['at'] = Variable<int>(at);
    return map;
  }

  SceneResultsCompanion toCompanion(bool nullToAbsent) {
    return SceneResultsCompanion(
      id: Value(id),
      sceneId: Value(sceneId),
      turn: Value(turn),
      correct: Value(correct),
      missedSlot: missedSlot == null && nullToAbsent
          ? const Value.absent()
          : Value(missedSlot),
      inWindow: Value(inWindow),
      review: Value(review),
      day: Value(day),
      at: Value(at),
    );
  }

  factory TurnResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TurnResultRow(
      id: serializer.fromJson<int>(json['id']),
      sceneId: serializer.fromJson<String>(json['sceneId']),
      turn: serializer.fromJson<int>(json['turn']),
      correct: serializer.fromJson<bool>(json['correct']),
      missedSlot: serializer.fromJson<String?>(json['missedSlot']),
      inWindow: serializer.fromJson<bool>(json['inWindow']),
      review: serializer.fromJson<bool>(json['review']),
      day: serializer.fromJson<String>(json['day']),
      at: serializer.fromJson<int>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sceneId': serializer.toJson<String>(sceneId),
      'turn': serializer.toJson<int>(turn),
      'correct': serializer.toJson<bool>(correct),
      'missedSlot': serializer.toJson<String?>(missedSlot),
      'inWindow': serializer.toJson<bool>(inWindow),
      'review': serializer.toJson<bool>(review),
      'day': serializer.toJson<String>(day),
      'at': serializer.toJson<int>(at),
    };
  }

  TurnResultRow copyWith({
    int? id,
    String? sceneId,
    int? turn,
    bool? correct,
    Value<String?> missedSlot = const Value.absent(),
    bool? inWindow,
    bool? review,
    String? day,
    int? at,
  }) => TurnResultRow(
    id: id ?? this.id,
    sceneId: sceneId ?? this.sceneId,
    turn: turn ?? this.turn,
    correct: correct ?? this.correct,
    missedSlot: missedSlot.present ? missedSlot.value : this.missedSlot,
    inWindow: inWindow ?? this.inWindow,
    review: review ?? this.review,
    day: day ?? this.day,
    at: at ?? this.at,
  );
  TurnResultRow copyWithCompanion(SceneResultsCompanion data) {
    return TurnResultRow(
      id: data.id.present ? data.id.value : this.id,
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      turn: data.turn.present ? data.turn.value : this.turn,
      correct: data.correct.present ? data.correct.value : this.correct,
      missedSlot: data.missedSlot.present
          ? data.missedSlot.value
          : this.missedSlot,
      inWindow: data.inWindow.present ? data.inWindow.value : this.inWindow,
      review: data.review.present ? data.review.value : this.review,
      day: data.day.present ? data.day.value : this.day,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TurnResultRow(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('turn: $turn, ')
          ..write('correct: $correct, ')
          ..write('missedSlot: $missedSlot, ')
          ..write('inWindow: $inWindow, ')
          ..write('review: $review, ')
          ..write('day: $day, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sceneId,
    turn,
    correct,
    missedSlot,
    inWindow,
    review,
    day,
    at,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TurnResultRow &&
          other.id == this.id &&
          other.sceneId == this.sceneId &&
          other.turn == this.turn &&
          other.correct == this.correct &&
          other.missedSlot == this.missedSlot &&
          other.inWindow == this.inWindow &&
          other.review == this.review &&
          other.day == this.day &&
          other.at == this.at);
}

class SceneResultsCompanion extends UpdateCompanion<TurnResultRow> {
  final Value<int> id;
  final Value<String> sceneId;
  final Value<int> turn;
  final Value<bool> correct;
  final Value<String?> missedSlot;
  final Value<bool> inWindow;
  final Value<bool> review;
  final Value<String> day;
  final Value<int> at;
  const SceneResultsCompanion({
    this.id = const Value.absent(),
    this.sceneId = const Value.absent(),
    this.turn = const Value.absent(),
    this.correct = const Value.absent(),
    this.missedSlot = const Value.absent(),
    this.inWindow = const Value.absent(),
    this.review = const Value.absent(),
    this.day = const Value.absent(),
    this.at = const Value.absent(),
  });
  SceneResultsCompanion.insert({
    this.id = const Value.absent(),
    required String sceneId,
    required int turn,
    required bool correct,
    this.missedSlot = const Value.absent(),
    this.inWindow = const Value.absent(),
    this.review = const Value.absent(),
    required String day,
    required int at,
  }) : sceneId = Value(sceneId),
       turn = Value(turn),
       correct = Value(correct),
       day = Value(day),
       at = Value(at);
  static Insertable<TurnResultRow> custom({
    Expression<int>? id,
    Expression<String>? sceneId,
    Expression<int>? turn,
    Expression<bool>? correct,
    Expression<String>? missedSlot,
    Expression<bool>? inWindow,
    Expression<bool>? review,
    Expression<String>? day,
    Expression<int>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sceneId != null) 'scene_id': sceneId,
      if (turn != null) 'turn': turn,
      if (correct != null) 'correct': correct,
      if (missedSlot != null) 'missed_slot': missedSlot,
      if (inWindow != null) 'in_window': inWindow,
      if (review != null) 'review': review,
      if (day != null) 'day': day,
      if (at != null) 'at': at,
    });
  }

  SceneResultsCompanion copyWith({
    Value<int>? id,
    Value<String>? sceneId,
    Value<int>? turn,
    Value<bool>? correct,
    Value<String?>? missedSlot,
    Value<bool>? inWindow,
    Value<bool>? review,
    Value<String>? day,
    Value<int>? at,
  }) {
    return SceneResultsCompanion(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      turn: turn ?? this.turn,
      correct: correct ?? this.correct,
      missedSlot: missedSlot ?? this.missedSlot,
      inWindow: inWindow ?? this.inWindow,
      review: review ?? this.review,
      day: day ?? this.day,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sceneId.present) {
      map['scene_id'] = Variable<String>(sceneId.value);
    }
    if (turn.present) {
      map['turn'] = Variable<int>(turn.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (missedSlot.present) {
      map['missed_slot'] = Variable<String>(missedSlot.value);
    }
    if (inWindow.present) {
      map['in_window'] = Variable<bool>(inWindow.value);
    }
    if (review.present) {
      map['review'] = Variable<bool>(review.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SceneResultsCompanion(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('turn: $turn, ')
          ..write('correct: $correct, ')
          ..write('missedSlot: $missedSlot, ')
          ..write('inWindow: $inWindow, ')
          ..write('review: $review, ')
          ..write('day: $day, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $ReviewsTable extends Reviews with TableInfo<$ReviewsTable, ReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<String> sceneId = GeneratedColumn<String>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnMeta = const VerificationMeta('turn');
  @override
  late final GeneratedColumn<int> turn = GeneratedColumn<int>(
    'turn',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<String> dueDay = GeneratedColumn<String>(
    'due_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<int> stage = GeneratedColumn<int>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [sceneId, turn, dueDay, stage];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('turn')) {
      context.handle(
        _turnMeta,
        turn.isAcceptableOrUnknown(data['turn']!, _turnMeta),
      );
    } else if (isInserting) {
      context.missing(_turnMeta);
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDayMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sceneId, turn};
  @override
  ReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRow(
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_id'],
      )!,
      turn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn'],
      )!,
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_day'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage'],
      )!,
    );
  }

  @override
  $ReviewsTable createAlias(String alias) {
    return $ReviewsTable(attachedDatabase, alias);
  }
}

class ReviewRow extends DataClass implements Insertable<ReviewRow> {
  final String sceneId;
  final int turn;
  final String dueDay;
  final int stage;
  const ReviewRow({
    required this.sceneId,
    required this.turn,
    required this.dueDay,
    required this.stage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scene_id'] = Variable<String>(sceneId);
    map['turn'] = Variable<int>(turn);
    map['due_day'] = Variable<String>(dueDay);
    map['stage'] = Variable<int>(stage);
    return map;
  }

  ReviewsCompanion toCompanion(bool nullToAbsent) {
    return ReviewsCompanion(
      sceneId: Value(sceneId),
      turn: Value(turn),
      dueDay: Value(dueDay),
      stage: Value(stage),
    );
  }

  factory ReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewRow(
      sceneId: serializer.fromJson<String>(json['sceneId']),
      turn: serializer.fromJson<int>(json['turn']),
      dueDay: serializer.fromJson<String>(json['dueDay']),
      stage: serializer.fromJson<int>(json['stage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sceneId': serializer.toJson<String>(sceneId),
      'turn': serializer.toJson<int>(turn),
      'dueDay': serializer.toJson<String>(dueDay),
      'stage': serializer.toJson<int>(stage),
    };
  }

  ReviewRow copyWith({
    String? sceneId,
    int? turn,
    String? dueDay,
    int? stage,
  }) => ReviewRow(
    sceneId: sceneId ?? this.sceneId,
    turn: turn ?? this.turn,
    dueDay: dueDay ?? this.dueDay,
    stage: stage ?? this.stage,
  );
  ReviewRow copyWithCompanion(ReviewsCompanion data) {
    return ReviewRow(
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      turn: data.turn.present ? data.turn.value : this.turn,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      stage: data.stage.present ? data.stage.value : this.stage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRow(')
          ..write('sceneId: $sceneId, ')
          ..write('turn: $turn, ')
          ..write('dueDay: $dueDay, ')
          ..write('stage: $stage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sceneId, turn, dueDay, stage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewRow &&
          other.sceneId == this.sceneId &&
          other.turn == this.turn &&
          other.dueDay == this.dueDay &&
          other.stage == this.stage);
}

class ReviewsCompanion extends UpdateCompanion<ReviewRow> {
  final Value<String> sceneId;
  final Value<int> turn;
  final Value<String> dueDay;
  final Value<int> stage;
  final Value<int> rowid;
  const ReviewsCompanion({
    this.sceneId = const Value.absent(),
    this.turn = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.stage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewsCompanion.insert({
    required String sceneId,
    required int turn,
    required String dueDay,
    this.stage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sceneId = Value(sceneId),
       turn = Value(turn),
       dueDay = Value(dueDay);
  static Insertable<ReviewRow> custom({
    Expression<String>? sceneId,
    Expression<int>? turn,
    Expression<String>? dueDay,
    Expression<int>? stage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sceneId != null) 'scene_id': sceneId,
      if (turn != null) 'turn': turn,
      if (dueDay != null) 'due_day': dueDay,
      if (stage != null) 'stage': stage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewsCompanion copyWith({
    Value<String>? sceneId,
    Value<int>? turn,
    Value<String>? dueDay,
    Value<int>? stage,
    Value<int>? rowid,
  }) {
    return ReviewsCompanion(
      sceneId: sceneId ?? this.sceneId,
      turn: turn ?? this.turn,
      dueDay: dueDay ?? this.dueDay,
      stage: stage ?? this.stage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sceneId.present) {
      map['scene_id'] = Variable<String>(sceneId.value);
    }
    if (turn.present) {
      map['turn'] = Variable<int>(turn.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<String>(dueDay.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(stage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewsCompanion(')
          ..write('sceneId: $sceneId, ')
          ..write('turn: $turn, ')
          ..write('dueDay: $dueDay, ')
          ..write('stage: $stage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RealmsTable realms = $RealmsTable(this);
  late final $ScenesTable scenes = $ScenesTable(this);
  late final $SceneResultsTable sceneResults = $SceneResultsTable(this);
  late final $ReviewsTable reviews = $ReviewsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    realms,
    scenes,
    sceneResults,
    reviews,
    meta,
  ];
}

typedef $$RealmsTableCreateCompanionBuilder =
    RealmsCompanion Function({
      required String id,
      required String name,
      Value<String> nameNative,
      required String normKeyValue,
      Value<int> importance,
      Value<double> confidence,
      Value<List<String>> contexts,
      Value<bool> selected,
      Value<bool> hasMaterial,
      Value<int> createdAt,
      Value<bool> unlocked,
      Value<int> rowid,
    });
typedef $$RealmsTableUpdateCompanionBuilder =
    RealmsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> nameNative,
      Value<String> normKeyValue,
      Value<int> importance,
      Value<double> confidence,
      Value<List<String>> contexts,
      Value<bool> selected,
      Value<bool> hasMaterial,
      Value<int> createdAt,
      Value<bool> unlocked,
      Value<int> rowid,
    });

class $$RealmsTableFilterComposer
    extends Composer<_$AppDatabase, $RealmsTable> {
  $$RealmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNative => $composableBuilder(
    column: $table.nameNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get contexts => $composableBuilder(
    column: $table.contexts,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasMaterial => $composableBuilder(
    column: $table.hasMaterial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RealmsTableOrderingComposer
    extends Composer<_$AppDatabase, $RealmsTable> {
  $$RealmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNative => $composableBuilder(
    column: $table.nameNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contexts => $composableBuilder(
    column: $table.contexts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasMaterial => $composableBuilder(
    column: $table.hasMaterial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RealmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RealmsTable> {
  $$RealmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNative => $composableBuilder(
    column: $table.nameNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get contexts =>
      $composableBuilder(column: $table.contexts, builder: (column) => column);

  GeneratedColumn<bool> get selected =>
      $composableBuilder(column: $table.selected, builder: (column) => column);

  GeneratedColumn<bool> get hasMaterial => $composableBuilder(
    column: $table.hasMaterial,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);
}

class $$RealmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RealmsTable,
          RealmRow,
          $$RealmsTableFilterComposer,
          $$RealmsTableOrderingComposer,
          $$RealmsTableAnnotationComposer,
          $$RealmsTableCreateCompanionBuilder,
          $$RealmsTableUpdateCompanionBuilder,
          (RealmRow, BaseReferences<_$AppDatabase, $RealmsTable, RealmRow>),
          RealmRow,
          PrefetchHooks Function()
        > {
  $$RealmsTableTableManager(_$AppDatabase db, $RealmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RealmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RealmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RealmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNative = const Value.absent(),
                Value<String> normKeyValue = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> contexts = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> hasMaterial = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RealmsCompanion(
                id: id,
                name: name,
                nameNative: nameNative,
                normKeyValue: normKeyValue,
                importance: importance,
                confidence: confidence,
                contexts: contexts,
                selected: selected,
                hasMaterial: hasMaterial,
                createdAt: createdAt,
                unlocked: unlocked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> nameNative = const Value.absent(),
                required String normKeyValue,
                Value<int> importance = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> contexts = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> hasMaterial = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RealmsCompanion.insert(
                id: id,
                name: name,
                nameNative: nameNative,
                normKeyValue: normKeyValue,
                importance: importance,
                confidence: confidence,
                contexts: contexts,
                selected: selected,
                hasMaterial: hasMaterial,
                createdAt: createdAt,
                unlocked: unlocked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RealmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RealmsTable,
      RealmRow,
      $$RealmsTableFilterComposer,
      $$RealmsTableOrderingComposer,
      $$RealmsTableAnnotationComposer,
      $$RealmsTableCreateCompanionBuilder,
      $$RealmsTableUpdateCompanionBuilder,
      (RealmRow, BaseReferences<_$AppDatabase, $RealmsTable, RealmRow>),
      RealmRow,
      PrefetchHooks Function()
    >;
typedef $$ScenesTableCreateCompanionBuilder =
    ScenesCompanion Function({
      required String id,
      required String title,
      Value<String> titleNative,
      Value<String> situation,
      Value<String> settingNative,
      Value<int> windowMs,
      required String turns,
      Value<String> source,
      Value<String?> realmId,
      required int createdAt,
      Value<bool> disabled,
      Value<int> rowid,
    });
typedef $$ScenesTableUpdateCompanionBuilder =
    ScenesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> titleNative,
      Value<String> situation,
      Value<String> settingNative,
      Value<int> windowMs,
      Value<String> turns,
      Value<String> source,
      Value<String?> realmId,
      Value<int> createdAt,
      Value<bool> disabled,
      Value<int> rowid,
    });

class $$ScenesTableFilterComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get situation => $composableBuilder(
    column: $table.situation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingNative => $composableBuilder(
    column: $table.settingNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowMs => $composableBuilder(
    column: $table.windowMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turns => $composableBuilder(
    column: $table.turns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScenesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get situation => $composableBuilder(
    column: $table.situation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingNative => $composableBuilder(
    column: $table.settingNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowMs => $composableBuilder(
    column: $table.windowMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turns => $composableBuilder(
    column: $table.turns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get situation =>
      $composableBuilder(column: $table.situation, builder: (column) => column);

  GeneratedColumn<String> get settingNative => $composableBuilder(
    column: $table.settingNative,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowMs =>
      $composableBuilder(column: $table.windowMs, builder: (column) => column);

  GeneratedColumn<String> get turns =>
      $composableBuilder(column: $table.turns, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get realmId =>
      $composableBuilder(column: $table.realmId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get disabled =>
      $composableBuilder(column: $table.disabled, builder: (column) => column);
}

class $$ScenesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScenesTable,
          SceneRow,
          $$ScenesTableFilterComposer,
          $$ScenesTableOrderingComposer,
          $$ScenesTableAnnotationComposer,
          $$ScenesTableCreateCompanionBuilder,
          $$ScenesTableUpdateCompanionBuilder,
          (SceneRow, BaseReferences<_$AppDatabase, $ScenesTable, SceneRow>),
          SceneRow,
          PrefetchHooks Function()
        > {
  $$ScenesTableTableManager(_$AppDatabase db, $ScenesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleNative = const Value.absent(),
                Value<String> situation = const Value.absent(),
                Value<String> settingNative = const Value.absent(),
                Value<int> windowMs = const Value.absent(),
                Value<String> turns = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> realmId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScenesCompanion(
                id: id,
                title: title,
                titleNative: titleNative,
                situation: situation,
                settingNative: settingNative,
                windowMs: windowMs,
                turns: turns,
                source: source,
                realmId: realmId,
                createdAt: createdAt,
                disabled: disabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> titleNative = const Value.absent(),
                Value<String> situation = const Value.absent(),
                Value<String> settingNative = const Value.absent(),
                Value<int> windowMs = const Value.absent(),
                required String turns,
                Value<String> source = const Value.absent(),
                Value<String?> realmId = const Value.absent(),
                required int createdAt,
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScenesCompanion.insert(
                id: id,
                title: title,
                titleNative: titleNative,
                situation: situation,
                settingNative: settingNative,
                windowMs: windowMs,
                turns: turns,
                source: source,
                realmId: realmId,
                createdAt: createdAt,
                disabled: disabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScenesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScenesTable,
      SceneRow,
      $$ScenesTableFilterComposer,
      $$ScenesTableOrderingComposer,
      $$ScenesTableAnnotationComposer,
      $$ScenesTableCreateCompanionBuilder,
      $$ScenesTableUpdateCompanionBuilder,
      (SceneRow, BaseReferences<_$AppDatabase, $ScenesTable, SceneRow>),
      SceneRow,
      PrefetchHooks Function()
    >;
typedef $$SceneResultsTableCreateCompanionBuilder =
    SceneResultsCompanion Function({
      Value<int> id,
      required String sceneId,
      required int turn,
      required bool correct,
      Value<String?> missedSlot,
      Value<bool> inWindow,
      Value<bool> review,
      required String day,
      required int at,
    });
typedef $$SceneResultsTableUpdateCompanionBuilder =
    SceneResultsCompanion Function({
      Value<int> id,
      Value<String> sceneId,
      Value<int> turn,
      Value<bool> correct,
      Value<String?> missedSlot,
      Value<bool> inWindow,
      Value<bool> review,
      Value<String> day,
      Value<int> at,
    });

class $$SceneResultsTableFilterComposer
    extends Composer<_$AppDatabase, $SceneResultsTable> {
  $$SceneResultsTableFilterComposer({
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

  ColumnFilters<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turn => $composableBuilder(
    column: $table.turn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missedSlot => $composableBuilder(
    column: $table.missedSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inWindow => $composableBuilder(
    column: $table.inWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get review => $composableBuilder(
    column: $table.review,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SceneResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $SceneResultsTable> {
  $$SceneResultsTableOrderingComposer({
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

  ColumnOrderings<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turn => $composableBuilder(
    column: $table.turn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missedSlot => $composableBuilder(
    column: $table.missedSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inWindow => $composableBuilder(
    column: $table.inWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get review => $composableBuilder(
    column: $table.review,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SceneResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SceneResultsTable> {
  $$SceneResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<int> get turn =>
      $composableBuilder(column: $table.turn, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<String> get missedSlot => $composableBuilder(
    column: $table.missedSlot,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get inWindow =>
      $composableBuilder(column: $table.inWindow, builder: (column) => column);

  GeneratedColumn<bool> get review =>
      $composableBuilder(column: $table.review, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$SceneResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SceneResultsTable,
          TurnResultRow,
          $$SceneResultsTableFilterComposer,
          $$SceneResultsTableOrderingComposer,
          $$SceneResultsTableAnnotationComposer,
          $$SceneResultsTableCreateCompanionBuilder,
          $$SceneResultsTableUpdateCompanionBuilder,
          (
            TurnResultRow,
            BaseReferences<_$AppDatabase, $SceneResultsTable, TurnResultRow>,
          ),
          TurnResultRow,
          PrefetchHooks Function()
        > {
  $$SceneResultsTableTableManager(_$AppDatabase db, $SceneResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SceneResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SceneResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SceneResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sceneId = const Value.absent(),
                Value<int> turn = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<String?> missedSlot = const Value.absent(),
                Value<bool> inWindow = const Value.absent(),
                Value<bool> review = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<int> at = const Value.absent(),
              }) => SceneResultsCompanion(
                id: id,
                sceneId: sceneId,
                turn: turn,
                correct: correct,
                missedSlot: missedSlot,
                inWindow: inWindow,
                review: review,
                day: day,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sceneId,
                required int turn,
                required bool correct,
                Value<String?> missedSlot = const Value.absent(),
                Value<bool> inWindow = const Value.absent(),
                Value<bool> review = const Value.absent(),
                required String day,
                required int at,
              }) => SceneResultsCompanion.insert(
                id: id,
                sceneId: sceneId,
                turn: turn,
                correct: correct,
                missedSlot: missedSlot,
                inWindow: inWindow,
                review: review,
                day: day,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SceneResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SceneResultsTable,
      TurnResultRow,
      $$SceneResultsTableFilterComposer,
      $$SceneResultsTableOrderingComposer,
      $$SceneResultsTableAnnotationComposer,
      $$SceneResultsTableCreateCompanionBuilder,
      $$SceneResultsTableUpdateCompanionBuilder,
      (
        TurnResultRow,
        BaseReferences<_$AppDatabase, $SceneResultsTable, TurnResultRow>,
      ),
      TurnResultRow,
      PrefetchHooks Function()
    >;
typedef $$ReviewsTableCreateCompanionBuilder =
    ReviewsCompanion Function({
      required String sceneId,
      required int turn,
      required String dueDay,
      Value<int> stage,
      Value<int> rowid,
    });
typedef $$ReviewsTableUpdateCompanionBuilder =
    ReviewsCompanion Function({
      Value<String> sceneId,
      Value<int> turn,
      Value<String> dueDay,
      Value<int> stage,
      Value<int> rowid,
    });

class $$ReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turn => $composableBuilder(
    column: $table.turn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turn => $composableBuilder(
    column: $table.turn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<int> get turn =>
      $composableBuilder(column: $table.turn, builder: (column) => column);

  GeneratedColumn<String> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);
}

class $$ReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewsTable,
          ReviewRow,
          $$ReviewsTableFilterComposer,
          $$ReviewsTableOrderingComposer,
          $$ReviewsTableAnnotationComposer,
          $$ReviewsTableCreateCompanionBuilder,
          $$ReviewsTableUpdateCompanionBuilder,
          (ReviewRow, BaseReferences<_$AppDatabase, $ReviewsTable, ReviewRow>),
          ReviewRow,
          PrefetchHooks Function()
        > {
  $$ReviewsTableTableManager(_$AppDatabase db, $ReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sceneId = const Value.absent(),
                Value<int> turn = const Value.absent(),
                Value<String> dueDay = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewsCompanion(
                sceneId: sceneId,
                turn: turn,
                dueDay: dueDay,
                stage: stage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sceneId,
                required int turn,
                required String dueDay,
                Value<int> stage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewsCompanion.insert(
                sceneId: sceneId,
                turn: turn,
                dueDay: dueDay,
                stage: stage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewsTable,
      ReviewRow,
      $$ReviewsTableFilterComposer,
      $$ReviewsTableOrderingComposer,
      $$ReviewsTableAnnotationComposer,
      $$ReviewsTableCreateCompanionBuilder,
      $$ReviewsTableUpdateCompanionBuilder,
      (ReviewRow, BaseReferences<_$AppDatabase, $ReviewsTable, ReviewRow>),
      ReviewRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RealmsTableTableManager get realms =>
      $$RealmsTableTableManager(_db, _db.realms);
  $$ScenesTableTableManager get scenes =>
      $$ScenesTableTableManager(_db, _db.scenes);
  $$SceneResultsTableTableManager get sceneResults =>
      $$SceneResultsTableTableManager(_db, _db.sceneResults);
  $$ReviewsTableTableManager get reviews =>
      $$ReviewsTableTableManager(_db, _db.reviews);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
