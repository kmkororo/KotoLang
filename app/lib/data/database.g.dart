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

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phraseMeta = const VerificationMeta('phrase');
  @override
  late final GeneratedColumn<String> phrase = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('term'),
  );
  static const VerificationMeta _meaningNativeMeta = const VerificationMeta(
    'meaningNative',
  );
  @override
  late final GeneratedColumn<String> meaningNative = GeneratedColumn<String>(
    'meaning_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
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
    defaultValue: const Constant(0.7),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  relatedTerms = GeneratedColumn<String>(
    'related_terms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($ItemsTable.$converterrelatedTerms);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> contexts =
      GeneratedColumn<String>(
        'contexts',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($ItemsTable.$convertercontexts);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  distractorsNative = GeneratedColumn<String>(
    'distractors_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($ItemsTable.$converterdistractorsNative);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> realmIds =
      GeneratedColumn<String>(
        'realm_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($ItemsTable.$converterrealmIds);
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
    phrase,
    normKeyValue,
    type,
    meaningNative,
    priority,
    confidence,
    relatedTerms,
    contexts,
    distractorsNative,
    realmIds,
    disabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _phraseMeta,
        phrase.isAcceptableOrUnknown(data['text']!, _phraseMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseMeta);
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('meaning_native')) {
      context.handle(
        _meaningNativeMeta,
        meaningNative.isAcceptableOrUnknown(
          data['meaning_native']!,
          _meaningNativeMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
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
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      phrase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      normKeyValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}norm_key_value'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      meaningNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning_native'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      relatedTerms: $ItemsTable.$converterrelatedTerms.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}related_terms'],
        )!,
      ),
      contexts: $ItemsTable.$convertercontexts.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}contexts'],
        )!,
      ),
      distractorsNative: $ItemsTable.$converterdistractorsNative.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}distractors_native'],
        )!,
      ),
      realmIds: $ItemsTable.$converterrealmIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}realm_ids'],
        )!,
      ),
      disabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disabled'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterrelatedTerms =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertercontexts =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterdistractorsNative =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterrealmIds =
      const StringListConverter();
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String phrase;
  final String normKeyValue;
  final String type;
  final String meaningNative;
  final int priority;
  final double confidence;
  final List<String> relatedTerms;
  final List<String> contexts;
  final List<String> distractorsNative;
  final List<String> realmIds;
  final bool disabled;
  const ItemRow({
    required this.id,
    required this.phrase,
    required this.normKeyValue,
    required this.type,
    required this.meaningNative,
    required this.priority,
    required this.confidence,
    required this.relatedTerms,
    required this.contexts,
    required this.distractorsNative,
    required this.realmIds,
    required this.disabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['text'] = Variable<String>(phrase);
    map['norm_key_value'] = Variable<String>(normKeyValue);
    map['type'] = Variable<String>(type);
    map['meaning_native'] = Variable<String>(meaningNative);
    map['priority'] = Variable<int>(priority);
    map['confidence'] = Variable<double>(confidence);
    {
      map['related_terms'] = Variable<String>(
        $ItemsTable.$converterrelatedTerms.toSql(relatedTerms),
      );
    }
    {
      map['contexts'] = Variable<String>(
        $ItemsTable.$convertercontexts.toSql(contexts),
      );
    }
    {
      map['distractors_native'] = Variable<String>(
        $ItemsTable.$converterdistractorsNative.toSql(distractorsNative),
      );
    }
    {
      map['realm_ids'] = Variable<String>(
        $ItemsTable.$converterrealmIds.toSql(realmIds),
      );
    }
    map['disabled'] = Variable<bool>(disabled);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      phrase: Value(phrase),
      normKeyValue: Value(normKeyValue),
      type: Value(type),
      meaningNative: Value(meaningNative),
      priority: Value(priority),
      confidence: Value(confidence),
      relatedTerms: Value(relatedTerms),
      contexts: Value(contexts),
      distractorsNative: Value(distractorsNative),
      realmIds: Value(realmIds),
      disabled: Value(disabled),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      phrase: serializer.fromJson<String>(json['phrase']),
      normKeyValue: serializer.fromJson<String>(json['normKeyValue']),
      type: serializer.fromJson<String>(json['type']),
      meaningNative: serializer.fromJson<String>(json['meaningNative']),
      priority: serializer.fromJson<int>(json['priority']),
      confidence: serializer.fromJson<double>(json['confidence']),
      relatedTerms: serializer.fromJson<List<String>>(json['relatedTerms']),
      contexts: serializer.fromJson<List<String>>(json['contexts']),
      distractorsNative: serializer.fromJson<List<String>>(
        json['distractorsNative'],
      ),
      realmIds: serializer.fromJson<List<String>>(json['realmIds']),
      disabled: serializer.fromJson<bool>(json['disabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'phrase': serializer.toJson<String>(phrase),
      'normKeyValue': serializer.toJson<String>(normKeyValue),
      'type': serializer.toJson<String>(type),
      'meaningNative': serializer.toJson<String>(meaningNative),
      'priority': serializer.toJson<int>(priority),
      'confidence': serializer.toJson<double>(confidence),
      'relatedTerms': serializer.toJson<List<String>>(relatedTerms),
      'contexts': serializer.toJson<List<String>>(contexts),
      'distractorsNative': serializer.toJson<List<String>>(distractorsNative),
      'realmIds': serializer.toJson<List<String>>(realmIds),
      'disabled': serializer.toJson<bool>(disabled),
    };
  }

  ItemRow copyWith({
    String? id,
    String? phrase,
    String? normKeyValue,
    String? type,
    String? meaningNative,
    int? priority,
    double? confidence,
    List<String>? relatedTerms,
    List<String>? contexts,
    List<String>? distractorsNative,
    List<String>? realmIds,
    bool? disabled,
  }) => ItemRow(
    id: id ?? this.id,
    phrase: phrase ?? this.phrase,
    normKeyValue: normKeyValue ?? this.normKeyValue,
    type: type ?? this.type,
    meaningNative: meaningNative ?? this.meaningNative,
    priority: priority ?? this.priority,
    confidence: confidence ?? this.confidence,
    relatedTerms: relatedTerms ?? this.relatedTerms,
    contexts: contexts ?? this.contexts,
    distractorsNative: distractorsNative ?? this.distractorsNative,
    realmIds: realmIds ?? this.realmIds,
    disabled: disabled ?? this.disabled,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      phrase: data.phrase.present ? data.phrase.value : this.phrase,
      normKeyValue: data.normKeyValue.present
          ? data.normKeyValue.value
          : this.normKeyValue,
      type: data.type.present ? data.type.value : this.type,
      meaningNative: data.meaningNative.present
          ? data.meaningNative.value
          : this.meaningNative,
      priority: data.priority.present ? data.priority.value : this.priority,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      relatedTerms: data.relatedTerms.present
          ? data.relatedTerms.value
          : this.relatedTerms,
      contexts: data.contexts.present ? data.contexts.value : this.contexts,
      distractorsNative: data.distractorsNative.present
          ? data.distractorsNative.value
          : this.distractorsNative,
      realmIds: data.realmIds.present ? data.realmIds.value : this.realmIds,
      disabled: data.disabled.present ? data.disabled.value : this.disabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('type: $type, ')
          ..write('meaningNative: $meaningNative, ')
          ..write('priority: $priority, ')
          ..write('confidence: $confidence, ')
          ..write('relatedTerms: $relatedTerms, ')
          ..write('contexts: $contexts, ')
          ..write('distractorsNative: $distractorsNative, ')
          ..write('realmIds: $realmIds, ')
          ..write('disabled: $disabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    phrase,
    normKeyValue,
    type,
    meaningNative,
    priority,
    confidence,
    relatedTerms,
    contexts,
    distractorsNative,
    realmIds,
    disabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.phrase == this.phrase &&
          other.normKeyValue == this.normKeyValue &&
          other.type == this.type &&
          other.meaningNative == this.meaningNative &&
          other.priority == this.priority &&
          other.confidence == this.confidence &&
          other.relatedTerms == this.relatedTerms &&
          other.contexts == this.contexts &&
          other.distractorsNative == this.distractorsNative &&
          other.realmIds == this.realmIds &&
          other.disabled == this.disabled);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> phrase;
  final Value<String> normKeyValue;
  final Value<String> type;
  final Value<String> meaningNative;
  final Value<int> priority;
  final Value<double> confidence;
  final Value<List<String>> relatedTerms;
  final Value<List<String>> contexts;
  final Value<List<String>> distractorsNative;
  final Value<List<String>> realmIds;
  final Value<bool> disabled;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.phrase = const Value.absent(),
    this.normKeyValue = const Value.absent(),
    this.type = const Value.absent(),
    this.meaningNative = const Value.absent(),
    this.priority = const Value.absent(),
    this.confidence = const Value.absent(),
    this.relatedTerms = const Value.absent(),
    this.contexts = const Value.absent(),
    this.distractorsNative = const Value.absent(),
    this.realmIds = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String phrase,
    required String normKeyValue,
    this.type = const Value.absent(),
    this.meaningNative = const Value.absent(),
    this.priority = const Value.absent(),
    this.confidence = const Value.absent(),
    this.relatedTerms = const Value.absent(),
    this.contexts = const Value.absent(),
    this.distractorsNative = const Value.absent(),
    this.realmIds = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       phrase = Value(phrase),
       normKeyValue = Value(normKeyValue);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? phrase,
    Expression<String>? normKeyValue,
    Expression<String>? type,
    Expression<String>? meaningNative,
    Expression<int>? priority,
    Expression<double>? confidence,
    Expression<String>? relatedTerms,
    Expression<String>? contexts,
    Expression<String>? distractorsNative,
    Expression<String>? realmIds,
    Expression<bool>? disabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phrase != null) 'text': phrase,
      if (normKeyValue != null) 'norm_key_value': normKeyValue,
      if (type != null) 'type': type,
      if (meaningNative != null) 'meaning_native': meaningNative,
      if (priority != null) 'priority': priority,
      if (confidence != null) 'confidence': confidence,
      if (relatedTerms != null) 'related_terms': relatedTerms,
      if (contexts != null) 'contexts': contexts,
      if (distractorsNative != null) 'distractors_native': distractorsNative,
      if (realmIds != null) 'realm_ids': realmIds,
      if (disabled != null) 'disabled': disabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? phrase,
    Value<String>? normKeyValue,
    Value<String>? type,
    Value<String>? meaningNative,
    Value<int>? priority,
    Value<double>? confidence,
    Value<List<String>>? relatedTerms,
    Value<List<String>>? contexts,
    Value<List<String>>? distractorsNative,
    Value<List<String>>? realmIds,
    Value<bool>? disabled,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      normKeyValue: normKeyValue ?? this.normKeyValue,
      type: type ?? this.type,
      meaningNative: meaningNative ?? this.meaningNative,
      priority: priority ?? this.priority,
      confidence: confidence ?? this.confidence,
      relatedTerms: relatedTerms ?? this.relatedTerms,
      contexts: contexts ?? this.contexts,
      distractorsNative: distractorsNative ?? this.distractorsNative,
      realmIds: realmIds ?? this.realmIds,
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
    if (phrase.present) {
      map['text'] = Variable<String>(phrase.value);
    }
    if (normKeyValue.present) {
      map['norm_key_value'] = Variable<String>(normKeyValue.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (meaningNative.present) {
      map['meaning_native'] = Variable<String>(meaningNative.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (relatedTerms.present) {
      map['related_terms'] = Variable<String>(
        $ItemsTable.$converterrelatedTerms.toSql(relatedTerms.value),
      );
    }
    if (contexts.present) {
      map['contexts'] = Variable<String>(
        $ItemsTable.$convertercontexts.toSql(contexts.value),
      );
    }
    if (distractorsNative.present) {
      map['distractors_native'] = Variable<String>(
        $ItemsTable.$converterdistractorsNative.toSql(distractorsNative.value),
      );
    }
    if (realmIds.present) {
      map['realm_ids'] = Variable<String>(
        $ItemsTable.$converterrealmIds.toSql(realmIds.value),
      );
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
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('type: $type, ')
          ..write('meaningNative: $meaningNative, ')
          ..write('priority: $priority, ')
          ..write('confidence: $confidence, ')
          ..write('relatedTerms: $relatedTerms, ')
          ..write('contexts: $contexts, ')
          ..write('distractorsNative: $distractorsNative, ')
          ..write('realmIds: $realmIds, ')
          ..write('disabled: $disabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SentencesTable extends Sentences
    with TableInfo<$SentencesTable, SentenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _translationNativeMeta = const VerificationMeta(
    'translationNative',
  );
  @override
  late final GeneratedColumn<String> translationNative =
      GeneratedColumn<String>(
        'translation_native',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('B1'),
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _speechActMeta = const VerificationMeta(
    'speechAct',
  );
  @override
  late final GeneratedColumn<String> speechAct = GeneratedColumn<String>(
    'speech_act',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('statement'),
  );
  static const VerificationMeta _naturalnessMeta = const VerificationMeta(
    'naturalness',
  );
  @override
  late final GeneratedColumn<int> naturalness = GeneratedColumn<int>(
    'naturalness',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _realmIdMeta = const VerificationMeta(
    'realmId',
  );
  @override
  late final GeneratedColumn<String> realmId = GeneratedColumn<String>(
    'realm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> itemIds =
      GeneratedColumn<String>(
        'item_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($SentencesTable.$converteritemIds);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  meaningOptionsNative = GeneratedColumn<String>(
    'meaning_options_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($SentencesTable.$convertermeaningOptionsNative);
  static const VerificationMeta _paraphraseEnMeta = const VerificationMeta(
    'paraphraseEn',
  );
  @override
  late final GeneratedColumn<String> paraphraseEn = GeneratedColumn<String>(
    'paraphrase_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  paraphraseOptionsEn = GeneratedColumn<String>(
    'paraphrase_options_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($SentencesTable.$converterparaphraseOptionsEn);
  static const VerificationMeta _cueEnMeta = const VerificationMeta('cueEn');
  @override
  late final GeneratedColumn<String> cueEn = GeneratedColumn<String>(
    'cue_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cueTranslationNativeMeta =
      const VerificationMeta('cueTranslationNative');
  @override
  late final GeneratedColumn<String> cueTranslationNative =
      GeneratedColumn<String>(
        'cue_translation_native',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  replyDistractorsEn = GeneratedColumn<String>(
    'reply_distractors_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($SentencesTable.$converterreplyDistractorsEn);
  static const VerificationMeta _registerSituationNativeMeta =
      const VerificationMeta('registerSituationNative');
  @override
  late final GeneratedColumn<String> registerSituationNative =
      GeneratedColumn<String>(
        'register_situation_native',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  registerOptionsEn = GeneratedColumn<String>(
    'register_options_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($SentencesTable.$converterregisterOptionsEn);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  registerWhyNative = GeneratedColumn<String>(
    'register_why_native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($SentencesTable.$converterregisterWhyNative);
  static const VerificationMeta _registerCorrectMeta = const VerificationMeta(
    'registerCorrect',
  );
  @override
  late final GeneratedColumn<int> registerCorrect = GeneratedColumn<int>(
    'register_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
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
    body,
    normKeyValue,
    translationNative,
    level,
    context,
    speechAct,
    naturalness,
    quality,
    realmId,
    itemIds,
    meaningOptionsNative,
    paraphraseEn,
    paraphraseOptionsEn,
    cueEn,
    cueTranslationNative,
    replyDistractorsEn,
    registerSituationNative,
    registerOptionsEn,
    registerWhyNative,
    registerCorrect,
    disabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentences';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
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
    if (data.containsKey('translation_native')) {
      context.handle(
        _translationNativeMeta,
        translationNative.isAcceptableOrUnknown(
          data['translation_native']!,
          _translationNativeMeta,
        ),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('speech_act')) {
      context.handle(
        _speechActMeta,
        speechAct.isAcceptableOrUnknown(data['speech_act']!, _speechActMeta),
      );
    }
    if (data.containsKey('naturalness')) {
      context.handle(
        _naturalnessMeta,
        naturalness.isAcceptableOrUnknown(
          data['naturalness']!,
          _naturalnessMeta,
        ),
      );
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('realm_id')) {
      context.handle(
        _realmIdMeta,
        realmId.isAcceptableOrUnknown(data['realm_id']!, _realmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_realmIdMeta);
    }
    if (data.containsKey('paraphrase_en')) {
      context.handle(
        _paraphraseEnMeta,
        paraphraseEn.isAcceptableOrUnknown(
          data['paraphrase_en']!,
          _paraphraseEnMeta,
        ),
      );
    }
    if (data.containsKey('cue_en')) {
      context.handle(
        _cueEnMeta,
        cueEn.isAcceptableOrUnknown(data['cue_en']!, _cueEnMeta),
      );
    }
    if (data.containsKey('cue_translation_native')) {
      context.handle(
        _cueTranslationNativeMeta,
        cueTranslationNative.isAcceptableOrUnknown(
          data['cue_translation_native']!,
          _cueTranslationNativeMeta,
        ),
      );
    }
    if (data.containsKey('register_situation_native')) {
      context.handle(
        _registerSituationNativeMeta,
        registerSituationNative.isAcceptableOrUnknown(
          data['register_situation_native']!,
          _registerSituationNativeMeta,
        ),
      );
    }
    if (data.containsKey('register_correct')) {
      context.handle(
        _registerCorrectMeta,
        registerCorrect.isAcceptableOrUnknown(
          data['register_correct']!,
          _registerCorrectMeta,
        ),
      );
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
  SentenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      normKeyValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}norm_key_value'],
      )!,
      translationNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_native'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      speechAct: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speech_act'],
      )!,
      naturalness: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}naturalness'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      realmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realm_id'],
      )!,
      itemIds: $SentencesTable.$converteritemIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_ids'],
        )!,
      ),
      meaningOptionsNative: $SentencesTable.$convertermeaningOptionsNative
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}meaning_options_native'],
            )!,
          ),
      paraphraseEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paraphrase_en'],
      )!,
      paraphraseOptionsEn: $SentencesTable.$converterparaphraseOptionsEn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}paraphrase_options_en'],
            )!,
          ),
      cueEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cue_en'],
      )!,
      cueTranslationNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cue_translation_native'],
      )!,
      replyDistractorsEn: $SentencesTable.$converterreplyDistractorsEn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reply_distractors_en'],
        )!,
      ),
      registerSituationNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_situation_native'],
      )!,
      registerOptionsEn: $SentencesTable.$converterregisterOptionsEn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}register_options_en'],
        )!,
      ),
      registerWhyNative: $SentencesTable.$converterregisterWhyNative.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}register_why_native'],
        )!,
      ),
      registerCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}register_correct'],
      )!,
      disabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disabled'],
      )!,
    );
  }

  @override
  $SentencesTable createAlias(String alias) {
    return $SentencesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converteritemIds =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertermeaningOptionsNative =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterparaphraseOptionsEn =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterreplyDistractorsEn =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterregisterOptionsEn =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterregisterWhyNative =
      const StringListConverter();
}

class SentenceRow extends DataClass implements Insertable<SentenceRow> {
  final String id;
  final String body;
  final String normKeyValue;
  final String translationNative;
  final String level;
  final String context;
  final String speechAct;
  final int naturalness;
  final int? quality;
  final String realmId;
  final List<String> itemIds;
  final List<String> meaningOptionsNative;
  final String paraphraseEn;
  final List<String> paraphraseOptionsEn;
  final String cueEn;
  final String cueTranslationNative;
  final List<String> replyDistractorsEn;
  final String registerSituationNative;
  final List<String> registerOptionsEn;
  final List<String> registerWhyNative;
  final int registerCorrect;
  final bool disabled;
  const SentenceRow({
    required this.id,
    required this.body,
    required this.normKeyValue,
    required this.translationNative,
    required this.level,
    required this.context,
    required this.speechAct,
    required this.naturalness,
    this.quality,
    required this.realmId,
    required this.itemIds,
    required this.meaningOptionsNative,
    required this.paraphraseEn,
    required this.paraphraseOptionsEn,
    required this.cueEn,
    required this.cueTranslationNative,
    required this.replyDistractorsEn,
    required this.registerSituationNative,
    required this.registerOptionsEn,
    required this.registerWhyNative,
    required this.registerCorrect,
    required this.disabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['text'] = Variable<String>(body);
    map['norm_key_value'] = Variable<String>(normKeyValue);
    map['translation_native'] = Variable<String>(translationNative);
    map['level'] = Variable<String>(level);
    map['context'] = Variable<String>(context);
    map['speech_act'] = Variable<String>(speechAct);
    map['naturalness'] = Variable<int>(naturalness);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    map['realm_id'] = Variable<String>(realmId);
    {
      map['item_ids'] = Variable<String>(
        $SentencesTable.$converteritemIds.toSql(itemIds),
      );
    }
    {
      map['meaning_options_native'] = Variable<String>(
        $SentencesTable.$convertermeaningOptionsNative.toSql(
          meaningOptionsNative,
        ),
      );
    }
    map['paraphrase_en'] = Variable<String>(paraphraseEn);
    {
      map['paraphrase_options_en'] = Variable<String>(
        $SentencesTable.$converterparaphraseOptionsEn.toSql(
          paraphraseOptionsEn,
        ),
      );
    }
    map['cue_en'] = Variable<String>(cueEn);
    map['cue_translation_native'] = Variable<String>(cueTranslationNative);
    {
      map['reply_distractors_en'] = Variable<String>(
        $SentencesTable.$converterreplyDistractorsEn.toSql(replyDistractorsEn),
      );
    }
    map['register_situation_native'] = Variable<String>(
      registerSituationNative,
    );
    {
      map['register_options_en'] = Variable<String>(
        $SentencesTable.$converterregisterOptionsEn.toSql(registerOptionsEn),
      );
    }
    {
      map['register_why_native'] = Variable<String>(
        $SentencesTable.$converterregisterWhyNative.toSql(registerWhyNative),
      );
    }
    map['register_correct'] = Variable<int>(registerCorrect);
    map['disabled'] = Variable<bool>(disabled);
    return map;
  }

  SentencesCompanion toCompanion(bool nullToAbsent) {
    return SentencesCompanion(
      id: Value(id),
      body: Value(body),
      normKeyValue: Value(normKeyValue),
      translationNative: Value(translationNative),
      level: Value(level),
      context: Value(context),
      speechAct: Value(speechAct),
      naturalness: Value(naturalness),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      realmId: Value(realmId),
      itemIds: Value(itemIds),
      meaningOptionsNative: Value(meaningOptionsNative),
      paraphraseEn: Value(paraphraseEn),
      paraphraseOptionsEn: Value(paraphraseOptionsEn),
      cueEn: Value(cueEn),
      cueTranslationNative: Value(cueTranslationNative),
      replyDistractorsEn: Value(replyDistractorsEn),
      registerSituationNative: Value(registerSituationNative),
      registerOptionsEn: Value(registerOptionsEn),
      registerWhyNative: Value(registerWhyNative),
      registerCorrect: Value(registerCorrect),
      disabled: Value(disabled),
    );
  }

  factory SentenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentenceRow(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      normKeyValue: serializer.fromJson<String>(json['normKeyValue']),
      translationNative: serializer.fromJson<String>(json['translationNative']),
      level: serializer.fromJson<String>(json['level']),
      context: serializer.fromJson<String>(json['context']),
      speechAct: serializer.fromJson<String>(json['speechAct']),
      naturalness: serializer.fromJson<int>(json['naturalness']),
      quality: serializer.fromJson<int?>(json['quality']),
      realmId: serializer.fromJson<String>(json['realmId']),
      itemIds: serializer.fromJson<List<String>>(json['itemIds']),
      meaningOptionsNative: serializer.fromJson<List<String>>(
        json['meaningOptionsNative'],
      ),
      paraphraseEn: serializer.fromJson<String>(json['paraphraseEn']),
      paraphraseOptionsEn: serializer.fromJson<List<String>>(
        json['paraphraseOptionsEn'],
      ),
      cueEn: serializer.fromJson<String>(json['cueEn']),
      cueTranslationNative: serializer.fromJson<String>(
        json['cueTranslationNative'],
      ),
      replyDistractorsEn: serializer.fromJson<List<String>>(
        json['replyDistractorsEn'],
      ),
      registerSituationNative: serializer.fromJson<String>(
        json['registerSituationNative'],
      ),
      registerOptionsEn: serializer.fromJson<List<String>>(
        json['registerOptionsEn'],
      ),
      registerWhyNative: serializer.fromJson<List<String>>(
        json['registerWhyNative'],
      ),
      registerCorrect: serializer.fromJson<int>(json['registerCorrect']),
      disabled: serializer.fromJson<bool>(json['disabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'body': serializer.toJson<String>(body),
      'normKeyValue': serializer.toJson<String>(normKeyValue),
      'translationNative': serializer.toJson<String>(translationNative),
      'level': serializer.toJson<String>(level),
      'context': serializer.toJson<String>(context),
      'speechAct': serializer.toJson<String>(speechAct),
      'naturalness': serializer.toJson<int>(naturalness),
      'quality': serializer.toJson<int?>(quality),
      'realmId': serializer.toJson<String>(realmId),
      'itemIds': serializer.toJson<List<String>>(itemIds),
      'meaningOptionsNative': serializer.toJson<List<String>>(
        meaningOptionsNative,
      ),
      'paraphraseEn': serializer.toJson<String>(paraphraseEn),
      'paraphraseOptionsEn': serializer.toJson<List<String>>(
        paraphraseOptionsEn,
      ),
      'cueEn': serializer.toJson<String>(cueEn),
      'cueTranslationNative': serializer.toJson<String>(cueTranslationNative),
      'replyDistractorsEn': serializer.toJson<List<String>>(replyDistractorsEn),
      'registerSituationNative': serializer.toJson<String>(
        registerSituationNative,
      ),
      'registerOptionsEn': serializer.toJson<List<String>>(registerOptionsEn),
      'registerWhyNative': serializer.toJson<List<String>>(registerWhyNative),
      'registerCorrect': serializer.toJson<int>(registerCorrect),
      'disabled': serializer.toJson<bool>(disabled),
    };
  }

  SentenceRow copyWith({
    String? id,
    String? body,
    String? normKeyValue,
    String? translationNative,
    String? level,
    String? context,
    String? speechAct,
    int? naturalness,
    Value<int?> quality = const Value.absent(),
    String? realmId,
    List<String>? itemIds,
    List<String>? meaningOptionsNative,
    String? paraphraseEn,
    List<String>? paraphraseOptionsEn,
    String? cueEn,
    String? cueTranslationNative,
    List<String>? replyDistractorsEn,
    String? registerSituationNative,
    List<String>? registerOptionsEn,
    List<String>? registerWhyNative,
    int? registerCorrect,
    bool? disabled,
  }) => SentenceRow(
    id: id ?? this.id,
    body: body ?? this.body,
    normKeyValue: normKeyValue ?? this.normKeyValue,
    translationNative: translationNative ?? this.translationNative,
    level: level ?? this.level,
    context: context ?? this.context,
    speechAct: speechAct ?? this.speechAct,
    naturalness: naturalness ?? this.naturalness,
    quality: quality.present ? quality.value : this.quality,
    realmId: realmId ?? this.realmId,
    itemIds: itemIds ?? this.itemIds,
    meaningOptionsNative: meaningOptionsNative ?? this.meaningOptionsNative,
    paraphraseEn: paraphraseEn ?? this.paraphraseEn,
    paraphraseOptionsEn: paraphraseOptionsEn ?? this.paraphraseOptionsEn,
    cueEn: cueEn ?? this.cueEn,
    cueTranslationNative: cueTranslationNative ?? this.cueTranslationNative,
    replyDistractorsEn: replyDistractorsEn ?? this.replyDistractorsEn,
    registerSituationNative:
        registerSituationNative ?? this.registerSituationNative,
    registerOptionsEn: registerOptionsEn ?? this.registerOptionsEn,
    registerWhyNative: registerWhyNative ?? this.registerWhyNative,
    registerCorrect: registerCorrect ?? this.registerCorrect,
    disabled: disabled ?? this.disabled,
  );
  SentenceRow copyWithCompanion(SentencesCompanion data) {
    return SentenceRow(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      normKeyValue: data.normKeyValue.present
          ? data.normKeyValue.value
          : this.normKeyValue,
      translationNative: data.translationNative.present
          ? data.translationNative.value
          : this.translationNative,
      level: data.level.present ? data.level.value : this.level,
      context: data.context.present ? data.context.value : this.context,
      speechAct: data.speechAct.present ? data.speechAct.value : this.speechAct,
      naturalness: data.naturalness.present
          ? data.naturalness.value
          : this.naturalness,
      quality: data.quality.present ? data.quality.value : this.quality,
      realmId: data.realmId.present ? data.realmId.value : this.realmId,
      itemIds: data.itemIds.present ? data.itemIds.value : this.itemIds,
      meaningOptionsNative: data.meaningOptionsNative.present
          ? data.meaningOptionsNative.value
          : this.meaningOptionsNative,
      paraphraseEn: data.paraphraseEn.present
          ? data.paraphraseEn.value
          : this.paraphraseEn,
      paraphraseOptionsEn: data.paraphraseOptionsEn.present
          ? data.paraphraseOptionsEn.value
          : this.paraphraseOptionsEn,
      cueEn: data.cueEn.present ? data.cueEn.value : this.cueEn,
      cueTranslationNative: data.cueTranslationNative.present
          ? data.cueTranslationNative.value
          : this.cueTranslationNative,
      replyDistractorsEn: data.replyDistractorsEn.present
          ? data.replyDistractorsEn.value
          : this.replyDistractorsEn,
      registerSituationNative: data.registerSituationNative.present
          ? data.registerSituationNative.value
          : this.registerSituationNative,
      registerOptionsEn: data.registerOptionsEn.present
          ? data.registerOptionsEn.value
          : this.registerOptionsEn,
      registerWhyNative: data.registerWhyNative.present
          ? data.registerWhyNative.value
          : this.registerWhyNative,
      registerCorrect: data.registerCorrect.present
          ? data.registerCorrect.value
          : this.registerCorrect,
      disabled: data.disabled.present ? data.disabled.value : this.disabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentenceRow(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('translationNative: $translationNative, ')
          ..write('level: $level, ')
          ..write('context: $context, ')
          ..write('speechAct: $speechAct, ')
          ..write('naturalness: $naturalness, ')
          ..write('quality: $quality, ')
          ..write('realmId: $realmId, ')
          ..write('itemIds: $itemIds, ')
          ..write('meaningOptionsNative: $meaningOptionsNative, ')
          ..write('paraphraseEn: $paraphraseEn, ')
          ..write('paraphraseOptionsEn: $paraphraseOptionsEn, ')
          ..write('cueEn: $cueEn, ')
          ..write('cueTranslationNative: $cueTranslationNative, ')
          ..write('replyDistractorsEn: $replyDistractorsEn, ')
          ..write('registerSituationNative: $registerSituationNative, ')
          ..write('registerOptionsEn: $registerOptionsEn, ')
          ..write('registerWhyNative: $registerWhyNative, ')
          ..write('registerCorrect: $registerCorrect, ')
          ..write('disabled: $disabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    body,
    normKeyValue,
    translationNative,
    level,
    context,
    speechAct,
    naturalness,
    quality,
    realmId,
    itemIds,
    meaningOptionsNative,
    paraphraseEn,
    paraphraseOptionsEn,
    cueEn,
    cueTranslationNative,
    replyDistractorsEn,
    registerSituationNative,
    registerOptionsEn,
    registerWhyNative,
    registerCorrect,
    disabled,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentenceRow &&
          other.id == this.id &&
          other.body == this.body &&
          other.normKeyValue == this.normKeyValue &&
          other.translationNative == this.translationNative &&
          other.level == this.level &&
          other.context == this.context &&
          other.speechAct == this.speechAct &&
          other.naturalness == this.naturalness &&
          other.quality == this.quality &&
          other.realmId == this.realmId &&
          other.itemIds == this.itemIds &&
          other.meaningOptionsNative == this.meaningOptionsNative &&
          other.paraphraseEn == this.paraphraseEn &&
          other.paraphraseOptionsEn == this.paraphraseOptionsEn &&
          other.cueEn == this.cueEn &&
          other.cueTranslationNative == this.cueTranslationNative &&
          other.replyDistractorsEn == this.replyDistractorsEn &&
          other.registerSituationNative == this.registerSituationNative &&
          other.registerOptionsEn == this.registerOptionsEn &&
          other.registerWhyNative == this.registerWhyNative &&
          other.registerCorrect == this.registerCorrect &&
          other.disabled == this.disabled);
}

class SentencesCompanion extends UpdateCompanion<SentenceRow> {
  final Value<String> id;
  final Value<String> body;
  final Value<String> normKeyValue;
  final Value<String> translationNative;
  final Value<String> level;
  final Value<String> context;
  final Value<String> speechAct;
  final Value<int> naturalness;
  final Value<int?> quality;
  final Value<String> realmId;
  final Value<List<String>> itemIds;
  final Value<List<String>> meaningOptionsNative;
  final Value<String> paraphraseEn;
  final Value<List<String>> paraphraseOptionsEn;
  final Value<String> cueEn;
  final Value<String> cueTranslationNative;
  final Value<List<String>> replyDistractorsEn;
  final Value<String> registerSituationNative;
  final Value<List<String>> registerOptionsEn;
  final Value<List<String>> registerWhyNative;
  final Value<int> registerCorrect;
  final Value<bool> disabled;
  final Value<int> rowid;
  const SentencesCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.normKeyValue = const Value.absent(),
    this.translationNative = const Value.absent(),
    this.level = const Value.absent(),
    this.context = const Value.absent(),
    this.speechAct = const Value.absent(),
    this.naturalness = const Value.absent(),
    this.quality = const Value.absent(),
    this.realmId = const Value.absent(),
    this.itemIds = const Value.absent(),
    this.meaningOptionsNative = const Value.absent(),
    this.paraphraseEn = const Value.absent(),
    this.paraphraseOptionsEn = const Value.absent(),
    this.cueEn = const Value.absent(),
    this.cueTranslationNative = const Value.absent(),
    this.replyDistractorsEn = const Value.absent(),
    this.registerSituationNative = const Value.absent(),
    this.registerOptionsEn = const Value.absent(),
    this.registerWhyNative = const Value.absent(),
    this.registerCorrect = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SentencesCompanion.insert({
    required String id,
    required String body,
    required String normKeyValue,
    this.translationNative = const Value.absent(),
    this.level = const Value.absent(),
    this.context = const Value.absent(),
    this.speechAct = const Value.absent(),
    this.naturalness = const Value.absent(),
    this.quality = const Value.absent(),
    required String realmId,
    this.itemIds = const Value.absent(),
    this.meaningOptionsNative = const Value.absent(),
    this.paraphraseEn = const Value.absent(),
    this.paraphraseOptionsEn = const Value.absent(),
    this.cueEn = const Value.absent(),
    this.cueTranslationNative = const Value.absent(),
    this.replyDistractorsEn = const Value.absent(),
    this.registerSituationNative = const Value.absent(),
    this.registerOptionsEn = const Value.absent(),
    this.registerWhyNative = const Value.absent(),
    this.registerCorrect = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body),
       normKeyValue = Value(normKeyValue),
       realmId = Value(realmId);
  static Insertable<SentenceRow> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<String>? normKeyValue,
    Expression<String>? translationNative,
    Expression<String>? level,
    Expression<String>? context,
    Expression<String>? speechAct,
    Expression<int>? naturalness,
    Expression<int>? quality,
    Expression<String>? realmId,
    Expression<String>? itemIds,
    Expression<String>? meaningOptionsNative,
    Expression<String>? paraphraseEn,
    Expression<String>? paraphraseOptionsEn,
    Expression<String>? cueEn,
    Expression<String>? cueTranslationNative,
    Expression<String>? replyDistractorsEn,
    Expression<String>? registerSituationNative,
    Expression<String>? registerOptionsEn,
    Expression<String>? registerWhyNative,
    Expression<int>? registerCorrect,
    Expression<bool>? disabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'text': body,
      if (normKeyValue != null) 'norm_key_value': normKeyValue,
      if (translationNative != null) 'translation_native': translationNative,
      if (level != null) 'level': level,
      if (context != null) 'context': context,
      if (speechAct != null) 'speech_act': speechAct,
      if (naturalness != null) 'naturalness': naturalness,
      if (quality != null) 'quality': quality,
      if (realmId != null) 'realm_id': realmId,
      if (itemIds != null) 'item_ids': itemIds,
      if (meaningOptionsNative != null)
        'meaning_options_native': meaningOptionsNative,
      if (paraphraseEn != null) 'paraphrase_en': paraphraseEn,
      if (paraphraseOptionsEn != null)
        'paraphrase_options_en': paraphraseOptionsEn,
      if (cueEn != null) 'cue_en': cueEn,
      if (cueTranslationNative != null)
        'cue_translation_native': cueTranslationNative,
      if (replyDistractorsEn != null)
        'reply_distractors_en': replyDistractorsEn,
      if (registerSituationNative != null)
        'register_situation_native': registerSituationNative,
      if (registerOptionsEn != null) 'register_options_en': registerOptionsEn,
      if (registerWhyNative != null) 'register_why_native': registerWhyNative,
      if (registerCorrect != null) 'register_correct': registerCorrect,
      if (disabled != null) 'disabled': disabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SentencesCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<String>? normKeyValue,
    Value<String>? translationNative,
    Value<String>? level,
    Value<String>? context,
    Value<String>? speechAct,
    Value<int>? naturalness,
    Value<int?>? quality,
    Value<String>? realmId,
    Value<List<String>>? itemIds,
    Value<List<String>>? meaningOptionsNative,
    Value<String>? paraphraseEn,
    Value<List<String>>? paraphraseOptionsEn,
    Value<String>? cueEn,
    Value<String>? cueTranslationNative,
    Value<List<String>>? replyDistractorsEn,
    Value<String>? registerSituationNative,
    Value<List<String>>? registerOptionsEn,
    Value<List<String>>? registerWhyNative,
    Value<int>? registerCorrect,
    Value<bool>? disabled,
    Value<int>? rowid,
  }) {
    return SentencesCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      normKeyValue: normKeyValue ?? this.normKeyValue,
      translationNative: translationNative ?? this.translationNative,
      level: level ?? this.level,
      context: context ?? this.context,
      speechAct: speechAct ?? this.speechAct,
      naturalness: naturalness ?? this.naturalness,
      quality: quality ?? this.quality,
      realmId: realmId ?? this.realmId,
      itemIds: itemIds ?? this.itemIds,
      meaningOptionsNative: meaningOptionsNative ?? this.meaningOptionsNative,
      paraphraseEn: paraphraseEn ?? this.paraphraseEn,
      paraphraseOptionsEn: paraphraseOptionsEn ?? this.paraphraseOptionsEn,
      cueEn: cueEn ?? this.cueEn,
      cueTranslationNative: cueTranslationNative ?? this.cueTranslationNative,
      replyDistractorsEn: replyDistractorsEn ?? this.replyDistractorsEn,
      registerSituationNative:
          registerSituationNative ?? this.registerSituationNative,
      registerOptionsEn: registerOptionsEn ?? this.registerOptionsEn,
      registerWhyNative: registerWhyNative ?? this.registerWhyNative,
      registerCorrect: registerCorrect ?? this.registerCorrect,
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
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (normKeyValue.present) {
      map['norm_key_value'] = Variable<String>(normKeyValue.value);
    }
    if (translationNative.present) {
      map['translation_native'] = Variable<String>(translationNative.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (speechAct.present) {
      map['speech_act'] = Variable<String>(speechAct.value);
    }
    if (naturalness.present) {
      map['naturalness'] = Variable<int>(naturalness.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (realmId.present) {
      map['realm_id'] = Variable<String>(realmId.value);
    }
    if (itemIds.present) {
      map['item_ids'] = Variable<String>(
        $SentencesTable.$converteritemIds.toSql(itemIds.value),
      );
    }
    if (meaningOptionsNative.present) {
      map['meaning_options_native'] = Variable<String>(
        $SentencesTable.$convertermeaningOptionsNative.toSql(
          meaningOptionsNative.value,
        ),
      );
    }
    if (paraphraseEn.present) {
      map['paraphrase_en'] = Variable<String>(paraphraseEn.value);
    }
    if (paraphraseOptionsEn.present) {
      map['paraphrase_options_en'] = Variable<String>(
        $SentencesTable.$converterparaphraseOptionsEn.toSql(
          paraphraseOptionsEn.value,
        ),
      );
    }
    if (cueEn.present) {
      map['cue_en'] = Variable<String>(cueEn.value);
    }
    if (cueTranslationNative.present) {
      map['cue_translation_native'] = Variable<String>(
        cueTranslationNative.value,
      );
    }
    if (replyDistractorsEn.present) {
      map['reply_distractors_en'] = Variable<String>(
        $SentencesTable.$converterreplyDistractorsEn.toSql(
          replyDistractorsEn.value,
        ),
      );
    }
    if (registerSituationNative.present) {
      map['register_situation_native'] = Variable<String>(
        registerSituationNative.value,
      );
    }
    if (registerOptionsEn.present) {
      map['register_options_en'] = Variable<String>(
        $SentencesTable.$converterregisterOptionsEn.toSql(
          registerOptionsEn.value,
        ),
      );
    }
    if (registerWhyNative.present) {
      map['register_why_native'] = Variable<String>(
        $SentencesTable.$converterregisterWhyNative.toSql(
          registerWhyNative.value,
        ),
      );
    }
    if (registerCorrect.present) {
      map['register_correct'] = Variable<int>(registerCorrect.value);
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
    return (StringBuffer('SentencesCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('normKeyValue: $normKeyValue, ')
          ..write('translationNative: $translationNative, ')
          ..write('level: $level, ')
          ..write('context: $context, ')
          ..write('speechAct: $speechAct, ')
          ..write('naturalness: $naturalness, ')
          ..write('quality: $quality, ')
          ..write('realmId: $realmId, ')
          ..write('itemIds: $itemIds, ')
          ..write('meaningOptionsNative: $meaningOptionsNative, ')
          ..write('paraphraseEn: $paraphraseEn, ')
          ..write('paraphraseOptionsEn: $paraphraseOptionsEn, ')
          ..write('cueEn: $cueEn, ')
          ..write('cueTranslationNative: $cueTranslationNative, ')
          ..write('replyDistractorsEn: $replyDistractorsEn, ')
          ..write('registerSituationNative: $registerSituationNative, ')
          ..write('registerOptionsEn: $registerOptionsEn, ')
          ..write('registerWhyNative: $registerWhyNative, ')
          ..write('registerCorrect: $registerCorrect, ')
          ..write('disabled: $disabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, QuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<String> sentenceId = GeneratedColumn<String>(
    'sentence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _realmIdMeta = const VerificationMeta(
    'realmId',
  );
  @override
  late final GeneratedColumn<String> realmId = GeneratedColumn<String>(
    'realm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationNativeMeta = const VerificationMeta(
    'translationNative',
  );
  @override
  late final GeneratedColumn<String> translationNative =
      GeneratedColumn<String>(
        'translation_native',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('B1'),
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> options =
      GeneratedColumn<String>(
        'options',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($QuestionsTable.$converteroptions);
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _beforeMeta = const VerificationMeta('before');
  @override
  late final GeneratedColumn<String> before = GeneratedColumn<String>(
    'before',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _afterMeta = const VerificationMeta('after');
  @override
  late final GeneratedColumn<String> after = GeneratedColumn<String>(
    'after',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  answerWords = GeneratedColumn<String>(
    'answer_words',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($QuestionsTable.$converteranswerWords);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> bankPool =
      GeneratedColumn<String>(
        'bank_pool',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($QuestionsTable.$converterbankPool);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tokens =
      GeneratedColumn<String>(
        'tokens',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($QuestionsTable.$convertertokens);
  static const VerificationMeta _finalPunctMeta = const VerificationMeta(
    'finalPunct',
  );
  @override
  late final GeneratedColumn<String> finalPunct = GeneratedColumn<String>(
    'final_punct',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cueTextMeta = const VerificationMeta(
    'cueText',
  );
  @override
  late final GeneratedColumn<String> cueText = GeneratedColumn<String>(
    'cue_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cueTranslationNativeMeta =
      const VerificationMeta('cueTranslationNative');
  @override
  late final GeneratedColumn<String> cueTranslationNative =
      GeneratedColumn<String>(
        'cue_translation_native',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _answerTextMeta = const VerificationMeta(
    'answerText',
  );
  @override
  late final GeneratedColumn<String> answerText = GeneratedColumn<String>(
    'answer_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    type,
    sentenceId,
    realmId,
    itemId,
    body,
    translationNative,
    level,
    context,
    options,
    correct,
    before,
    after,
    answerWords,
    bankPool,
    tokens,
    finalPunct,
    cueText,
    cueTranslationNative,
    note,
    answerText,
    disabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceIdMeta);
    }
    if (data.containsKey('realm_id')) {
      context.handle(
        _realmIdMeta,
        realmId.isAcceptableOrUnknown(data['realm_id']!, _realmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_realmIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('translation_native')) {
      context.handle(
        _translationNativeMeta,
        translationNative.isAcceptableOrUnknown(
          data['translation_native']!,
          _translationNativeMeta,
        ),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('before')) {
      context.handle(
        _beforeMeta,
        before.isAcceptableOrUnknown(data['before']!, _beforeMeta),
      );
    }
    if (data.containsKey('after')) {
      context.handle(
        _afterMeta,
        after.isAcceptableOrUnknown(data['after']!, _afterMeta),
      );
    }
    if (data.containsKey('final_punct')) {
      context.handle(
        _finalPunctMeta,
        finalPunct.isAcceptableOrUnknown(data['final_punct']!, _finalPunctMeta),
      );
    }
    if (data.containsKey('cue_text')) {
      context.handle(
        _cueTextMeta,
        cueText.isAcceptableOrUnknown(data['cue_text']!, _cueTextMeta),
      );
    }
    if (data.containsKey('cue_translation_native')) {
      context.handle(
        _cueTranslationNativeMeta,
        cueTranslationNative.isAcceptableOrUnknown(
          data['cue_translation_native']!,
          _cueTranslationNativeMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('answer_text')) {
      context.handle(
        _answerTextMeta,
        answerText.isAcceptableOrUnknown(data['answer_text']!, _answerTextMeta),
      );
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
  QuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_id'],
      )!,
      realmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realm_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      translationNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_native'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      options: $QuestionsTable.$converteroptions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}options'],
        )!,
      ),
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      before: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before'],
      )!,
      after: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after'],
      )!,
      answerWords: $QuestionsTable.$converteranswerWords.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}answer_words'],
        )!,
      ),
      bankPool: $QuestionsTable.$converterbankPool.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}bank_pool'],
        )!,
      ),
      tokens: $QuestionsTable.$convertertokens.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tokens'],
        )!,
      ),
      finalPunct: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_punct'],
      )!,
      cueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cue_text'],
      )!,
      cueTranslationNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cue_translation_native'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      answerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_text'],
      )!,
      disabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disabled'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converteroptions =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converteranswerWords =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterbankPool =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertokens =
      const StringListConverter();
}

class QuestionRow extends DataClass implements Insertable<QuestionRow> {
  final String id;
  final String type;
  final String sentenceId;
  final String realmId;
  final String? itemId;
  final String body;
  final String translationNative;
  final String level;
  final String context;
  final List<String> options;
  final int correct;
  final String before;
  final String after;
  final List<String> answerWords;
  final List<String> bankPool;
  final List<String> tokens;
  final String finalPunct;
  final String cueText;
  final String cueTranslationNative;
  final String note;
  final String answerText;
  final bool disabled;
  const QuestionRow({
    required this.id,
    required this.type,
    required this.sentenceId,
    required this.realmId,
    this.itemId,
    required this.body,
    required this.translationNative,
    required this.level,
    required this.context,
    required this.options,
    required this.correct,
    required this.before,
    required this.after,
    required this.answerWords,
    required this.bankPool,
    required this.tokens,
    required this.finalPunct,
    required this.cueText,
    required this.cueTranslationNative,
    required this.note,
    required this.answerText,
    required this.disabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['sentence_id'] = Variable<String>(sentenceId);
    map['realm_id'] = Variable<String>(realmId);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['text'] = Variable<String>(body);
    map['translation_native'] = Variable<String>(translationNative);
    map['level'] = Variable<String>(level);
    map['context'] = Variable<String>(context);
    {
      map['options'] = Variable<String>(
        $QuestionsTable.$converteroptions.toSql(options),
      );
    }
    map['correct'] = Variable<int>(correct);
    map['before'] = Variable<String>(before);
    map['after'] = Variable<String>(after);
    {
      map['answer_words'] = Variable<String>(
        $QuestionsTable.$converteranswerWords.toSql(answerWords),
      );
    }
    {
      map['bank_pool'] = Variable<String>(
        $QuestionsTable.$converterbankPool.toSql(bankPool),
      );
    }
    {
      map['tokens'] = Variable<String>(
        $QuestionsTable.$convertertokens.toSql(tokens),
      );
    }
    map['final_punct'] = Variable<String>(finalPunct);
    map['cue_text'] = Variable<String>(cueText);
    map['cue_translation_native'] = Variable<String>(cueTranslationNative);
    map['note'] = Variable<String>(note);
    map['answer_text'] = Variable<String>(answerText);
    map['disabled'] = Variable<bool>(disabled);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      type: Value(type),
      sentenceId: Value(sentenceId),
      realmId: Value(realmId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      body: Value(body),
      translationNative: Value(translationNative),
      level: Value(level),
      context: Value(context),
      options: Value(options),
      correct: Value(correct),
      before: Value(before),
      after: Value(after),
      answerWords: Value(answerWords),
      bankPool: Value(bankPool),
      tokens: Value(tokens),
      finalPunct: Value(finalPunct),
      cueText: Value(cueText),
      cueTranslationNative: Value(cueTranslationNative),
      note: Value(note),
      answerText: Value(answerText),
      disabled: Value(disabled),
    );
  }

  factory QuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      sentenceId: serializer.fromJson<String>(json['sentenceId']),
      realmId: serializer.fromJson<String>(json['realmId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      body: serializer.fromJson<String>(json['body']),
      translationNative: serializer.fromJson<String>(json['translationNative']),
      level: serializer.fromJson<String>(json['level']),
      context: serializer.fromJson<String>(json['context']),
      options: serializer.fromJson<List<String>>(json['options']),
      correct: serializer.fromJson<int>(json['correct']),
      before: serializer.fromJson<String>(json['before']),
      after: serializer.fromJson<String>(json['after']),
      answerWords: serializer.fromJson<List<String>>(json['answerWords']),
      bankPool: serializer.fromJson<List<String>>(json['bankPool']),
      tokens: serializer.fromJson<List<String>>(json['tokens']),
      finalPunct: serializer.fromJson<String>(json['finalPunct']),
      cueText: serializer.fromJson<String>(json['cueText']),
      cueTranslationNative: serializer.fromJson<String>(
        json['cueTranslationNative'],
      ),
      note: serializer.fromJson<String>(json['note']),
      answerText: serializer.fromJson<String>(json['answerText']),
      disabled: serializer.fromJson<bool>(json['disabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'sentenceId': serializer.toJson<String>(sentenceId),
      'realmId': serializer.toJson<String>(realmId),
      'itemId': serializer.toJson<String?>(itemId),
      'body': serializer.toJson<String>(body),
      'translationNative': serializer.toJson<String>(translationNative),
      'level': serializer.toJson<String>(level),
      'context': serializer.toJson<String>(context),
      'options': serializer.toJson<List<String>>(options),
      'correct': serializer.toJson<int>(correct),
      'before': serializer.toJson<String>(before),
      'after': serializer.toJson<String>(after),
      'answerWords': serializer.toJson<List<String>>(answerWords),
      'bankPool': serializer.toJson<List<String>>(bankPool),
      'tokens': serializer.toJson<List<String>>(tokens),
      'finalPunct': serializer.toJson<String>(finalPunct),
      'cueText': serializer.toJson<String>(cueText),
      'cueTranslationNative': serializer.toJson<String>(cueTranslationNative),
      'note': serializer.toJson<String>(note),
      'answerText': serializer.toJson<String>(answerText),
      'disabled': serializer.toJson<bool>(disabled),
    };
  }

  QuestionRow copyWith({
    String? id,
    String? type,
    String? sentenceId,
    String? realmId,
    Value<String?> itemId = const Value.absent(),
    String? body,
    String? translationNative,
    String? level,
    String? context,
    List<String>? options,
    int? correct,
    String? before,
    String? after,
    List<String>? answerWords,
    List<String>? bankPool,
    List<String>? tokens,
    String? finalPunct,
    String? cueText,
    String? cueTranslationNative,
    String? note,
    String? answerText,
    bool? disabled,
  }) => QuestionRow(
    id: id ?? this.id,
    type: type ?? this.type,
    sentenceId: sentenceId ?? this.sentenceId,
    realmId: realmId ?? this.realmId,
    itemId: itemId.present ? itemId.value : this.itemId,
    body: body ?? this.body,
    translationNative: translationNative ?? this.translationNative,
    level: level ?? this.level,
    context: context ?? this.context,
    options: options ?? this.options,
    correct: correct ?? this.correct,
    before: before ?? this.before,
    after: after ?? this.after,
    answerWords: answerWords ?? this.answerWords,
    bankPool: bankPool ?? this.bankPool,
    tokens: tokens ?? this.tokens,
    finalPunct: finalPunct ?? this.finalPunct,
    cueText: cueText ?? this.cueText,
    cueTranslationNative: cueTranslationNative ?? this.cueTranslationNative,
    note: note ?? this.note,
    answerText: answerText ?? this.answerText,
    disabled: disabled ?? this.disabled,
  );
  QuestionRow copyWithCompanion(QuestionsCompanion data) {
    return QuestionRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      sentenceId: data.sentenceId.present
          ? data.sentenceId.value
          : this.sentenceId,
      realmId: data.realmId.present ? data.realmId.value : this.realmId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      body: data.body.present ? data.body.value : this.body,
      translationNative: data.translationNative.present
          ? data.translationNative.value
          : this.translationNative,
      level: data.level.present ? data.level.value : this.level,
      context: data.context.present ? data.context.value : this.context,
      options: data.options.present ? data.options.value : this.options,
      correct: data.correct.present ? data.correct.value : this.correct,
      before: data.before.present ? data.before.value : this.before,
      after: data.after.present ? data.after.value : this.after,
      answerWords: data.answerWords.present
          ? data.answerWords.value
          : this.answerWords,
      bankPool: data.bankPool.present ? data.bankPool.value : this.bankPool,
      tokens: data.tokens.present ? data.tokens.value : this.tokens,
      finalPunct: data.finalPunct.present
          ? data.finalPunct.value
          : this.finalPunct,
      cueText: data.cueText.present ? data.cueText.value : this.cueText,
      cueTranslationNative: data.cueTranslationNative.present
          ? data.cueTranslationNative.value
          : this.cueTranslationNative,
      note: data.note.present ? data.note.value : this.note,
      answerText: data.answerText.present
          ? data.answerText.value
          : this.answerText,
      disabled: data.disabled.present ? data.disabled.value : this.disabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('realmId: $realmId, ')
          ..write('itemId: $itemId, ')
          ..write('body: $body, ')
          ..write('translationNative: $translationNative, ')
          ..write('level: $level, ')
          ..write('context: $context, ')
          ..write('options: $options, ')
          ..write('correct: $correct, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('answerWords: $answerWords, ')
          ..write('bankPool: $bankPool, ')
          ..write('tokens: $tokens, ')
          ..write('finalPunct: $finalPunct, ')
          ..write('cueText: $cueText, ')
          ..write('cueTranslationNative: $cueTranslationNative, ')
          ..write('note: $note, ')
          ..write('answerText: $answerText, ')
          ..write('disabled: $disabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    sentenceId,
    realmId,
    itemId,
    body,
    translationNative,
    level,
    context,
    options,
    correct,
    before,
    after,
    answerWords,
    bankPool,
    tokens,
    finalPunct,
    cueText,
    cueTranslationNative,
    note,
    answerText,
    disabled,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.sentenceId == this.sentenceId &&
          other.realmId == this.realmId &&
          other.itemId == this.itemId &&
          other.body == this.body &&
          other.translationNative == this.translationNative &&
          other.level == this.level &&
          other.context == this.context &&
          other.options == this.options &&
          other.correct == this.correct &&
          other.before == this.before &&
          other.after == this.after &&
          other.answerWords == this.answerWords &&
          other.bankPool == this.bankPool &&
          other.tokens == this.tokens &&
          other.finalPunct == this.finalPunct &&
          other.cueText == this.cueText &&
          other.cueTranslationNative == this.cueTranslationNative &&
          other.note == this.note &&
          other.answerText == this.answerText &&
          other.disabled == this.disabled);
}

class QuestionsCompanion extends UpdateCompanion<QuestionRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> sentenceId;
  final Value<String> realmId;
  final Value<String?> itemId;
  final Value<String> body;
  final Value<String> translationNative;
  final Value<String> level;
  final Value<String> context;
  final Value<List<String>> options;
  final Value<int> correct;
  final Value<String> before;
  final Value<String> after;
  final Value<List<String>> answerWords;
  final Value<List<String>> bankPool;
  final Value<List<String>> tokens;
  final Value<String> finalPunct;
  final Value<String> cueText;
  final Value<String> cueTranslationNative;
  final Value<String> note;
  final Value<String> answerText;
  final Value<bool> disabled;
  final Value<int> rowid;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.realmId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.body = const Value.absent(),
    this.translationNative = const Value.absent(),
    this.level = const Value.absent(),
    this.context = const Value.absent(),
    this.options = const Value.absent(),
    this.correct = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.answerWords = const Value.absent(),
    this.bankPool = const Value.absent(),
    this.tokens = const Value.absent(),
    this.finalPunct = const Value.absent(),
    this.cueText = const Value.absent(),
    this.cueTranslationNative = const Value.absent(),
    this.note = const Value.absent(),
    this.answerText = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestionsCompanion.insert({
    required String id,
    required String type,
    required String sentenceId,
    required String realmId,
    this.itemId = const Value.absent(),
    required String body,
    this.translationNative = const Value.absent(),
    this.level = const Value.absent(),
    this.context = const Value.absent(),
    this.options = const Value.absent(),
    this.correct = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.answerWords = const Value.absent(),
    this.bankPool = const Value.absent(),
    this.tokens = const Value.absent(),
    this.finalPunct = const Value.absent(),
    this.cueText = const Value.absent(),
    this.cueTranslationNative = const Value.absent(),
    this.note = const Value.absent(),
    this.answerText = const Value.absent(),
    this.disabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       sentenceId = Value(sentenceId),
       realmId = Value(realmId),
       body = Value(body);
  static Insertable<QuestionRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? sentenceId,
    Expression<String>? realmId,
    Expression<String>? itemId,
    Expression<String>? body,
    Expression<String>? translationNative,
    Expression<String>? level,
    Expression<String>? context,
    Expression<String>? options,
    Expression<int>? correct,
    Expression<String>? before,
    Expression<String>? after,
    Expression<String>? answerWords,
    Expression<String>? bankPool,
    Expression<String>? tokens,
    Expression<String>? finalPunct,
    Expression<String>? cueText,
    Expression<String>? cueTranslationNative,
    Expression<String>? note,
    Expression<String>? answerText,
    Expression<bool>? disabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (sentenceId != null) 'sentence_id': sentenceId,
      if (realmId != null) 'realm_id': realmId,
      if (itemId != null) 'item_id': itemId,
      if (body != null) 'text': body,
      if (translationNative != null) 'translation_native': translationNative,
      if (level != null) 'level': level,
      if (context != null) 'context': context,
      if (options != null) 'options': options,
      if (correct != null) 'correct': correct,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (answerWords != null) 'answer_words': answerWords,
      if (bankPool != null) 'bank_pool': bankPool,
      if (tokens != null) 'tokens': tokens,
      if (finalPunct != null) 'final_punct': finalPunct,
      if (cueText != null) 'cue_text': cueText,
      if (cueTranslationNative != null)
        'cue_translation_native': cueTranslationNative,
      if (note != null) 'note': note,
      if (answerText != null) 'answer_text': answerText,
      if (disabled != null) 'disabled': disabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? sentenceId,
    Value<String>? realmId,
    Value<String?>? itemId,
    Value<String>? body,
    Value<String>? translationNative,
    Value<String>? level,
    Value<String>? context,
    Value<List<String>>? options,
    Value<int>? correct,
    Value<String>? before,
    Value<String>? after,
    Value<List<String>>? answerWords,
    Value<List<String>>? bankPool,
    Value<List<String>>? tokens,
    Value<String>? finalPunct,
    Value<String>? cueText,
    Value<String>? cueTranslationNative,
    Value<String>? note,
    Value<String>? answerText,
    Value<bool>? disabled,
    Value<int>? rowid,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      sentenceId: sentenceId ?? this.sentenceId,
      realmId: realmId ?? this.realmId,
      itemId: itemId ?? this.itemId,
      body: body ?? this.body,
      translationNative: translationNative ?? this.translationNative,
      level: level ?? this.level,
      context: context ?? this.context,
      options: options ?? this.options,
      correct: correct ?? this.correct,
      before: before ?? this.before,
      after: after ?? this.after,
      answerWords: answerWords ?? this.answerWords,
      bankPool: bankPool ?? this.bankPool,
      tokens: tokens ?? this.tokens,
      finalPunct: finalPunct ?? this.finalPunct,
      cueText: cueText ?? this.cueText,
      cueTranslationNative: cueTranslationNative ?? this.cueTranslationNative,
      note: note ?? this.note,
      answerText: answerText ?? this.answerText,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<String>(sentenceId.value);
    }
    if (realmId.present) {
      map['realm_id'] = Variable<String>(realmId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (translationNative.present) {
      map['translation_native'] = Variable<String>(translationNative.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (options.present) {
      map['options'] = Variable<String>(
        $QuestionsTable.$converteroptions.toSql(options.value),
      );
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (before.present) {
      map['before'] = Variable<String>(before.value);
    }
    if (after.present) {
      map['after'] = Variable<String>(after.value);
    }
    if (answerWords.present) {
      map['answer_words'] = Variable<String>(
        $QuestionsTable.$converteranswerWords.toSql(answerWords.value),
      );
    }
    if (bankPool.present) {
      map['bank_pool'] = Variable<String>(
        $QuestionsTable.$converterbankPool.toSql(bankPool.value),
      );
    }
    if (tokens.present) {
      map['tokens'] = Variable<String>(
        $QuestionsTable.$convertertokens.toSql(tokens.value),
      );
    }
    if (finalPunct.present) {
      map['final_punct'] = Variable<String>(finalPunct.value);
    }
    if (cueText.present) {
      map['cue_text'] = Variable<String>(cueText.value);
    }
    if (cueTranslationNative.present) {
      map['cue_translation_native'] = Variable<String>(
        cueTranslationNative.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (answerText.present) {
      map['answer_text'] = Variable<String>(answerText.value);
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
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('realmId: $realmId, ')
          ..write('itemId: $itemId, ')
          ..write('body: $body, ')
          ..write('translationNative: $translationNative, ')
          ..write('level: $level, ')
          ..write('context: $context, ')
          ..write('options: $options, ')
          ..write('correct: $correct, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('answerWords: $answerWords, ')
          ..write('bankPool: $bankPool, ')
          ..write('tokens: $tokens, ')
          ..write('finalPunct: $finalPunct, ')
          ..write('cueText: $cueText, ')
          ..write('cueTranslationNative: $cueTranslationNative, ')
          ..write('note: $note, ')
          ..write('answerText: $answerText, ')
          ..write('disabled: $disabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SrsStatesTable extends SrsStates
    with TableInfo<$SrsStatesTable, SrsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SrsStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxMeta = const VerificationMeta('box');
  @override
  late final GeneratedColumn<int> box = GeneratedColumn<int>(
    'box',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<String> due = GeneratedColumn<String>(
    'due',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastResultMeta = const VerificationMeta(
    'lastResult',
  );
  @override
  late final GeneratedColumn<String> lastResult = GeneratedColumn<String>(
    'last_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<String> lastSeen = GeneratedColumn<String>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introducedMeta = const VerificationMeta(
    'introduced',
  );
  @override
  late final GeneratedColumn<bool> introduced = GeneratedColumn<bool>(
    'introduced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("introduced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _heldByGateMeta = const VerificationMeta(
    'heldByGate',
  );
  @override
  late final GeneratedColumn<bool> heldByGate = GeneratedColumn<bool>(
    'held_by_gate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("held_by_gate" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSentenceIdMeta = const VerificationMeta(
    'lastSentenceId',
  );
  @override
  late final GeneratedColumn<String> lastSentenceId = GeneratedColumn<String>(
    'last_sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatsMeta = const VerificationMeta(
    'formats',
  );
  @override
  late final GeneratedColumn<String> formats = GeneratedColumn<String>(
    'formats',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    box,
    due,
    reps,
    lapses,
    lastResult,
    lastSeen,
    introduced,
    heldByGate,
    lastSentenceId,
    formats,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'srs_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SrsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('box')) {
      context.handle(
        _boxMeta,
        box.isAcceptableOrUnknown(data['box']!, _boxMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    } else if (isInserting) {
      context.missing(_dueMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_result')) {
      context.handle(
        _lastResultMeta,
        lastResult.isAcceptableOrUnknown(data['last_result']!, _lastResultMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('introduced')) {
      context.handle(
        _introducedMeta,
        introduced.isAcceptableOrUnknown(data['introduced']!, _introducedMeta),
      );
    }
    if (data.containsKey('held_by_gate')) {
      context.handle(
        _heldByGateMeta,
        heldByGate.isAcceptableOrUnknown(
          data['held_by_gate']!,
          _heldByGateMeta,
        ),
      );
    }
    if (data.containsKey('last_sentence_id')) {
      context.handle(
        _lastSentenceIdMeta,
        lastSentenceId.isAcceptableOrUnknown(
          data['last_sentence_id']!,
          _lastSentenceIdMeta,
        ),
      );
    }
    if (data.containsKey('formats')) {
      context.handle(
        _formatsMeta,
        formats.isAcceptableOrUnknown(data['formats']!, _formatsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  SrsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SrsRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      box: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box'],
      )!,
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_result'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_seen'],
      ),
      introduced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}introduced'],
      )!,
      heldByGate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}held_by_gate'],
      )!,
      lastSentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sentence_id'],
      ),
      formats: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formats'],
      )!,
    );
  }

  @override
  $SrsStatesTable createAlias(String alias) {
    return $SrsStatesTable(attachedDatabase, alias);
  }
}

class SrsRow extends DataClass implements Insertable<SrsRow> {
  final String itemId;
  final int box;
  final String due;
  final int reps;
  final int lapses;
  final String? lastResult;
  final String? lastSeen;
  final bool introduced;
  final bool heldByGate;
  final String? lastSentenceId;

  /// `{"gist":{"n":1,"ok":1}, ...}` — read and written as a unit.
  final String formats;
  const SrsRow({
    required this.itemId,
    required this.box,
    required this.due,
    required this.reps,
    required this.lapses,
    this.lastResult,
    this.lastSeen,
    required this.introduced,
    required this.heldByGate,
    this.lastSentenceId,
    required this.formats,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['box'] = Variable<int>(box);
    map['due'] = Variable<String>(due);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastResult != null) {
      map['last_result'] = Variable<String>(lastResult);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<String>(lastSeen);
    }
    map['introduced'] = Variable<bool>(introduced);
    map['held_by_gate'] = Variable<bool>(heldByGate);
    if (!nullToAbsent || lastSentenceId != null) {
      map['last_sentence_id'] = Variable<String>(lastSentenceId);
    }
    map['formats'] = Variable<String>(formats);
    return map;
  }

  SrsStatesCompanion toCompanion(bool nullToAbsent) {
    return SrsStatesCompanion(
      itemId: Value(itemId),
      box: Value(box),
      due: Value(due),
      reps: Value(reps),
      lapses: Value(lapses),
      lastResult: lastResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResult),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      introduced: Value(introduced),
      heldByGate: Value(heldByGate),
      lastSentenceId: lastSentenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSentenceId),
      formats: Value(formats),
    );
  }

  factory SrsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SrsRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      box: serializer.fromJson<int>(json['box']),
      due: serializer.fromJson<String>(json['due']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastResult: serializer.fromJson<String?>(json['lastResult']),
      lastSeen: serializer.fromJson<String?>(json['lastSeen']),
      introduced: serializer.fromJson<bool>(json['introduced']),
      heldByGate: serializer.fromJson<bool>(json['heldByGate']),
      lastSentenceId: serializer.fromJson<String?>(json['lastSentenceId']),
      formats: serializer.fromJson<String>(json['formats']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'box': serializer.toJson<int>(box),
      'due': serializer.toJson<String>(due),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastResult': serializer.toJson<String?>(lastResult),
      'lastSeen': serializer.toJson<String?>(lastSeen),
      'introduced': serializer.toJson<bool>(introduced),
      'heldByGate': serializer.toJson<bool>(heldByGate),
      'lastSentenceId': serializer.toJson<String?>(lastSentenceId),
      'formats': serializer.toJson<String>(formats),
    };
  }

  SrsRow copyWith({
    String? itemId,
    int? box,
    String? due,
    int? reps,
    int? lapses,
    Value<String?> lastResult = const Value.absent(),
    Value<String?> lastSeen = const Value.absent(),
    bool? introduced,
    bool? heldByGate,
    Value<String?> lastSentenceId = const Value.absent(),
    String? formats,
  }) => SrsRow(
    itemId: itemId ?? this.itemId,
    box: box ?? this.box,
    due: due ?? this.due,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastResult: lastResult.present ? lastResult.value : this.lastResult,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    introduced: introduced ?? this.introduced,
    heldByGate: heldByGate ?? this.heldByGate,
    lastSentenceId: lastSentenceId.present
        ? lastSentenceId.value
        : this.lastSentenceId,
    formats: formats ?? this.formats,
  );
  SrsRow copyWithCompanion(SrsStatesCompanion data) {
    return SrsRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      box: data.box.present ? data.box.value : this.box,
      due: data.due.present ? data.due.value : this.due,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastResult: data.lastResult.present
          ? data.lastResult.value
          : this.lastResult,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      introduced: data.introduced.present
          ? data.introduced.value
          : this.introduced,
      heldByGate: data.heldByGate.present
          ? data.heldByGate.value
          : this.heldByGate,
      lastSentenceId: data.lastSentenceId.present
          ? data.lastSentenceId.value
          : this.lastSentenceId,
      formats: data.formats.present ? data.formats.value : this.formats,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SrsRow(')
          ..write('itemId: $itemId, ')
          ..write('box: $box, ')
          ..write('due: $due, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastResult: $lastResult, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('introduced: $introduced, ')
          ..write('heldByGate: $heldByGate, ')
          ..write('lastSentenceId: $lastSentenceId, ')
          ..write('formats: $formats')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    box,
    due,
    reps,
    lapses,
    lastResult,
    lastSeen,
    introduced,
    heldByGate,
    lastSentenceId,
    formats,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SrsRow &&
          other.itemId == this.itemId &&
          other.box == this.box &&
          other.due == this.due &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastResult == this.lastResult &&
          other.lastSeen == this.lastSeen &&
          other.introduced == this.introduced &&
          other.heldByGate == this.heldByGate &&
          other.lastSentenceId == this.lastSentenceId &&
          other.formats == this.formats);
}

class SrsStatesCompanion extends UpdateCompanion<SrsRow> {
  final Value<String> itemId;
  final Value<int> box;
  final Value<String> due;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<String?> lastResult;
  final Value<String?> lastSeen;
  final Value<bool> introduced;
  final Value<bool> heldByGate;
  final Value<String?> lastSentenceId;
  final Value<String> formats;
  final Value<int> rowid;
  const SrsStatesCompanion({
    this.itemId = const Value.absent(),
    this.box = const Value.absent(),
    this.due = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.introduced = const Value.absent(),
    this.heldByGate = const Value.absent(),
    this.lastSentenceId = const Value.absent(),
    this.formats = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SrsStatesCompanion.insert({
    required String itemId,
    this.box = const Value.absent(),
    required String due,
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.introduced = const Value.absent(),
    this.heldByGate = const Value.absent(),
    this.lastSentenceId = const Value.absent(),
    this.formats = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       due = Value(due);
  static Insertable<SrsRow> custom({
    Expression<String>? itemId,
    Expression<int>? box,
    Expression<String>? due,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<String>? lastResult,
    Expression<String>? lastSeen,
    Expression<bool>? introduced,
    Expression<bool>? heldByGate,
    Expression<String>? lastSentenceId,
    Expression<String>? formats,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (box != null) 'box': box,
      if (due != null) 'due': due,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastResult != null) 'last_result': lastResult,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (introduced != null) 'introduced': introduced,
      if (heldByGate != null) 'held_by_gate': heldByGate,
      if (lastSentenceId != null) 'last_sentence_id': lastSentenceId,
      if (formats != null) 'formats': formats,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SrsStatesCompanion copyWith({
    Value<String>? itemId,
    Value<int>? box,
    Value<String>? due,
    Value<int>? reps,
    Value<int>? lapses,
    Value<String?>? lastResult,
    Value<String?>? lastSeen,
    Value<bool>? introduced,
    Value<bool>? heldByGate,
    Value<String?>? lastSentenceId,
    Value<String>? formats,
    Value<int>? rowid,
  }) {
    return SrsStatesCompanion(
      itemId: itemId ?? this.itemId,
      box: box ?? this.box,
      due: due ?? this.due,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastResult: lastResult ?? this.lastResult,
      lastSeen: lastSeen ?? this.lastSeen,
      introduced: introduced ?? this.introduced,
      heldByGate: heldByGate ?? this.heldByGate,
      lastSentenceId: lastSentenceId ?? this.lastSentenceId,
      formats: formats ?? this.formats,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (box.present) {
      map['box'] = Variable<int>(box.value);
    }
    if (due.present) {
      map['due'] = Variable<String>(due.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastResult.present) {
      map['last_result'] = Variable<String>(lastResult.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<String>(lastSeen.value);
    }
    if (introduced.present) {
      map['introduced'] = Variable<bool>(introduced.value);
    }
    if (heldByGate.present) {
      map['held_by_gate'] = Variable<bool>(heldByGate.value);
    }
    if (lastSentenceId.present) {
      map['last_sentence_id'] = Variable<String>(lastSentenceId.value);
    }
    if (formats.present) {
      map['formats'] = Variable<String>(formats.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SrsStatesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('box: $box, ')
          ..write('due: $due, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastResult: $lastResult, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('introduced: $introduced, ')
          ..write('heldByGate: $heldByGate, ')
          ..write('lastSentenceId: $lastSentenceId, ')
          ..write('formats: $formats, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestionStatsTable extends QuestionStats
    with TableInfo<$QuestionStatsTable, QuestionStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nMeta = const VerificationMeta('n');
  @override
  late final GeneratedColumn<int> n = GeneratedColumn<int>(
    'n',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<int> ok = GeneratedColumn<int>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAtMeta = const VerificationMeta('lastAt');
  @override
  late final GeneratedColumn<int> lastAt = GeneratedColumn<int>(
    'last_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, n, ok, lastAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'question_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('n')) {
      context.handle(_nMeta, n.isAcceptableOrUnknown(data['n']!, _nMeta));
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    }
    if (data.containsKey('last_at')) {
      context.handle(
        _lastAtMeta,
        lastAt.isAcceptableOrUnknown(data['last_at']!, _lastAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  QuestionStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionStatRow(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      n: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}n'],
      )!,
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ok'],
      )!,
      lastAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_at'],
      )!,
    );
  }

  @override
  $QuestionStatsTable createAlias(String alias) {
    return $QuestionStatsTable(attachedDatabase, alias);
  }
}

class QuestionStatRow extends DataClass implements Insertable<QuestionStatRow> {
  final String questionId;
  final int n;
  final int ok;
  final int lastAt;
  const QuestionStatRow({
    required this.questionId,
    required this.n,
    required this.ok,
    required this.lastAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['n'] = Variable<int>(n);
    map['ok'] = Variable<int>(ok);
    map['last_at'] = Variable<int>(lastAt);
    return map;
  }

  QuestionStatsCompanion toCompanion(bool nullToAbsent) {
    return QuestionStatsCompanion(
      questionId: Value(questionId),
      n: Value(n),
      ok: Value(ok),
      lastAt: Value(lastAt),
    );
  }

  factory QuestionStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionStatRow(
      questionId: serializer.fromJson<String>(json['questionId']),
      n: serializer.fromJson<int>(json['n']),
      ok: serializer.fromJson<int>(json['ok']),
      lastAt: serializer.fromJson<int>(json['lastAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'n': serializer.toJson<int>(n),
      'ok': serializer.toJson<int>(ok),
      'lastAt': serializer.toJson<int>(lastAt),
    };
  }

  QuestionStatRow copyWith({
    String? questionId,
    int? n,
    int? ok,
    int? lastAt,
  }) => QuestionStatRow(
    questionId: questionId ?? this.questionId,
    n: n ?? this.n,
    ok: ok ?? this.ok,
    lastAt: lastAt ?? this.lastAt,
  );
  QuestionStatRow copyWithCompanion(QuestionStatsCompanion data) {
    return QuestionStatRow(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      n: data.n.present ? data.n.value : this.n,
      ok: data.ok.present ? data.ok.value : this.ok,
      lastAt: data.lastAt.present ? data.lastAt.value : this.lastAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionStatRow(')
          ..write('questionId: $questionId, ')
          ..write('n: $n, ')
          ..write('ok: $ok, ')
          ..write('lastAt: $lastAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, n, ok, lastAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionStatRow &&
          other.questionId == this.questionId &&
          other.n == this.n &&
          other.ok == this.ok &&
          other.lastAt == this.lastAt);
}

class QuestionStatsCompanion extends UpdateCompanion<QuestionStatRow> {
  final Value<String> questionId;
  final Value<int> n;
  final Value<int> ok;
  final Value<int> lastAt;
  final Value<int> rowid;
  const QuestionStatsCompanion({
    this.questionId = const Value.absent(),
    this.n = const Value.absent(),
    this.ok = const Value.absent(),
    this.lastAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestionStatsCompanion.insert({
    required String questionId,
    this.n = const Value.absent(),
    this.ok = const Value.absent(),
    this.lastAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId);
  static Insertable<QuestionStatRow> custom({
    Expression<String>? questionId,
    Expression<int>? n,
    Expression<int>? ok,
    Expression<int>? lastAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (n != null) 'n': n,
      if (ok != null) 'ok': ok,
      if (lastAt != null) 'last_at': lastAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestionStatsCompanion copyWith({
    Value<String>? questionId,
    Value<int>? n,
    Value<int>? ok,
    Value<int>? lastAt,
    Value<int>? rowid,
  }) {
    return QuestionStatsCompanion(
      questionId: questionId ?? this.questionId,
      n: n ?? this.n,
      ok: ok ?? this.ok,
      lastAt: lastAt ?? this.lastAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (n.present) {
      map['n'] = Variable<int>(n.value);
    }
    if (ok.present) {
      map['ok'] = Variable<int>(ok.value);
    }
    if (lastAt.present) {
      map['last_at'] = Variable<int>(lastAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionStatsCompanion(')
          ..write('questionId: $questionId, ')
          ..write('n: $n, ')
          ..write('ok: $ok, ')
          ..write('lastAt: $lastAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoriesTable extends Histories
    with TableInfo<$HistoriesTable, HistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _realmIdMeta = const VerificationMeta(
    'realmId',
  );
  @override
  late final GeneratedColumn<String> realmId = GeneratedColumn<String>(
    'realm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _wasDueMeta = const VerificationMeta('wasDue');
  @override
  late final GeneratedColumn<bool> wasDue = GeneratedColumn<bool>(
    'was_due',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_due" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    at,
    questionId,
    itemId,
    realmId,
    type,
    correct,
    wasDue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('realm_id')) {
      context.handle(
        _realmIdMeta,
        realmId.isAcceptableOrUnknown(data['realm_id']!, _realmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_realmIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('was_due')) {
      context.handle(
        _wasDueMeta,
        wasDue.isAcceptableOrUnknown(data['was_due']!, _wasDueMeta),
      );
    } else if (isInserting) {
      context.missing(_wasDueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      realmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realm_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      wasDue: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_due'],
      )!,
    );
  }

  @override
  $HistoriesTable createAlias(String alias) {
    return $HistoriesTable(attachedDatabase, alias);
  }
}

class HistoryRow extends DataClass implements Insertable<HistoryRow> {
  final int id;
  final String day;
  final int at;
  final String questionId;
  final String? itemId;
  final String realmId;
  final String type;
  final bool correct;
  final bool wasDue;
  const HistoryRow({
    required this.id,
    required this.day,
    required this.at,
    required this.questionId,
    this.itemId,
    required this.realmId,
    required this.type,
    required this.correct,
    required this.wasDue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<String>(day);
    map['at'] = Variable<int>(at);
    map['question_id'] = Variable<String>(questionId);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['realm_id'] = Variable<String>(realmId);
    map['type'] = Variable<String>(type);
    map['correct'] = Variable<bool>(correct);
    map['was_due'] = Variable<bool>(wasDue);
    return map;
  }

  HistoriesCompanion toCompanion(bool nullToAbsent) {
    return HistoriesCompanion(
      id: Value(id),
      day: Value(day),
      at: Value(at),
      questionId: Value(questionId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      realmId: Value(realmId),
      type: Value(type),
      correct: Value(correct),
      wasDue: Value(wasDue),
    );
  }

  factory HistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRow(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<String>(json['day']),
      at: serializer.fromJson<int>(json['at']),
      questionId: serializer.fromJson<String>(json['questionId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      realmId: serializer.fromJson<String>(json['realmId']),
      type: serializer.fromJson<String>(json['type']),
      correct: serializer.fromJson<bool>(json['correct']),
      wasDue: serializer.fromJson<bool>(json['wasDue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<String>(day),
      'at': serializer.toJson<int>(at),
      'questionId': serializer.toJson<String>(questionId),
      'itemId': serializer.toJson<String?>(itemId),
      'realmId': serializer.toJson<String>(realmId),
      'type': serializer.toJson<String>(type),
      'correct': serializer.toJson<bool>(correct),
      'wasDue': serializer.toJson<bool>(wasDue),
    };
  }

  HistoryRow copyWith({
    int? id,
    String? day,
    int? at,
    String? questionId,
    Value<String?> itemId = const Value.absent(),
    String? realmId,
    String? type,
    bool? correct,
    bool? wasDue,
  }) => HistoryRow(
    id: id ?? this.id,
    day: day ?? this.day,
    at: at ?? this.at,
    questionId: questionId ?? this.questionId,
    itemId: itemId.present ? itemId.value : this.itemId,
    realmId: realmId ?? this.realmId,
    type: type ?? this.type,
    correct: correct ?? this.correct,
    wasDue: wasDue ?? this.wasDue,
  );
  HistoryRow copyWithCompanion(HistoriesCompanion data) {
    return HistoryRow(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      at: data.at.present ? data.at.value : this.at,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      realmId: data.realmId.present ? data.realmId.value : this.realmId,
      type: data.type.present ? data.type.value : this.type,
      correct: data.correct.present ? data.correct.value : this.correct,
      wasDue: data.wasDue.present ? data.wasDue.value : this.wasDue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRow(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('at: $at, ')
          ..write('questionId: $questionId, ')
          ..write('itemId: $itemId, ')
          ..write('realmId: $realmId, ')
          ..write('type: $type, ')
          ..write('correct: $correct, ')
          ..write('wasDue: $wasDue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    day,
    at,
    questionId,
    itemId,
    realmId,
    type,
    correct,
    wasDue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRow &&
          other.id == this.id &&
          other.day == this.day &&
          other.at == this.at &&
          other.questionId == this.questionId &&
          other.itemId == this.itemId &&
          other.realmId == this.realmId &&
          other.type == this.type &&
          other.correct == this.correct &&
          other.wasDue == this.wasDue);
}

class HistoriesCompanion extends UpdateCompanion<HistoryRow> {
  final Value<int> id;
  final Value<String> day;
  final Value<int> at;
  final Value<String> questionId;
  final Value<String?> itemId;
  final Value<String> realmId;
  final Value<String> type;
  final Value<bool> correct;
  final Value<bool> wasDue;
  const HistoriesCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.at = const Value.absent(),
    this.questionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.realmId = const Value.absent(),
    this.type = const Value.absent(),
    this.correct = const Value.absent(),
    this.wasDue = const Value.absent(),
  });
  HistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String day,
    required int at,
    required String questionId,
    this.itemId = const Value.absent(),
    required String realmId,
    required String type,
    required bool correct,
    required bool wasDue,
  }) : day = Value(day),
       at = Value(at),
       questionId = Value(questionId),
       realmId = Value(realmId),
       type = Value(type),
       correct = Value(correct),
       wasDue = Value(wasDue);
  static Insertable<HistoryRow> custom({
    Expression<int>? id,
    Expression<String>? day,
    Expression<int>? at,
    Expression<String>? questionId,
    Expression<String>? itemId,
    Expression<String>? realmId,
    Expression<String>? type,
    Expression<bool>? correct,
    Expression<bool>? wasDue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (at != null) 'at': at,
      if (questionId != null) 'question_id': questionId,
      if (itemId != null) 'item_id': itemId,
      if (realmId != null) 'realm_id': realmId,
      if (type != null) 'type': type,
      if (correct != null) 'correct': correct,
      if (wasDue != null) 'was_due': wasDue,
    });
  }

  HistoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? day,
    Value<int>? at,
    Value<String>? questionId,
    Value<String?>? itemId,
    Value<String>? realmId,
    Value<String>? type,
    Value<bool>? correct,
    Value<bool>? wasDue,
  }) {
    return HistoriesCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      at: at ?? this.at,
      questionId: questionId ?? this.questionId,
      itemId: itemId ?? this.itemId,
      realmId: realmId ?? this.realmId,
      type: type ?? this.type,
      correct: correct ?? this.correct,
      wasDue: wasDue ?? this.wasDue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (realmId.present) {
      map['realm_id'] = Variable<String>(realmId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (wasDue.present) {
      map['was_due'] = Variable<bool>(wasDue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoriesCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('at: $at, ')
          ..write('questionId: $questionId, ')
          ..write('itemId: $itemId, ')
          ..write('realmId: $realmId, ')
          ..write('type: $type, ')
          ..write('correct: $correct, ')
          ..write('wasDue: $wasDue')
          ..write(')'))
        .toString();
  }
}

class $BatchesTable extends Batches with TableInfo<$BatchesTable, BatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _promptVersionMeta = const VerificationMeta(
    'promptVersion',
  );
  @override
  late final GeneratedColumn<String> promptVersion = GeneratedColumn<String>(
    'prompt_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _countsMeta = const VerificationMeta('counts');
  @override
  late final GeneratedColumn<String> counts = GeneratedColumn<String>(
    'counts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    realmId,
    promptVersion,
    language,
    at,
    counts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<BatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('realm_id')) {
      context.handle(
        _realmIdMeta,
        realmId.isAcceptableOrUnknown(data['realm_id']!, _realmIdMeta),
      );
    }
    if (data.containsKey('prompt_version')) {
      context.handle(
        _promptVersionMeta,
        promptVersion.isAcceptableOrUnknown(
          data['prompt_version']!,
          _promptVersionMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('counts')) {
      context.handle(
        _countsMeta,
        counts.isAcceptableOrUnknown(data['counts']!, _countsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BatchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      realmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}realm_id'],
      ),
      promptVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_version'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      counts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counts'],
      )!,
    );
  }

  @override
  $BatchesTable createAlias(String alias) {
    return $BatchesTable(attachedDatabase, alias);
  }
}

class BatchRow extends DataClass implements Insertable<BatchRow> {
  final String id;
  final String kind;
  final String? realmId;
  final String promptVersion;
  final String language;
  final int at;
  final String counts;
  const BatchRow({
    required this.id,
    required this.kind,
    this.realmId,
    required this.promptVersion,
    required this.language,
    required this.at,
    required this.counts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || realmId != null) {
      map['realm_id'] = Variable<String>(realmId);
    }
    map['prompt_version'] = Variable<String>(promptVersion);
    map['language'] = Variable<String>(language);
    map['at'] = Variable<int>(at);
    map['counts'] = Variable<String>(counts);
    return map;
  }

  BatchesCompanion toCompanion(bool nullToAbsent) {
    return BatchesCompanion(
      id: Value(id),
      kind: Value(kind),
      realmId: realmId == null && nullToAbsent
          ? const Value.absent()
          : Value(realmId),
      promptVersion: Value(promptVersion),
      language: Value(language),
      at: Value(at),
      counts: Value(counts),
    );
  }

  factory BatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BatchRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      realmId: serializer.fromJson<String?>(json['realmId']),
      promptVersion: serializer.fromJson<String>(json['promptVersion']),
      language: serializer.fromJson<String>(json['language']),
      at: serializer.fromJson<int>(json['at']),
      counts: serializer.fromJson<String>(json['counts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'realmId': serializer.toJson<String?>(realmId),
      'promptVersion': serializer.toJson<String>(promptVersion),
      'language': serializer.toJson<String>(language),
      'at': serializer.toJson<int>(at),
      'counts': serializer.toJson<String>(counts),
    };
  }

  BatchRow copyWith({
    String? id,
    String? kind,
    Value<String?> realmId = const Value.absent(),
    String? promptVersion,
    String? language,
    int? at,
    String? counts,
  }) => BatchRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    realmId: realmId.present ? realmId.value : this.realmId,
    promptVersion: promptVersion ?? this.promptVersion,
    language: language ?? this.language,
    at: at ?? this.at,
    counts: counts ?? this.counts,
  );
  BatchRow copyWithCompanion(BatchesCompanion data) {
    return BatchRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      realmId: data.realmId.present ? data.realmId.value : this.realmId,
      promptVersion: data.promptVersion.present
          ? data.promptVersion.value
          : this.promptVersion,
      language: data.language.present ? data.language.value : this.language,
      at: data.at.present ? data.at.value : this.at,
      counts: data.counts.present ? data.counts.value : this.counts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BatchRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('realmId: $realmId, ')
          ..write('promptVersion: $promptVersion, ')
          ..write('language: $language, ')
          ..write('at: $at, ')
          ..write('counts: $counts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, realmId, promptVersion, language, at, counts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BatchRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.realmId == this.realmId &&
          other.promptVersion == this.promptVersion &&
          other.language == this.language &&
          other.at == this.at &&
          other.counts == this.counts);
}

class BatchesCompanion extends UpdateCompanion<BatchRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> realmId;
  final Value<String> promptVersion;
  final Value<String> language;
  final Value<int> at;
  final Value<String> counts;
  final Value<int> rowid;
  const BatchesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.realmId = const Value.absent(),
    this.promptVersion = const Value.absent(),
    this.language = const Value.absent(),
    this.at = const Value.absent(),
    this.counts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BatchesCompanion.insert({
    required String id,
    required String kind,
    this.realmId = const Value.absent(),
    this.promptVersion = const Value.absent(),
    this.language = const Value.absent(),
    required int at,
    this.counts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       at = Value(at);
  static Insertable<BatchRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? realmId,
    Expression<String>? promptVersion,
    Expression<String>? language,
    Expression<int>? at,
    Expression<String>? counts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (realmId != null) 'realm_id': realmId,
      if (promptVersion != null) 'prompt_version': promptVersion,
      if (language != null) 'language': language,
      if (at != null) 'at': at,
      if (counts != null) 'counts': counts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? realmId,
    Value<String>? promptVersion,
    Value<String>? language,
    Value<int>? at,
    Value<String>? counts,
    Value<int>? rowid,
  }) {
    return BatchesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      realmId: realmId ?? this.realmId,
      promptVersion: promptVersion ?? this.promptVersion,
      language: language ?? this.language,
      at: at ?? this.at,
      counts: counts ?? this.counts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (realmId.present) {
      map['realm_id'] = Variable<String>(realmId.value);
    }
    if (promptVersion.present) {
      map['prompt_version'] = Variable<String>(promptVersion.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (counts.present) {
      map['counts'] = Variable<String>(counts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatchesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('realmId: $realmId, ')
          ..write('promptVersion: $promptVersion, ')
          ..write('language: $language, ')
          ..write('at: $at, ')
          ..write('counts: $counts, ')
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
  late final $ItemsTable items = $ItemsTable(this);
  late final $SentencesTable sentences = $SentencesTable(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $SrsStatesTable srsStates = $SrsStatesTable(this);
  late final $QuestionStatsTable questionStats = $QuestionStatsTable(this);
  late final $HistoriesTable histories = $HistoriesTable(this);
  late final $BatchesTable batches = $BatchesTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    realms,
    items,
    sentences,
    questions,
    srsStates,
    questionStats,
    histories,
    batches,
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
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String phrase,
      required String normKeyValue,
      Value<String> type,
      Value<String> meaningNative,
      Value<int> priority,
      Value<double> confidence,
      Value<List<String>> relatedTerms,
      Value<List<String>> contexts,
      Value<List<String>> distractorsNative,
      Value<List<String>> realmIds,
      Value<bool> disabled,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> phrase,
      Value<String> normKeyValue,
      Value<String> type,
      Value<String> meaningNative,
      Value<int> priority,
      Value<double> confidence,
      Value<List<String>> relatedTerms,
      Value<List<String>> contexts,
      Value<List<String>> distractorsNative,
      Value<List<String>> realmIds,
      Value<bool> disabled,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
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

  ColumnFilters<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaningNative => $composableBuilder(
    column: $table.meaningNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get relatedTerms => $composableBuilder(
    column: $table.relatedTerms,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get contexts => $composableBuilder(
    column: $table.contexts,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get distractorsNative => $composableBuilder(
    column: $table.distractorsNative,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get realmIds => $composableBuilder(
    column: $table.realmIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
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

  ColumnOrderings<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaningNative => $composableBuilder(
    column: $table.meaningNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedTerms => $composableBuilder(
    column: $table.relatedTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contexts => $composableBuilder(
    column: $table.contexts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get distractorsNative => $composableBuilder(
    column: $table.distractorsNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmIds => $composableBuilder(
    column: $table.realmIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phrase =>
      $composableBuilder(column: $table.phrase, builder: (column) => column);

  GeneratedColumn<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get meaningNative => $composableBuilder(
    column: $table.meaningNative,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get relatedTerms =>
      $composableBuilder(
        column: $table.relatedTerms,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get contexts =>
      $composableBuilder(column: $table.contexts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String>
  get distractorsNative => $composableBuilder(
    column: $table.distractorsNative,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get realmIds =>
      $composableBuilder(column: $table.realmIds, builder: (column) => column);

  GeneratedColumn<bool> get disabled =>
      $composableBuilder(column: $table.disabled, builder: (column) => column);
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          ItemRow,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemRow, BaseReferences<_$AppDatabase, $ItemsTable, ItemRow>),
          ItemRow,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> phrase = const Value.absent(),
                Value<String> normKeyValue = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> meaningNative = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> relatedTerms = const Value.absent(),
                Value<List<String>> contexts = const Value.absent(),
                Value<List<String>> distractorsNative = const Value.absent(),
                Value<List<String>> realmIds = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                phrase: phrase,
                normKeyValue: normKeyValue,
                type: type,
                meaningNative: meaningNative,
                priority: priority,
                confidence: confidence,
                relatedTerms: relatedTerms,
                contexts: contexts,
                distractorsNative: distractorsNative,
                realmIds: realmIds,
                disabled: disabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String phrase,
                required String normKeyValue,
                Value<String> type = const Value.absent(),
                Value<String> meaningNative = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<List<String>> relatedTerms = const Value.absent(),
                Value<List<String>> contexts = const Value.absent(),
                Value<List<String>> distractorsNative = const Value.absent(),
                Value<List<String>> realmIds = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                phrase: phrase,
                normKeyValue: normKeyValue,
                type: type,
                meaningNative: meaningNative,
                priority: priority,
                confidence: confidence,
                relatedTerms: relatedTerms,
                contexts: contexts,
                distractorsNative: distractorsNative,
                realmIds: realmIds,
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

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      ItemRow,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemRow, BaseReferences<_$AppDatabase, $ItemsTable, ItemRow>),
      ItemRow,
      PrefetchHooks Function()
    >;
typedef $$SentencesTableCreateCompanionBuilder =
    SentencesCompanion Function({
      required String id,
      required String body,
      required String normKeyValue,
      Value<String> translationNative,
      Value<String> level,
      Value<String> context,
      Value<String> speechAct,
      Value<int> naturalness,
      Value<int?> quality,
      required String realmId,
      Value<List<String>> itemIds,
      Value<List<String>> meaningOptionsNative,
      Value<String> paraphraseEn,
      Value<List<String>> paraphraseOptionsEn,
      Value<String> cueEn,
      Value<String> cueTranslationNative,
      Value<List<String>> replyDistractorsEn,
      Value<String> registerSituationNative,
      Value<List<String>> registerOptionsEn,
      Value<List<String>> registerWhyNative,
      Value<int> registerCorrect,
      Value<bool> disabled,
      Value<int> rowid,
    });
typedef $$SentencesTableUpdateCompanionBuilder =
    SentencesCompanion Function({
      Value<String> id,
      Value<String> body,
      Value<String> normKeyValue,
      Value<String> translationNative,
      Value<String> level,
      Value<String> context,
      Value<String> speechAct,
      Value<int> naturalness,
      Value<int?> quality,
      Value<String> realmId,
      Value<List<String>> itemIds,
      Value<List<String>> meaningOptionsNative,
      Value<String> paraphraseEn,
      Value<List<String>> paraphraseOptionsEn,
      Value<String> cueEn,
      Value<String> cueTranslationNative,
      Value<List<String>> replyDistractorsEn,
      Value<String> registerSituationNative,
      Value<List<String>> registerOptionsEn,
      Value<List<String>> registerWhyNative,
      Value<int> registerCorrect,
      Value<bool> disabled,
      Value<int> rowid,
    });

class $$SentencesTableFilterComposer
    extends Composer<_$AppDatabase, $SentencesTable> {
  $$SentencesTableFilterComposer({
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speechAct => $composableBuilder(
    column: $table.speechAct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get naturalness => $composableBuilder(
    column: $table.naturalness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get itemIds => $composableBuilder(
    column: $table.itemIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get meaningOptionsNative => $composableBuilder(
    column: $table.meaningOptionsNative,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get paraphraseEn => $composableBuilder(
    column: $table.paraphraseEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get paraphraseOptionsEn => $composableBuilder(
    column: $table.paraphraseOptionsEn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get cueEn => $composableBuilder(
    column: $table.cueEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get replyDistractorsEn => $composableBuilder(
    column: $table.replyDistractorsEn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get registerSituationNative => $composableBuilder(
    column: $table.registerSituationNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get registerOptionsEn => $composableBuilder(
    column: $table.registerOptionsEn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get registerWhyNative => $composableBuilder(
    column: $table.registerWhyNative,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get registerCorrect => $composableBuilder(
    column: $table.registerCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SentencesTableOrderingComposer
    extends Composer<_$AppDatabase, $SentencesTable> {
  $$SentencesTableOrderingComposer({
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speechAct => $composableBuilder(
    column: $table.speechAct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get naturalness => $composableBuilder(
    column: $table.naturalness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemIds => $composableBuilder(
    column: $table.itemIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaningOptionsNative => $composableBuilder(
    column: $table.meaningOptionsNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paraphraseEn => $composableBuilder(
    column: $table.paraphraseEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paraphraseOptionsEn => $composableBuilder(
    column: $table.paraphraseOptionsEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cueEn => $composableBuilder(
    column: $table.cueEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyDistractorsEn => $composableBuilder(
    column: $table.replyDistractorsEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerSituationNative => $composableBuilder(
    column: $table.registerSituationNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerOptionsEn => $composableBuilder(
    column: $table.registerOptionsEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerWhyNative => $composableBuilder(
    column: $table.registerWhyNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get registerCorrect => $composableBuilder(
    column: $table.registerCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentencesTable> {
  $$SentencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get normKeyValue => $composableBuilder(
    column: $table.normKeyValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get speechAct =>
      $composableBuilder(column: $table.speechAct, builder: (column) => column);

  GeneratedColumn<int> get naturalness => $composableBuilder(
    column: $table.naturalness,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get realmId =>
      $composableBuilder(column: $table.realmId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get itemIds =>
      $composableBuilder(column: $table.itemIds, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String>
  get meaningOptionsNative => $composableBuilder(
    column: $table.meaningOptionsNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paraphraseEn => $composableBuilder(
    column: $table.paraphraseEn,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get paraphraseOptionsEn => $composableBuilder(
    column: $table.paraphraseOptionsEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cueEn =>
      $composableBuilder(column: $table.cueEn, builder: (column) => column);

  GeneratedColumn<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get replyDistractorsEn => $composableBuilder(
    column: $table.replyDistractorsEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registerSituationNative => $composableBuilder(
    column: $table.registerSituationNative,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get registerOptionsEn => $composableBuilder(
    column: $table.registerOptionsEn,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get registerWhyNative => $composableBuilder(
    column: $table.registerWhyNative,
    builder: (column) => column,
  );

  GeneratedColumn<int> get registerCorrect => $composableBuilder(
    column: $table.registerCorrect,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get disabled =>
      $composableBuilder(column: $table.disabled, builder: (column) => column);
}

class $$SentencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SentencesTable,
          SentenceRow,
          $$SentencesTableFilterComposer,
          $$SentencesTableOrderingComposer,
          $$SentencesTableAnnotationComposer,
          $$SentencesTableCreateCompanionBuilder,
          $$SentencesTableUpdateCompanionBuilder,
          (
            SentenceRow,
            BaseReferences<_$AppDatabase, $SentencesTable, SentenceRow>,
          ),
          SentenceRow,
          PrefetchHooks Function()
        > {
  $$SentencesTableTableManager(_$AppDatabase db, $SentencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> normKeyValue = const Value.absent(),
                Value<String> translationNative = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> speechAct = const Value.absent(),
                Value<int> naturalness = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String> realmId = const Value.absent(),
                Value<List<String>> itemIds = const Value.absent(),
                Value<List<String>> meaningOptionsNative = const Value.absent(),
                Value<String> paraphraseEn = const Value.absent(),
                Value<List<String>> paraphraseOptionsEn = const Value.absent(),
                Value<String> cueEn = const Value.absent(),
                Value<String> cueTranslationNative = const Value.absent(),
                Value<List<String>> replyDistractorsEn = const Value.absent(),
                Value<String> registerSituationNative = const Value.absent(),
                Value<List<String>> registerOptionsEn = const Value.absent(),
                Value<List<String>> registerWhyNative = const Value.absent(),
                Value<int> registerCorrect = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SentencesCompanion(
                id: id,
                body: body,
                normKeyValue: normKeyValue,
                translationNative: translationNative,
                level: level,
                context: context,
                speechAct: speechAct,
                naturalness: naturalness,
                quality: quality,
                realmId: realmId,
                itemIds: itemIds,
                meaningOptionsNative: meaningOptionsNative,
                paraphraseEn: paraphraseEn,
                paraphraseOptionsEn: paraphraseOptionsEn,
                cueEn: cueEn,
                cueTranslationNative: cueTranslationNative,
                replyDistractorsEn: replyDistractorsEn,
                registerSituationNative: registerSituationNative,
                registerOptionsEn: registerOptionsEn,
                registerWhyNative: registerWhyNative,
                registerCorrect: registerCorrect,
                disabled: disabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String body,
                required String normKeyValue,
                Value<String> translationNative = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> speechAct = const Value.absent(),
                Value<int> naturalness = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                required String realmId,
                Value<List<String>> itemIds = const Value.absent(),
                Value<List<String>> meaningOptionsNative = const Value.absent(),
                Value<String> paraphraseEn = const Value.absent(),
                Value<List<String>> paraphraseOptionsEn = const Value.absent(),
                Value<String> cueEn = const Value.absent(),
                Value<String> cueTranslationNative = const Value.absent(),
                Value<List<String>> replyDistractorsEn = const Value.absent(),
                Value<String> registerSituationNative = const Value.absent(),
                Value<List<String>> registerOptionsEn = const Value.absent(),
                Value<List<String>> registerWhyNative = const Value.absent(),
                Value<int> registerCorrect = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SentencesCompanion.insert(
                id: id,
                body: body,
                normKeyValue: normKeyValue,
                translationNative: translationNative,
                level: level,
                context: context,
                speechAct: speechAct,
                naturalness: naturalness,
                quality: quality,
                realmId: realmId,
                itemIds: itemIds,
                meaningOptionsNative: meaningOptionsNative,
                paraphraseEn: paraphraseEn,
                paraphraseOptionsEn: paraphraseOptionsEn,
                cueEn: cueEn,
                cueTranslationNative: cueTranslationNative,
                replyDistractorsEn: replyDistractorsEn,
                registerSituationNative: registerSituationNative,
                registerOptionsEn: registerOptionsEn,
                registerWhyNative: registerWhyNative,
                registerCorrect: registerCorrect,
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

typedef $$SentencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SentencesTable,
      SentenceRow,
      $$SentencesTableFilterComposer,
      $$SentencesTableOrderingComposer,
      $$SentencesTableAnnotationComposer,
      $$SentencesTableCreateCompanionBuilder,
      $$SentencesTableUpdateCompanionBuilder,
      (
        SentenceRow,
        BaseReferences<_$AppDatabase, $SentencesTable, SentenceRow>,
      ),
      SentenceRow,
      PrefetchHooks Function()
    >;
typedef $$QuestionsTableCreateCompanionBuilder =
    QuestionsCompanion Function({
      required String id,
      required String type,
      required String sentenceId,
      required String realmId,
      Value<String?> itemId,
      required String body,
      Value<String> translationNative,
      Value<String> level,
      Value<String> context,
      Value<List<String>> options,
      Value<int> correct,
      Value<String> before,
      Value<String> after,
      Value<List<String>> answerWords,
      Value<List<String>> bankPool,
      Value<List<String>> tokens,
      Value<String> finalPunct,
      Value<String> cueText,
      Value<String> cueTranslationNative,
      Value<String> note,
      Value<String> answerText,
      Value<bool> disabled,
      Value<int> rowid,
    });
typedef $$QuestionsTableUpdateCompanionBuilder =
    QuestionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> sentenceId,
      Value<String> realmId,
      Value<String?> itemId,
      Value<String> body,
      Value<String> translationNative,
      Value<String> level,
      Value<String> context,
      Value<List<String>> options,
      Value<int> correct,
      Value<String> before,
      Value<String> after,
      Value<List<String>> answerWords,
      Value<List<String>> bankPool,
      Value<List<String>> tokens,
      Value<String> finalPunct,
      Value<String> cueText,
      Value<String> cueTranslationNative,
      Value<String> note,
      Value<String> answerText,
      Value<bool> disabled,
      Value<int> rowid,
    });

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get answerWords => $composableBuilder(
    column: $table.answerWords,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get bankPool => $composableBuilder(
    column: $table.bankPool,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get finalPunct => $composableBuilder(
    column: $table.finalPunct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cueText => $composableBuilder(
    column: $table.cueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerWords => $composableBuilder(
    column: $table.answerWords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankPool => $composableBuilder(
    column: $table.bankPool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalPunct => $composableBuilder(
    column: $table.finalPunct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cueText => $composableBuilder(
    column: $table.cueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disabled => $composableBuilder(
    column: $table.disabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get realmId =>
      $composableBuilder(column: $table.realmId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get translationNative => $composableBuilder(
    column: $table.translationNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get options =>
      $composableBuilder(column: $table.options, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<String> get before =>
      $composableBuilder(column: $table.before, builder: (column) => column);

  GeneratedColumn<String> get after =>
      $composableBuilder(column: $table.after, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get answerWords =>
      $composableBuilder(
        column: $table.answerWords,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get bankPool =>
      $composableBuilder(column: $table.bankPool, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tokens =>
      $composableBuilder(column: $table.tokens, builder: (column) => column);

  GeneratedColumn<String> get finalPunct => $composableBuilder(
    column: $table.finalPunct,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cueText =>
      $composableBuilder(column: $table.cueText, builder: (column) => column);

  GeneratedColumn<String> get cueTranslationNative => $composableBuilder(
    column: $table.cueTranslationNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get disabled =>
      $composableBuilder(column: $table.disabled, builder: (column) => column);
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          QuestionRow,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (
            QuestionRow,
            BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
          ),
          QuestionRow,
          PrefetchHooks Function()
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> sentenceId = const Value.absent(),
                Value<String> realmId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> translationNative = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<List<String>> options = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<String> before = const Value.absent(),
                Value<String> after = const Value.absent(),
                Value<List<String>> answerWords = const Value.absent(),
                Value<List<String>> bankPool = const Value.absent(),
                Value<List<String>> tokens = const Value.absent(),
                Value<String> finalPunct = const Value.absent(),
                Value<String> cueText = const Value.absent(),
                Value<String> cueTranslationNative = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> answerText = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                type: type,
                sentenceId: sentenceId,
                realmId: realmId,
                itemId: itemId,
                body: body,
                translationNative: translationNative,
                level: level,
                context: context,
                options: options,
                correct: correct,
                before: before,
                after: after,
                answerWords: answerWords,
                bankPool: bankPool,
                tokens: tokens,
                finalPunct: finalPunct,
                cueText: cueText,
                cueTranslationNative: cueTranslationNative,
                note: note,
                answerText: answerText,
                disabled: disabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String sentenceId,
                required String realmId,
                Value<String?> itemId = const Value.absent(),
                required String body,
                Value<String> translationNative = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<List<String>> options = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<String> before = const Value.absent(),
                Value<String> after = const Value.absent(),
                Value<List<String>> answerWords = const Value.absent(),
                Value<List<String>> bankPool = const Value.absent(),
                Value<List<String>> tokens = const Value.absent(),
                Value<String> finalPunct = const Value.absent(),
                Value<String> cueText = const Value.absent(),
                Value<String> cueTranslationNative = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> answerText = const Value.absent(),
                Value<bool> disabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion.insert(
                id: id,
                type: type,
                sentenceId: sentenceId,
                realmId: realmId,
                itemId: itemId,
                body: body,
                translationNative: translationNative,
                level: level,
                context: context,
                options: options,
                correct: correct,
                before: before,
                after: after,
                answerWords: answerWords,
                bankPool: bankPool,
                tokens: tokens,
                finalPunct: finalPunct,
                cueText: cueText,
                cueTranslationNative: cueTranslationNative,
                note: note,
                answerText: answerText,
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

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      QuestionRow,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (
        QuestionRow,
        BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
      ),
      QuestionRow,
      PrefetchHooks Function()
    >;
typedef $$SrsStatesTableCreateCompanionBuilder =
    SrsStatesCompanion Function({
      required String itemId,
      Value<int> box,
      required String due,
      Value<int> reps,
      Value<int> lapses,
      Value<String?> lastResult,
      Value<String?> lastSeen,
      Value<bool> introduced,
      Value<bool> heldByGate,
      Value<String?> lastSentenceId,
      Value<String> formats,
      Value<int> rowid,
    });
typedef $$SrsStatesTableUpdateCompanionBuilder =
    SrsStatesCompanion Function({
      Value<String> itemId,
      Value<int> box,
      Value<String> due,
      Value<int> reps,
      Value<int> lapses,
      Value<String?> lastResult,
      Value<String?> lastSeen,
      Value<bool> introduced,
      Value<bool> heldByGate,
      Value<String?> lastSentenceId,
      Value<String> formats,
      Value<int> rowid,
    });

class $$SrsStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get introduced => $composableBuilder(
    column: $table.introduced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get heldByGate => $composableBuilder(
    column: $table.heldByGate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSentenceId => $composableBuilder(
    column: $table.lastSentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formats => $composableBuilder(
    column: $table.formats,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SrsStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get introduced => $composableBuilder(
    column: $table.introduced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get heldByGate => $composableBuilder(
    column: $table.heldByGate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSentenceId => $composableBuilder(
    column: $table.lastSentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formats => $composableBuilder(
    column: $table.formats,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SrsStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get box =>
      $composableBuilder(column: $table.box, builder: (column) => column);

  GeneratedColumn<String> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get introduced => $composableBuilder(
    column: $table.introduced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get heldByGate => $composableBuilder(
    column: $table.heldByGate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSentenceId => $composableBuilder(
    column: $table.lastSentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formats =>
      $composableBuilder(column: $table.formats, builder: (column) => column);
}

class $$SrsStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SrsStatesTable,
          SrsRow,
          $$SrsStatesTableFilterComposer,
          $$SrsStatesTableOrderingComposer,
          $$SrsStatesTableAnnotationComposer,
          $$SrsStatesTableCreateCompanionBuilder,
          $$SrsStatesTableUpdateCompanionBuilder,
          (SrsRow, BaseReferences<_$AppDatabase, $SrsStatesTable, SrsRow>),
          SrsRow,
          PrefetchHooks Function()
        > {
  $$SrsStatesTableTableManager(_$AppDatabase db, $SrsStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SrsStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SrsStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SrsStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> box = const Value.absent(),
                Value<String> due = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                Value<String?> lastSeen = const Value.absent(),
                Value<bool> introduced = const Value.absent(),
                Value<bool> heldByGate = const Value.absent(),
                Value<String?> lastSentenceId = const Value.absent(),
                Value<String> formats = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SrsStatesCompanion(
                itemId: itemId,
                box: box,
                due: due,
                reps: reps,
                lapses: lapses,
                lastResult: lastResult,
                lastSeen: lastSeen,
                introduced: introduced,
                heldByGate: heldByGate,
                lastSentenceId: lastSentenceId,
                formats: formats,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<int> box = const Value.absent(),
                required String due,
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                Value<String?> lastSeen = const Value.absent(),
                Value<bool> introduced = const Value.absent(),
                Value<bool> heldByGate = const Value.absent(),
                Value<String?> lastSentenceId = const Value.absent(),
                Value<String> formats = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SrsStatesCompanion.insert(
                itemId: itemId,
                box: box,
                due: due,
                reps: reps,
                lapses: lapses,
                lastResult: lastResult,
                lastSeen: lastSeen,
                introduced: introduced,
                heldByGate: heldByGate,
                lastSentenceId: lastSentenceId,
                formats: formats,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SrsStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SrsStatesTable,
      SrsRow,
      $$SrsStatesTableFilterComposer,
      $$SrsStatesTableOrderingComposer,
      $$SrsStatesTableAnnotationComposer,
      $$SrsStatesTableCreateCompanionBuilder,
      $$SrsStatesTableUpdateCompanionBuilder,
      (SrsRow, BaseReferences<_$AppDatabase, $SrsStatesTable, SrsRow>),
      SrsRow,
      PrefetchHooks Function()
    >;
typedef $$QuestionStatsTableCreateCompanionBuilder =
    QuestionStatsCompanion Function({
      required String questionId,
      Value<int> n,
      Value<int> ok,
      Value<int> lastAt,
      Value<int> rowid,
    });
typedef $$QuestionStatsTableUpdateCompanionBuilder =
    QuestionStatsCompanion Function({
      Value<String> questionId,
      Value<int> n,
      Value<int> ok,
      Value<int> lastAt,
      Value<int> rowid,
    });

class $$QuestionStatsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionStatsTable> {
  $$QuestionStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAt => $composableBuilder(
    column: $table.lastAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestionStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionStatsTable> {
  $$QuestionStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAt => $composableBuilder(
    column: $table.lastAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionStatsTable> {
  $$QuestionStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get n =>
      $composableBuilder(column: $table.n, builder: (column) => column);

  GeneratedColumn<int> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<int> get lastAt =>
      $composableBuilder(column: $table.lastAt, builder: (column) => column);
}

class $$QuestionStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionStatsTable,
          QuestionStatRow,
          $$QuestionStatsTableFilterComposer,
          $$QuestionStatsTableOrderingComposer,
          $$QuestionStatsTableAnnotationComposer,
          $$QuestionStatsTableCreateCompanionBuilder,
          $$QuestionStatsTableUpdateCompanionBuilder,
          (
            QuestionStatRow,
            BaseReferences<_$AppDatabase, $QuestionStatsTable, QuestionStatRow>,
          ),
          QuestionStatRow,
          PrefetchHooks Function()
        > {
  $$QuestionStatsTableTableManager(_$AppDatabase db, $QuestionStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<int> n = const Value.absent(),
                Value<int> ok = const Value.absent(),
                Value<int> lastAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionStatsCompanion(
                questionId: questionId,
                n: n,
                ok: ok,
                lastAt: lastAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                Value<int> n = const Value.absent(),
                Value<int> ok = const Value.absent(),
                Value<int> lastAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionStatsCompanion.insert(
                questionId: questionId,
                n: n,
                ok: ok,
                lastAt: lastAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestionStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionStatsTable,
      QuestionStatRow,
      $$QuestionStatsTableFilterComposer,
      $$QuestionStatsTableOrderingComposer,
      $$QuestionStatsTableAnnotationComposer,
      $$QuestionStatsTableCreateCompanionBuilder,
      $$QuestionStatsTableUpdateCompanionBuilder,
      (
        QuestionStatRow,
        BaseReferences<_$AppDatabase, $QuestionStatsTable, QuestionStatRow>,
      ),
      QuestionStatRow,
      PrefetchHooks Function()
    >;
typedef $$HistoriesTableCreateCompanionBuilder =
    HistoriesCompanion Function({
      Value<int> id,
      required String day,
      required int at,
      required String questionId,
      Value<String?> itemId,
      required String realmId,
      required String type,
      required bool correct,
      required bool wasDue,
    });
typedef $$HistoriesTableUpdateCompanionBuilder =
    HistoriesCompanion Function({
      Value<int> id,
      Value<String> day,
      Value<int> at,
      Value<String> questionId,
      Value<String?> itemId,
      Value<String> realmId,
      Value<String> type,
      Value<bool> correct,
      Value<bool> wasDue,
    });

class $$HistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableFilterComposer({
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

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasDue => $composableBuilder(
    column: $table.wasDue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableOrderingComposer({
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

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasDue => $composableBuilder(
    column: $table.wasDue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get realmId =>
      $composableBuilder(column: $table.realmId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<bool> get wasDue =>
      $composableBuilder(column: $table.wasDue, builder: (column) => column);
}

class $$HistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoriesTable,
          HistoryRow,
          $$HistoriesTableFilterComposer,
          $$HistoriesTableOrderingComposer,
          $$HistoriesTableAnnotationComposer,
          $$HistoriesTableCreateCompanionBuilder,
          $$HistoriesTableUpdateCompanionBuilder,
          (
            HistoryRow,
            BaseReferences<_$AppDatabase, $HistoriesTable, HistoryRow>,
          ),
          HistoryRow,
          PrefetchHooks Function()
        > {
  $$HistoriesTableTableManager(_$AppDatabase db, $HistoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> realmId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<bool> wasDue = const Value.absent(),
              }) => HistoriesCompanion(
                id: id,
                day: day,
                at: at,
                questionId: questionId,
                itemId: itemId,
                realmId: realmId,
                type: type,
                correct: correct,
                wasDue: wasDue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String day,
                required int at,
                required String questionId,
                Value<String?> itemId = const Value.absent(),
                required String realmId,
                required String type,
                required bool correct,
                required bool wasDue,
              }) => HistoriesCompanion.insert(
                id: id,
                day: day,
                at: at,
                questionId: questionId,
                itemId: itemId,
                realmId: realmId,
                type: type,
                correct: correct,
                wasDue: wasDue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoriesTable,
      HistoryRow,
      $$HistoriesTableFilterComposer,
      $$HistoriesTableOrderingComposer,
      $$HistoriesTableAnnotationComposer,
      $$HistoriesTableCreateCompanionBuilder,
      $$HistoriesTableUpdateCompanionBuilder,
      (HistoryRow, BaseReferences<_$AppDatabase, $HistoriesTable, HistoryRow>),
      HistoryRow,
      PrefetchHooks Function()
    >;
typedef $$BatchesTableCreateCompanionBuilder =
    BatchesCompanion Function({
      required String id,
      required String kind,
      Value<String?> realmId,
      Value<String> promptVersion,
      Value<String> language,
      required int at,
      Value<String> counts,
      Value<int> rowid,
    });
typedef $$BatchesTableUpdateCompanionBuilder =
    BatchesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String?> realmId,
      Value<String> promptVersion,
      Value<String> language,
      Value<int> at,
      Value<String> counts,
      Value<int> rowid,
    });

class $$BatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counts => $composableBuilder(
    column: $table.counts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get realmId => $composableBuilder(
    column: $table.realmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counts => $composableBuilder(
    column: $table.counts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get realmId =>
      $composableBuilder(column: $table.realmId, builder: (column) => column);

  GeneratedColumn<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get counts =>
      $composableBuilder(column: $table.counts, builder: (column) => column);
}

class $$BatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BatchesTable,
          BatchRow,
          $$BatchesTableFilterComposer,
          $$BatchesTableOrderingComposer,
          $$BatchesTableAnnotationComposer,
          $$BatchesTableCreateCompanionBuilder,
          $$BatchesTableUpdateCompanionBuilder,
          (BatchRow, BaseReferences<_$AppDatabase, $BatchesTable, BatchRow>),
          BatchRow,
          PrefetchHooks Function()
        > {
  $$BatchesTableTableManager(_$AppDatabase db, $BatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> realmId = const Value.absent(),
                Value<String> promptVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> counts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BatchesCompanion(
                id: id,
                kind: kind,
                realmId: realmId,
                promptVersion: promptVersion,
                language: language,
                at: at,
                counts: counts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> realmId = const Value.absent(),
                Value<String> promptVersion = const Value.absent(),
                Value<String> language = const Value.absent(),
                required int at,
                Value<String> counts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BatchesCompanion.insert(
                id: id,
                kind: kind,
                realmId: realmId,
                promptVersion: promptVersion,
                language: language,
                at: at,
                counts: counts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BatchesTable,
      BatchRow,
      $$BatchesTableFilterComposer,
      $$BatchesTableOrderingComposer,
      $$BatchesTableAnnotationComposer,
      $$BatchesTableCreateCompanionBuilder,
      $$BatchesTableUpdateCompanionBuilder,
      (BatchRow, BaseReferences<_$AppDatabase, $BatchesTable, BatchRow>),
      BatchRow,
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
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$SentencesTableTableManager get sentences =>
      $$SentencesTableTableManager(_db, _db.sentences);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$SrsStatesTableTableManager get srsStates =>
      $$SrsStatesTableTableManager(_db, _db.srsStates);
  $$QuestionStatsTableTableManager get questionStats =>
      $$QuestionStatsTableTableManager(_db, _db.questionStats);
  $$HistoriesTableTableManager get histories =>
      $$HistoriesTableTableManager(_db, _db.histories);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db, _db.batches);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
