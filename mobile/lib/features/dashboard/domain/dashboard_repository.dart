import 'dashboard_data.dart';
import 'dashboard_period.dart';

/// Where the dashboard's figures come from.
///
/// One call per period, returning everything the screen renders. A single
/// call rather than one per card because the real endpoint is one request:
/// six parallel fetches would make the dashboard six chances to fail and
/// six spinners to coordinate.
abstract interface class DashboardRepository {
  /// Figures for [period], already computed.
  Future<DashboardData> load(DashboardPeriod period);
}
