import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, injectable.
///
/// Lives in core rather than inside a feature because more than one
/// feature needs it — the dashboard greets by time of day, transactions
/// label dates "Today" and "Yesterday" and refuse future dates — and a
/// feature importing another feature's providers to get at a clock is how
/// features quietly stop being separable.
///
/// Code that calls `DateTime.now()` directly cannot be tested at all, and
/// gives a suite that behaves differently depending on the day it runs.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
