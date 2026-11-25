"""Command-line interface.

Run `lifepilot --help`, or `python -m lifepilot --help` without installing.
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
from datetime import date as Date

from . import categorize, db, importers, reports
from .models import UNCATEGORIZED, Budget, Rule, Transaction, parse_date
from .money import format_money, parse_money


# --- output helpers -------------------------------------------------------


def _table(headers: list[str], rows: list[list[str]], *, right: set[int] = frozenset()) -> str:
    if not rows:
        return "(nothing to show)"
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt(cells: list[str]) -> str:
        return "  ".join(
            cell.rjust(widths[i]) if i in right else cell.ljust(widths[i])
            for i, cell in enumerate(cells)
        ).rstrip()

    lines = [fmt(headers), "  ".join("-" * w for w in widths)]
    lines.extend(fmt(row) for row in rows)
    return "\n".join(lines)


def _bar(share: float, width: int = 20) -> str:
    filled = max(0, min(width, round(share * width)))
    return "#" * filled + "." * (width - filled)


def _resolve_range(args: argparse.Namespace) -> tuple[str | None, str | None]:
    """Turn --month / --from / --to into inclusive ISO bounds."""
    if getattr(args, "month", None):
        return reports.month_bounds(args.month)
    start = parse_date(args.start).isoformat() if getattr(args, "start", None) else None
    end = parse_date(args.end).isoformat() if getattr(args, "end", None) else None
    return start, end


def _range_label(start: str | None, end: str | None) -> str:
    if start and end:
        return f"{start} to {end}"
    if start:
        return f"since {start}"
    if end:
        return f"up to {end}"
    return "all time"


# --- commands -------------------------------------------------------------


def cmd_init(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    path = db.resolve_db_path(args.db)
    added = 0 if args.no_seed else categorize.seed_default_rules(conn)
    print(f"Database ready at {path}")
    if added:
        print(f"Seeded {added} starter categorization rules (edit with `lifepilot rules`).")
    return 0


def cmd_add(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    tx = Transaction(
        date=parse_date(args.date) if args.date else Date.today(),
        description=args.description,
        amount_cents=parse_money(args.amount),
        account=args.account,
        category=args.category or categorize.categorize(args.description, db.list_rules(conn)),
        notes=args.notes or "",
    )
    tx_id = db.add_transaction(conn, tx)
    if tx_id is None:
        print("Already recorded an identical transaction; nothing added.")
        return 1
    print(
        f"Added #{tx_id}: {tx.date} {tx.description} "
        f"{format_money(tx.amount_cents)} [{tx.category}]"
    )
    return 0


def cmd_import(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    try:
        result = importers.read_csv(
            args.path,
            account=args.account,
            date_column=args.date_column,
            description_column=args.description_column,
            amount_column=args.amount_column,
            flip_signs=args.flip_signs,
        )
    except (OSError, ValueError) as exc:
        print(f"Import failed: {exc}", file=sys.stderr)
        return 2

    rules = db.list_rules(conn)
    for tx in result.transactions:
        tx.category = categorize.categorize(tx.description, rules)

    for warning in result.warnings:
        print(f"warning: {warning}", file=sys.stderr)

    if args.dry_run:
        rows = [
            [tx.date.isoformat(), tx.description[:40], format_money(tx.amount_cents), tx.category]
            for tx in result.transactions[: args.limit]
        ]
        print(_table(["DATE", "DESCRIPTION", "AMOUNT", "CATEGORY"], rows, right={2}))
        print(f"\nDry run: {len(result.transactions)} transaction(s) parsed, nothing written.")
        return 0

    inserted, skipped = db.add_transactions(conn, result.transactions)
    print(f"Imported {inserted} transaction(s) into account '{args.account}'.")
    if skipped:
        print(f"Skipped {skipped} duplicate(s) already in the database.")
    uncategorized = sum(1 for tx in result.transactions if tx.category == UNCATEGORIZED)
    if uncategorized:
        print(
            f"{uncategorized} transaction(s) are uncategorized - "
            "add rules, then run `lifepilot recategorize`."
        )
    return 0


def cmd_list(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    start, end = _resolve_range(args)
    txs = db.list_transactions(
        conn,
        start=start,
        end=end,
        category=args.category,
        account=args.account,
        search=args.search,
        limit=args.limit,
    )
    rows = [
        [
            str(tx.id),
            tx.date.isoformat(),
            tx.description[:44],
            format_money(tx.amount_cents),
            tx.category,
            tx.account,
        ]
        for tx in txs
    ]
    print(_table(["ID", "DATE", "DESCRIPTION", "AMOUNT", "CATEGORY", "ACCOUNT"], rows, right={0, 3}))
    if txs:
        total = sum(tx.amount_cents for tx in txs)
        print(f"\n{len(txs)} transaction(s), net {format_money(total)}")
    return 0


def cmd_recategorize(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    changed = categorize.apply_rules(conn, only_uncategorized=not args.all)
    scope = "all transactions" if args.all else "uncategorized transactions"
    print(f"Recategorized {changed} transaction(s) across {scope}.")
    return 0


def cmd_set_category(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    if not db.set_category(conn, args.id, args.category):
        print(f"No transaction #{args.id}.", file=sys.stderr)
        return 1
    print(f"#{args.id} is now '{args.category}'.")
    return 0


def cmd_delete(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    if not db.delete_transaction(conn, args.id):
        print(f"No transaction #{args.id}.", file=sys.stderr)
        return 1
    print(f"Deleted #{args.id}.")
    return 0


def cmd_rules(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    if args.rules_action == "list":
        rows = [
            [str(r.id), r.pattern, r.category, str(r.priority), "regex" if r.is_regex else "text"]
            for r in db.list_rules(conn)
        ]
        print(_table(["ID", "PATTERN", "CATEGORY", "PRIORITY", "KIND"], rows, right={0, 3}))
        return 0

    if args.rules_action == "add":
        rule = Rule(
            pattern=args.pattern,
            category=args.category,
            priority=args.priority,
            is_regex=args.regex,
        )
        rule_id = db.add_rule(conn, rule)
        if rule_id is None:
            print("That pattern/category pair already exists.")
            return 1
        print(f"Added rule #{rule_id}: '{rule.pattern}' -> {rule.category}")
        return 0

    if args.rules_action == "rm":
        if not db.delete_rule(conn, args.id):
            print(f"No rule #{args.id}.", file=sys.stderr)
            return 1
        print(f"Deleted rule #{args.id}.")
        return 0

    if args.rules_action == "seed":
        print(f"Added {categorize.seed_default_rules(conn)} starter rule(s).")
        return 0

    return 2


def cmd_budget(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    if args.budget_action == "list":
        rows = [[b.category, format_money(b.monthly_cents)] for b in db.list_budgets(conn)]
        print(_table(["CATEGORY", "MONTHLY"], rows, right={1}))
        return 0

    if args.budget_action == "set":
        cents = abs(parse_money(args.amount))
        db.set_budget(conn, Budget(category=args.category, monthly_cents=cents))
        print(f"Budget for '{args.category}' set to {format_money(cents)}/month.")
        return 0

    if args.budget_action == "rm":
        if not db.delete_budget(conn, args.category):
            print(f"No budget for '{args.category}'.", file=sys.stderr)
            return 1
        print(f"Removed budget for '{args.category}'.")
        return 0

    return 2


def cmd_report(args: argparse.Namespace, conn: sqlite3.Connection) -> int:
    if args.report_action == "summary":
        start, end = _resolve_range(args)
        s = reports.summary(conn, start=start, end=end)
        print(f"Summary - {_range_label(start, end)}")
        print(f"  Income    {format_money(s.income_cents):>14}")
        print(f"  Expenses  {format_money(s.expense_cents):>14}")
        print(f"  Net       {format_money(s.net_cents):>14}")
        if s.income_cents > 0:
            print(f"  Saved     {s.savings_rate:>13.1%}")
        print(f"  ({s.count} transaction(s); transfers excluded)")
        return 0

    if args.report_action == "categories":
        start, end = _resolve_range(args)
        totals = reports.by_category(conn, start=start, end=end, expenses_only=not args.income)
        kind = "Income" if args.income else "Spending"
        print(f"{kind} by category - {_range_label(start, end)}\n")
        rows = [
            [t.category, format_money(t.total_cents), str(t.count), f"{t.share:.1%}", _bar(t.share)]
            for t in totals
        ]
        print(_table(["CATEGORY", "TOTAL", "N", "SHARE", ""], rows, right={1, 2, 3}))
        return 0

    if args.report_action == "trend":
        trend = reports.monthly_trend(conn, months=args.months)
        rows = [
            [
                month,
                format_money(s.income_cents),
                format_money(s.expense_cents),
                format_money(s.net_cents),
            ]
            for month, s in trend
        ]
        print(_table(["MONTH", "INCOME", "EXPENSES", "NET"], rows, right={1, 2, 3}))
        return 0

    if args.report_action == "budget":
        month = args.month or reports.current_month()
        lines = reports.budget_report(conn, month)
        if not lines:
            print("No budgets set yet. Try `lifepilot budget set groceries 400`.")
            return 0
        print(f"Budget vs actual - {month}\n")
        rows = [
            [
                line.category,
                format_money(line.budget_cents),
                format_money(line.spent_cents),
                format_money(line.remaining_cents),
                f"{line.used_share:.0%}" + (" OVER" if line.over_budget else ""),
                _bar(min(line.used_share, 1.0)),
            ]
            for line in lines
        ]
        print(_table(["CATEGORY", "BUDGET", "SPENT", "LEFT", "USED", ""], rows, right={1, 2, 3, 4}))
        return 0

    return 2


# --- parser ---------------------------------------------------------------


def _add_range_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--month", help="restrict to one month, as YYYY-MM")
    parser.add_argument("--from", dest="start", help="start date (inclusive)")
    parser.add_argument("--to", dest="end", help="end date (inclusive)")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lifepilot", description="Track personal finances from the command line."
    )
    parser.add_argument("--db", help="database file (default: $LIFEPILOT_DB or data/finance.db)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("init", help="create the database")
    p.add_argument("--no-seed", action="store_true", help="skip the starter categorization rules")
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("add", help="record one transaction")
    p.add_argument("description")
    p.add_argument("amount", help="negative for spending, e.g. -42.50")
    p.add_argument("--date", help="default: today")
    p.add_argument("--account", default="default")
    p.add_argument("--category", help="default: whatever the rules match")
    p.add_argument("--notes")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("import", help="import a CSV bank export")
    p.add_argument("path")
    p.add_argument("--account", default="default")
    p.add_argument("--date-column")
    p.add_argument("--description-column")
    p.add_argument("--amount-column")
    p.add_argument("--flip-signs", action="store_true", help="export lists expenses as positive")
    p.add_argument("--dry-run", action="store_true", help="parse and print, write nothing")
    p.add_argument("--limit", type=int, default=20, help="rows to show in a dry run")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("list", help="list transactions")
    _add_range_args(p)
    p.add_argument("--category")
    p.add_argument("--account")
    p.add_argument("--search", help="match text in the description")
    p.add_argument("--limit", type=int, default=50)
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("recategorize", help="re-run rules over stored transactions")
    p.add_argument("--all", action="store_true", help="also revisit already-categorized rows")
    p.set_defaults(func=cmd_recategorize)

    p = sub.add_parser("set-category", help="set one transaction's category by hand")
    p.add_argument("id", type=int)
    p.add_argument("category")
    p.set_defaults(func=cmd_set_category)

    p = sub.add_parser("delete", help="delete a transaction")
    p.add_argument("id", type=int)
    p.set_defaults(func=cmd_delete)

    p = sub.add_parser("rules", help="manage categorization rules")
    rsub = p.add_subparsers(dest="rules_action", required=True)
    rsub.add_parser("list", help="show all rules")
    radd = rsub.add_parser("add", help="add a rule")
    radd.add_argument("pattern")
    radd.add_argument("category")
    radd.add_argument("--priority", type=int, default=100, help="lower wins (default 100)")
    radd.add_argument("--regex", action="store_true", help="treat the pattern as a regex")
    rrm = rsub.add_parser("rm", help="delete a rule")
    rrm.add_argument("id", type=int)
    rsub.add_parser("seed", help="add the starter ruleset")
    p.set_defaults(func=cmd_rules)

    p = sub.add_parser("budget", help="manage monthly budgets")
    bsub = p.add_subparsers(dest="budget_action", required=True)
    bsub.add_parser("list", help="show all budgets")
    bset = bsub.add_parser("set", help="set a category's monthly budget")
    bset.add_argument("category")
    bset.add_argument("amount")
    brm = bsub.add_parser("rm", help="remove a budget")
    brm.add_argument("category")
    p.set_defaults(func=cmd_budget)

    p = sub.add_parser("report", help="summaries and breakdowns")
    rpsub = p.add_subparsers(dest="report_action", required=True)
    rsum = rpsub.add_parser("summary", help="income, expenses, net")
    _add_range_args(rsum)
    rcat = rpsub.add_parser("categories", help="breakdown by category")
    _add_range_args(rcat)
    rcat.add_argument("--income", action="store_true", help="break down income instead of spending")
    rtr = rpsub.add_parser("trend", help="month-by-month totals")
    rtr.add_argument("--months", type=int, default=6)
    rbud = rpsub.add_parser("budget", help="budget vs actual for a month")
    rbud.add_argument("--month", help="default: this month")
    p.set_defaults(func=cmd_report)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        with db.session(args.db) as conn:
            return args.func(args, conn)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
