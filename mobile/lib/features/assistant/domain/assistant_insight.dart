import '../../../core/money/money.dart';

/// How an insight should read, not what colour it is.
///
/// The screen maps these onto the design system's tones; the assistant
/// says what kind of thing it is telling you and stays out of the
/// palette.
enum InsightTone { neutral, good, watch, warning }

/// One line inside an insight card.
class InsightRow {
  const InsightRow({required this.label, required this.value, this.share});

  final String label;
  final String value;

  /// 0..1, when the row is worth drawing a bar for. Computed where the
  /// figures are, never by a widget.
  final double? share;
}

/// A small card the assistant attaches to an answer.
///
/// ## Why answers carry structure and not just prose
///
/// "Food was 32% of your spending" is a sentence; a bar next to the
/// figure is the same fact read in a glance. Keeping the structure
/// separate from the words also means the numbers come from the
/// repositories that own them — the text never states a figure the card
/// does not also carry.
class AssistantInsight {
  const AssistantInsight({
    required this.title,
    this.amount,
    this.caption,
    this.ratio,
    this.rows = const [],
    this.tone = InsightTone.neutral,
  });

  final String title;

  /// The headline figure, when there is one.
  final Money? amount;

  /// A line under the figure: what period it covers, what it compares
  /// with.
  final String? caption;

  /// 0..1, drawn as a bar. Already computed.
  final double? ratio;

  final List<InsightRow> rows;
  final InsightTone tone;

  bool get hasRows => rows.isNotEmpty;
}
