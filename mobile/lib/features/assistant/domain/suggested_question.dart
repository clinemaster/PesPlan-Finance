/// Questions worth asking, grouped the way a user thinks about money.
///
/// ## Why the suggestions are the product
///
/// Nobody knows what a financial assistant can answer until they see a
/// question it handles. An empty box with a cursor in it gets one
/// hesitant question and then abandonment; four groups of real questions
/// teach the shape of what this thing is for in a glance — and every one
/// of these is answered from what the user has actually recorded.
class SuggestionGroup {
  const SuggestionGroup({required this.title, required this.questions});

  final String title;
  final List<String> questions;

  /// The questions this group adds beyond the quick picks, so the
  /// welcome screen never shows the same chip twice.
  List<String> get remaining => [
    for (final question in questions)
      if (!opening.contains(question)) question,
  ];

  /// The full set, in the order the screen shows them.
  static const List<SuggestionGroup> all = [
    SuggestionGroup(
      title: 'Spending',
      questions: [
        'How much did I spend this month?',
        'What is my biggest spending category?',
        'Where can I reduce my expenses?',
      ],
    ),
    SuggestionGroup(
      title: 'Income',
      questions: [
        'How much did I earn this month?',
        'Compare my income this year with last year.',
      ],
    ),
    SuggestionGroup(
      title: 'Budgets',
      questions: [
        'Am I within my budget?',
        'Which budget is close to its limit?',
      ],
    ),
    SuggestionGroup(
      title: 'Savings',
      questions: [
        'How much have I saved this year?',
        'How can I reach my savings goal faster?',
      ],
    ),
    SuggestionGroup(
      title: 'Overview',
      questions: [
        'Give me a summary of my finances this month.',
        'What changed compared with last month?',
      ],
    ),
  ];

  /// The handful shown on the welcome screen, one from each area so the
  /// range is visible without a wall of chips.
  static const List<String> opening = [
    'How much did I spend this month?',
    'Am I within my budget?',
    'How much have I saved this year?',
    'Give me a summary of my finances this month.',
  ];
}
