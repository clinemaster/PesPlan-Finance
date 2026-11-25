from datetime import date

from lifepilot import db
from lifepilot.models import Budget, Rule, Transaction


def _tx(day=1, desc="Coffee", cents=-540, **kw):
    return Transaction(date=date(2026, 11, day), description=desc, amount_cents=cents, **kw)


def test_add_and_list(conn):
    assert db.add_transaction(conn, _tx()) is not None
    txs = db.list_transactions(conn)
    assert len(txs) == 1
    assert txs[0].description == "Coffee"
    assert txs[0].amount_cents == -540


def test_duplicate_is_skipped(conn):
    assert db.add_transaction(conn, _tx()) is not None
    assert db.add_transaction(conn, _tx()) is None
    assert len(db.list_transactions(conn)) == 1


def test_bulk_insert_counts_duplicates(conn):
    inserted, skipped = db.add_transactions(conn, [_tx(1), _tx(1), _tx(2)])
    assert (inserted, skipped) == (2, 1)


def test_list_filters(conn):
    db.add_transactions(
        conn,
        [
            _tx(1, "Rent", -115000, category="housing"),
            _tx(5, "Tesco", -8235, category="groceries", account="visa"),
            _tx(20, "Salary", 320000, category="income"),
        ],
    )
    assert len(db.list_transactions(conn, category="groceries")) == 1
    assert len(db.list_transactions(conn, account="visa")) == 1
    assert len(db.list_transactions(conn, start="2026-11-04", end="2026-11-10")) == 1
    assert len(db.list_transactions(conn, search="esc")) == 1
    assert len(db.list_transactions(conn, limit=2)) == 2


def test_list_is_newest_first(conn):
    db.add_transactions(conn, [_tx(1, "First"), _tx(9, "Last")])
    assert [tx.description for tx in db.list_transactions(conn)] == ["Last", "First"]


def test_set_category_and_delete(conn):
    tx_id = db.add_transaction(conn, _tx())
    assert db.set_category(conn, tx_id, "dining")
    assert db.list_transactions(conn)[0].category == "dining"
    assert db.delete_transaction(conn, tx_id)
    assert db.list_transactions(conn) == []


def test_missing_rows_report_false(conn):
    assert not db.set_category(conn, 999, "dining")
    assert not db.delete_transaction(conn, 999)
    assert not db.delete_rule(conn, 999)
    assert not db.delete_budget(conn, "nope")


def test_rules_crud(conn):
    rule_id = db.add_rule(conn, Rule(pattern="tesco", category="groceries"))
    assert rule_id is not None
    assert db.add_rule(conn, Rule(pattern="tesco", category="groceries")) is None
    assert [r.pattern for r in db.list_rules(conn)] == ["tesco"]
    assert db.delete_rule(conn, rule_id)
    assert db.list_rules(conn) == []


def test_rules_listed_by_priority(conn):
    db.add_rule(conn, Rule(pattern="late", category="b", priority=200))
    db.add_rule(conn, Rule(pattern="early", category="a", priority=10))
    assert [r.pattern for r in db.list_rules(conn)] == ["early", "late"]


def test_budget_set_is_upsert(conn):
    db.set_budget(conn, Budget(category="groceries", monthly_cents=40000))
    db.set_budget(conn, Budget(category="groceries", monthly_cents=45000))
    budgets = db.list_budgets(conn)
    assert len(budgets) == 1
    assert budgets[0].monthly_cents == 45000
