/// Which plan the account is on.
enum Plan {
  free,
  premium;

  String get label => switch (this) {
    Plan.free => 'Free',
    Plan.premium => 'Premium',
  };

  bool get isPremium => this == Plan.premium;
}

/// One row of the plan comparison.
///
/// ## Both columns are described, not ticked
///
/// A table of ticks and crosses says "you are missing out" and very
/// little else. Saying what the free plan actually gives — "20 questions
/// a day", not a cross — is both more useful and more honest, and it
/// stops the free tier reading as a crippled demo of the paid one.
class PlanFeature {
  const PlanFeature({
    required this.title,
    required this.free,
    required this.premium,
  });

  final String title;

  /// What the free plan gives. Never empty.
  final String free;

  /// What premium gives.
  final String premium;

  /// Whether the two differ. The ones that do not are listed first, so
  /// the comparison opens with what everyone already has.
  bool get differs => free != premium;

  /// The provisional comparison.
  ///
  /// Provisional in the strongest sense: no price, no entitlement, and
  /// nothing in the app enforces a single line of it. These are a
  /// product proposal rendered as a table so it can be looked at and
  /// argued with before anyone builds billing.
  static const List<PlanFeature> all = [
    PlanFeature(
      title: 'Recording transactions',
      free: 'Unlimited',
      premium: 'Unlimited',
    ),
    PlanFeature(
      title: 'Budgets and savings goals',
      free: 'Unlimited',
      premium: 'Unlimited',
    ),
    PlanFeature(
      title: 'Monthly and yearly reports',
      free: 'Included',
      premium: 'Included',
    ),
    PlanFeature(
      title: 'Speaking a transaction',
      free: '10 a day',
      premium: 'Unlimited',
    ),
    PlanFeature(
      title: 'Assistant questions',
      free: '20 a day',
      premium: '200 a day',
    ),
    PlanFeature(
      title: 'Year-on-year comparisons',
      free: 'This year and last',
      premium: 'Every year you have recorded',
    ),
    PlanFeature(
      title: 'Spending insights',
      free: 'Category breakdown',
      premium: 'Trends, outliers and what changed',
    ),
    PlanFeature(
      title: 'Exporting your data',
      free: 'CSV',
      premium: 'CSV and PDF reports',
    ),
  ];

  /// What everyone gets, whichever plan they are on.
  static List<PlanFeature> get shared => [
    for (final feature in all)
      if (!feature.differs) feature,
  ];

  /// What premium adds.
  static List<PlanFeature> get upgrades => [
    for (final feature in all)
      if (feature.differs) feature,
  ];
}

/// The account's plan, as the app currently believes it.
///
/// ## Nothing here is enforced, and nothing has been paid
///
/// There is no billing, no store, no receipt and no entitlement check.
/// The plan is a value held in memory and on this device so the premium
/// presentation can be reviewed; every screen that shows it says so.
class Subscription {
  const Subscription({
    required this.plan,
    this.renewsOn,
    this.isMockUpgrade = false,
  });

  static const Subscription free = Subscription(plan: Plan.free);

  final Plan plan;

  /// When it would renew. Null on the free plan.
  final DateTime? renewsOn;

  /// True when premium was switched on from inside the app rather than
  /// bought. Always true in this phase — the screens label it.
  final bool isMockUpgrade;

  bool get isPremium => plan.isPremium;

  String get statusLine => switch (plan) {
    Plan.free => 'You are on the free plan.',
    Plan.premium => 'You are on Premium.',
  };
}
