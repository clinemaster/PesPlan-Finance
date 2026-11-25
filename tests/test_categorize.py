from datetime import date

from lifepilot import categorize, db
from lifepilot.models import UNCATEGORIZED, Rule, Transaction


def test_substring_match_is_case_insensitive():
    rules = [Rule(pattern="tesco", category="groceries", id=1)]
    assert categorize.categorize("TESCO SUPERMARKET 4417", rules) == "groceries"


def test_no_match_is_uncategorized():
    rules = [Rule(pattern="tesco", category="groceries", id=1)]
    assert categorize.categorize("Unknown merchant", rules) == UNCATEGORIZED


def test_regex_rule():
    rules = [Rule(pattern=r"uber\s*eats", category="dining", is_regex=True, id=1)]
    assert categorize.categorize("UBER EATS 1234", rules) == "dining"
    assert categorize.categorize("UBER TRIP 1234", rules) == UNCATEGORIZED


def test_lower_priority_number_wins():
    rules = [
        Rule(pattern="uber", category="transport", priority=100, id=1),
        Rule(pattern="uber eats", category="dining", priority=10, id=2),
    ]
    assert categorize.categorize("UBER EATS 99", rules) == "dining"


def test_broken_regex_does_not_crash():
    rules = [
        Rule(pattern="[unclosed", category="bad", is_regex=True, priority=1, id=1),
        Rule(pattern="coffee", category="dining", priority=2, id=2),
    ]
    assert categorize.categorize("Blue Bottle Coffee", rules) == "dining"


def test_seed_default_rules_is_idempotent(conn):
    first = categorize.seed_default_rules(conn)
    assert first == len(categorize.DEFAULT_RULES)
    assert categorize.seed_default_rules(conn) == 0


def test_apply_rules_fills_uncategorized(conn):
    categorize.seed_default_rules(conn)
    db.add_transactions(
        conn,
        [
            Transaction(date=date(2026, 11, 2), description="TESCO 441", amount_cents=-8235),
            Transaction(date=date(2026, 11, 3), description="Mystery shop", amount_cents=-1000),
        ],
    )
    assert categorize.apply_rules(conn) == 1
    categories = {tx.description: tx.category for tx in db.list_transactions(conn)}
    assert categories["TESCO 441"] == "groceries"
    assert categories["Mystery shop"] == UNCATEGORIZED


def test_apply_rules_leaves_manual_categories_alone(conn):
    db.add_rule(conn, Rule(pattern="tesco", category="groceries"))
    tx_id = db.add_transaction(
        conn,
        Transaction(
            date=date(2026, 11, 2),
            description="TESCO 441",
            amount_cents=-8235,
            category="gifts",
        ),
    )
    assert categorize.apply_rules(conn) == 0
    assert db.list_transactions(conn)[0].category == "gifts"
    # --all overrides the manual choice.
    assert categorize.apply_rules(conn, only_uncategorized=False) == 1
    assert db.list_transactions(conn)[0].category == "groceries"
    assert tx_id is not None


def test_apply_rules_without_rules_is_a_noop(conn):
    db.add_transaction(
        conn, Transaction(date=date(2026, 11, 2), description="TESCO", amount_cents=-100)
    )
    assert categorize.apply_rules(conn) == 0
