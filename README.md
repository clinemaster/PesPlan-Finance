# LifePilot Finance

A command-line personal finance tracker. Import your bank CSV exports, let rules
categorize the transactions, and report on where the money went.

- **No runtime dependencies** — standard library and SQLite only.
- **Exact money** — amounts are stored as integer cents, never floats.
- **Local data** — one SQLite file, nothing leaves your machine.
- **Idempotent imports** — re-importing an overlapping export skips duplicates.

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows; use source .venv/bin/activate elsewhere
pip install -e ".[dev]"       # drop [dev] if you don't want pytest
lifepilot init
```

You can also run it without installing:

```bash
python -m lifepilot --help
```

## Quick start

```bash
lifepilot init                                        # create the DB + starter rules
lifepilot import sample_data/transactions.csv --account current
lifepilot report summary --month 2026-11
lifepilot report categories --month 2026-11
```

```
Summary - 2026-11-01 to 2026-11-30
  Income          3,650.00
  Expenses        1,712.75
  Net             1,937.25
  Saved             53.1%
  (17 transaction(s); transfers excluded)
```

## Commands

| Command | What it does |
| --- | --- |
| `init` | Create the database and seed starter rules (`--no-seed` to skip) |
| `add DESCRIPTION AMOUNT` | Record one transaction (`--date`, `--account`, `--category`, `--notes`) |
| `import PATH` | Import a CSV export (`--dry-run` to preview) |
| `list` | List transactions, filtered by date, category, account or text |
| `recategorize` | Re-run the rules (`--all` to revisit already-categorized rows) |
| `set-category ID CATEGORY` | Override one transaction's category |
| `delete ID` | Delete a transaction |
| `rules list\|add\|rm\|seed` | Manage categorization rules |
| `budget list\|set\|rm` | Manage monthly budgets per category |
| `report summary\|categories\|trend\|budget` | Reports |

Every command accepts `--db PATH`. Date ranges accept either `--month YYYY-MM` or
`--from`/`--to`.

### Amounts

Expenses are negative, income positive:

```bash
lifepilot add "Blue Bottle Coffee" -5.40
lifepilot add "Side project invoice" 450.00 --date 2026-11-22
```

### Importing

Columns are detected from the header (`date`/`transaction date`/`posted date`,
`description`/`payee`/`memo`, `amount`, or separate `debit`/`credit` columns). When
detection guesses wrong, say so explicitly:

```bash
lifepilot import export.csv --date-column "Posting Date" --amount-column "Value"
lifepilot import export.csv --flip-signs        # export writes expenses as positive
lifepilot import export.csv --dry-run           # parse and print, write nothing
```

Unparseable rows are reported as warnings with their line number and skipped; the
rest of the file still imports. Duplicates are detected by a fingerprint of
date + description + amount + account, so overlapping statement exports are safe
to re-import.

### Categorization

A rule is a pattern plus a category. Substring patterns match case-insensitively;
`--regex` patterns are matched with `re.search`. The lowest `--priority` number
wins, so a specific rule can beat a general one:

```bash
lifepilot rules add "uber eats" dining --priority 10
lifepilot rules add "uber" transport              # priority 100 by default
lifepilot rules add "^SQ \*" shopping --regex
lifepilot recategorize
```

`recategorize` only touches uncategorized transactions, so manual corrections via
`set-category` survive; pass `--all` to let the rules overwrite them.

### Budgets

```bash
lifepilot budget set groceries 180
lifepilot report budget --month 2026-11
```

```
CATEGORY     BUDGET     SPENT    LEFT       USED
---------  --------  --------  ------  ---------
dining        80.00     93.90  -13.90  117% OVER
groceries    180.00    197.37  -17.37  110% OVER
housing    1,200.00  1,150.00   50.00        96%
```

## Notes on the numbers

- **Transfers are excluded** from summaries, category breakdowns and trends. Money
  moved between your own accounts is neither income nor spending, and counting it
  skews every total. The seeded rules put anything matching `transfer` into the
  `transfers` category.
- **Expense figures are positive magnitudes** in reports (`Expenses 1,712.75`),
  while `Net` keeps its sign so a deficit reads as negative.
- **Budgets cover expenses only** and are compared per calendar month.

## Project layout

```
src/lifepilot/
  cli.py          argparse CLI; one cmd_* function per subcommand
  db.py           SQLite schema and queries
  models.py       Transaction / Rule / Budget, date parsing
  money.py        cents <-> text, no floats
  importers.py    CSV reading and column detection
  categorize.py   rule matching and the starter ruleset
  reports.py      summaries, category breakdowns, trends, budget vs actual
tests/            pytest suite (87 tests)
sample_data/      an example CSV export
data/             your database lives here (gitignored)
```

## Tests

```bash
pytest
```

## Data location

The database is `data/finance.db` by default. Override per-command with `--db`, or
globally with the `LIFEPILOT_DB` environment variable. `.gitignore` excludes
`data/*.db` and `data/*.csv` so real financial data is never committed.
