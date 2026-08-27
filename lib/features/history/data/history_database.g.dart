// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_database.dart';

// ignore_for_file: type=lint
class $HistoryEntriesTable extends HistoryEntries
    with TableInfo<$HistoryEntriesTable, HistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityKindMeta = const VerificationMeta(
    'activityKind',
  );
  @override
  late final GeneratedColumn<int> activityKind = GeneratedColumn<int>(
    'activity_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadKindMeta = const VerificationMeta(
    'payloadKind',
  );
  @override
  late final GeneratedColumn<int> payloadKind = GeneratedColumn<int>(
    'payload_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawPayloadMeta = const VerificationMeta(
    'rawPayload',
  );
  @override
  late final GeneratedColumn<String> rawPayload = GeneratedColumn<String>(
    'raw_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayHostMeta = const VerificationMeta(
    'displayHost',
  );
  @override
  late final GeneratedColumn<String> displayHost = GeneratedColumn<String>(
    'display_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isInHistoryMeta = const VerificationMeta(
    'isInHistory',
  );
  @override
  late final GeneratedColumn<bool> isInHistory = GeneratedColumn<bool>(
    'is_in_history',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_in_history" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _savedAtUtcMeta = const VerificationMeta(
    'savedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> savedAtUtc = GeneratedColumn<DateTime>(
    'saved_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verificationCodeMeta = const VerificationMeta(
    'verificationCode',
  );
  @override
  late final GeneratedColumn<String> verificationCode = GeneratedColumn<String>(
    'verification_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrableDomainMeta = const VerificationMeta(
    'registrableDomain',
  );
  @override
  late final GeneratedColumn<String> registrableDomain =
      GeneratedColumn<String>(
        'registrable_domain',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _qrPngBytesMeta = const VerificationMeta(
    'qrPngBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> qrPngBytes = GeneratedColumn<Uint8List>(
    'qr_png_bytes',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<int> source = GeneratedColumn<int>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityKind,
    payloadKind,
    rawPayload,
    displayHost,
    title,
    note,
    isInHistory,
    savedAtUtc,
    verificationCode,
    registrableDomain,
    qrPngBytes,
    source,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_kind')) {
      context.handle(
        _activityKindMeta,
        activityKind.isAcceptableOrUnknown(
          data['activity_kind']!,
          _activityKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityKindMeta);
    }
    if (data.containsKey('payload_kind')) {
      context.handle(
        _payloadKindMeta,
        payloadKind.isAcceptableOrUnknown(
          data['payload_kind']!,
          _payloadKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadKindMeta);
    }
    if (data.containsKey('raw_payload')) {
      context.handle(
        _rawPayloadMeta,
        rawPayload.isAcceptableOrUnknown(data['raw_payload']!, _rawPayloadMeta),
      );
    } else if (isInserting) {
      context.missing(_rawPayloadMeta);
    }
    if (data.containsKey('display_host')) {
      context.handle(
        _displayHostMeta,
        displayHost.isAcceptableOrUnknown(
          data['display_host']!,
          _displayHostMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_in_history')) {
      context.handle(
        _isInHistoryMeta,
        isInHistory.isAcceptableOrUnknown(
          data['is_in_history']!,
          _isInHistoryMeta,
        ),
      );
    }
    if (data.containsKey('saved_at_utc')) {
      context.handle(
        _savedAtUtcMeta,
        savedAtUtc.isAcceptableOrUnknown(
          data['saved_at_utc']!,
          _savedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('verification_code')) {
      context.handle(
        _verificationCodeMeta,
        verificationCode.isAcceptableOrUnknown(
          data['verification_code']!,
          _verificationCodeMeta,
        ),
      );
    }
    if (data.containsKey('registrable_domain')) {
      context.handle(
        _registrableDomainMeta,
        registrableDomain.isAcceptableOrUnknown(
          data['registrable_domain']!,
          _registrableDomainMeta,
        ),
      );
    }
    if (data.containsKey('qr_png_bytes')) {
      context.handle(
        _qrPngBytesMeta,
        qrPngBytes.isAcceptableOrUnknown(
          data['qr_png_bytes']!,
          _qrPngBytesMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_kind'],
      )!,
      payloadKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_kind'],
      )!,
      rawPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_payload'],
      )!,
      displayHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_host'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isInHistory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_in_history'],
      )!,
      savedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at_utc'],
      ),
      verificationCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_code'],
      ),
      registrableDomain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registrable_domain'],
      ),
      qrPngBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}qr_png_bytes'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $HistoryEntriesTable createAlias(String alias) {
    return $HistoryEntriesTable(attachedDatabase, alias);
  }
}

class HistoryEntry extends DataClass implements Insertable<HistoryEntry> {
  final String id;
  final int activityKind;
  final int payloadKind;
  final String rawPayload;
  final String? displayHost;
  final String? title;
  final String? note;
  final bool isInHistory;
  final DateTime? savedAtUtc;
  final String? verificationCode;
  final String? registrableDomain;
  final Uint8List? qrPngBytes;
  final int source;
  final DateTime createdAtUtc;
  const HistoryEntry({
    required this.id,
    required this.activityKind,
    required this.payloadKind,
    required this.rawPayload,
    this.displayHost,
    this.title,
    this.note,
    required this.isInHistory,
    this.savedAtUtc,
    this.verificationCode,
    this.registrableDomain,
    this.qrPngBytes,
    required this.source,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_kind'] = Variable<int>(activityKind);
    map['payload_kind'] = Variable<int>(payloadKind);
    map['raw_payload'] = Variable<String>(rawPayload);
    if (!nullToAbsent || displayHost != null) {
      map['display_host'] = Variable<String>(displayHost);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_in_history'] = Variable<bool>(isInHistory);
    if (!nullToAbsent || savedAtUtc != null) {
      map['saved_at_utc'] = Variable<DateTime>(savedAtUtc);
    }
    if (!nullToAbsent || verificationCode != null) {
      map['verification_code'] = Variable<String>(verificationCode);
    }
    if (!nullToAbsent || registrableDomain != null) {
      map['registrable_domain'] = Variable<String>(registrableDomain);
    }
    if (!nullToAbsent || qrPngBytes != null) {
      map['qr_png_bytes'] = Variable<Uint8List>(qrPngBytes);
    }
    map['source'] = Variable<int>(source);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  HistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return HistoryEntriesCompanion(
      id: Value(id),
      activityKind: Value(activityKind),
      payloadKind: Value(payloadKind),
      rawPayload: Value(rawPayload),
      displayHost: displayHost == null && nullToAbsent
          ? const Value.absent()
          : Value(displayHost),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isInHistory: Value(isInHistory),
      savedAtUtc: savedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(savedAtUtc),
      verificationCode: verificationCode == null && nullToAbsent
          ? const Value.absent()
          : Value(verificationCode),
      registrableDomain: registrableDomain == null && nullToAbsent
          ? const Value.absent()
          : Value(registrableDomain),
      qrPngBytes: qrPngBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(qrPngBytes),
      source: Value(source),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory HistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEntry(
      id: serializer.fromJson<String>(json['id']),
      activityKind: serializer.fromJson<int>(json['activityKind']),
      payloadKind: serializer.fromJson<int>(json['payloadKind']),
      rawPayload: serializer.fromJson<String>(json['rawPayload']),
      displayHost: serializer.fromJson<String?>(json['displayHost']),
      title: serializer.fromJson<String?>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      isInHistory: serializer.fromJson<bool>(json['isInHistory']),
      savedAtUtc: serializer.fromJson<DateTime?>(json['savedAtUtc']),
      verificationCode: serializer.fromJson<String?>(json['verificationCode']),
      registrableDomain: serializer.fromJson<String?>(
        json['registrableDomain'],
      ),
      qrPngBytes: serializer.fromJson<Uint8List?>(json['qrPngBytes']),
      source: serializer.fromJson<int>(json['source']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityKind': serializer.toJson<int>(activityKind),
      'payloadKind': serializer.toJson<int>(payloadKind),
      'rawPayload': serializer.toJson<String>(rawPayload),
      'displayHost': serializer.toJson<String?>(displayHost),
      'title': serializer.toJson<String?>(title),
      'note': serializer.toJson<String?>(note),
      'isInHistory': serializer.toJson<bool>(isInHistory),
      'savedAtUtc': serializer.toJson<DateTime?>(savedAtUtc),
      'verificationCode': serializer.toJson<String?>(verificationCode),
      'registrableDomain': serializer.toJson<String?>(registrableDomain),
      'qrPngBytes': serializer.toJson<Uint8List?>(qrPngBytes),
      'source': serializer.toJson<int>(source),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  HistoryEntry copyWith({
    String? id,
    int? activityKind,
    int? payloadKind,
    String? rawPayload,
    Value<String?> displayHost = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isInHistory,
    Value<DateTime?> savedAtUtc = const Value.absent(),
    Value<String?> verificationCode = const Value.absent(),
    Value<String?> registrableDomain = const Value.absent(),
    Value<Uint8List?> qrPngBytes = const Value.absent(),
    int? source,
    DateTime? createdAtUtc,
  }) => HistoryEntry(
    id: id ?? this.id,
    activityKind: activityKind ?? this.activityKind,
    payloadKind: payloadKind ?? this.payloadKind,
    rawPayload: rawPayload ?? this.rawPayload,
    displayHost: displayHost.present ? displayHost.value : this.displayHost,
    title: title.present ? title.value : this.title,
    note: note.present ? note.value : this.note,
    isInHistory: isInHistory ?? this.isInHistory,
    savedAtUtc: savedAtUtc.present ? savedAtUtc.value : this.savedAtUtc,
    verificationCode: verificationCode.present
        ? verificationCode.value
        : this.verificationCode,
    registrableDomain: registrableDomain.present
        ? registrableDomain.value
        : this.registrableDomain,
    qrPngBytes: qrPngBytes.present ? qrPngBytes.value : this.qrPngBytes,
    source: source ?? this.source,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  HistoryEntry copyWithCompanion(HistoryEntriesCompanion data) {
    return HistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      activityKind: data.activityKind.present
          ? data.activityKind.value
          : this.activityKind,
      payloadKind: data.payloadKind.present
          ? data.payloadKind.value
          : this.payloadKind,
      rawPayload: data.rawPayload.present
          ? data.rawPayload.value
          : this.rawPayload,
      displayHost: data.displayHost.present
          ? data.displayHost.value
          : this.displayHost,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      isInHistory: data.isInHistory.present
          ? data.isInHistory.value
          : this.isInHistory,
      savedAtUtc: data.savedAtUtc.present
          ? data.savedAtUtc.value
          : this.savedAtUtc,
      verificationCode: data.verificationCode.present
          ? data.verificationCode.value
          : this.verificationCode,
      registrableDomain: data.registrableDomain.present
          ? data.registrableDomain.value
          : this.registrableDomain,
      qrPngBytes: data.qrPngBytes.present
          ? data.qrPngBytes.value
          : this.qrPngBytes,
      source: data.source.present ? data.source.value : this.source,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntry(')
          ..write('id: $id, ')
          ..write('activityKind: $activityKind, ')
          ..write('payloadKind: $payloadKind, ')
          ..write('rawPayload: $rawPayload, ')
          ..write('displayHost: $displayHost, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('isInHistory: $isInHistory, ')
          ..write('savedAtUtc: $savedAtUtc, ')
          ..write('verificationCode: $verificationCode, ')
          ..write('registrableDomain: $registrableDomain, ')
          ..write('qrPngBytes: $qrPngBytes, ')
          ..write('source: $source, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityKind,
    payloadKind,
    rawPayload,
    displayHost,
    title,
    note,
    isInHistory,
    savedAtUtc,
    verificationCode,
    registrableDomain,
    $driftBlobEquality.hash(qrPngBytes),
    source,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEntry &&
          other.id == this.id &&
          other.activityKind == this.activityKind &&
          other.payloadKind == this.payloadKind &&
          other.rawPayload == this.rawPayload &&
          other.displayHost == this.displayHost &&
          other.title == this.title &&
          other.note == this.note &&
          other.isInHistory == this.isInHistory &&
          other.savedAtUtc == this.savedAtUtc &&
          other.verificationCode == this.verificationCode &&
          other.registrableDomain == this.registrableDomain &&
          $driftBlobEquality.equals(other.qrPngBytes, this.qrPngBytes) &&
          other.source == this.source &&
          other.createdAtUtc == this.createdAtUtc);
}

class HistoryEntriesCompanion extends UpdateCompanion<HistoryEntry> {
  final Value<String> id;
  final Value<int> activityKind;
  final Value<int> payloadKind;
  final Value<String> rawPayload;
  final Value<String?> displayHost;
  final Value<String?> title;
  final Value<String?> note;
  final Value<bool> isInHistory;
  final Value<DateTime?> savedAtUtc;
  final Value<String?> verificationCode;
  final Value<String?> registrableDomain;
  final Value<Uint8List?> qrPngBytes;
  final Value<int> source;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const HistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.activityKind = const Value.absent(),
    this.payloadKind = const Value.absent(),
    this.rawPayload = const Value.absent(),
    this.displayHost = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.isInHistory = const Value.absent(),
    this.savedAtUtc = const Value.absent(),
    this.verificationCode = const Value.absent(),
    this.registrableDomain = const Value.absent(),
    this.qrPngBytes = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryEntriesCompanion.insert({
    required String id,
    required int activityKind,
    required int payloadKind,
    required String rawPayload,
    this.displayHost = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.isInHistory = const Value.absent(),
    this.savedAtUtc = const Value.absent(),
    this.verificationCode = const Value.absent(),
    this.registrableDomain = const Value.absent(),
    this.qrPngBytes = const Value.absent(),
    required int source,
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityKind = Value(activityKind),
       payloadKind = Value(payloadKind),
       rawPayload = Value(rawPayload),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<HistoryEntry> custom({
    Expression<String>? id,
    Expression<int>? activityKind,
    Expression<int>? payloadKind,
    Expression<String>? rawPayload,
    Expression<String>? displayHost,
    Expression<String>? title,
    Expression<String>? note,
    Expression<bool>? isInHistory,
    Expression<DateTime>? savedAtUtc,
    Expression<String>? verificationCode,
    Expression<String>? registrableDomain,
    Expression<Uint8List>? qrPngBytes,
    Expression<int>? source,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityKind != null) 'activity_kind': activityKind,
      if (payloadKind != null) 'payload_kind': payloadKind,
      if (rawPayload != null) 'raw_payload': rawPayload,
      if (displayHost != null) 'display_host': displayHost,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (isInHistory != null) 'is_in_history': isInHistory,
      if (savedAtUtc != null) 'saved_at_utc': savedAtUtc,
      if (verificationCode != null) 'verification_code': verificationCode,
      if (registrableDomain != null) 'registrable_domain': registrableDomain,
      if (qrPngBytes != null) 'qr_png_bytes': qrPngBytes,
      if (source != null) 'source': source,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? activityKind,
    Value<int>? payloadKind,
    Value<String>? rawPayload,
    Value<String?>? displayHost,
    Value<String?>? title,
    Value<String?>? note,
    Value<bool>? isInHistory,
    Value<DateTime?>? savedAtUtc,
    Value<String?>? verificationCode,
    Value<String?>? registrableDomain,
    Value<Uint8List?>? qrPngBytes,
    Value<int>? source,
    Value<DateTime>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return HistoryEntriesCompanion(
      id: id ?? this.id,
      activityKind: activityKind ?? this.activityKind,
      payloadKind: payloadKind ?? this.payloadKind,
      rawPayload: rawPayload ?? this.rawPayload,
      displayHost: displayHost ?? this.displayHost,
      title: title ?? this.title,
      note: note ?? this.note,
      isInHistory: isInHistory ?? this.isInHistory,
      savedAtUtc: savedAtUtc ?? this.savedAtUtc,
      verificationCode: verificationCode ?? this.verificationCode,
      registrableDomain: registrableDomain ?? this.registrableDomain,
      qrPngBytes: qrPngBytes ?? this.qrPngBytes,
      source: source ?? this.source,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityKind.present) {
      map['activity_kind'] = Variable<int>(activityKind.value);
    }
    if (payloadKind.present) {
      map['payload_kind'] = Variable<int>(payloadKind.value);
    }
    if (rawPayload.present) {
      map['raw_payload'] = Variable<String>(rawPayload.value);
    }
    if (displayHost.present) {
      map['display_host'] = Variable<String>(displayHost.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isInHistory.present) {
      map['is_in_history'] = Variable<bool>(isInHistory.value);
    }
    if (savedAtUtc.present) {
      map['saved_at_utc'] = Variable<DateTime>(savedAtUtc.value);
    }
    if (verificationCode.present) {
      map['verification_code'] = Variable<String>(verificationCode.value);
    }
    if (registrableDomain.present) {
      map['registrable_domain'] = Variable<String>(registrableDomain.value);
    }
    if (qrPngBytes.present) {
      map['qr_png_bytes'] = Variable<Uint8List>(qrPngBytes.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(source.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('activityKind: $activityKind, ')
          ..write('payloadKind: $payloadKind, ')
          ..write('rawPayload: $rawPayload, ')
          ..write('displayHost: $displayHost, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('isInHistory: $isInHistory, ')
          ..write('savedAtUtc: $savedAtUtc, ')
          ..write('verificationCode: $verificationCode, ')
          ..write('registrableDomain: $registrableDomain, ')
          ..write('qrPngBytes: $qrPngBytes, ')
          ..write('source: $source, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HistoryDatabase extends GeneratedDatabase {
  _$HistoryDatabase(QueryExecutor e) : super(e);
  $HistoryDatabaseManager get managers => $HistoryDatabaseManager(this);
  late final $HistoryEntriesTable historyEntries = $HistoryEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [historyEntries];
}

typedef $$HistoryEntriesTableCreateCompanionBuilder =
    HistoryEntriesCompanion Function({
      required String id,
      required int activityKind,
      required int payloadKind,
      required String rawPayload,
      Value<String?> displayHost,
      Value<String?> title,
      Value<String?> note,
      Value<bool> isInHistory,
      Value<DateTime?> savedAtUtc,
      Value<String?> verificationCode,
      Value<String?> registrableDomain,
      Value<Uint8List?> qrPngBytes,
      required int source,
      required DateTime createdAtUtc,
      Value<int> rowid,
    });
typedef $$HistoryEntriesTableUpdateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<String> id,
      Value<int> activityKind,
      Value<int> payloadKind,
      Value<String> rawPayload,
      Value<String?> displayHost,
      Value<String?> title,
      Value<String?> note,
      Value<bool> isInHistory,
      Value<DateTime?> savedAtUtc,
      Value<String?> verificationCode,
      Value<String?> registrableDomain,
      Value<Uint8List?> qrPngBytes,
      Value<int> source,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

class $$HistoryEntriesTableFilterComposer
    extends Composer<_$HistoryDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableFilterComposer({
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

  ColumnFilters<int> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadKind => $composableBuilder(
    column: $table.payloadKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayHost => $composableBuilder(
    column: $table.displayHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInHistory => $composableBuilder(
    column: $table.isInHistory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationCode => $composableBuilder(
    column: $table.verificationCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get qrPngBytes => $composableBuilder(
    column: $table.qrPngBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryEntriesTableOrderingComposer
    extends Composer<_$HistoryDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadKind => $composableBuilder(
    column: $table.payloadKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayHost => $composableBuilder(
    column: $table.displayHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInHistory => $composableBuilder(
    column: $table.isInHistory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationCode => $composableBuilder(
    column: $table.verificationCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get qrPngBytes => $composableBuilder(
    column: $table.qrPngBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryEntriesTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadKind => $composableBuilder(
    column: $table.payloadKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawPayload => $composableBuilder(
    column: $table.rawPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayHost => $composableBuilder(
    column: $table.displayHost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isInHistory => $composableBuilder(
    column: $table.isInHistory,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verificationCode => $composableBuilder(
    column: $table.verificationCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get qrPngBytes => $composableBuilder(
    column: $table.qrPngBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );
}

class $$HistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $HistoryEntriesTable,
          HistoryEntry,
          $$HistoryEntriesTableFilterComposer,
          $$HistoryEntriesTableOrderingComposer,
          $$HistoryEntriesTableAnnotationComposer,
          $$HistoryEntriesTableCreateCompanionBuilder,
          $$HistoryEntriesTableUpdateCompanionBuilder,
          (
            HistoryEntry,
            BaseReferences<
              _$HistoryDatabase,
              $HistoryEntriesTable,
              HistoryEntry
            >,
          ),
          HistoryEntry,
          PrefetchHooks Function()
        > {
  $$HistoryEntriesTableTableManager(
    _$HistoryDatabase db,
    $HistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> activityKind = const Value.absent(),
                Value<int> payloadKind = const Value.absent(),
                Value<String> rawPayload = const Value.absent(),
                Value<String?> displayHost = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isInHistory = const Value.absent(),
                Value<DateTime?> savedAtUtc = const Value.absent(),
                Value<String?> verificationCode = const Value.absent(),
                Value<String?> registrableDomain = const Value.absent(),
                Value<Uint8List?> qrPngBytes = const Value.absent(),
                Value<int> source = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryEntriesCompanion(
                id: id,
                activityKind: activityKind,
                payloadKind: payloadKind,
                rawPayload: rawPayload,
                displayHost: displayHost,
                title: title,
                note: note,
                isInHistory: isInHistory,
                savedAtUtc: savedAtUtc,
                verificationCode: verificationCode,
                registrableDomain: registrableDomain,
                qrPngBytes: qrPngBytes,
                source: source,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int activityKind,
                required int payloadKind,
                required String rawPayload,
                Value<String?> displayHost = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isInHistory = const Value.absent(),
                Value<DateTime?> savedAtUtc = const Value.absent(),
                Value<String?> verificationCode = const Value.absent(),
                Value<String?> registrableDomain = const Value.absent(),
                Value<Uint8List?> qrPngBytes = const Value.absent(),
                required int source,
                required DateTime createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => HistoryEntriesCompanion.insert(
                id: id,
                activityKind: activityKind,
                payloadKind: payloadKind,
                rawPayload: rawPayload,
                displayHost: displayHost,
                title: title,
                note: note,
                isInHistory: isInHistory,
                savedAtUtc: savedAtUtc,
                verificationCode: verificationCode,
                registrableDomain: registrableDomain,
                qrPngBytes: qrPngBytes,
                source: source,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $HistoryEntriesTable,
      HistoryEntry,
      $$HistoryEntriesTableFilterComposer,
      $$HistoryEntriesTableOrderingComposer,
      $$HistoryEntriesTableAnnotationComposer,
      $$HistoryEntriesTableCreateCompanionBuilder,
      $$HistoryEntriesTableUpdateCompanionBuilder,
      (
        HistoryEntry,
        BaseReferences<_$HistoryDatabase, $HistoryEntriesTable, HistoryEntry>,
      ),
      HistoryEntry,
      PrefetchHooks Function()
    >;

class $HistoryDatabaseManager {
  final _$HistoryDatabase _db;
  $HistoryDatabaseManager(this._db);
  $$HistoryEntriesTableTableManager get historyEntries =>
      $$HistoryEntriesTableTableManager(_db, _db.historyEntries);
}
