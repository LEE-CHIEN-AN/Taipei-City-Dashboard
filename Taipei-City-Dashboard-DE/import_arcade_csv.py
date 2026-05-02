"""
import_arcade_csv.py
將雙北騎樓整平 CSV 資料匯入 postgres-data（dashboard DB）。

資料來源（相對於 Taipei-City-Dashboard-FE/public/mapData/）：
  arcade_total_by_district.csv
  arcade_yearly_by_city.csv
  arcade_yearly_by_district.csv

執行前請確認：
  1. setup_arcade_tables.sql 已在 postgres-data DB 執行完畢
  2. 已安裝 psycopg2-binary：
       pip install psycopg2-binary
  3. 環境變數已設定（或直接修改下方 DB_CONFIG）

Usage:
  python import_arcade_csv.py
"""

import os
import csv

try:
    import psycopg2
except ImportError:
    raise SystemExit(
        "[ERROR] 找不到 psycopg2 模組。請先執行：\n"
        "  pip install psycopg2-binary\n"
        "若使用 conda 環境：\n"
        "  conda install -c conda-forge psycopg2"
    )

# ── DB 連線設定 ────────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DATA_DB_HOST",     "localhost"),
    "port":     int(os.getenv("DATA_DB_PORT", "5433")),
    "dbname":   os.getenv("DATA_DB_NAME",     "dashboard"),
    "user":     os.getenv("DATA_DB_USER",     "postgres"),
    "password": os.getenv("DATA_DB_PASSWORD", "password"),
}

# ── CSV 路徑（相對於本腳本）────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_DIR = os.path.join(
    SCRIPT_DIR,
    "..", "Taipei-City-Dashboard-FE", "public", "mapData"
)

CSV_TOTAL    = os.path.join(CSV_DIR, "arcade_total_by_district.csv")
CSV_BY_CITY  = os.path.join(CSV_DIR, "arcade_yearly_by_city.csv")
CSV_BY_DIST  = os.path.join(CSV_DIR, "arcade_yearly_by_district.csv")


def connect():
    return psycopg2.connect(**DB_CONFIG)


def import_total_by_district(cur):
    print("匯入 arcade_total_by_district ...")
    cur.execute("TRUNCATE TABLE public.arcade_total_by_district RESTART IDENTITY;")
    with open(CSV_TOTAL, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = [
            (row["city"], row["district"], float(row["total_length_m"]))
            for row in reader
        ]
    cur.executemany(
        "INSERT INTO public.arcade_total_by_district (city, district, total_length_m) VALUES (%s, %s, %s)",
        rows,
    )
    print(f"  → 匯入 {len(rows)} 筆")


def import_yearly_by_city(cur):
    print("匯入 arcade_yearly_by_city ...")
    cur.execute("TRUNCATE TABLE public.arcade_yearly_by_city RESTART IDENTITY;")
    with open(CSV_BY_CITY, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = [
            (row["city"], int(float(row["year"])), float(row["city_total_m"]))
            for row in reader
        ]
    cur.executemany(
        "INSERT INTO public.arcade_yearly_by_city (city, year, city_total_m) VALUES (%s, %s, %s)",
        rows,
    )
    print(f"  → 匯入 {len(rows)} 筆")


def import_yearly_by_district(cur):
    print("匯入 arcade_yearly_by_district ...")
    cur.execute("TRUNCATE TABLE public.arcade_yearly_by_district RESTART IDENTITY;")
    with open(CSV_BY_DIST, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = [
            (row["city"], row["district"], int(float(row["year"])), float(row["length_m"]))
            for row in reader
        ]
    cur.executemany(
        "INSERT INTO public.arcade_yearly_by_district (city, district, year, length_m) VALUES (%s, %s, %s, %s)",
        rows,
    )
    print(f"  → 匯入 {len(rows)} 筆")


def main():
    conn = connect()
    try:
        with conn.cursor() as cur:
            import_total_by_district(cur)
            import_yearly_by_city(cur)
            import_yearly_by_district(cur)
        conn.commit()
        print("✓ 所有資料匯入完成")
    except Exception as e:
        conn.rollback()
        print(f"✗ 匯入失敗：{e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
