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
  static const VerificationMeta _codeFormatMeta = const VerificationMeta(
    'codeFormat',
  );
  @override
  late final GeneratedColumn<String> codeFormat = GeneratedColumn<String>(
    'code_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('qrCode'),
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
    codeFormat,
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
    if (data.containsKey('code_format')) {
      context.handle(
        _codeFormatMeta,
        codeFormat.isAcceptableOrUnknown(data['code_format']!, _codeFormatMeta),
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
      codeFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_format'],
      )!,
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
  final String codeFormat;
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
    required this.codeFormat,
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
    map['code_format'] = Variable<String>(codeFormat);
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
      codeFormat: Value(codeFormat),
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
      codeFormat: serializer.fromJson<String>(json['codeFormat']),
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
      'codeFormat': serializer.toJson<String>(codeFormat),
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
    String? codeFormat,
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
    codeFormat: codeFormat ?? this.codeFormat,
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
      codeFormat: data.codeFormat.present
          ? data.codeFormat.value
          : this.codeFormat,
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
          ..write('codeFormat: $codeFormat, ')
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
    codeFormat,
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
          other.codeFormat == this.codeFormat &&
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
  final Value<String> codeFormat;
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
    this.codeFormat = const Value.absent(),
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
    this.codeFormat = const Value.absent(),
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
    Expression<String>? codeFormat,
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
      if (codeFormat != null) 'code_format': codeFormat,
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
    Value<String>? codeFormat,
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
      codeFormat: codeFormat ?? this.codeFormat,
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
    if (codeFormat.present) {
      map['code_format'] = Variable<String>(codeFormat.value);
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
          ..write('codeFormat: $codeFormat, ')
          ..write('source: $source, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedCollectionsTable extends SavedCollections
    with TableInfo<$SavedCollectionsTable, SavedCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedCollectionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedCollectionRow> instance, {
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
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedCollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
    );
  }

  @override
  $SavedCollectionsTable createAlias(String alias) {
    return $SavedCollectionsTable(attachedDatabase, alias);
  }
}

class SavedCollectionRow extends DataClass
    implements Insertable<SavedCollectionRow> {
  final String id;
  final String name;
  final String normalizedName;
  const SavedCollectionRow({
    required this.id,
    required this.name,
    required this.normalizedName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    return map;
  }

  SavedCollectionsCompanion toCompanion(bool nullToAbsent) {
    return SavedCollectionsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
    );
  }

  factory SavedCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedCollectionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
    };
  }

  SavedCollectionRow copyWith({
    String? id,
    String? name,
    String? normalizedName,
  }) => SavedCollectionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
  );
  SavedCollectionRow copyWithCompanion(SavedCollectionsCompanion data) {
    return SavedCollectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedCollectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedCollectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName);
}

class SavedCollectionsCompanion extends UpdateCompanion<SavedCollectionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int> rowid;
  const SavedCollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedCollectionsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName);
  static Insertable<SavedCollectionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedCollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int>? rowid,
  }) {
    return SavedCollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
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
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedCollectionItemsTable extends SavedCollectionItems
    with TableInfo<$SavedCollectionItemsTable, SavedCollectionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedCollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES history_entries (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [collectionId, entryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedCollectionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, entryId};
  @override
  SavedCollectionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedCollectionItem(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
    );
  }

  @override
  $SavedCollectionItemsTable createAlias(String alias) {
    return $SavedCollectionItemsTable(attachedDatabase, alias);
  }
}

class SavedCollectionItem extends DataClass
    implements Insertable<SavedCollectionItem> {
  final String collectionId;
  final String entryId;
  const SavedCollectionItem({
    required this.collectionId,
    required this.entryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['entry_id'] = Variable<String>(entryId);
    return map;
  }

  SavedCollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return SavedCollectionItemsCompanion(
      collectionId: Value(collectionId),
      entryId: Value(entryId),
    );
  }

  factory SavedCollectionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedCollectionItem(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      entryId: serializer.fromJson<String>(json['entryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'entryId': serializer.toJson<String>(entryId),
    };
  }

  SavedCollectionItem copyWith({String? collectionId, String? entryId}) =>
      SavedCollectionItem(
        collectionId: collectionId ?? this.collectionId,
        entryId: entryId ?? this.entryId,
      );
  SavedCollectionItem copyWithCompanion(SavedCollectionItemsCompanion data) {
    return SavedCollectionItem(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedCollectionItem(')
          ..write('collectionId: $collectionId, ')
          ..write('entryId: $entryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, entryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedCollectionItem &&
          other.collectionId == this.collectionId &&
          other.entryId == this.entryId);
}

class SavedCollectionItemsCompanion
    extends UpdateCompanion<SavedCollectionItem> {
  final Value<String> collectionId;
  final Value<String> entryId;
  final Value<int> rowid;
  const SavedCollectionItemsCompanion({
    this.collectionId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedCollectionItemsCompanion.insert({
    required String collectionId,
    required String entryId,
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       entryId = Value(entryId);
  static Insertable<SavedCollectionItem> custom({
    Expression<String>? collectionId,
    Expression<String>? entryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (entryId != null) 'entry_id': entryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedCollectionItemsCompanion copyWith({
    Value<String>? collectionId,
    Value<String>? entryId,
    Value<int>? rowid,
  }) {
    return SavedCollectionItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      entryId: entryId ?? this.entryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedCollectionItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('entryId: $entryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedTagsTable extends SavedTags
    with TableInfo<$SavedTagsTable, SavedTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedTagsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedTag> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $SavedTagsTable createAlias(String alias) {
    return $SavedTagsTable(attachedDatabase, alias);
  }
}

class SavedTag extends DataClass implements Insertable<SavedTag> {
  final String id;
  final String name;
  const SavedTag({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  SavedTagsCompanion toCompanion(bool nullToAbsent) {
    return SavedTagsCompanion(id: Value(id), name: Value(name));
  }

  factory SavedTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedTag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  SavedTag copyWith({String? id, String? name}) =>
      SavedTag(id: id ?? this.id, name: name ?? this.name);
  SavedTag copyWithCompanion(SavedTagsCompanion data) {
    return SavedTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedTag(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedTag && other.id == this.id && other.name == this.name);
}

class SavedTagsCompanion extends UpdateCompanion<SavedTag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const SavedTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedTagsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SavedTag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return SavedTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedTagItemsTable extends SavedTagItems
    with TableInfo<$SavedTagItemsTable, SavedTagItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedTagItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES history_entries (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [tagId, entryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_tag_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedTagItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tagId, entryId};
  @override
  SavedTagItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedTagItem(
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
    );
  }

  @override
  $SavedTagItemsTable createAlias(String alias) {
    return $SavedTagItemsTable(attachedDatabase, alias);
  }
}

class SavedTagItem extends DataClass implements Insertable<SavedTagItem> {
  final String tagId;
  final String entryId;
  const SavedTagItem({required this.tagId, required this.entryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag_id'] = Variable<String>(tagId);
    map['entry_id'] = Variable<String>(entryId);
    return map;
  }

  SavedTagItemsCompanion toCompanion(bool nullToAbsent) {
    return SavedTagItemsCompanion(tagId: Value(tagId), entryId: Value(entryId));
  }

  factory SavedTagItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedTagItem(
      tagId: serializer.fromJson<String>(json['tagId']),
      entryId: serializer.fromJson<String>(json['entryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tagId': serializer.toJson<String>(tagId),
      'entryId': serializer.toJson<String>(entryId),
    };
  }

  SavedTagItem copyWith({String? tagId, String? entryId}) => SavedTagItem(
    tagId: tagId ?? this.tagId,
    entryId: entryId ?? this.entryId,
  );
  SavedTagItem copyWithCompanion(SavedTagItemsCompanion data) {
    return SavedTagItem(
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedTagItem(')
          ..write('tagId: $tagId, ')
          ..write('entryId: $entryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tagId, entryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedTagItem &&
          other.tagId == this.tagId &&
          other.entryId == this.entryId);
}

class SavedTagItemsCompanion extends UpdateCompanion<SavedTagItem> {
  final Value<String> tagId;
  final Value<String> entryId;
  final Value<int> rowid;
  const SavedTagItemsCompanion({
    this.tagId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedTagItemsCompanion.insert({
    required String tagId,
    required String entryId,
    this.rowid = const Value.absent(),
  }) : tagId = Value(tagId),
       entryId = Value(entryId);
  static Insertable<SavedTagItem> custom({
    Expression<String>? tagId,
    Expression<String>? entryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tagId != null) 'tag_id': tagId,
      if (entryId != null) 'entry_id': entryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedTagItemsCompanion copyWith({
    Value<String>? tagId,
    Value<String>? entryId,
    Value<int>? rowid,
  }) {
    return SavedTagItemsCompanion(
      tagId: tagId ?? this.tagId,
      entryId: entryId ?? this.entryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedTagItemsCompanion(')
          ..write('tagId: $tagId, ')
          ..write('entryId: $entryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HistoryDatabase extends GeneratedDatabase {
  _$HistoryDatabase(QueryExecutor e) : super(e);
  $HistoryDatabaseManager get managers => $HistoryDatabaseManager(this);
  late final $HistoryEntriesTable historyEntries = $HistoryEntriesTable(this);
  late final $SavedCollectionsTable savedCollections = $SavedCollectionsTable(
    this,
  );
  late final $SavedCollectionItemsTable savedCollectionItems =
      $SavedCollectionItemsTable(this);
  late final $SavedTagsTable savedTags = $SavedTagsTable(this);
  late final $SavedTagItemsTable savedTagItems = $SavedTagItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyEntries,
    savedCollections,
    savedCollectionItems,
    savedTags,
    savedTagItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_collection_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'history_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_collection_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_tag_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'history_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_tag_items', kind: UpdateKind.delete)],
    ),
  ]);
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
      Value<String> codeFormat,
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
      Value<String> codeFormat,
      Value<int> source,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

final class $$HistoryEntriesTableReferences
    extends
        BaseReferences<_$HistoryDatabase, $HistoryEntriesTable, HistoryEntry> {
  $$HistoryEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $SavedCollectionItemsTable,
    List<SavedCollectionItem>
  >
  _savedCollectionItemsRefsTable(_$HistoryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedCollectionItems,
        aliasName: 'history_entries__id__saved_collection_items__entry_id',
      );

  $$SavedCollectionItemsTableProcessedTableManager
  get savedCollectionItemsRefs {
    final manager = $$SavedCollectionItemsTableTableManager(
      $_db,
      $_db.savedCollectionItems,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedCollectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedTagItemsTable, List<SavedTagItem>>
  _savedTagItemsRefsTable(_$HistoryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedTagItems,
        aliasName: 'history_entries__id__saved_tag_items__entry_id',
      );

  $$SavedTagItemsTableProcessedTableManager get savedTagItemsRefs {
    final manager = $$SavedTagItemsTableTableManager(
      $_db,
      $_db.savedTagItems,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedTagItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  ColumnFilters<String> get codeFormat => $composableBuilder(
    column: $table.codeFormat,
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

  Expression<bool> savedCollectionItemsRefs(
    Expression<bool> Function($$SavedCollectionItemsTableFilterComposer f) f,
  ) {
    final $$SavedCollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedCollectionItems,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedCollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedCollectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedTagItemsRefs(
    Expression<bool> Function($$SavedTagItemsTableFilterComposer f) f,
  ) {
    final $$SavedTagItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedTagItems,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedTagItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  ColumnOrderings<String> get codeFormat => $composableBuilder(
    column: $table.codeFormat,
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

  GeneratedColumn<String> get codeFormat => $composableBuilder(
    column: $table.codeFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  Expression<T> savedCollectionItemsRefs<T extends Object>(
    Expression<T> Function($$SavedCollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedCollectionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedCollectionItems,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedCollectionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedCollectionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> savedTagItemsRefs<T extends Object>(
    Expression<T> Function($$SavedTagItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedTagItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedTagItems,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedTagItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (HistoryEntry, $$HistoryEntriesTableReferences),
          HistoryEntry,
          PrefetchHooks Function({
            bool savedCollectionItemsRefs,
            bool savedTagItemsRefs,
          })
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
                Value<String> codeFormat = const Value.absent(),
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
                codeFormat: codeFormat,
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
                Value<String> codeFormat = const Value.absent(),
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
                codeFormat: codeFormat,
                source: source,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HistoryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({savedCollectionItemsRefs = false, savedTagItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (savedCollectionItemsRefs) db.savedCollectionItems,
                    if (savedTagItemsRefs) db.savedTagItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (savedCollectionItemsRefs)
                        await $_getPrefetchedData<
                          HistoryEntry,
                          $HistoryEntriesTable,
                          SavedCollectionItem
                        >(
                          currentTable: table,
                          referencedTable: $$HistoryEntriesTableReferences
                              ._savedCollectionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HistoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).savedCollectionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedTagItemsRefs)
                        await $_getPrefetchedData<
                          HistoryEntry,
                          $HistoryEntriesTable,
                          SavedTagItem
                        >(
                          currentTable: table,
                          referencedTable: $$HistoryEntriesTableReferences
                              ._savedTagItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HistoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).savedTagItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
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
      (HistoryEntry, $$HistoryEntriesTableReferences),
      HistoryEntry,
      PrefetchHooks Function({
        bool savedCollectionItemsRefs,
        bool savedTagItemsRefs,
      })
    >;
typedef $$SavedCollectionsTableCreateCompanionBuilder =
    SavedCollectionsCompanion Function({
      required String id,
      required String name,
      required String normalizedName,
      Value<int> rowid,
    });
typedef $$SavedCollectionsTableUpdateCompanionBuilder =
    SavedCollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<int> rowid,
    });

final class $$SavedCollectionsTableReferences
    extends
        BaseReferences<
          _$HistoryDatabase,
          $SavedCollectionsTable,
          SavedCollectionRow
        > {
  $$SavedCollectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $SavedCollectionItemsTable,
    List<SavedCollectionItem>
  >
  _savedCollectionItemsRefsTable(_$HistoryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedCollectionItems,
        aliasName:
            'saved_collections__id__saved_collection_items__collection_id',
      );

  $$SavedCollectionItemsTableProcessedTableManager
  get savedCollectionItemsRefs {
    final manager = $$SavedCollectionItemsTableTableManager(
      $_db,
      $_db.savedCollectionItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedCollectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedCollectionsTableFilterComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionsTable> {
  $$SavedCollectionsTableFilterComposer({
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

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedCollectionItemsRefs(
    Expression<bool> Function($$SavedCollectionItemsTableFilterComposer f) f,
  ) {
    final $$SavedCollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedCollectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedCollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedCollectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedCollectionsTableOrderingComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionsTable> {
  $$SavedCollectionsTableOrderingComposer({
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

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedCollectionsTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionsTable> {
  $$SavedCollectionsTableAnnotationComposer({
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

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  Expression<T> savedCollectionItemsRefs<T extends Object>(
    Expression<T> Function($$SavedCollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedCollectionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedCollectionItems,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedCollectionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedCollectionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedCollectionsTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $SavedCollectionsTable,
          SavedCollectionRow,
          $$SavedCollectionsTableFilterComposer,
          $$SavedCollectionsTableOrderingComposer,
          $$SavedCollectionsTableAnnotationComposer,
          $$SavedCollectionsTableCreateCompanionBuilder,
          $$SavedCollectionsTableUpdateCompanionBuilder,
          (SavedCollectionRow, $$SavedCollectionsTableReferences),
          SavedCollectionRow,
          PrefetchHooks Function({bool savedCollectionItemsRefs})
        > {
  $$SavedCollectionsTableTableManager(
    _$HistoryDatabase db,
    $SavedCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedCollectionsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                Value<int> rowid = const Value.absent(),
              }) => SavedCollectionsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedCollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedCollectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedCollectionItemsRefs) db.savedCollectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedCollectionItemsRefs)
                    await $_getPrefetchedData<
                      SavedCollectionRow,
                      $SavedCollectionsTable,
                      SavedCollectionItem
                    >(
                      currentTable: table,
                      referencedTable: $$SavedCollectionsTableReferences
                          ._savedCollectionItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedCollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedCollectionItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $SavedCollectionsTable,
      SavedCollectionRow,
      $$SavedCollectionsTableFilterComposer,
      $$SavedCollectionsTableOrderingComposer,
      $$SavedCollectionsTableAnnotationComposer,
      $$SavedCollectionsTableCreateCompanionBuilder,
      $$SavedCollectionsTableUpdateCompanionBuilder,
      (SavedCollectionRow, $$SavedCollectionsTableReferences),
      SavedCollectionRow,
      PrefetchHooks Function({bool savedCollectionItemsRefs})
    >;
typedef $$SavedCollectionItemsTableCreateCompanionBuilder =
    SavedCollectionItemsCompanion Function({
      required String collectionId,
      required String entryId,
      Value<int> rowid,
    });
typedef $$SavedCollectionItemsTableUpdateCompanionBuilder =
    SavedCollectionItemsCompanion Function({
      Value<String> collectionId,
      Value<String> entryId,
      Value<int> rowid,
    });

final class $$SavedCollectionItemsTableReferences
    extends
        BaseReferences<
          _$HistoryDatabase,
          $SavedCollectionItemsTable,
          SavedCollectionItem
        > {
  $$SavedCollectionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedCollectionsTable _collectionIdTable(_$HistoryDatabase db) =>
      db.savedCollections.createAlias(
        'saved_collection_items__collection_id__saved_collections__id',
      );

  $$SavedCollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $$SavedCollectionsTableTableManager(
      $_db,
      $_db.savedCollections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $HistoryEntriesTable _entryIdTable(_$HistoryDatabase db) => db
      .historyEntries
      .createAlias('saved_collection_items__entry_id__history_entries__id');

  $$HistoryEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$HistoryEntriesTableTableManager(
      $_db,
      $_db.historyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedCollectionItemsTableFilterComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionItemsTable> {
  $$SavedCollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedCollectionsTableFilterComposer get collectionId {
    final $$SavedCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.savedCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.savedCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableFilterComposer get entryId {
    final $$HistoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedCollectionItemsTableOrderingComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionItemsTable> {
  $$SavedCollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedCollectionsTableOrderingComposer get collectionId {
    final $$SavedCollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.savedCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedCollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.savedCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableOrderingComposer get entryId {
    final $$HistoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedCollectionItemsTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $SavedCollectionItemsTable> {
  $$SavedCollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedCollectionsTableAnnotationComposer get collectionId {
    final $$SavedCollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.savedCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedCollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableAnnotationComposer get entryId {
    final $$HistoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedCollectionItemsTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $SavedCollectionItemsTable,
          SavedCollectionItem,
          $$SavedCollectionItemsTableFilterComposer,
          $$SavedCollectionItemsTableOrderingComposer,
          $$SavedCollectionItemsTableAnnotationComposer,
          $$SavedCollectionItemsTableCreateCompanionBuilder,
          $$SavedCollectionItemsTableUpdateCompanionBuilder,
          (SavedCollectionItem, $$SavedCollectionItemsTableReferences),
          SavedCollectionItem,
          PrefetchHooks Function({bool collectionId, bool entryId})
        > {
  $$SavedCollectionItemsTableTableManager(
    _$HistoryDatabase db,
    $SavedCollectionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedCollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedCollectionItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SavedCollectionItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collectionId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedCollectionItemsCompanion(
                collectionId: collectionId,
                entryId: entryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionId,
                required String entryId,
                Value<int> rowid = const Value.absent(),
              }) => SavedCollectionItemsCompanion.insert(
                collectionId: collectionId,
                entryId: entryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedCollectionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false, entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable:
                                    $$SavedCollectionItemsTableReferences
                                        ._collectionIdTable(db),
                                referencedColumn:
                                    $$SavedCollectionItemsTableReferences
                                        ._collectionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable:
                                    $$SavedCollectionItemsTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$SavedCollectionItemsTableReferences
                                        ._entryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedCollectionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $SavedCollectionItemsTable,
      SavedCollectionItem,
      $$SavedCollectionItemsTableFilterComposer,
      $$SavedCollectionItemsTableOrderingComposer,
      $$SavedCollectionItemsTableAnnotationComposer,
      $$SavedCollectionItemsTableCreateCompanionBuilder,
      $$SavedCollectionItemsTableUpdateCompanionBuilder,
      (SavedCollectionItem, $$SavedCollectionItemsTableReferences),
      SavedCollectionItem,
      PrefetchHooks Function({bool collectionId, bool entryId})
    >;
typedef $$SavedTagsTableCreateCompanionBuilder =
    SavedTagsCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $$SavedTagsTableUpdateCompanionBuilder =
    SavedTagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

final class $$SavedTagsTableReferences
    extends BaseReferences<_$HistoryDatabase, $SavedTagsTable, SavedTag> {
  $$SavedTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SavedTagItemsTable, List<SavedTagItem>>
  _savedTagItemsRefsTable(_$HistoryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedTagItems,
        aliasName: 'saved_tags__id__saved_tag_items__tag_id',
      );

  $$SavedTagItemsTableProcessedTableManager get savedTagItemsRefs {
    final manager = $$SavedTagItemsTableTableManager(
      $_db,
      $_db.savedTagItems,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedTagItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedTagsTableFilterComposer
    extends Composer<_$HistoryDatabase, $SavedTagsTable> {
  $$SavedTagsTableFilterComposer({
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

  Expression<bool> savedTagItemsRefs(
    Expression<bool> Function($$SavedTagItemsTableFilterComposer f) f,
  ) {
    final $$SavedTagItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedTagItems,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedTagItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedTagsTableOrderingComposer
    extends Composer<_$HistoryDatabase, $SavedTagsTable> {
  $$SavedTagsTableOrderingComposer({
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
}

class $$SavedTagsTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $SavedTagsTable> {
  $$SavedTagsTableAnnotationComposer({
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

  Expression<T> savedTagItemsRefs<T extends Object>(
    Expression<T> Function($$SavedTagItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedTagItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedTagItems,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedTagItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedTagsTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $SavedTagsTable,
          SavedTag,
          $$SavedTagsTableFilterComposer,
          $$SavedTagsTableOrderingComposer,
          $$SavedTagsTableAnnotationComposer,
          $$SavedTagsTableCreateCompanionBuilder,
          $$SavedTagsTableUpdateCompanionBuilder,
          (SavedTag, $$SavedTagsTableReferences),
          SavedTag,
          PrefetchHooks Function({bool savedTagItemsRefs})
        > {
  $$SavedTagsTableTableManager(_$HistoryDatabase db, $SavedTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedTagsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => SavedTagsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedTagItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedTagItemsRefs) db.savedTagItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedTagItemsRefs)
                    await $_getPrefetchedData<
                      SavedTag,
                      $SavedTagsTable,
                      SavedTagItem
                    >(
                      currentTable: table,
                      referencedTable: $$SavedTagsTableReferences
                          ._savedTagItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedTagsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedTagItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $SavedTagsTable,
      SavedTag,
      $$SavedTagsTableFilterComposer,
      $$SavedTagsTableOrderingComposer,
      $$SavedTagsTableAnnotationComposer,
      $$SavedTagsTableCreateCompanionBuilder,
      $$SavedTagsTableUpdateCompanionBuilder,
      (SavedTag, $$SavedTagsTableReferences),
      SavedTag,
      PrefetchHooks Function({bool savedTagItemsRefs})
    >;
typedef $$SavedTagItemsTableCreateCompanionBuilder =
    SavedTagItemsCompanion Function({
      required String tagId,
      required String entryId,
      Value<int> rowid,
    });
typedef $$SavedTagItemsTableUpdateCompanionBuilder =
    SavedTagItemsCompanion Function({
      Value<String> tagId,
      Value<String> entryId,
      Value<int> rowid,
    });

final class $$SavedTagItemsTableReferences
    extends
        BaseReferences<_$HistoryDatabase, $SavedTagItemsTable, SavedTagItem> {
  $$SavedTagItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedTagsTable _tagIdTable(_$HistoryDatabase db) =>
      db.savedTags.createAlias('saved_tag_items__tag_id__saved_tags__id');

  $$SavedTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$SavedTagsTableTableManager(
      $_db,
      $_db.savedTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $HistoryEntriesTable _entryIdTable(_$HistoryDatabase db) => db
      .historyEntries
      .createAlias('saved_tag_items__entry_id__history_entries__id');

  $$HistoryEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$HistoryEntriesTableTableManager(
      $_db,
      $_db.historyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedTagItemsTableFilterComposer
    extends Composer<_$HistoryDatabase, $SavedTagItemsTable> {
  $$SavedTagItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedTagsTableFilterComposer get tagId {
    final $$SavedTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.savedTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagsTableFilterComposer(
            $db: $db,
            $table: $db.savedTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableFilterComposer get entryId {
    final $$HistoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedTagItemsTableOrderingComposer
    extends Composer<_$HistoryDatabase, $SavedTagItemsTable> {
  $$SavedTagItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedTagsTableOrderingComposer get tagId {
    final $$SavedTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.savedTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagsTableOrderingComposer(
            $db: $db,
            $table: $db.savedTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableOrderingComposer get entryId {
    final $$HistoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedTagItemsTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $SavedTagItemsTable> {
  $$SavedTagItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedTagsTableAnnotationComposer get tagId {
    final $$SavedTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.savedTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HistoryEntriesTableAnnotationComposer get entryId {
    final $$HistoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.historyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.historyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedTagItemsTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $SavedTagItemsTable,
          SavedTagItem,
          $$SavedTagItemsTableFilterComposer,
          $$SavedTagItemsTableOrderingComposer,
          $$SavedTagItemsTableAnnotationComposer,
          $$SavedTagItemsTableCreateCompanionBuilder,
          $$SavedTagItemsTableUpdateCompanionBuilder,
          (SavedTagItem, $$SavedTagItemsTableReferences),
          SavedTagItem,
          PrefetchHooks Function({bool tagId, bool entryId})
        > {
  $$SavedTagItemsTableTableManager(
    _$HistoryDatabase db,
    $SavedTagItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedTagItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedTagItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedTagItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tagId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedTagItemsCompanion(
                tagId: tagId,
                entryId: entryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tagId,
                required String entryId,
                Value<int> rowid = const Value.absent(),
              }) => SavedTagItemsCompanion.insert(
                tagId: tagId,
                entryId: entryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedTagItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false, entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$SavedTagItemsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$SavedTagItemsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$SavedTagItemsTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$SavedTagItemsTableReferences
                                    ._entryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedTagItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $SavedTagItemsTable,
      SavedTagItem,
      $$SavedTagItemsTableFilterComposer,
      $$SavedTagItemsTableOrderingComposer,
      $$SavedTagItemsTableAnnotationComposer,
      $$SavedTagItemsTableCreateCompanionBuilder,
      $$SavedTagItemsTableUpdateCompanionBuilder,
      (SavedTagItem, $$SavedTagItemsTableReferences),
      SavedTagItem,
      PrefetchHooks Function({bool tagId, bool entryId})
    >;

class $HistoryDatabaseManager {
  final _$HistoryDatabase _db;
  $HistoryDatabaseManager(this._db);
  $$HistoryEntriesTableTableManager get historyEntries =>
      $$HistoryEntriesTableTableManager(_db, _db.historyEntries);
  $$SavedCollectionsTableTableManager get savedCollections =>
      $$SavedCollectionsTableTableManager(_db, _db.savedCollections);
  $$SavedCollectionItemsTableTableManager get savedCollectionItems =>
      $$SavedCollectionItemsTableTableManager(_db, _db.savedCollectionItems);
  $$SavedTagsTableTableManager get savedTags =>
      $$SavedTagsTableTableManager(_db, _db.savedTags);
  $$SavedTagItemsTableTableManager get savedTagItems =>
      $$SavedTagItemsTableTableManager(_db, _db.savedTagItems);
}
