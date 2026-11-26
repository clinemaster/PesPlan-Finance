import 'package:material_ui/material_ui.dart';

/// One icon family, named by meaning.
///
/// ## Why a map instead of using `Icons.*` directly
///
/// Two problems appear in every growing app. First, mixed families: someone
/// reaches for a filled icon on one screen and an outlined one on the next,
/// and the UI starts to look assembled rather than designed. Second, drift:
/// "add" is `Icons.add` here and `Icons.add_circle` there.
///
/// Both are solved by naming icons for what they *mean* in LifePilot and
/// resolving them in one place. Screens write `AppIcons.income`, not
/// `Icons.arrow_downward`.
///
/// **The family is Material Symbols Rounded (the `*_rounded` variants).**
/// Rounded matches the 12px corner radii of cards and buttons; the sharp and
/// filled families do not. Adding a non-rounded icon is a visual regression.
abstract final class AppIcons {
  const AppIcons._();

  // ------------------------------------------------------------ navigation
  static const IconData home = Icons.home_rounded;
  static const IconData transactions = Icons.receipt_long_rounded;
  static const IconData budgets = Icons.account_balance_wallet_rounded;
  static const IconData goals = Icons.flag_rounded;
  static const IconData insights = Icons.insights_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData profile = Icons.person_rounded;

  /// The conversational helper. A sparkle rather than a robot or a speech
  /// bubble: the first says "something clever happens here", the other two
  /// promise either a machine or a chat transcript, and the feature is
  /// neither.
  static const IconData assistant = Icons.auto_awesome_rounded;

  /// Outlined, unlike its neighbours, because a filled bell reads as "you
  /// have unread items" even when the badge is absent.
  static const IconData notifications = Icons.notifications_none_rounded;

  /// Speaking an amount instead of typing it. Shares the money group's
  /// logic: the icon names the input method, not the device.
  static const IconData voice = Icons.mic_rounded;

  // ---------------------------------------------------------------- money
  // Direction is the meaning: money arriving points in, money leaving
  // points out. Arrows are used rather than +/- because they survive
  // translation and read instantly to a first-time user.
  static const IconData income = Icons.south_west_rounded;
  static const IconData expense = Icons.north_east_rounded;
  static const IconData savings = Icons.savings_rounded;
  static const IconData balance = Icons.account_balance_rounded;
  static const IconData transfer = Icons.swap_horiz_rounded;
  static const IconData currency = Icons.payments_rounded;

  // --------------------------------------------------------------- actions
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list_rounded;
  static const IconData sort = Icons.swap_vert_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData share = Icons.ios_share_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData upload = Icons.upload_file_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData chevronDown = Icons.expand_more_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData visible = Icons.visibility_rounded;
  static const IconData hidden = Icons.visibility_off_rounded;

  // ---------------------------------------------------------------- status
  // Each status icon ships beside a text label. An icon alone — like a
  // colour alone — is not an accessible way to state a status.
  static const IconData success = Icons.check_circle_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData pending = Icons.schedule_rounded;

  // -------------------------------------------------------------- spending
  // Everyday categories. Deliberately ordinary objects — a first-time user
  // should not have to decode a metaphor.
  static const IconData groceries = Icons.shopping_basket_rounded;
  static const IconData dining = Icons.restaurant_rounded;
  static const IconData transport = Icons.directions_bus_rounded;
  static const IconData fuel = Icons.local_gas_station_rounded;
  static const IconData housing = Icons.house_rounded;
  static const IconData utilities = Icons.bolt_rounded;
  static const IconData airtime = Icons.smartphone_rounded;
  static const IconData health = Icons.medical_services_rounded;
  static const IconData education = Icons.school_rounded;
  static const IconData family = Icons.family_restroom_rounded;
  static const IconData shopping = Icons.shopping_bag_rounded;
  static const IconData entertainment = Icons.movie_rounded;
  static const IconData subscriptions = Icons.autorenew_rounded;
  static const IconData insurance = Icons.shield_rounded;
  static const IconData loan = Icons.request_quote_rounded;
  static const IconData gift = Icons.card_giftcard_rounded;
  static const IconData travel = Icons.flight_rounded;
  static const IconData business = Icons.work_rounded;
  static const IconData cash = Icons.local_atm_rounded;
  static const IconData other = Icons.category_rounded;

  /// Category key to icon.
  ///
  /// Keys are lowercase and match the backend's free-text category names
  /// (see `docs/EXISTING_DATABASE_ASSESSMENT.md` — categories are strings,
  /// not a table). [other] is the fallback, so an unrecognised category still
  /// renders rather than throwing.
  static const Map<String, IconData> byCategory = {
    'groceries': groceries,
    'dining': dining,
    'transport': transport,
    'fuel': fuel,
    'housing': housing,
    'rent': housing,
    'utilities': utilities,
    'airtime': airtime,
    'data': airtime,
    'health': health,
    'education': education,
    'school fees': education,
    'family': family,
    'shopping': shopping,
    'entertainment': entertainment,
    'subscriptions': subscriptions,
    'insurance': insurance,
    'loan': loan,
    'gift': gift,
    'travel': travel,
    'business': business,
    'cash': cash,
    'salary': income,
    'income': income,
    'savings': savings,
    'transfers': transfer,
    'uncategorized': other,
    'other': other,
  };

  /// The icon for a category name, falling back to [other].
  static IconData forCategory(String category) =>
      byCategory[category.trim().toLowerCase()] ?? other;
}
