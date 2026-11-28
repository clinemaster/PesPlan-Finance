import '../../../core/money/money.dart';
import '../../budgets/domain/budget_repository.dart';
import '../../reports/domain/report_data.dart';
import '../../reports/domain/report_repository.dart';
import '../../savings/domain/savings_repository.dart';
import '../domain/assistant_insight.dart';
import '../domain/assistant_repository.dart';
import '../domain/chat_message.dart';
import 'financial_snapshot.dart';

/// What a question is asking about.
enum Intent {
  spendingTotal,
  biggestCategory,
  reduceSpending,
  incomeTotal,
  incomeComparison,
  budgetStatus,
  budgetPressure,
  savingsTotal,
  savingsAdvice,
  summary,
  monthComparison,
  help,
}

/// An assistant, while there is no assistant.
///
/// ## What this is, plainly
///
/// A keyword matcher over the user's own figures. It reads the question
/// for what it is about, fetches the matching numbers from the
/// repositories that own them, and writes a sentence around them. There
/// is no model, no API key, no network call and nothing sent anywhere —
/// Phase 18 replaces this class, and the interface above it is shaped so
/// that nothing else has to change when it does.
///
/// ## Why it reads real figures instead of returning canned text
///
/// Canned answers would have been a tenth of the work and would have
/// made the screen a lie: the user can tap through to Reports and check
/// every number this says. An assistant whose figures disagree with the
/// rest of the app is worse than no assistant, so the numbers come from
/// the same repositories those screens read.
///
/// ## The sixth file allowed to add up money
///
/// Shares, differences and "how much is left" are arithmetic on amounts,
/// which Architecture Rule 1 keeps out of the app. This class plays the
/// server; `test/transactions/architecture_test.dart` fails the build if
/// any of it leaks upward.
class MockAssistantRepository implements AssistantRepository {
  MockAssistantRepository({
    required this.now,
    required this.reports,
    required this.budgets,
    required this.savings,
    this.delay = const Duration(milliseconds: 700),
    this.dailyLimit = 20,
    this.shouldFail = false,
  });

  final DateTime Function() now;
  final ReportRepository reports;
  final BudgetRepository budgets;
  final SavingsRepository savings;

  /// Long enough that the typing indicator is a real state. Tests pass
  /// zero.
  final Duration delay;

  /// A mock allowance. Nothing is billed or enforced.
  final int dailyLimit;

  /// Set by the review control in Settings, so the error state can be
  /// reached without breaking the app to see it.
  final bool shouldFail;

  int _asked = 0;

  @override
  Future<AssistantUsage> usage() async =>
      AssistantUsage(used: _asked, dailyLimit: dailyLimit);

  @override
  Future<AssistantReply> ask({
    required String question,
    List<ChatMessage> history = const [],
  }) async {
    await Future<void>.delayed(delay);

    if (shouldFail) {
      throw const AssistantUnavailable(
        "I couldn't work that out just now. Please try again.",
      );
    }

    _asked++;

    final snapshot = await FinancialSnapshot.gather(
      now: now(),
      reports: reports,
      budgets: budgets,
      savings: savings,
    );

    if (snapshot.hasNothing) return _nothingRecorded();

    return switch (_intentOf(question)) {
      Intent.spendingTotal => _spendingTotal(snapshot),
      Intent.biggestCategory => _biggestCategory(snapshot),
      Intent.reduceSpending => _reduceSpending(snapshot),
      Intent.incomeTotal => _incomeTotal(snapshot),
      Intent.incomeComparison => _incomeComparison(snapshot),
      Intent.budgetStatus => _budgetStatus(snapshot),
      Intent.budgetPressure => _budgetPressure(snapshot),
      Intent.savingsTotal => _savingsTotal(snapshot),
      Intent.savingsAdvice => _savingsAdvice(snapshot),
      Intent.summary => _summary(snapshot),
      Intent.monthComparison => _monthComparison(snapshot),
      Intent.help => _help(),
    };
  }

  // ------------------------------------------------------- reading the
  // question

  /// Which question this is, by the words in it.
  ///
  /// Order matters: "how much have I saved toward my goal" is about
  /// savings even though it contains "how much", so the specific
  /// readings are tried before the general ones.
  static Intent _intentOf(String question) {
    final text = question.toLowerCase();

    bool has(List<String> words) => words.any(text.contains);

    final aboutSavings = has(['saved', 'saving', 'savings', 'goal', 'akiba']);
    final aboutBudget = has(['budget', 'limit', 'bajeti']);
    final aboutIncome = has(['earn', 'income', 'salary', 'mapato', 'earned']);
    final aboutSpending = has([
      'spend',
      'spent',
      'spending',
      'expense',
      'expenses',
      'cost',
      'matumizi',
    ]);

    if (has(['summary', 'overview', 'how am i doing', 'muhtasari'])) {
      return Intent.summary;
    }
    if (has(['changed', 'compared with last month', 'vs last month']) &&
        !aboutIncome) {
      return Intent.monthComparison;
    }
    if (aboutSavings) {
      if (has(['faster', 'how can i', 'reach', 'sooner', 'advice'])) {
        return Intent.savingsAdvice;
      }
      return Intent.savingsTotal;
    }
    if (aboutBudget) {
      if (has(['close', 'near', 'over', 'which', 'warning'])) {
        return Intent.budgetPressure;
      }
      return Intent.budgetStatus;
    }
    if (aboutIncome) {
      if (has(['compare', 'last year', 'versus', 'vs'])) {
        return Intent.incomeComparison;
      }
      return Intent.incomeTotal;
    }
    if (aboutSpending) {
      if (has(['reduce', 'cut', 'save money', 'less', 'lower'])) {
        return Intent.reduceSpending;
      }
      if (has(['biggest', 'most', 'largest', 'top', 'category'])) {
        return Intent.biggestCategory;
      }
      return Intent.spendingTotal;
    }
    if (has(['compare', 'last month', 'last year'])) {
      return Intent.monthComparison;
    }

    return Intent.help;
  }

  // ---------------------------------------------------------- answers

  AssistantReply _nothingRecorded() => const AssistantReply(
    text:
        "You haven't recorded anything yet, so there is nothing for me to "
        'look at. Add a transaction — by typing or by voice — and ask me '
        'again.',
    followUps: ['What can you help me with?'],
  );

  AssistantReply _spendingTotal(FinancialSnapshot snapshot) {
    final month = snapshot.thisMonth;
    if (!snapshot.hasThisMonth) {
      return const AssistantReply(
        text:
            'Nothing has been recorded this month yet, so your spending is '
            'still at zero.',
        followUps: ['How much did I spend last month?'],
      );
    }

    final top = snapshot.topCategory;
    final text = top == null
        ? 'You have spent ${month.expenses.format()} this month.'
        : 'You have spent ${month.expenses.format()} this month. '
              '${top.label} was your biggest category, about '
              '${top.percent}% of it.';

    return AssistantReply(
      text: text,
      insights: [
        AssistantInsight(
          title: 'Spending this month',
          amount: month.expenses,
          caption: '${month.transactionCount} transactions recorded',
          rows: _categoryRows(month, take: 3),
        ),
      ],
      followUps: [
        'What is my biggest spending category?',
        'Am I within my budget?',
      ],
    );
  }

  AssistantReply _biggestCategory(FinancialSnapshot snapshot) {
    final top = snapshot.topCategory;
    if (top == null) {
      return const AssistantReply(
        text:
            'Nothing has been recorded this month, so there is no biggest '
            'category yet.',
      );
    }

    return AssistantReply(
      text:
          '${top.label} is your biggest spending category this month at '
          '${top.amount.format()} — about ${top.percent}% of everything you '
          'spent, across ${top.transactionCount} transactions.',
      insights: [
        AssistantInsight(
          title: 'Where it went this month',
          rows: _categoryRows(snapshot.thisMonth, take: 5),
        ),
      ],
      followUps: ['Where can I reduce my expenses?'],
    );
  }

  AssistantReply _reduceSpending(FinancialSnapshot snapshot) {
    final month = snapshot.thisMonth;
    if (month.categories.isEmpty) {
      return const AssistantReply(
        text:
            'There is nothing recorded this month for me to look through '
            'yet.',
      );
    }

    final top = month.categories.first;
    final unbudgeted = snapshot.budgets.unbudgetedSpending;

    final lines = <String>[
      'Your three largest categories this month are '
          '${month.categories.take(3).map((c) => '${c.label} '
              '(${c.amount.format()})').join(', ')}.',
      'The easiest change is usually the biggest one: ${top.label} is '
          '${top.percent}% of your spending.',
    ];

    if (unbudgeted.minorUnits > 0) {
      lines.add(
        '${unbudgeted.format()} went on categories with no budget set. '
        'Setting a limit for those makes overspending visible before it '
        'happens.',
      );
    }

    return AssistantReply(
      text: lines.join('\n\n'),
      insights: [
        AssistantInsight(
          title: 'Largest categories',
          rows: _categoryRows(month, take: 3),
          tone: InsightTone.watch,
        ),
      ],
      followUps: ['Am I within my budget?'],
    );
  }

  AssistantReply _incomeTotal(FinancialSnapshot snapshot) {
    final month = snapshot.thisMonth;

    return AssistantReply(
      text:
          'You have recorded ${month.income.format()} of income this month, '
          'against ${month.expenses.format()} of spending. That leaves '
          '${month.net.format()} — income less spending, not a bank '
          'balance.',
      insights: [
        AssistantInsight(
          title: 'This month',
          amount: month.net,
          caption: 'Income less spending',
          rows: [
            InsightRow(label: 'Money in', value: month.income.format()),
            InsightRow(label: 'Money out', value: month.expenses.format()),
          ],
          tone: month.net.isNegative ? InsightTone.warning : InsightTone.good,
        ),
      ],
      followUps: ['Compare my income this year with last year.'],
    );
  }

  AssistantReply _incomeComparison(FinancialSnapshot snapshot) {
    final thisYear = snapshot.thisYear.income.minorUnits;
    final lastYear = snapshot.lastYear.income.minorUnits;

    if (lastYear == 0) {
      return AssistantReply(
        text:
            'You have recorded ${snapshot.thisYear.income.format()} of income '
            'so far this year. There is nothing recorded for last year to '
            'compare it with.',
        insights: [
          AssistantInsight(
            title: 'Income this year',
            amount: snapshot.thisYear.income,
            caption: '${snapshot.today.year}, so far',
          ),
        ],
      );
    }

    final difference = thisYear - lastYear;
    final share = (difference / lastYear * 100).abs().round();
    final direction = difference >= 0 ? 'more' : 'less';

    return AssistantReply(
      text:
          'So far in ${snapshot.today.year} you have recorded '
          '${snapshot.thisYear.income.format()} of income. In '
          '${snapshot.today.year - 1} it was '
          '${snapshot.lastYear.income.format()} — about $share% $direction. '
          'The year is not over, so this is a part-year comparison.',
      insights: [
        AssistantInsight(
          title: 'Income by year',
          rows: [
            InsightRow(
              label: '${snapshot.today.year}',
              value: snapshot.thisYear.income.format(),
            ),
            InsightRow(
              label: '${snapshot.today.year - 1}',
              value: snapshot.lastYear.income.format(),
            ),
          ],
          tone: difference >= 0 ? InsightTone.good : InsightTone.watch,
        ),
      ],
      followUps: ['Give me a summary of my finances this month.'],
    );
  }

  AssistantReply _budgetStatus(FinancialSnapshot snapshot) {
    final overall = snapshot.budgets.overall;
    if (overall == null) {
      return const AssistantReply(
        text:
            'You have not set an overall budget for this month, so there is '
            'no limit for me to measure against. You can set one on the '
            'Budgets screen.',
        followUps: ['Which budget is close to its limit?'],
      );
    }

    final verdict = overall.isOver
        ? 'You are over your budget for this month.'
        : 'Yes — you are within your budget.';

    return AssistantReply(
      text:
          '$verdict You have used ${overall.percent}% of it: '
          '${overall.spent.format()} of ${overall.budget.amount.format()}, '
          'with ${overall.isOver ? '${overall.overspend.format()} over' : '${overall.remaining.format()} remaining'}.',
      insights: [
        AssistantInsight(
          title: 'Monthly budget',
          amount: overall.isOver ? overall.overspend : overall.remaining,
          caption: overall.isOver ? 'Over the limit' : 'Left to spend',
          ratio: overall.ratio > 1 ? 1 : overall.ratio,
          tone: overall.isOver ? InsightTone.warning : InsightTone.good,
          rows: [
            InsightRow(label: 'Spent', value: overall.spent.format()),
            InsightRow(label: 'Budget', value: overall.budget.amount.format()),
          ],
        ),
      ],
      followUps: ['Which budget is close to its limit?'],
    );
  }

  AssistantReply _budgetPressure(FinancialSnapshot snapshot) {
    final pressing = [
      for (final progress in snapshot.budgets.categories)
        if (progress.status.needsAttention) progress,
    ];

    if (snapshot.budgets.categories.isEmpty) {
      return const AssistantReply(
        text:
            'You have no category budgets set for this month, so there is '
            'nothing close to a limit. Setting one for your biggest category '
            'is usually the place to start.',
        followUps: ['What is my biggest spending category?'],
      );
    }

    if (pressing.isEmpty) {
      return AssistantReply(
        text:
            'None of your ${snapshot.budgets.categories.length} category '
            'budgets need attention right now — they are all comfortably '
            'within their limits.',
        insights: [
          AssistantInsight(
            title: 'Category budgets',
            rows: [
              for (final progress in snapshot.budgets.categories.take(3))
                InsightRow(
                  label: progress.budget.name,
                  value: '${progress.percent}% used',
                  share: progress.ratio > 1 ? 1 : progress.ratio,
                ),
            ],
            tone: InsightTone.good,
          ),
        ],
      );
    }

    final worst = pressing.first;
    return AssistantReply(
      text:
          '${pressing.length} of your budgets need attention. '
          '${worst.budget.name} is the most pressing at ${worst.percent}% — '
          '${worst.isOver ? '${worst.overspend.format()} over its limit' : 'only ${worst.remaining.format()} left'}.',
      insights: [
        AssistantInsight(
          title: 'Needs attention',
          tone: InsightTone.warning,
          rows: [
            for (final progress in pressing)
              InsightRow(
                label: progress.budget.name,
                value:
                    '${progress.spent.format()} of ${progress.budget.amount.format()}',
                share: progress.ratio > 1 ? 1 : progress.ratio,
              ),
          ],
        ),
      ],
      followUps: ['Where can I reduce my expenses?'],
    );
  }

  AssistantReply _savingsTotal(FinancialSnapshot snapshot) {
    final board = snapshot.savings;
    if (board.active.isEmpty && board.completed.isEmpty) {
      return const AssistantReply(
        text:
            'You have not set any savings goals yet. Creating one — even a '
            'small one — is what turns money left over into money set '
            'aside.',
        followUps: ['Give me a summary of my finances this month.'],
      );
    }

    final leading = board.active.isEmpty ? null : board.active.first;
    final text = leading == null
        ? 'All of your goals are complete. Nothing is in progress right now.'
        : 'You have ${board.totalSaved.format()} set aside across '
              '${board.activeCount} active '
              '${board.activeCount == 1 ? 'goal' : 'goals'}, out of '
              '${board.totalTarget.format()}. ${leading.goal.name} is '
              'furthest along at ${leading.cappedPercent}%, with '
              '${leading.remaining.format()} to go.';

    return AssistantReply(
      text: text,
      insights: [
        AssistantInsight(
          title: 'Set aside',
          amount: board.totalSaved,
          caption: 'Across active goals',
          ratio: board.barValue,
          tone: InsightTone.good,
          rows: [
            for (final progress in board.active.take(3))
              InsightRow(
                label: progress.goal.name,
                value:
                    '${progress.saved.format()} of ${progress.goal.target.format()}',
                share: progress.barValue,
              ),
          ],
        ),
      ],
      followUps: ['How can I reach my savings goal faster?'],
    );
  }

  AssistantReply _savingsAdvice(FinancialSnapshot snapshot) {
    final board = snapshot.savings;
    if (board.active.isEmpty) {
      return const AssistantReply(
        text:
            'There is no goal in progress at the moment. Setting one gives '
            'the money somewhere to go.',
      );
    }

    final goal = board.active.first;
    final unbudgeted = snapshot.budgets.unbudgetedSpending;

    final lines = <String>[
      '${goal.goal.name} needs ${goal.remaining.format()} more to reach '
          '${goal.goal.target.format()}.',
      'I will not guess a date for you — that depends on what you put in. '
          'What I can see is where the money is going now:',
    ];

    if (unbudgeted.minorUnits > 0) {
      lines.add(
        '• ${unbudgeted.format()} went on categories with no budget this '
        'month. A limit there is the most direct way to free something up.',
      );
    }
    final top = snapshot.topCategory;
    if (top != null) {
      lines.add(
        '• ${top.label} is your largest category at ${top.amount.format()}. '
        'Even a tenth of that each month adds up against this goal.',
      );
    }

    return AssistantReply(
      text: lines.join('\n'),
      insights: [
        AssistantInsight(
          title: goal.goal.name,
          amount: goal.remaining,
          caption: 'Still to go',
          ratio: goal.barValue,
          tone: InsightTone.neutral,
        ),
      ],
      followUps: ['Where can I reduce my expenses?'],
    );
  }

  AssistantReply _summary(FinancialSnapshot snapshot) {
    final month = snapshot.thisMonth;
    final overall = snapshot.budgets.overall;
    final board = snapshot.savings;

    final lines = <String>[
      'Here is this month so far.',
      '• In: ${month.income.format()}, out: ${month.expenses.format()}, '
          'leaving ${month.net.format()}.',
    ];

    final top = snapshot.topCategory;
    if (top != null) {
      lines.add(
        '• Biggest category: ${top.label} at ${top.amount.format()} '
        '(${top.percent}%).',
      );
    }
    if (overall != null) {
      lines.add(
        '• Budget: ${overall.percent}% used, '
        '${overall.isOver ? '${overall.overspend.format()} over' : '${overall.remaining.format()} left'}.',
      );
    }
    if (board.active.isNotEmpty) {
      lines.add(
        '• Savings: ${board.totalSaved.format()} set aside across '
        '${board.activeCount} '
        '${board.activeCount == 1 ? 'goal' : 'goals'}.',
      );
    }

    return AssistantReply(
      text: lines.join('\n'),
      insights: [
        AssistantInsight(
          title: 'This month',
          amount: month.net,
          caption: 'Income less spending',
          tone: month.net.isNegative ? InsightTone.warning : InsightTone.good,
          rows: [
            InsightRow(label: 'Money in', value: month.income.format()),
            InsightRow(label: 'Money out', value: month.expenses.format()),
            if (overall != null)
              InsightRow(
                label: 'Budget used',
                value: '${overall.percent}%',
                share: overall.ratio > 1 ? 1 : overall.ratio,
              ),
          ],
        ),
      ],
      followUps: ['What changed compared with last month?'],
    );
  }

  AssistantReply _monthComparison(FinancialSnapshot snapshot) {
    final thisMonth = snapshot.thisMonth.expenses.minorUnits;
    final lastMonth = snapshot.lastMonth.expenses.minorUnits;

    if (lastMonth == 0) {
      return AssistantReply(
        text:
            'There is nothing recorded for last month, so I have nothing to '
            'compare this month with. So far this month you have spent '
            '${snapshot.thisMonth.expenses.format()}.',
      );
    }

    final difference = thisMonth - lastMonth;
    final share = (difference / lastMonth * 100).abs().round();
    final direction = difference >= 0 ? 'more' : 'less';
    final amount = Money(difference.abs());

    return AssistantReply(
      text:
          'You have spent ${snapshot.thisMonth.expenses.format()} this month '
          'against ${snapshot.lastMonth.expenses.format()} last month — '
          '${amount.format()} $direction, about $share%. Bear in mind this '
          'month is not finished yet.',
      insights: [
        AssistantInsight(
          title: 'Spending, month on month',
          rows: [
            InsightRow(
              label: 'This month',
              value: snapshot.thisMonth.expenses.format(),
            ),
            InsightRow(
              label: 'Last month',
              value: snapshot.lastMonth.expenses.format(),
            ),
          ],
          tone: difference > 0 ? InsightTone.watch : InsightTone.good,
        ),
      ],
      followUps: ['What is my biggest spending category?'],
    );
  }

  AssistantReply _help() => const AssistantReply(
    text:
        'I can answer questions about the money you have recorded in '
        'LifePilot — what you spent, what came in, how your budgets are '
        'doing and how your savings goals are coming along.\n\n'
        'I do not give investment or tax advice, and I only see what is in '
        'this app.',
    followUps: [
      'How much did I spend this month?',
      'Am I within my budget?',
      'How much have I saved this year?',
    ],
  );

  // ------------------------------------------------------------ helpers

  List<InsightRow> _categoryRows(ReportData report, {required int take}) => [
    for (final slice in report.categories.take(take))
      InsightRow(
        label: slice.label,
        value: slice.amount.format(),
        share: slice.share,
      ),
  ];
}
