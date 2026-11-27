import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/goal_movement.dart';
import '../domain/savings_goal.dart';

/// Keeps goals and their movements between launches.
///
/// Two keys rather than one nested blob: a goal and its history change at
/// different times — a contribution rewrites the movements and leaves the
/// goals untouched — and keeping them apart means a damaged history
/// cannot take the goals down with it.
class SavingsStore {
  const SavingsStore(this._store);

  final KeyValueStore _store;

  static const String _goalsKey = 'savings.goals';
  static const String _movementsKey = 'savings.movements';

  /// True once something has been written, even an empty list — so a user
  /// who deletes their last goal is not handed a fresh set of seeded ones
  /// on the next launch.
  bool get hasStoredData => _store.getString(_goalsKey) != null;

  List<SavingsGoal> readGoals() {
    final raw = _store.getString(_goalsKey);
    // Growable, not const: a caller that reads and then adds should not
    // meet "Cannot add to an unmodifiable list" for the empty case only.
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list) _decodeGoal(entry as Map<String, dynamic>),
      ];
    } on Object {
      // Unreadable state is treated as none: the user loses their plans,
      // which is recoverable, rather than meeting a crash on launch,
      // which is not.
      return [];
    }
  }

  List<GoalMovement> readMovements() {
    final raw = _store.getString(_movementsKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list)
          _decodeMovement(entry as Map<String, dynamic>),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> writeGoals(List<SavingsGoal> goals) => _store.setString(
    _goalsKey,
    jsonEncode([for (final goal in goals) _encodeGoal(goal)]),
  );

  Future<void> writeMovements(List<GoalMovement> movements) => _store.setString(
    _movementsKey,
    jsonEncode([for (final movement in movements) _encode(movement)]),
  );

  Future<void> clear() async {
    await _store.remove(_goalsKey);
    await _store.remove(_movementsKey);
  }

  static Map<String, dynamic> _encodeGoal(SavingsGoal goal) => {
    'id': goal.id,
    'name': goal.name,
    'target': goal.target.minorUnits,
    'currency': goal.target.currency.code,
    'createdAt': goal.createdAt.toIso8601String(),
    'iconKey': goal.iconKey,
    'targetDate': goal.targetDate?.toIso8601String(),
    'description': goal.description,
  };

  static SavingsGoal _decodeGoal(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    target: Money(
      json['target'] as int,
      currency: _currencyFor(json['currency'] as String?),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    iconKey: (json['iconKey'] as String?) ?? GoalIcon.fallback,
    targetDate: switch (json['targetDate']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
    description: (json['description'] as String?) ?? '',
  );

  static Map<String, dynamic> _encode(GoalMovement movement) => {
    'id': movement.id,
    'goalId': movement.goalId,
    'kind': movement.kind.name,
    'amount': movement.amount.minorUnits,
    'currency': movement.amount.currency.code,
    'date': movement.date.toIso8601String(),
    'recordedAt': movement.recordedAt.toIso8601String(),
    'description': movement.description,
  };

  static GoalMovement _decodeMovement(Map<String, dynamic> json) =>
      GoalMovement(
        id: json['id'] as String,
        goalId: json['goalId'] as String,
        kind: json['kind'] == 'withdrawal'
            ? MovementKind.withdrawal
            : MovementKind.contribution,
        amount: Money(
          json['amount'] as int,
          currency: _currencyFor(json['currency'] as String?),
        ),
        date: DateTime.parse(json['date'] as String),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        description: (json['description'] as String?) ?? '',
      );

  static Currency _currencyFor(String? code) {
    for (final currency in Currency.supported) {
      if (currency.code == code) return currency;
    }
    return Currency.tzs;
  }
}
