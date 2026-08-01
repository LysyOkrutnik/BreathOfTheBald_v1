// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _levelKeyMeta =
      const VerificationMeta('levelKey');
  @override
  late final GeneratedColumn<String> levelKey = GeneratedColumn<String>(
      'level_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
      'duration_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
      'rounds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _retentionSecMeta =
      const VerificationMeta('retentionSec');
  @override
  late final GeneratedColumn<int> retentionSec = GeneratedColumn<int>(
      'retention_sec', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _xpEarnedMeta =
      const VerificationMeta('xpEarned');
  @override
  late final GeneratedColumn<int> xpEarned = GeneratedColumn<int>(
      'xp_earned', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _spo2MinMeta =
      const VerificationMeta('spo2Min');
  @override
  late final GeneratedColumn<int> spo2Min = GeneratedColumn<int>(
      'spo2_min', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _spo2AvgMeta =
      const VerificationMeta('spo2Avg');
  @override
  late final GeneratedColumn<int> spo2Avg = GeneratedColumn<int>(
      'spo2_avg', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _hrMinMeta = const VerificationMeta('hrMin');
  @override
  late final GeneratedColumn<int> hrMin = GeneratedColumn<int>(
      'hr_min', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _hrAvgMeta = const VerificationMeta('hrAvg');
  @override
  late final GeneratedColumn<int> hrAvg = GeneratedColumn<int>(
      'hr_avg', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        timestamp,
        levelKey,
        durationSec,
        rounds,
        retentionSec,
        xpEarned,
        spo2Min,
        spo2Avg,
        hrMin,
        hrAvg
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('level_key')) {
      context.handle(_levelKeyMeta,
          levelKey.isAcceptableOrUnknown(data['level_key']!, _levelKeyMeta));
    } else if (isInserting) {
      context.missing(_levelKeyMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('rounds')) {
      context.handle(_roundsMeta,
          rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta));
    } else if (isInserting) {
      context.missing(_roundsMeta);
    }
    if (data.containsKey('retention_sec')) {
      context.handle(
          _retentionSecMeta,
          retentionSec.isAcceptableOrUnknown(
              data['retention_sec']!, _retentionSecMeta));
    }
    if (data.containsKey('xp_earned')) {
      context.handle(_xpEarnedMeta,
          xpEarned.isAcceptableOrUnknown(data['xp_earned']!, _xpEarnedMeta));
    }
    if (data.containsKey('spo2_min')) {
      context.handle(_spo2MinMeta,
          spo2Min.isAcceptableOrUnknown(data['spo2_min']!, _spo2MinMeta));
    }
    if (data.containsKey('spo2_avg')) {
      context.handle(_spo2AvgMeta,
          spo2Avg.isAcceptableOrUnknown(data['spo2_avg']!, _spo2AvgMeta));
    }
    if (data.containsKey('hr_min')) {
      context.handle(
          _hrMinMeta, hrMin.isAcceptableOrUnknown(data['hr_min']!, _hrMinMeta));
    }
    if (data.containsKey('hr_avg')) {
      context.handle(
          _hrAvgMeta, hrAvg.isAcceptableOrUnknown(data['hr_avg']!, _hrAvgMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      levelKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level_key'])!,
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_sec'])!,
      rounds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rounds'])!,
      retentionSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retention_sec'])!,
      xpEarned: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp_earned'])!,
      spo2Min: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}spo2_min']),
      spo2Avg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}spo2_avg']),
      hrMin: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hr_min']),
      hrAvg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hr_avg']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final DateTime timestamp;

  /// Key of the [LevelData] exercise that was performed (e.g. 'mild', 'box').
  final String levelKey;

  /// Total wall-clock length of the session, in seconds.
  final int durationSec;
  final int rounds;

  /// Sum of all breath-hold (retention) durations across the session, in seconds.
  final int retentionSec;
  final int xpEarned;

  /// Blood-oxygen (SpO2 %) read from Health Connect during the session window;
  /// null when no wearable data was available.
  final int? spo2Min;
  final int? spo2Avg;

  /// Heart rate (bpm) read from Health Connect during the session window.
  final int? hrMin;
  final int? hrAvg;
  const Session(
      {required this.id,
      required this.timestamp,
      required this.levelKey,
      required this.durationSec,
      required this.rounds,
      required this.retentionSec,
      required this.xpEarned,
      this.spo2Min,
      this.spo2Avg,
      this.hrMin,
      this.hrAvg});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['level_key'] = Variable<String>(levelKey);
    map['duration_sec'] = Variable<int>(durationSec);
    map['rounds'] = Variable<int>(rounds);
    map['retention_sec'] = Variable<int>(retentionSec);
    map['xp_earned'] = Variable<int>(xpEarned);
    if (!nullToAbsent || spo2Min != null) {
      map['spo2_min'] = Variable<int>(spo2Min);
    }
    if (!nullToAbsent || spo2Avg != null) {
      map['spo2_avg'] = Variable<int>(spo2Avg);
    }
    if (!nullToAbsent || hrMin != null) {
      map['hr_min'] = Variable<int>(hrMin);
    }
    if (!nullToAbsent || hrAvg != null) {
      map['hr_avg'] = Variable<int>(hrAvg);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      levelKey: Value(levelKey),
      durationSec: Value(durationSec),
      rounds: Value(rounds),
      retentionSec: Value(retentionSec),
      xpEarned: Value(xpEarned),
      spo2Min: spo2Min == null && nullToAbsent
          ? const Value.absent()
          : Value(spo2Min),
      spo2Avg: spo2Avg == null && nullToAbsent
          ? const Value.absent()
          : Value(spo2Avg),
      hrMin:
          hrMin == null && nullToAbsent ? const Value.absent() : Value(hrMin),
      hrAvg:
          hrAvg == null && nullToAbsent ? const Value.absent() : Value(hrAvg),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      levelKey: serializer.fromJson<String>(json['levelKey']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      rounds: serializer.fromJson<int>(json['rounds']),
      retentionSec: serializer.fromJson<int>(json['retentionSec']),
      xpEarned: serializer.fromJson<int>(json['xpEarned']),
      spo2Min: serializer.fromJson<int?>(json['spo2Min']),
      spo2Avg: serializer.fromJson<int?>(json['spo2Avg']),
      hrMin: serializer.fromJson<int?>(json['hrMin']),
      hrAvg: serializer.fromJson<int?>(json['hrAvg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'levelKey': serializer.toJson<String>(levelKey),
      'durationSec': serializer.toJson<int>(durationSec),
      'rounds': serializer.toJson<int>(rounds),
      'retentionSec': serializer.toJson<int>(retentionSec),
      'xpEarned': serializer.toJson<int>(xpEarned),
      'spo2Min': serializer.toJson<int?>(spo2Min),
      'spo2Avg': serializer.toJson<int?>(spo2Avg),
      'hrMin': serializer.toJson<int?>(hrMin),
      'hrAvg': serializer.toJson<int?>(hrAvg),
    };
  }

  Session copyWith(
          {int? id,
          DateTime? timestamp,
          String? levelKey,
          int? durationSec,
          int? rounds,
          int? retentionSec,
          int? xpEarned,
          Value<int?> spo2Min = const Value.absent(),
          Value<int?> spo2Avg = const Value.absent(),
          Value<int?> hrMin = const Value.absent(),
          Value<int?> hrAvg = const Value.absent()}) =>
      Session(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        levelKey: levelKey ?? this.levelKey,
        durationSec: durationSec ?? this.durationSec,
        rounds: rounds ?? this.rounds,
        retentionSec: retentionSec ?? this.retentionSec,
        xpEarned: xpEarned ?? this.xpEarned,
        spo2Min: spo2Min.present ? spo2Min.value : this.spo2Min,
        spo2Avg: spo2Avg.present ? spo2Avg.value : this.spo2Avg,
        hrMin: hrMin.present ? hrMin.value : this.hrMin,
        hrAvg: hrAvg.present ? hrAvg.value : this.hrAvg,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      levelKey: data.levelKey.present ? data.levelKey.value : this.levelKey,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      retentionSec: data.retentionSec.present
          ? data.retentionSec.value
          : this.retentionSec,
      xpEarned: data.xpEarned.present ? data.xpEarned.value : this.xpEarned,
      spo2Min: data.spo2Min.present ? data.spo2Min.value : this.spo2Min,
      spo2Avg: data.spo2Avg.present ? data.spo2Avg.value : this.spo2Avg,
      hrMin: data.hrMin.present ? data.hrMin.value : this.hrMin,
      hrAvg: data.hrAvg.present ? data.hrAvg.value : this.hrAvg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('levelKey: $levelKey, ')
          ..write('durationSec: $durationSec, ')
          ..write('rounds: $rounds, ')
          ..write('retentionSec: $retentionSec, ')
          ..write('xpEarned: $xpEarned, ')
          ..write('spo2Min: $spo2Min, ')
          ..write('spo2Avg: $spo2Avg, ')
          ..write('hrMin: $hrMin, ')
          ..write('hrAvg: $hrAvg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp, levelKey, durationSec, rounds,
      retentionSec, xpEarned, spo2Min, spo2Avg, hrMin, hrAvg);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.levelKey == this.levelKey &&
          other.durationSec == this.durationSec &&
          other.rounds == this.rounds &&
          other.retentionSec == this.retentionSec &&
          other.xpEarned == this.xpEarned &&
          other.spo2Min == this.spo2Min &&
          other.spo2Avg == this.spo2Avg &&
          other.hrMin == this.hrMin &&
          other.hrAvg == this.hrAvg);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> levelKey;
  final Value<int> durationSec;
  final Value<int> rounds;
  final Value<int> retentionSec;
  final Value<int> xpEarned;
  final Value<int?> spo2Min;
  final Value<int?> spo2Avg;
  final Value<int?> hrMin;
  final Value<int?> hrAvg;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.levelKey = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.rounds = const Value.absent(),
    this.retentionSec = const Value.absent(),
    this.xpEarned = const Value.absent(),
    this.spo2Min = const Value.absent(),
    this.spo2Avg = const Value.absent(),
    this.hrMin = const Value.absent(),
    this.hrAvg = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String levelKey,
    required int durationSec,
    required int rounds,
    this.retentionSec = const Value.absent(),
    this.xpEarned = const Value.absent(),
    this.spo2Min = const Value.absent(),
    this.spo2Avg = const Value.absent(),
    this.hrMin = const Value.absent(),
    this.hrAvg = const Value.absent(),
  })  : timestamp = Value(timestamp),
        levelKey = Value(levelKey),
        durationSec = Value(durationSec),
        rounds = Value(rounds);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? levelKey,
    Expression<int>? durationSec,
    Expression<int>? rounds,
    Expression<int>? retentionSec,
    Expression<int>? xpEarned,
    Expression<int>? spo2Min,
    Expression<int>? spo2Avg,
    Expression<int>? hrMin,
    Expression<int>? hrAvg,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (levelKey != null) 'level_key': levelKey,
      if (durationSec != null) 'duration_sec': durationSec,
      if (rounds != null) 'rounds': rounds,
      if (retentionSec != null) 'retention_sec': retentionSec,
      if (xpEarned != null) 'xp_earned': xpEarned,
      if (spo2Min != null) 'spo2_min': spo2Min,
      if (spo2Avg != null) 'spo2_avg': spo2Avg,
      if (hrMin != null) 'hr_min': hrMin,
      if (hrAvg != null) 'hr_avg': hrAvg,
    });
  }

  SessionsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? timestamp,
      Value<String>? levelKey,
      Value<int>? durationSec,
      Value<int>? rounds,
      Value<int>? retentionSec,
      Value<int>? xpEarned,
      Value<int?>? spo2Min,
      Value<int?>? spo2Avg,
      Value<int?>? hrMin,
      Value<int?>? hrAvg}) {
    return SessionsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      levelKey: levelKey ?? this.levelKey,
      durationSec: durationSec ?? this.durationSec,
      rounds: rounds ?? this.rounds,
      retentionSec: retentionSec ?? this.retentionSec,
      xpEarned: xpEarned ?? this.xpEarned,
      spo2Min: spo2Min ?? this.spo2Min,
      spo2Avg: spo2Avg ?? this.spo2Avg,
      hrMin: hrMin ?? this.hrMin,
      hrAvg: hrAvg ?? this.hrAvg,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (levelKey.present) {
      map['level_key'] = Variable<String>(levelKey.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (retentionSec.present) {
      map['retention_sec'] = Variable<int>(retentionSec.value);
    }
    if (xpEarned.present) {
      map['xp_earned'] = Variable<int>(xpEarned.value);
    }
    if (spo2Min.present) {
      map['spo2_min'] = Variable<int>(spo2Min.value);
    }
    if (spo2Avg.present) {
      map['spo2_avg'] = Variable<int>(spo2Avg.value);
    }
    if (hrMin.present) {
      map['hr_min'] = Variable<int>(hrMin.value);
    }
    if (hrAvg.present) {
      map['hr_avg'] = Variable<int>(hrAvg.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('levelKey: $levelKey, ')
          ..write('durationSec: $durationSec, ')
          ..write('rounds: $rounds, ')
          ..write('retentionSec: $retentionSec, ')
          ..write('xpEarned: $xpEarned, ')
          ..write('spo2Min: $spo2Min, ')
          ..write('spo2Avg: $spo2Avg, ')
          ..write('hrMin: $hrMin, ')
          ..write('hrAvg: $hrAvg')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _totalXpMeta =
      const VerificationMeta('totalXp');
  @override
  late final GeneratedColumn<int> totalXp = GeneratedColumn<int>(
      'total_xp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _dailyStreakMeta =
      const VerificationMeta('dailyStreak');
  @override
  late final GeneratedColumn<int> dailyStreak = GeneratedColumn<int>(
      'daily_streak', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastSessionDateMeta =
      const VerificationMeta('lastSessionDate');
  @override
  late final GeneratedColumn<DateTime> lastSessionDate =
      GeneratedColumn<DateTime>('last_session_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, level, totalXp, dailyStreak, lastSessionDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('total_xp')) {
      context.handle(_totalXpMeta,
          totalXp.isAcceptableOrUnknown(data['total_xp']!, _totalXpMeta));
    }
    if (data.containsKey('daily_streak')) {
      context.handle(
          _dailyStreakMeta,
          dailyStreak.isAcceptableOrUnknown(
              data['daily_streak']!, _dailyStreakMeta));
    }
    if (data.containsKey('last_session_date')) {
      context.handle(
          _lastSessionDateMeta,
          lastSessionDate.isAcceptableOrUnknown(
              data['last_session_date']!, _lastSessionDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      totalXp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_xp'])!,
      dailyStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}daily_streak'])!,
      lastSessionDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_session_date']),
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final int id;
  final int level;
  final int totalXp;
  final int dailyStreak;
  final DateTime? lastSessionDate;
  const UserProfileData(
      {required this.id,
      required this.level,
      required this.totalXp,
      required this.dailyStreak,
      this.lastSessionDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['level'] = Variable<int>(level);
    map['total_xp'] = Variable<int>(totalXp);
    map['daily_streak'] = Variable<int>(dailyStreak);
    if (!nullToAbsent || lastSessionDate != null) {
      map['last_session_date'] = Variable<DateTime>(lastSessionDate);
    }
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      level: Value(level),
      totalXp: Value(totalXp),
      dailyStreak: Value(dailyStreak),
      lastSessionDate: lastSessionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSessionDate),
    );
  }

  factory UserProfileData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      id: serializer.fromJson<int>(json['id']),
      level: serializer.fromJson<int>(json['level']),
      totalXp: serializer.fromJson<int>(json['totalXp']),
      dailyStreak: serializer.fromJson<int>(json['dailyStreak']),
      lastSessionDate: serializer.fromJson<DateTime?>(json['lastSessionDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'level': serializer.toJson<int>(level),
      'totalXp': serializer.toJson<int>(totalXp),
      'dailyStreak': serializer.toJson<int>(dailyStreak),
      'lastSessionDate': serializer.toJson<DateTime?>(lastSessionDate),
    };
  }

  UserProfileData copyWith(
          {int? id,
          int? level,
          int? totalXp,
          int? dailyStreak,
          Value<DateTime?> lastSessionDate = const Value.absent()}) =>
      UserProfileData(
        id: id ?? this.id,
        level: level ?? this.level,
        totalXp: totalXp ?? this.totalXp,
        dailyStreak: dailyStreak ?? this.dailyStreak,
        lastSessionDate: lastSessionDate.present
            ? lastSessionDate.value
            : this.lastSessionDate,
      );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      totalXp: data.totalXp.present ? data.totalXp.value : this.totalXp,
      dailyStreak:
          data.dailyStreak.present ? data.dailyStreak.value : this.dailyStreak,
      lastSessionDate: data.lastSessionDate.present
          ? data.lastSessionDate.value
          : this.lastSessionDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('totalXp: $totalXp, ')
          ..write('dailyStreak: $dailyStreak, ')
          ..write('lastSessionDate: $lastSessionDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, level, totalXp, dailyStreak, lastSessionDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.id == this.id &&
          other.level == this.level &&
          other.totalXp == this.totalXp &&
          other.dailyStreak == this.dailyStreak &&
          other.lastSessionDate == this.lastSessionDate);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<int> id;
  final Value<int> level;
  final Value<int> totalXp;
  final Value<int> dailyStreak;
  final Value<DateTime?> lastSessionDate;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.totalXp = const Value.absent(),
    this.dailyStreak = const Value.absent(),
    this.lastSessionDate = const Value.absent(),
  });
  UserProfileCompanion.insert({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.totalXp = const Value.absent(),
    this.dailyStreak = const Value.absent(),
    this.lastSessionDate = const Value.absent(),
  });
  static Insertable<UserProfileData> custom({
    Expression<int>? id,
    Expression<int>? level,
    Expression<int>? totalXp,
    Expression<int>? dailyStreak,
    Expression<DateTime>? lastSessionDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (totalXp != null) 'total_xp': totalXp,
      if (dailyStreak != null) 'daily_streak': dailyStreak,
      if (lastSessionDate != null) 'last_session_date': lastSessionDate,
    });
  }

  UserProfileCompanion copyWith(
      {Value<int>? id,
      Value<int>? level,
      Value<int>? totalXp,
      Value<int>? dailyStreak,
      Value<DateTime?>? lastSessionDate}) {
    return UserProfileCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (totalXp.present) {
      map['total_xp'] = Variable<int>(totalXp.value);
    }
    if (dailyStreak.present) {
      map['daily_streak'] = Variable<int>(dailyStreak.value);
    }
    if (lastSessionDate.present) {
      map['last_session_date'] = Variable<DateTime>(lastSessionDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('totalXp: $totalXp, ')
          ..write('dailyStreak: $dailyStreak, ')
          ..write('lastSessionDate: $lastSessionDate')
          ..write(')'))
        .toString();
  }
}

class $HealthMetricsTable extends HealthMetrics
    with TableInfo<$HealthMetricsTable, HealthMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _co2ToleranceScoreMeta =
      const VerificationMeta('co2ToleranceScore');
  @override
  late final GeneratedColumn<int> co2ToleranceScore = GeneratedColumn<int>(
      'co2_tolerance_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _avgBreathsPerMinMeta =
      const VerificationMeta('avgBreathsPerMin');
  @override
  late final GeneratedColumn<int> avgBreathsPerMin = GeneratedColumn<int>(
      'avg_breaths_per_min', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, timestamp, co2ToleranceScore, avgBreathsPerMin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_metrics';
  @override
  VerificationContext validateIntegrity(Insertable<HealthMetric> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('co2_tolerance_score')) {
      context.handle(
          _co2ToleranceScoreMeta,
          co2ToleranceScore.isAcceptableOrUnknown(
              data['co2_tolerance_score']!, _co2ToleranceScoreMeta));
    }
    if (data.containsKey('avg_breaths_per_min')) {
      context.handle(
          _avgBreathsPerMinMeta,
          avgBreathsPerMin.isAcceptableOrUnknown(
              data['avg_breaths_per_min']!, _avgBreathsPerMinMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthMetric(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      co2ToleranceScore: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}co2_tolerance_score']),
      avgBreathsPerMin: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}avg_breaths_per_min']),
    );
  }

  @override
  $HealthMetricsTable createAlias(String alias) {
    return $HealthMetricsTable(attachedDatabase, alias);
  }
}

class HealthMetric extends DataClass implements Insertable<HealthMetric> {
  final int id;
  final DateTime timestamp;
  final int? co2ToleranceScore;
  final int? avgBreathsPerMin;
  const HealthMetric(
      {required this.id,
      required this.timestamp,
      this.co2ToleranceScore,
      this.avgBreathsPerMin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || co2ToleranceScore != null) {
      map['co2_tolerance_score'] = Variable<int>(co2ToleranceScore);
    }
    if (!nullToAbsent || avgBreathsPerMin != null) {
      map['avg_breaths_per_min'] = Variable<int>(avgBreathsPerMin);
    }
    return map;
  }

  HealthMetricsCompanion toCompanion(bool nullToAbsent) {
    return HealthMetricsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      co2ToleranceScore: co2ToleranceScore == null && nullToAbsent
          ? const Value.absent()
          : Value(co2ToleranceScore),
      avgBreathsPerMin: avgBreathsPerMin == null && nullToAbsent
          ? const Value.absent()
          : Value(avgBreathsPerMin),
    );
  }

  factory HealthMetric.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthMetric(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      co2ToleranceScore: serializer.fromJson<int?>(json['co2ToleranceScore']),
      avgBreathsPerMin: serializer.fromJson<int?>(json['avgBreathsPerMin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'co2ToleranceScore': serializer.toJson<int?>(co2ToleranceScore),
      'avgBreathsPerMin': serializer.toJson<int?>(avgBreathsPerMin),
    };
  }

  HealthMetric copyWith(
          {int? id,
          DateTime? timestamp,
          Value<int?> co2ToleranceScore = const Value.absent(),
          Value<int?> avgBreathsPerMin = const Value.absent()}) =>
      HealthMetric(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        co2ToleranceScore: co2ToleranceScore.present
            ? co2ToleranceScore.value
            : this.co2ToleranceScore,
        avgBreathsPerMin: avgBreathsPerMin.present
            ? avgBreathsPerMin.value
            : this.avgBreathsPerMin,
      );
  HealthMetric copyWithCompanion(HealthMetricsCompanion data) {
    return HealthMetric(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      co2ToleranceScore: data.co2ToleranceScore.present
          ? data.co2ToleranceScore.value
          : this.co2ToleranceScore,
      avgBreathsPerMin: data.avgBreathsPerMin.present
          ? data.avgBreathsPerMin.value
          : this.avgBreathsPerMin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthMetric(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('co2ToleranceScore: $co2ToleranceScore, ')
          ..write('avgBreathsPerMin: $avgBreathsPerMin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, co2ToleranceScore, avgBreathsPerMin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthMetric &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.co2ToleranceScore == this.co2ToleranceScore &&
          other.avgBreathsPerMin == this.avgBreathsPerMin);
}

class HealthMetricsCompanion extends UpdateCompanion<HealthMetric> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<int?> co2ToleranceScore;
  final Value<int?> avgBreathsPerMin;
  const HealthMetricsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.co2ToleranceScore = const Value.absent(),
    this.avgBreathsPerMin = const Value.absent(),
  });
  HealthMetricsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    this.co2ToleranceScore = const Value.absent(),
    this.avgBreathsPerMin = const Value.absent(),
  }) : timestamp = Value(timestamp);
  static Insertable<HealthMetric> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<int>? co2ToleranceScore,
    Expression<int>? avgBreathsPerMin,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (co2ToleranceScore != null) 'co2_tolerance_score': co2ToleranceScore,
      if (avgBreathsPerMin != null) 'avg_breaths_per_min': avgBreathsPerMin,
    });
  }

  HealthMetricsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? timestamp,
      Value<int?>? co2ToleranceScore,
      Value<int?>? avgBreathsPerMin}) {
    return HealthMetricsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      co2ToleranceScore: co2ToleranceScore ?? this.co2ToleranceScore,
      avgBreathsPerMin: avgBreathsPerMin ?? this.avgBreathsPerMin,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (co2ToleranceScore.present) {
      map['co2_tolerance_score'] = Variable<int>(co2ToleranceScore.value);
    }
    if (avgBreathsPerMin.present) {
      map['avg_breaths_per_min'] = Variable<int>(avgBreathsPerMin.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthMetricsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('co2ToleranceScore: $co2ToleranceScore, ')
          ..write('avgBreathsPerMin: $avgBreathsPerMin')
          ..write(')'))
        .toString();
  }
}

class $PlannedSessionsTable extends PlannedSessions
    with TableInfo<$PlannedSessionsTable, PlannedSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlannedSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _scheduledAtMeta =
      const VerificationMeta('scheduledAt');
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
      'scheduled_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _levelKeyMeta =
      const VerificationMeta('levelKey');
  @override
  late final GeneratedColumn<String> levelKey = GeneratedColumn<String>(
      'level_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, scheduledAt, levelKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planned_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<PlannedSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
          _scheduledAtMeta,
          scheduledAt.isAcceptableOrUnknown(
              data['scheduled_at']!, _scheduledAtMeta));
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('level_key')) {
      context.handle(_levelKeyMeta,
          levelKey.isAcceptableOrUnknown(data['level_key']!, _levelKeyMeta));
    } else if (isInserting) {
      context.missing(_levelKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlannedSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlannedSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      scheduledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_at'])!,
      levelKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level_key'])!,
    );
  }

  @override
  $PlannedSessionsTable createAlias(String alias) {
    return $PlannedSessionsTable(attachedDatabase, alias);
  }
}

class PlannedSession extends DataClass implements Insertable<PlannedSession> {
  final int id;

  /// The exact date and time the session is planned for.
  final DateTime scheduledAt;

  /// Key of the planned [LevelData] exercise.
  final String levelKey;
  const PlannedSession(
      {required this.id, required this.scheduledAt, required this.levelKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    map['level_key'] = Variable<String>(levelKey);
    return map;
  }

  PlannedSessionsCompanion toCompanion(bool nullToAbsent) {
    return PlannedSessionsCompanion(
      id: Value(id),
      scheduledAt: Value(scheduledAt),
      levelKey: Value(levelKey),
    );
  }

  factory PlannedSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlannedSession(
      id: serializer.fromJson<int>(json['id']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
      levelKey: serializer.fromJson<String>(json['levelKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
      'levelKey': serializer.toJson<String>(levelKey),
    };
  }

  PlannedSession copyWith({int? id, DateTime? scheduledAt, String? levelKey}) =>
      PlannedSession(
        id: id ?? this.id,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        levelKey: levelKey ?? this.levelKey,
      );
  PlannedSession copyWithCompanion(PlannedSessionsCompanion data) {
    return PlannedSession(
      id: data.id.present ? data.id.value : this.id,
      scheduledAt:
          data.scheduledAt.present ? data.scheduledAt.value : this.scheduledAt,
      levelKey: data.levelKey.present ? data.levelKey.value : this.levelKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlannedSession(')
          ..write('id: $id, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('levelKey: $levelKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scheduledAt, levelKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedSession &&
          other.id == this.id &&
          other.scheduledAt == this.scheduledAt &&
          other.levelKey == this.levelKey);
}

class PlannedSessionsCompanion extends UpdateCompanion<PlannedSession> {
  final Value<int> id;
  final Value<DateTime> scheduledAt;
  final Value<String> levelKey;
  const PlannedSessionsCompanion({
    this.id = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.levelKey = const Value.absent(),
  });
  PlannedSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime scheduledAt,
    required String levelKey,
  })  : scheduledAt = Value(scheduledAt),
        levelKey = Value(levelKey);
  static Insertable<PlannedSession> custom({
    Expression<int>? id,
    Expression<DateTime>? scheduledAt,
    Expression<String>? levelKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (levelKey != null) 'level_key': levelKey,
    });
  }

  PlannedSessionsCompanion copyWith(
      {Value<int>? id, Value<DateTime>? scheduledAt, Value<String>? levelKey}) {
    return PlannedSessionsCompanion(
      id: id ?? this.id,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      levelKey: levelKey ?? this.levelKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (levelKey.present) {
      map['level_key'] = Variable<String>(levelKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlannedSessionsCompanion(')
          ..write('id: $id, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('levelKey: $levelKey')
          ..write(')'))
        .toString();
  }
}

class $CustomPresetsTable extends CustomPresets
    with TableInfo<$CustomPresetsTable, CustomPreset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomPresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inhaleSecMeta =
      const VerificationMeta('inhaleSec');
  @override
  late final GeneratedColumn<int> inhaleSec = GeneratedColumn<int>(
      'inhale_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _holdInSecMeta =
      const VerificationMeta('holdInSec');
  @override
  late final GeneratedColumn<int> holdInSec = GeneratedColumn<int>(
      'hold_in_sec', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _exhaleSecMeta =
      const VerificationMeta('exhaleSec');
  @override
  late final GeneratedColumn<int> exhaleSec = GeneratedColumn<int>(
      'exhale_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _holdOutSecMeta =
      const VerificationMeta('holdOutSec');
  @override
  late final GeneratedColumn<int> holdOutSec = GeneratedColumn<int>(
      'hold_out_sec', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cyclesMeta = const VerificationMeta('cycles');
  @override
  late final GeneratedColumn<int> cycles = GeneratedColumn<int>(
      'cycles', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(8));
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
      'rounds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        inhaleSec,
        holdInSec,
        exhaleSec,
        holdOutSec,
        cycles,
        rounds,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_presets';
  @override
  VerificationContext validateIntegrity(Insertable<CustomPreset> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('inhale_sec')) {
      context.handle(_inhaleSecMeta,
          inhaleSec.isAcceptableOrUnknown(data['inhale_sec']!, _inhaleSecMeta));
    } else if (isInserting) {
      context.missing(_inhaleSecMeta);
    }
    if (data.containsKey('hold_in_sec')) {
      context.handle(
          _holdInSecMeta,
          holdInSec.isAcceptableOrUnknown(
              data['hold_in_sec']!, _holdInSecMeta));
    }
    if (data.containsKey('exhale_sec')) {
      context.handle(_exhaleSecMeta,
          exhaleSec.isAcceptableOrUnknown(data['exhale_sec']!, _exhaleSecMeta));
    } else if (isInserting) {
      context.missing(_exhaleSecMeta);
    }
    if (data.containsKey('hold_out_sec')) {
      context.handle(
          _holdOutSecMeta,
          holdOutSec.isAcceptableOrUnknown(
              data['hold_out_sec']!, _holdOutSecMeta));
    }
    if (data.containsKey('cycles')) {
      context.handle(_cyclesMeta,
          cycles.isAcceptableOrUnknown(data['cycles']!, _cyclesMeta));
    }
    if (data.containsKey('rounds')) {
      context.handle(_roundsMeta,
          rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomPreset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomPreset(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      inhaleSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}inhale_sec'])!,
      holdInSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hold_in_sec'])!,
      exhaleSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}exhale_sec'])!,
      holdOutSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hold_out_sec'])!,
      cycles: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cycles'])!,
      rounds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rounds'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CustomPresetsTable createAlias(String alias) {
    return $CustomPresetsTable(attachedDatabase, alias);
  }
}

class CustomPreset extends DataClass implements Insertable<CustomPreset> {
  final int id;
  final String name;
  final int inhaleSec;
  final int holdInSec;
  final int exhaleSec;
  final int holdOutSec;
  final int cycles;
  final int rounds;
  final DateTime createdAt;
  const CustomPreset(
      {required this.id,
      required this.name,
      required this.inhaleSec,
      required this.holdInSec,
      required this.exhaleSec,
      required this.holdOutSec,
      required this.cycles,
      required this.rounds,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['inhale_sec'] = Variable<int>(inhaleSec);
    map['hold_in_sec'] = Variable<int>(holdInSec);
    map['exhale_sec'] = Variable<int>(exhaleSec);
    map['hold_out_sec'] = Variable<int>(holdOutSec);
    map['cycles'] = Variable<int>(cycles);
    map['rounds'] = Variable<int>(rounds);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomPresetsCompanion toCompanion(bool nullToAbsent) {
    return CustomPresetsCompanion(
      id: Value(id),
      name: Value(name),
      inhaleSec: Value(inhaleSec),
      holdInSec: Value(holdInSec),
      exhaleSec: Value(exhaleSec),
      holdOutSec: Value(holdOutSec),
      cycles: Value(cycles),
      rounds: Value(rounds),
      createdAt: Value(createdAt),
    );
  }

  factory CustomPreset.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomPreset(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      inhaleSec: serializer.fromJson<int>(json['inhaleSec']),
      holdInSec: serializer.fromJson<int>(json['holdInSec']),
      exhaleSec: serializer.fromJson<int>(json['exhaleSec']),
      holdOutSec: serializer.fromJson<int>(json['holdOutSec']),
      cycles: serializer.fromJson<int>(json['cycles']),
      rounds: serializer.fromJson<int>(json['rounds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'inhaleSec': serializer.toJson<int>(inhaleSec),
      'holdInSec': serializer.toJson<int>(holdInSec),
      'exhaleSec': serializer.toJson<int>(exhaleSec),
      'holdOutSec': serializer.toJson<int>(holdOutSec),
      'cycles': serializer.toJson<int>(cycles),
      'rounds': serializer.toJson<int>(rounds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomPreset copyWith(
          {int? id,
          String? name,
          int? inhaleSec,
          int? holdInSec,
          int? exhaleSec,
          int? holdOutSec,
          int? cycles,
          int? rounds,
          DateTime? createdAt}) =>
      CustomPreset(
        id: id ?? this.id,
        name: name ?? this.name,
        inhaleSec: inhaleSec ?? this.inhaleSec,
        holdInSec: holdInSec ?? this.holdInSec,
        exhaleSec: exhaleSec ?? this.exhaleSec,
        holdOutSec: holdOutSec ?? this.holdOutSec,
        cycles: cycles ?? this.cycles,
        rounds: rounds ?? this.rounds,
        createdAt: createdAt ?? this.createdAt,
      );
  CustomPreset copyWithCompanion(CustomPresetsCompanion data) {
    return CustomPreset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      inhaleSec: data.inhaleSec.present ? data.inhaleSec.value : this.inhaleSec,
      holdInSec: data.holdInSec.present ? data.holdInSec.value : this.holdInSec,
      exhaleSec: data.exhaleSec.present ? data.exhaleSec.value : this.exhaleSec,
      holdOutSec:
          data.holdOutSec.present ? data.holdOutSec.value : this.holdOutSec,
      cycles: data.cycles.present ? data.cycles.value : this.cycles,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomPreset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('inhaleSec: $inhaleSec, ')
          ..write('holdInSec: $holdInSec, ')
          ..write('exhaleSec: $exhaleSec, ')
          ..write('holdOutSec: $holdOutSec, ')
          ..write('cycles: $cycles, ')
          ..write('rounds: $rounds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, inhaleSec, holdInSec, exhaleSec,
      holdOutSec, cycles, rounds, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomPreset &&
          other.id == this.id &&
          other.name == this.name &&
          other.inhaleSec == this.inhaleSec &&
          other.holdInSec == this.holdInSec &&
          other.exhaleSec == this.exhaleSec &&
          other.holdOutSec == this.holdOutSec &&
          other.cycles == this.cycles &&
          other.rounds == this.rounds &&
          other.createdAt == this.createdAt);
}

class CustomPresetsCompanion extends UpdateCompanion<CustomPreset> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> inhaleSec;
  final Value<int> holdInSec;
  final Value<int> exhaleSec;
  final Value<int> holdOutSec;
  final Value<int> cycles;
  final Value<int> rounds;
  final Value<DateTime> createdAt;
  const CustomPresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.inhaleSec = const Value.absent(),
    this.holdInSec = const Value.absent(),
    this.exhaleSec = const Value.absent(),
    this.holdOutSec = const Value.absent(),
    this.cycles = const Value.absent(),
    this.rounds = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CustomPresetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int inhaleSec,
    this.holdInSec = const Value.absent(),
    required int exhaleSec,
    this.holdOutSec = const Value.absent(),
    this.cycles = const Value.absent(),
    this.rounds = const Value.absent(),
    required DateTime createdAt,
  })  : name = Value(name),
        inhaleSec = Value(inhaleSec),
        exhaleSec = Value(exhaleSec),
        createdAt = Value(createdAt);
  static Insertable<CustomPreset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? inhaleSec,
    Expression<int>? holdInSec,
    Expression<int>? exhaleSec,
    Expression<int>? holdOutSec,
    Expression<int>? cycles,
    Expression<int>? rounds,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (inhaleSec != null) 'inhale_sec': inhaleSec,
      if (holdInSec != null) 'hold_in_sec': holdInSec,
      if (exhaleSec != null) 'exhale_sec': exhaleSec,
      if (holdOutSec != null) 'hold_out_sec': holdOutSec,
      if (cycles != null) 'cycles': cycles,
      if (rounds != null) 'rounds': rounds,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CustomPresetsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? inhaleSec,
      Value<int>? holdInSec,
      Value<int>? exhaleSec,
      Value<int>? holdOutSec,
      Value<int>? cycles,
      Value<int>? rounds,
      Value<DateTime>? createdAt}) {
    return CustomPresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      inhaleSec: inhaleSec ?? this.inhaleSec,
      holdInSec: holdInSec ?? this.holdInSec,
      exhaleSec: exhaleSec ?? this.exhaleSec,
      holdOutSec: holdOutSec ?? this.holdOutSec,
      cycles: cycles ?? this.cycles,
      rounds: rounds ?? this.rounds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (inhaleSec.present) {
      map['inhale_sec'] = Variable<int>(inhaleSec.value);
    }
    if (holdInSec.present) {
      map['hold_in_sec'] = Variable<int>(holdInSec.value);
    }
    if (exhaleSec.present) {
      map['exhale_sec'] = Variable<int>(exhaleSec.value);
    }
    if (holdOutSec.present) {
      map['hold_out_sec'] = Variable<int>(holdOutSec.value);
    }
    if (cycles.present) {
      map['cycles'] = Variable<int>(cycles.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomPresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('inhaleSec: $inhaleSec, ')
          ..write('holdInSec: $holdInSec, ')
          ..write('exhaleSec: $exhaleSec, ')
          ..write('holdOutSec: $holdOutSec, ')
          ..write('cycles: $cycles, ')
          ..write('rounds: $rounds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $HealthMetricsTable healthMetrics = $HealthMetricsTable(this);
  late final $PlannedSessionsTable plannedSessions =
      $PlannedSessionsTable(this);
  late final $CustomPresetsTable customPresets = $CustomPresetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [sessions, userProfile, healthMetrics, plannedSessions, customPresets];
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required DateTime timestamp,
  required String levelKey,
  required int durationSec,
  required int rounds,
  Value<int> retentionSec,
  Value<int> xpEarned,
  Value<int?> spo2Min,
  Value<int?> spo2Avg,
  Value<int?> hrMin,
  Value<int?> hrAvg,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<DateTime> timestamp,
  Value<String> levelKey,
  Value<int> durationSec,
  Value<int> rounds,
  Value<int> retentionSec,
  Value<int> xpEarned,
  Value<int?> spo2Min,
  Value<int?> spo2Avg,
  Value<int?> hrMin,
  Value<int?> hrAvg,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get levelKey => $composableBuilder(
      column: $table.levelKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retentionSec => $composableBuilder(
      column: $table.retentionSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xpEarned => $composableBuilder(
      column: $table.xpEarned, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get spo2Min => $composableBuilder(
      column: $table.spo2Min, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get spo2Avg => $composableBuilder(
      column: $table.spo2Avg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hrMin => $composableBuilder(
      column: $table.hrMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hrAvg => $composableBuilder(
      column: $table.hrAvg, builder: (column) => ColumnFilters(column));
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get levelKey => $composableBuilder(
      column: $table.levelKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retentionSec => $composableBuilder(
      column: $table.retentionSec,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xpEarned => $composableBuilder(
      column: $table.xpEarned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get spo2Min => $composableBuilder(
      column: $table.spo2Min, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get spo2Avg => $composableBuilder(
      column: $table.spo2Avg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hrMin => $composableBuilder(
      column: $table.hrMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hrAvg => $composableBuilder(
      column: $table.hrAvg, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get levelKey =>
      $composableBuilder(column: $table.levelKey, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<int> get retentionSec => $composableBuilder(
      column: $table.retentionSec, builder: (column) => column);

  GeneratedColumn<int> get xpEarned =>
      $composableBuilder(column: $table.xpEarned, builder: (column) => column);

  GeneratedColumn<int> get spo2Min =>
      $composableBuilder(column: $table.spo2Min, builder: (column) => column);

  GeneratedColumn<int> get spo2Avg =>
      $composableBuilder(column: $table.spo2Avg, builder: (column) => column);

  GeneratedColumn<int> get hrMin =>
      $composableBuilder(column: $table.hrMin, builder: (column) => column);

  GeneratedColumn<int> get hrAvg =>
      $composableBuilder(column: $table.hrAvg, builder: (column) => column);
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
    Session,
    PrefetchHooks Function()> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> levelKey = const Value.absent(),
            Value<int> durationSec = const Value.absent(),
            Value<int> rounds = const Value.absent(),
            Value<int> retentionSec = const Value.absent(),
            Value<int> xpEarned = const Value.absent(),
            Value<int?> spo2Min = const Value.absent(),
            Value<int?> spo2Avg = const Value.absent(),
            Value<int?> hrMin = const Value.absent(),
            Value<int?> hrAvg = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            timestamp: timestamp,
            levelKey: levelKey,
            durationSec: durationSec,
            rounds: rounds,
            retentionSec: retentionSec,
            xpEarned: xpEarned,
            spo2Min: spo2Min,
            spo2Avg: spo2Avg,
            hrMin: hrMin,
            hrAvg: hrAvg,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime timestamp,
            required String levelKey,
            required int durationSec,
            required int rounds,
            Value<int> retentionSec = const Value.absent(),
            Value<int> xpEarned = const Value.absent(),
            Value<int?> spo2Min = const Value.absent(),
            Value<int?> spo2Avg = const Value.absent(),
            Value<int?> hrMin = const Value.absent(),
            Value<int?> hrAvg = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            timestamp: timestamp,
            levelKey: levelKey,
            durationSec: durationSec,
            rounds: rounds,
            retentionSec: retentionSec,
            xpEarned: xpEarned,
            spo2Min: spo2Min,
            spo2Avg: spo2Avg,
            hrMin: hrMin,
            hrAvg: hrAvg,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
    Session,
    PrefetchHooks Function()>;
typedef $$UserProfileTableCreateCompanionBuilder = UserProfileCompanion
    Function({
  Value<int> id,
  Value<int> level,
  Value<int> totalXp,
  Value<int> dailyStreak,
  Value<DateTime?> lastSessionDate,
});
typedef $$UserProfileTableUpdateCompanionBuilder = UserProfileCompanion
    Function({
  Value<int> id,
  Value<int> level,
  Value<int> totalXp,
  Value<int> dailyStreak,
  Value<DateTime?> lastSessionDate,
});

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalXp => $composableBuilder(
      column: $table.totalXp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyStreak => $composableBuilder(
      column: $table.dailyStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSessionDate => $composableBuilder(
      column: $table.lastSessionDate,
      builder: (column) => ColumnFilters(column));
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalXp => $composableBuilder(
      column: $table.totalXp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyStreak => $composableBuilder(
      column: $table.dailyStreak, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSessionDate => $composableBuilder(
      column: $table.lastSessionDate,
      builder: (column) => ColumnOrderings(column));
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get totalXp =>
      $composableBuilder(column: $table.totalXp, builder: (column) => column);

  GeneratedColumn<int> get dailyStreak => $composableBuilder(
      column: $table.dailyStreak, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSessionDate => $composableBuilder(
      column: $table.lastSessionDate, builder: (column) => column);
}

class $$UserProfileTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileData,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileData,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>
    ),
    UserProfileData,
    PrefetchHooks Function()> {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<int> totalXp = const Value.absent(),
            Value<int> dailyStreak = const Value.absent(),
            Value<DateTime?> lastSessionDate = const Value.absent(),
          }) =>
              UserProfileCompanion(
            id: id,
            level: level,
            totalXp: totalXp,
            dailyStreak: dailyStreak,
            lastSessionDate: lastSessionDate,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<int> totalXp = const Value.absent(),
            Value<int> dailyStreak = const Value.absent(),
            Value<DateTime?> lastSessionDate = const Value.absent(),
          }) =>
              UserProfileCompanion.insert(
            id: id,
            level: level,
            totalXp: totalXp,
            dailyStreak: dailyStreak,
            lastSessionDate: lastSessionDate,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfileTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileData,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileData,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>
    ),
    UserProfileData,
    PrefetchHooks Function()>;
typedef $$HealthMetricsTableCreateCompanionBuilder = HealthMetricsCompanion
    Function({
  Value<int> id,
  required DateTime timestamp,
  Value<int?> co2ToleranceScore,
  Value<int?> avgBreathsPerMin,
});
typedef $$HealthMetricsTableUpdateCompanionBuilder = HealthMetricsCompanion
    Function({
  Value<int> id,
  Value<DateTime> timestamp,
  Value<int?> co2ToleranceScore,
  Value<int?> avgBreathsPerMin,
});

class $$HealthMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthMetricsTable> {
  $$HealthMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get co2ToleranceScore => $composableBuilder(
      column: $table.co2ToleranceScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avgBreathsPerMin => $composableBuilder(
      column: $table.avgBreathsPerMin,
      builder: (column) => ColumnFilters(column));
}

class $$HealthMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthMetricsTable> {
  $$HealthMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get co2ToleranceScore => $composableBuilder(
      column: $table.co2ToleranceScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avgBreathsPerMin => $composableBuilder(
      column: $table.avgBreathsPerMin,
      builder: (column) => ColumnOrderings(column));
}

class $$HealthMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthMetricsTable> {
  $$HealthMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get co2ToleranceScore => $composableBuilder(
      column: $table.co2ToleranceScore, builder: (column) => column);

  GeneratedColumn<int> get avgBreathsPerMin => $composableBuilder(
      column: $table.avgBreathsPerMin, builder: (column) => column);
}

class $$HealthMetricsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HealthMetricsTable,
    HealthMetric,
    $$HealthMetricsTableFilterComposer,
    $$HealthMetricsTableOrderingComposer,
    $$HealthMetricsTableAnnotationComposer,
    $$HealthMetricsTableCreateCompanionBuilder,
    $$HealthMetricsTableUpdateCompanionBuilder,
    (
      HealthMetric,
      BaseReferences<_$AppDatabase, $HealthMetricsTable, HealthMetric>
    ),
    HealthMetric,
    PrefetchHooks Function()> {
  $$HealthMetricsTableTableManager(_$AppDatabase db, $HealthMetricsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int?> co2ToleranceScore = const Value.absent(),
            Value<int?> avgBreathsPerMin = const Value.absent(),
          }) =>
              HealthMetricsCompanion(
            id: id,
            timestamp: timestamp,
            co2ToleranceScore: co2ToleranceScore,
            avgBreathsPerMin: avgBreathsPerMin,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime timestamp,
            Value<int?> co2ToleranceScore = const Value.absent(),
            Value<int?> avgBreathsPerMin = const Value.absent(),
          }) =>
              HealthMetricsCompanion.insert(
            id: id,
            timestamp: timestamp,
            co2ToleranceScore: co2ToleranceScore,
            avgBreathsPerMin: avgBreathsPerMin,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HealthMetricsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HealthMetricsTable,
    HealthMetric,
    $$HealthMetricsTableFilterComposer,
    $$HealthMetricsTableOrderingComposer,
    $$HealthMetricsTableAnnotationComposer,
    $$HealthMetricsTableCreateCompanionBuilder,
    $$HealthMetricsTableUpdateCompanionBuilder,
    (
      HealthMetric,
      BaseReferences<_$AppDatabase, $HealthMetricsTable, HealthMetric>
    ),
    HealthMetric,
    PrefetchHooks Function()>;
typedef $$PlannedSessionsTableCreateCompanionBuilder = PlannedSessionsCompanion
    Function({
  Value<int> id,
  required DateTime scheduledAt,
  required String levelKey,
});
typedef $$PlannedSessionsTableUpdateCompanionBuilder = PlannedSessionsCompanion
    Function({
  Value<int> id,
  Value<DateTime> scheduledAt,
  Value<String> levelKey,
});

class $$PlannedSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlannedSessionsTable> {
  $$PlannedSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get levelKey => $composableBuilder(
      column: $table.levelKey, builder: (column) => ColumnFilters(column));
}

class $$PlannedSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlannedSessionsTable> {
  $$PlannedSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get levelKey => $composableBuilder(
      column: $table.levelKey, builder: (column) => ColumnOrderings(column));
}

class $$PlannedSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlannedSessionsTable> {
  $$PlannedSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => column);

  GeneratedColumn<String> get levelKey =>
      $composableBuilder(column: $table.levelKey, builder: (column) => column);
}

class $$PlannedSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlannedSessionsTable,
    PlannedSession,
    $$PlannedSessionsTableFilterComposer,
    $$PlannedSessionsTableOrderingComposer,
    $$PlannedSessionsTableAnnotationComposer,
    $$PlannedSessionsTableCreateCompanionBuilder,
    $$PlannedSessionsTableUpdateCompanionBuilder,
    (
      PlannedSession,
      BaseReferences<_$AppDatabase, $PlannedSessionsTable, PlannedSession>
    ),
    PlannedSession,
    PrefetchHooks Function()> {
  $$PlannedSessionsTableTableManager(
      _$AppDatabase db, $PlannedSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlannedSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlannedSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlannedSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> scheduledAt = const Value.absent(),
            Value<String> levelKey = const Value.absent(),
          }) =>
              PlannedSessionsCompanion(
            id: id,
            scheduledAt: scheduledAt,
            levelKey: levelKey,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime scheduledAt,
            required String levelKey,
          }) =>
              PlannedSessionsCompanion.insert(
            id: id,
            scheduledAt: scheduledAt,
            levelKey: levelKey,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlannedSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlannedSessionsTable,
    PlannedSession,
    $$PlannedSessionsTableFilterComposer,
    $$PlannedSessionsTableOrderingComposer,
    $$PlannedSessionsTableAnnotationComposer,
    $$PlannedSessionsTableCreateCompanionBuilder,
    $$PlannedSessionsTableUpdateCompanionBuilder,
    (
      PlannedSession,
      BaseReferences<_$AppDatabase, $PlannedSessionsTable, PlannedSession>
    ),
    PlannedSession,
    PrefetchHooks Function()>;
typedef $$CustomPresetsTableCreateCompanionBuilder = CustomPresetsCompanion
    Function({
  Value<int> id,
  required String name,
  required int inhaleSec,
  Value<int> holdInSec,
  required int exhaleSec,
  Value<int> holdOutSec,
  Value<int> cycles,
  Value<int> rounds,
  required DateTime createdAt,
});
typedef $$CustomPresetsTableUpdateCompanionBuilder = CustomPresetsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<int> inhaleSec,
  Value<int> holdInSec,
  Value<int> exhaleSec,
  Value<int> holdOutSec,
  Value<int> cycles,
  Value<int> rounds,
  Value<DateTime> createdAt,
});

class $$CustomPresetsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomPresetsTable> {
  $$CustomPresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get inhaleSec => $composableBuilder(
      column: $table.inhaleSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get holdInSec => $composableBuilder(
      column: $table.holdInSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get exhaleSec => $composableBuilder(
      column: $table.exhaleSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get holdOutSec => $composableBuilder(
      column: $table.holdOutSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cycles => $composableBuilder(
      column: $table.cycles, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CustomPresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomPresetsTable> {
  $$CustomPresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get inhaleSec => $composableBuilder(
      column: $table.inhaleSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get holdInSec => $composableBuilder(
      column: $table.holdInSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get exhaleSec => $composableBuilder(
      column: $table.exhaleSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get holdOutSec => $composableBuilder(
      column: $table.holdOutSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cycles => $composableBuilder(
      column: $table.cycles, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CustomPresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomPresetsTable> {
  $$CustomPresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get inhaleSec =>
      $composableBuilder(column: $table.inhaleSec, builder: (column) => column);

  GeneratedColumn<int> get holdInSec =>
      $composableBuilder(column: $table.holdInSec, builder: (column) => column);

  GeneratedColumn<int> get exhaleSec =>
      $composableBuilder(column: $table.exhaleSec, builder: (column) => column);

  GeneratedColumn<int> get holdOutSec => $composableBuilder(
      column: $table.holdOutSec, builder: (column) => column);

  GeneratedColumn<int> get cycles =>
      $composableBuilder(column: $table.cycles, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomPresetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CustomPresetsTable,
    CustomPreset,
    $$CustomPresetsTableFilterComposer,
    $$CustomPresetsTableOrderingComposer,
    $$CustomPresetsTableAnnotationComposer,
    $$CustomPresetsTableCreateCompanionBuilder,
    $$CustomPresetsTableUpdateCompanionBuilder,
    (
      CustomPreset,
      BaseReferences<_$AppDatabase, $CustomPresetsTable, CustomPreset>
    ),
    CustomPreset,
    PrefetchHooks Function()> {
  $$CustomPresetsTableTableManager(_$AppDatabase db, $CustomPresetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomPresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomPresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomPresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> inhaleSec = const Value.absent(),
            Value<int> holdInSec = const Value.absent(),
            Value<int> exhaleSec = const Value.absent(),
            Value<int> holdOutSec = const Value.absent(),
            Value<int> cycles = const Value.absent(),
            Value<int> rounds = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              CustomPresetsCompanion(
            id: id,
            name: name,
            inhaleSec: inhaleSec,
            holdInSec: holdInSec,
            exhaleSec: exhaleSec,
            holdOutSec: holdOutSec,
            cycles: cycles,
            rounds: rounds,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required int inhaleSec,
            Value<int> holdInSec = const Value.absent(),
            required int exhaleSec,
            Value<int> holdOutSec = const Value.absent(),
            Value<int> cycles = const Value.absent(),
            Value<int> rounds = const Value.absent(),
            required DateTime createdAt,
          }) =>
              CustomPresetsCompanion.insert(
            id: id,
            name: name,
            inhaleSec: inhaleSec,
            holdInSec: holdInSec,
            exhaleSec: exhaleSec,
            holdOutSec: holdOutSec,
            cycles: cycles,
            rounds: rounds,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CustomPresetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CustomPresetsTable,
    CustomPreset,
    $$CustomPresetsTableFilterComposer,
    $$CustomPresetsTableOrderingComposer,
    $$CustomPresetsTableAnnotationComposer,
    $$CustomPresetsTableCreateCompanionBuilder,
    $$CustomPresetsTableUpdateCompanionBuilder,
    (
      CustomPreset,
      BaseReferences<_$AppDatabase, $CustomPresetsTable, CustomPreset>
    ),
    CustomPreset,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$HealthMetricsTableTableManager get healthMetrics =>
      $$HealthMetricsTableTableManager(_db, _db.healthMetrics);
  $$PlannedSessionsTableTableManager get plannedSessions =>
      $$PlannedSessionsTableTableManager(_db, _db.plannedSessions);
  $$CustomPresetsTableTableManager get customPresets =>
      $$CustomPresetsTableTableManager(_db, _db.customPresets);
}
