import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import '../money/money.dart';

/// A labelled text field.
///
/// ## Why the label sits above the field
///
/// Material's floating label animates into the border, which saves vertical
/// space and costs clarity: at a large text scale the floating label crops,
/// and a half-filled form becomes hard to scan. A static label above the
/// field stays readable at every text size and is what a first-time user
/// expects from a paper form.
///
/// ## Errors
///
/// An error is red **and** worded. The message says what to do ("Enter an
/// amount greater than zero"), not what went wrong ("Invalid input"), and it
/// is announced to a screen reader through the field's semantics.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction,
    this.autofocus = false,
    this.isRequired = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// Non-null puts the field in its error state.
  final String? error;

  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool autofocus;

  /// Marks the field required, visually and in semantics.
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible, not bare: a label long enough to be a question
            // overflows a 320px screen, and the required marker beside it
            // leaves no room to shrink into. Wrapping is better than a
            // yellow-and-black stripe.
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: enabled ? finance.textPrimary : finance.textDisabled,
                ),
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: AppTypography.label.copyWith(color: finance.expense),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          textField: true,
          label: label,
          hint: hint,
          // The validation message travels with the field, so a screen reader
          // hears it rather than only sighted users seeing red.
          value: hasError ? error : null,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: obscureText ? 1 : maxLines,
            onChanged: onChanged,
            textInputAction: textInputAction,
            autofocus: autofocus,
            style: AppTypography.bodyLarge.copyWith(
              color: enabled ? finance.textPrimary : finance.textDisabled,
            ),
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              helperText: helper,
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, size: AppIconSize.md),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// A field for entering an amount of money.
///
/// ## The one place a client touches a number
///
/// The app never computes money (architecture Rule 1), but it has to *accept*
/// it. This field is that boundary, and it is deliberately narrow:
///
/// * The keyboard is numeric, with a decimal point only where the currency
///   has subunits — TZS has none, so the user is not offered a decimal key
///   they must not use.
/// * Input is filtered to digits and at most one separator, so a stray letter
///   never reaches the parser.
/// * [onChangedMinorUnits] reports an **integer minor-unit** value, matching
///   the backend contract. No `double` crosses this boundary.
///
/// The currency symbol is shown as a prefix so the user always knows what
/// they are entering, and the figure uses the tabular amount style so digits
/// line up as they type.
class AmountField extends StatelessWidget {
  const AmountField({
    required this.label,
    super.key,
    this.controller,
    this.currency = Currency.tzs,
    this.error,
    this.helper,
    this.enabled = true,
    this.autofocus = false,
    this.onChangedMinorUnits,
  });

  final String label;
  final TextEditingController? controller;
  final Currency currency;
  final String? error;
  final String? helper;
  final bool enabled;
  final bool autofocus;

  /// Reports the parsed value in integer minor units, or `null` when the
  /// field does not currently hold a valid amount.
  final ValueChanged<int?>? onChangedMinorUnits;

  /// Digits, plus one decimal separator for currencies that have subunits.
  List<TextInputFormatter> get _formatters => [
    FilteringTextInputFormatter.allow(
      currency.decimalDigits == 0 ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
    ),
    _SingleSeparatorFormatter(maxDecimals: currency.decimalDigits),
  ];

  /// Text to integer minor units. Returns `null` for anything unparseable,
  /// so the caller can distinguish "empty" from "zero".
  int? _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final parts = text.split('.');
    final wholeText = parts.first.isEmpty ? '0' : parts.first;
    final whole = int.tryParse(wholeText);
    if (whole == null) return null;

    if (currency.decimalDigits == 0) return whole;

    final fractionText = (parts.length > 1 ? parts[1] : '')
        .padRight(currency.decimalDigits, '0')
        .substring(0, currency.decimalDigits);
    final fraction = int.tryParse(fractionText) ?? 0;

    var scale = 1;
    for (var i = 0; i < currency.decimalDigits; i++) {
      scale *= 10;
    }
    return whole * scale + fraction;
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: enabled ? finance.textPrimary : finance.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          textField: true,
          label: '$label in ${currency.code}',
          value: hasError ? error : null,
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: currency.decimalDigits == 0
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _formatters,
            onChanged: onChangedMinorUnits == null
                ? null
                : (value) => onChangedMinorUnits!(_parse(value)),
            // Tabular figures so the number does not shift as digits change.
            style: AppTypography.amountLarge.copyWith(
              color: enabled ? finance.textPrimary : finance.textDisabled,
            ),
            decoration: InputDecoration(
              hintText: currency.decimalDigits == 0 ? '0' : '0.00',
              errorText: error,
              helperText: helper,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.sm,
                ),
                child: Text(
                  currency.symbol,
                  style: AppTypography.amountLarge.copyWith(
                    color: finance.textSecondary,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
          ),
        ),
      ],
    );
  }
}

/// Allows at most one decimal separator and caps the fractional digits.
class _SingleSeparatorFormatter extends TextInputFormatter {
  const _SingleSeparatorFormatter({required this.maxDecimals});

  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if (text.split('.').length > 2) return oldValue;

    final separator = text.indexOf('.');
    if (separator >= 0 && text.length - separator - 1 > maxDecimals) {
      return oldValue;
    }

    return newValue;
  }
}

/// A search field.
///
/// Rounded, filled, with a leading magnifier and a clear button that appears
/// only when there is something to clear — an always-visible clear button on
/// an empty field is a target that does nothing.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final hasText = _controller.text.isNotEmpty;

    return Semantics(
      textField: true,
      label: widget.hint,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {});
          widget.onChanged?.call(value);
        },
        onSubmitted: widget.onSubmitted,
        style: AppTypography.bodyLarge.copyWith(color: finance.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          fillColor: finance.surfaceMuted,
          prefixIcon: Icon(
            AppIcons.search,
            size: AppIconSize.md,
            color: finance.textSecondary,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(AppIcons.close, size: AppIconSize.md),
                  color: finance.textSecondary,
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged?.call('');
                  },
                )
              : null,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

/// A labelled dropdown.
///
/// Uses the platform menu rather than a custom overlay, so it inherits the
/// system's scrolling, dismissal and accessibility behaviour.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.itemLabel,
    super.key,
    this.hint,
    this.error,
    this.enabled = true,
  });

  final String label;
  final List<T> items;
  final T? value;
  final ValueChanged<T?>? onChanged;

  /// How to render each item. Keeps the widget generic without forcing
  /// callers to implement `toString`.
  final String Function(T item) itemLabel;

  final String? hint;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    // DropdownButtonFormField installs its own DefaultTextStyle from `style`,
    // which resets a null fontFamily instead of inheriting the ambient one.
    // Resolving the family here keeps the dropdown's text in the same face as
    // every other label. Production is unaffected (both resolve to the
    // platform default); without it the font only diverges where the ambient
    // family is explicit.
    final ambient = DefaultTextStyle.of(context).style;
    final itemStyle = AppTypography.bodyLarge.copyWith(
      color: enabled ? finance.textPrimary : finance.textDisabled,
      fontFamily: ambient.fontFamily,
      fontFamilyFallback: ambient.fontFamilyFallback,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: enabled ? finance.textPrimary : finance.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<T>(
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          icon: Icon(AppIcons.chevronDown, color: finance.textSecondary),
          style: itemStyle,
          decoration: InputDecoration(hintText: hint, errorText: error),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), style: itemStyle),
              ),
          ],
        ),
      ],
    );
  }
}

/// A date selector that opens the platform date picker.
///
/// Read-only text plus a calendar icon: typing a date is error-prone and
/// locale-dependent, and the picker already solves both.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.hint = 'Select a date',
    this.error,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;

  /// Pre-formatted display text, or `null` when nothing is chosen.
  /// Formatting is a localisation concern and stays with the caller.
  final String? value;

  final ValueChanged<DateTime> onChanged;
  final String hint;
  final String? error;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? now,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: enabled ? finance.textPrimary : finance.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          label: '$label. ${hasValue ? value! : hint}',
          excludeSemantics: true,
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: AppRadius.inputAll,
            child: Container(
              height: AppSpacing.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.inputAll,
                border: Border.all(
                  color: error != null ? finance.expense : finance.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.calendar,
                    size: AppIconSize.md,
                    color: finance.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      hasValue ? value! : hint,
                      style: AppTypography.bodyLarge.copyWith(
                        color: hasValue
                            ? finance.textPrimary
                            : finance.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            error!,
            style: AppTypography.caption.copyWith(color: finance.expenseText),
          ),
        ],
      ],
    );
  }
}

/// Currency selection.
///
/// The foundation for global expansion: TZS leads because Tanzania ships
/// first, and each option shows the code, the symbol and the name so a user
/// is never guessing what "KSh" means.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    required this.value,
    required this.onChanged,
    super.key,
    this.label = 'Currency',
    this.options = Currency.supported,
  });

  final Currency value;
  final ValueChanged<Currency?> onChanged;
  final String label;
  final List<Currency> options;

  static const Map<String, String> _names = {
    'TZS': 'Tanzanian Shilling',
    'KES': 'Kenyan Shilling',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
  };

  @override
  Widget build(BuildContext context) {
    return AppDropdown<Currency>(
      label: label,
      items: options,
      value: value,
      onChanged: onChanged,
      itemLabel: (currency) =>
          '${currency.code} · ${currency.symbol} · '
          '${_names[currency.code] ?? currency.code}',
    );
  }
}
