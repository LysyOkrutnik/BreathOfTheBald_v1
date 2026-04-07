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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modeIdMeta = const VerificationMeta('modeId');
  @override
  late final GeneratedColumn<String> modeId = GeneratedColumn<String>(
      'mode_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
      'rounds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _maxRetentionSecMeta =
      const VerificationMeta('maxRetentionSec');
  @override
  late final GeneratedColumn<int> maxRetentionSec = GeneratedColumn<int>(
      'max_retention_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _xpEarnedMeta =
      const VerificationMeta('xpEarned');
  @override
  late final GeneratedColumn<int> xpEarned = GeneratedColumn<int>(
      'xp_earned', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, timestamp, modeId, rounds, maxRetentionSec, xpEarned];
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
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('mode_id')) {
      context.handle(_modeIdMeta,
          modeId.isAcceptableOrUnknown(data['mode_id']!, _modeIdMeta));
    } else if (isInserting) {
      context.missing(_modeIdMeta);
    }
    if (data.containsKey('rounds')) {
      context.handle(_roundsMeta,
          rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta));
    } else if (isInserting) {
      context.missing(_roundsMeta);
    }
    if (data.containsKey('max_retention_sec')) {
      context.handle(
          _maxRetentionSecMeta,
          maxRetentionSec.isAcceptableOrUnknown(
              data['max_retention_sec']!, _maxRetentionSecMeta));
    } else if (isInserting) {
      context.missing(_maxRetentionSecMeta);
    }
    if (data.containsKey('xp_earned')) {
      context.handle(_xpEarnedMeta,
          xpEarned.isAcceptableOrUnknown(data['xp_earned']!, _xpEarnedMeta));
    } else if (isInserting) {
      context.missing(_xpEarnedMeta);
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
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      modeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode_id'])!,
      rounds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rounds'])!,
      maxRetentionSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_retention_sec'])!,
      xpEarned: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp_earned'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final DateTime timestamp;
  final String modeId;
  final int rounds;
  final int maxRetentionSec;
  final int xpEarned;
  const Session(
      {required this.id,
      required this.timestamp,
      required this.modeId,
      required this.rounds,
      required this.maxRetentionSec,
      required this.xpEarned});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['mode_id'] = Variable<String>(modeId);
    map['rounds'] = Variable<int>(rounds);
    map['max_retention_sec'] = Variable<int>(maxRetentionSec);
    map['xp_earned'] = Variable<int>(xpEarned);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      modeId: Value(modeId),
      rounds: Value(rounds),
      maxRetentionSec: Value(maxRetentionSec),
      xpEarned: Value(xpEarned),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      modeId: serializer.fromJson<String>(json['modeId']),
      rounds: serializer.fromJson<int>(json['rounds']),
      maxRetentionSec: serializer.fromJson<int>(json['maxRetentionSec']),
      xpEarned: serializer.fromJson<int>(json['xpEarned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'modeId': serializer.toJson<String>(modeId),
      'rounds': serializer.toJson<int>(rounds),
      'maxRetentionSec': serializer.toJson<int>(maxRetentionSec),
      'xpEarned': serializer.toJson<int>(xpEarned),
    };
  }

  Session copyWith(
          {String? id,
          DateTime? timestamp,
          String? modeId,
          int? rounds,
          int? maxRetentionSec,
          int? xpEarned}) =>
      Session(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        modeId: modeId ?? this.modeId,
        rounds: rounds ?? this.rounds,
        maxRetentionSec: maxRetentionSec ?? this.maxRetentionSec,
        xpEarned: xpEarned ?? this.xpEarned,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      modeId: data.modeId.present ? data.modeId.value : this.modeId,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      maxRetentionSec: data.maxRetentionSec.present
          ? data.maxRetentionSec.value
          : this.maxRetentionSec,
      xpEarned: data.xpEarned.present ? data.xpEarned.value : this.xpEarned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('modeId: $modeId, ')
          ..write('rounds: $rounds, ')
          ..write('maxRetentionSec: $maxRetentionSec, ')
          ..write('xpEarned: $xpEarned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, modeId, rounds, maxRetentionSec, xpEarned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.modeId == this.modeId &&
          other.rounds == this.rounds &&
          other.maxRetentionSec == this.maxRetentionSec &&
          other.xpEarned == this.xpEarned);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> modeId;
  final Value<int> rounds;
  final Value<int> maxRetentionSec;
  final Value<int> xpEarned;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.modeId = const Value.absent(),
    this.rounds = const Value.absent(),
    this.maxRetentionSec = const Value.absent(),
    this.xpEarned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required DateTime timestamp,
    required String modeId,
    required int rounds,
    required int maxRetentionSec,
    required int xpEarned,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        timestamp = Value(timestamp),
        modeId = Value(modeId),
        rounds = Value(rounds),
        maxRetentionSec = Value(maxRetentionSec),
        xpEarned = Value(xpEarned);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? modeId,
    Expression<int>? rounds,
    Expression<int>? maxRetentionSec,
    Expression<int>? xpEarned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (modeId != null) 'mode_id': modeId,
      if (rounds != null) 'rounds': rounds,
      if (maxRetentionSec != null) 'max_retention_sec': maxRetentionSec,
      if (xpEarned != null) 'xp_earned': xpEarned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? timestamp,
      Value<String>? modeId,
      Value<int>? rounds,
      Value<int>? maxRetentionSec,
      Value<int>? xpEarned,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      modeId: modeId ?? this.modeId,
      rounds: rounds ?? this.rounds,
      maxRetentionSec: maxRetentionSec ?? this.maxRetentionSec,
      xpEarned: xpEarned ?? this.xpEarned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (modeId.present) {
      map['mode_id'] = Variable<String>(modeId.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (maxRetentionSec.present) {
      map['max_retention_sec'] = Variable<int>(maxRetentionSec.value);
    }
    if (xpEarned.present) {
      map['xp_earned'] = Variable<int>(xpEarned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('modeId: $modeId, ')
          ..write('rounds: $rounds, ')
          ..write('maxRetentionSec: $maxRetentionSec, ')
          ..write('xpEarned: $xpEarned, ')
          ..write('rowid: $rowid')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $HealthMetricsTable healthMetrics = $HealthMetricsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [sessions, userProfile, healthMetrics];
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required DateTime timestamp,
  required String modeId,
  required int rounds,
  required int maxRetentionSec,
  required int xpEarned,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<String> modeId,
  Value<int> rounds,
  Value<int> maxRetentionSec,
  Value<int> xpEarned,
  Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modeId => $composableBuilder(
      column: $table.modeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxRetentionSec => $composableBuilder(
      column: $table.maxRetentionSec,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xpEarned => $composableBuilder(
      column: $table.xpEarned, builder: (column) => ColumnFilters(column));
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
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modeId => $composableBuilder(
      column: $table.modeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxRetentionSec => $composableBuilder(
      column: $table.maxRetentionSec,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xpEarned => $composableBuilder(
      column: $table.xpEarned, builder: (column) => ColumnOrderings(column));
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get modeId =>
      $composableBuilder(column: $table.modeId, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<int> get maxRetentionSec => $composableBuilder(
      column: $table.maxRetentionSec, builder: (column) => column);

  GeneratedColumn<int> get xpEarned =>
      $composableBuilder(column: $table.xpEarned, builder: (column) => column);
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
            Value<String> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> modeId = const Value.absent(),
            Value<int> rounds = const Value.absent(),
            Value<int> maxRetentionSec = const Value.absent(),
            Value<int> xpEarned = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            timestamp: timestamp,
            modeId: modeId,
            rounds: rounds,
            maxRetentionSec: maxRetentionSec,
            xpEarned: xpEarned,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime timestamp,
            required String modeId,
            required int rounds,
            required int maxRetentionSec,
            required int xpEarned,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            timestamp: timestamp,
            modeId: modeId,
            rounds: rounds,
            maxRetentionSec: maxRetentionSec,
            xpEarned: xpEarned,
            rowid: rowid,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$HealthMetricsTableTableManager get healthMetrics =>
      $$HealthMetricsTableTableManager(_db, _db.healthMetrics);
}
