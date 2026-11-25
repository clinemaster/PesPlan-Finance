import pytest

from lifepilot.cli import main


@pytest.fixture
def db_path(tmp_path):
    return str(tmp_path / "test.db")


def run(db_path, *args):
    return main(["--db", db_path, *args])


def test_init_seeds_rules(db_path, capsys):
    assert run(db_path, "init") == 0
    assert "starter categorization rules" in capsys.readouterr().out


def test_init_no_seed(db_path, capsys):
    assert run(db_path, "init", "--no-seed") == 0
    assert run(db_path, "rules", "list") == 0
    assert "(nothing to show)" in capsys.readouterr().out


def test_add_autocategorizes(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "add", "TESCO SUPERMARKET", "-82.35", "--date", "2026-11-02") == 0
    assert "[groceries]" in capsys.readouterr().out


def test_add_rejects_bad_amount(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "add", "Mystery", "not-money") == 2
    assert "error:" in capsys.readouterr().err


def test_duplicate_add_reports_nonzero(db_path):
    run(db_path, "init")
    args = ("add", "Coffee", "-5.40", "--date", "2026-11-02")
    assert run(db_path, *args) == 0
    assert run(db_path, *args) == 1


def test_import_then_report(db_path, tmp_path, capsys):
    csv_path = tmp_path / "bank.csv"
    csv_path.write_text(
        "Date,Description,Amount\n"
        "2026-11-01,ACME PAYROLL,3200.00\n"
        "2026-11-02,TESCO 441,-82.35\n"
        "2026-11-03,Monthly Rent,-1150.00\n",
        encoding="utf-8",
    )
    run(db_path, "init")
    assert run(db_path, "import", str(csv_path)) == 0
    assert "Imported 3" in capsys.readouterr().out

    assert run(db_path, "report", "summary", "--month", "2026-11") == 0
    out = capsys.readouterr().out
    assert "3,200.00" in out
    assert "1,232.35" in out


def test_import_dry_run_writes_nothing(db_path, tmp_path, capsys):
    csv_path = tmp_path / "bank.csv"
    csv_path.write_text("Date,Description,Amount\n2026-11-02,TESCO,-82.35\n", encoding="utf-8")
    run(db_path, "init")
    assert run(db_path, "import", str(csv_path), "--dry-run") == 0
    assert "nothing written" in capsys.readouterr().out
    run(db_path, "list")
    assert "(nothing to show)" in capsys.readouterr().out


def test_import_of_unreadable_file(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "import", "does-not-exist.csv") == 2
    assert "Import failed" in capsys.readouterr().err


def test_rules_and_recategorize(db_path, capsys):
    run(db_path, "init", "--no-seed")
    run(db_path, "add", "WEIRD MERCHANT 7", "-20.00", "--date", "2026-11-02")
    run(db_path, "rules", "add", "weird merchant", "shopping")
    assert run(db_path, "recategorize") == 0
    assert "Recategorized 1" in capsys.readouterr().out
    run(db_path, "list", "--category", "shopping")
    assert "WEIRD MERCHANT 7" in capsys.readouterr().out


def test_set_category_and_delete(db_path, capsys):
    run(db_path, "init")
    run(db_path, "add", "Something", "-10.00", "--date", "2026-11-02")
    assert run(db_path, "set-category", "1", "gifts") == 0
    assert run(db_path, "delete", "1") == 0
    assert run(db_path, "delete", "1") == 1
    capsys.readouterr()


def test_budget_flow(db_path, capsys):
    run(db_path, "init")
    run(db_path, "add", "TESCO", "-120.00", "--date", "2026-11-02")
    assert run(db_path, "budget", "set", "groceries", "100") == 0
    assert run(db_path, "report", "budget", "--month", "2026-11") == 0
    out = capsys.readouterr().out
    assert "OVER" in out
    assert "-20.00" in out


def test_budget_report_without_budgets(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "report", "budget", "--month", "2026-11") == 0
    assert "No budgets set yet" in capsys.readouterr().out


def test_report_trend_and_categories(db_path, capsys):
    run(db_path, "init")
    run(db_path, "add", "TESCO", "-80.00", "--date", "2026-10-02")
    run(db_path, "add", "ACME PAYROLL", "2000.00", "--date", "2026-11-01")
    assert run(db_path, "report", "trend", "--months", "3") == 0
    out = capsys.readouterr().out
    assert "2026-10" in out
    assert "2026-11" in out

    assert run(db_path, "report", "categories", "--income") == 0
    assert "income" in capsys.readouterr().out


def test_bad_month_is_an_error(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "report", "summary", "--month", "nope") == 2
    assert "error:" in capsys.readouterr().err


def test_report_year(db_path, capsys):
    run(db_path, "init")
    run(db_path, "add", "ACME PAYROLL", "3200.00", "--date", "2026-08-01")
    run(db_path, "add", "TESCO", "-120.00", "--date", "2026-08-05")
    run(db_path, "add", "TESCO", "-150.00", "--date", "2026-11-05")
    assert run(db_path, "report", "year", "--year", "2026") == 0
    out = capsys.readouterr().out
    assert "Year 2026" in out
    assert "Spending by month" in out
    assert "avg 135.00/month" in out  # mean of the two months that have records
    assert "Aug" in out and "Nov" in out
    assert "All years" not in out  # only one year of data


def test_report_year_compares_against_the_prior_year(db_path, capsys):
    run(db_path, "init")
    run(db_path, "add", "TESCO", "-100.00", "--date", "2025-03-05")
    run(db_path, "add", "TESCO", "-130.00", "--date", "2026-03-05")
    assert run(db_path, "report", "year", "--year", "2026") == 0
    out = capsys.readouterr().out
    assert "VS 2025" in out
    assert "30.00" in out  # spent 30 more in March than the year before
    assert "All years" in out


def test_report_year_with_no_data(db_path, capsys):
    run(db_path, "init")
    assert run(db_path, "report", "year", "--year", "2019") == 0
    assert "Year 2019" in capsys.readouterr().out
