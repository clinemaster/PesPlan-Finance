import 'report_data.dart';
import 'report_period.dart';

/// Where reports come from.
///
/// The screen asks for a [ReportData] — totalled, bucketed, ranked and
/// with its metrics already chosen — rather than raw records it would have
/// to analyse. That keeps the analysis on the far side of this boundary,
/// which is where a reporting API will sit.
abstract interface class ReportRepository {
  /// The report for [period].
  Future<ReportData> report(ReportPeriod period);

  /// Two years, side by side.
  Future<YearComparison> compareYears(int earlier, int later);

  /// Years that actually hold records, newest first.
  ///
  /// The comparison screen offers these rather than a free year picker,
  /// so a user cannot select two empty years and conclude the feature is
  /// broken.
  Future<List<int>> yearsWithData();
}
