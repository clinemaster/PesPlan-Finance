import pytest

from lifepilot import importers


def write(tmp_path, name, text):
    path = tmp_path / name
    path.write_text(text, encoding="utf-8")
    return path


def test_signed_amount_column(tmp_path):
    path = write(
        tmp_path,
        "simple.csv",
        "Date,Description,Amount\n2026-11-02,TESCO 441,-82.35\n2026-11-01,PAYROLL,3200.00\n",
    )
    result = importers.read_csv(path, account="visa")
    assert [tx.amount_cents for tx in result.transactions] == [-8235, 320000]
    assert all(tx.account == "visa" for tx in result.transactions)
    assert result.warnings == []


def test_header_aliases_are_detected(tmp_path):
    path = write(
        tmp_path,
        "aliases.csv",
        "Transaction Date,Payee,Transaction Amount\n01/12/2026,Rent,-1150.00\n",
    )
    result = importers.read_csv(path)
    assert result.transactions[0].date.isoformat() == "2026-12-01"
    assert result.transactions[0].amount_cents == -115000


def test_debit_credit_columns(tmp_path):
    path = write(
        tmp_path,
        "dc.csv",
        "Date,Description,Debit,Credit\n"
        "2026-11-02,Groceries,82.35,\n"
        "2026-11-01,Salary,,3200.00\n"
        "2026-11-03,Zero padded,0.00,25.00\n",
    )
    result = importers.read_csv(path)
    assert [tx.amount_cents for tx in result.transactions] == [-8235, 320000, 2500]


def test_debit_and_credit_on_one_row_is_skipped(tmp_path):
    path = write(
        tmp_path,
        "both.csv",
        "Date,Description,Debit,Credit\n2026-11-02,Confused,10.00,20.00\n",
    )
    result = importers.read_csv(path)
    assert result.transactions == []
    assert len(result.warnings) == 1


def test_flip_signs(tmp_path):
    path = write(tmp_path, "flip.csv", "Date,Description,Amount\n2026-11-02,Groceries,82.35\n")
    result = importers.read_csv(path, flip_signs=True)
    assert result.transactions[0].amount_cents == -8235


def test_explicit_column_overrides(tmp_path):
    path = write(
        tmp_path,
        "odd.csv",
        "when,what,how much\n2026-11-02,Groceries,-82.35\n",
    )
    result = importers.read_csv(
        path, date_column="when", description_column="what", amount_column="how much"
    )
    assert result.transactions[0].amount_cents == -8235


def test_bad_rows_warn_without_aborting(tmp_path):
    path = write(
        tmp_path,
        "mixed.csv",
        "Date,Description,Amount\n"
        "2026-11-02,Good,-10.00\n"
        "garbage,Bad date,-10.00\n"
        "2026-11-04,Bad amount,abc\n"
        "2026-11-05,Also good,-20.00\n",
    )
    result = importers.read_csv(path)
    assert [tx.description for tx in result.transactions] == ["Good", "Also good"]
    assert len(result.warnings) == 2
    assert "line 3" in result.warnings[0]


def test_blank_description_gets_placeholder(tmp_path):
    path = write(tmp_path, "blank.csv", "Date,Description,Amount\n2026-11-02,,-10.00\n")
    result = importers.read_csv(path)
    assert result.transactions[0].description == "(no description)"


def test_unrecognizable_header_raises(tmp_path):
    path = write(tmp_path, "nope.csv", "foo,bar\n1,2\n")
    with pytest.raises(ValueError, match="could not find column"):
        importers.read_csv(path)


def test_bom_is_handled(tmp_path):
    path = tmp_path / "bom.csv"
    path.write_text("Date,Description,Amount\n2026-11-02,Coffee,-5.40\n", encoding="utf-8-sig")
    result = importers.read_csv(path)
    assert result.transactions[0].description == "Coffee"
