"""
行人事故圓餅圖 ETL
讀取 data/ 下的 CSV，過濾 台北市/新北市 + 人與車，
統計天候分布、事故子類別分布，寫入 postgres-data 的 dashboard DB。
"""
import csv
import glob
import os
import subprocess

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
CSV_FILES = glob.glob(os.path.join(DATA_DIR, "NPA_TM*.csv"))

LOCATION_COL  = "發生地點"
TYPE_MAIN_COL = "事故類型及型態大類別名稱"
TYPE_SUB_COL  = "事故類型及型態子類別名稱"
WEATHER_COL   = "天候名稱"

weather_counts = {}
subtype_counts = {}

for path in sorted(CSV_FILES):
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            loc  = row.get(LOCATION_COL, "")
            main = row.get(TYPE_MAIN_COL, "")
            if not (loc.startswith("台北市") or loc.startswith("新北市")):
                continue
            if main != "人與車":
                continue
            w = row.get(WEATHER_COL, "不明").strip() or "不明"
            s = row.get(TYPE_SUB_COL,  "其他").strip() or "其他"
            weather_counts[w] = weather_counts.get(w, 0) + 1
            subtype_counts[s] = subtype_counts.get(s, 0) + 1

print(f"天候: {weather_counts}")
print(f"子類別: {subtype_counts}")

# 組 SQL
lines = [
    "BEGIN;",
    # 天候 table
    "DROP TABLE IF EXISTS public.ped_accident_weather_stats;",
    "CREATE TABLE public.ped_accident_weather_stats ("
    "  weather VARCHAR(20), count INTEGER);",
]
for w, c in sorted(weather_counts.items(), key=lambda x: -x[1]):
    lines.append(f"INSERT INTO public.ped_accident_weather_stats VALUES ('{w}', {c});")

lines += [
    # 事故子類別 table
    "DROP TABLE IF EXISTS public.ped_accident_subtype_stats;",
    "CREATE TABLE public.ped_accident_subtype_stats ("
    "  subtype VARCHAR(50), count INTEGER);",
]
for s, c in sorted(subtype_counts.items(), key=lambda x: -x[1]):
    safe = s.replace("'", "''")
    lines.append(f"INSERT INTO public.ped_accident_subtype_stats VALUES ('{safe}', {c});")

lines.append("COMMIT;")

sql = "\n".join(lines)
sql_path = os.path.join(os.path.dirname(__file__), "ped_pie_stats.sql")
with open(sql_path, "w", encoding="utf-8") as f:
    f.write(sql)
print(f"SQL 已寫入 {sql_path}")

# 執行到 docker
subprocess.run(["docker", "cp", sql_path, "postgres-data:/tmp/ped_pie_stats.sql"], check=True)
result = subprocess.run(
    ["docker", "exec", "postgres-data", "psql", "-U", "postgres", "-d", "dashboard", "-f", "/tmp/ped_pie_stats.sql"],
    capture_output=True, text=True
)
print(result.stdout)
if result.returncode != 0:
    print("ERROR:", result.stderr)
else:
    print("DB 寫入完成")
