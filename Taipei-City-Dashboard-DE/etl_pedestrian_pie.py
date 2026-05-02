"""
行人事故圓餅圖 ETL
讀取 data/ 下的 CSV，過濾 台北市/新北市 + 人與車，
統計天候分布、事故子類別分布（分城市），寫入 postgres-data 的 dashboard DB。
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

# city -> weather -> count  &  city -> subtype -> count
# cities: 'taipei'(臺北市), 'metrotaipei'(雙北合計)
weather_counts = {"taipei": {}, "metrotaipei": {}}
subtype_counts = {"taipei": {}, "metrotaipei": {}}

for path in sorted(CSV_FILES):
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            loc  = row.get(LOCATION_COL, "")
            main = row.get(TYPE_MAIN_COL, "")
            is_taipei    = loc.startswith("臺北市") or loc.startswith("台北市")
            is_newtaipei = loc.startswith("新北市")
            if not (is_taipei or is_newtaipei):
                continue
            if main != "人與車":
                continue
            w = row.get(WEATHER_COL, "不明").strip() or "不明"
            s = row.get(TYPE_SUB_COL,  "其他").strip() or "其他"
            # metrotaipei = 雙北合計
            weather_counts["metrotaipei"][w] = weather_counts["metrotaipei"].get(w, 0) + 1
            subtype_counts["metrotaipei"][s] = subtype_counts["metrotaipei"].get(s, 0) + 1
            # taipei only
            if is_taipei:
                weather_counts["taipei"][w] = weather_counts["taipei"].get(w, 0) + 1
                subtype_counts["taipei"][s] = subtype_counts["taipei"].get(s, 0) + 1

print(f"天候(metrotaipei): {weather_counts['metrotaipei']}")
print(f"天候(taipei): {weather_counts['taipei']}")

# 組 SQL
lines = [
    "BEGIN;",
    # 天候 table（加 city 欄位）
    "DROP TABLE IF EXISTS public.ped_accident_weather_stats;",
    "CREATE TABLE public.ped_accident_weather_stats (city VARCHAR(20), weather VARCHAR(20), count INTEGER);",
]
for city, counts in weather_counts.items():
    for w, c in sorted(counts.items(), key=lambda x: -x[1]):
        safe_w = w.replace("'", "''")
        lines.append(f"INSERT INTO public.ped_accident_weather_stats VALUES ('{city}', '{safe_w}', {c});")

lines += [
    # 事故子類別 table（加 city 欄位）
    "DROP TABLE IF EXISTS public.ped_accident_subtype_stats;",
    "CREATE TABLE public.ped_accident_subtype_stats (city VARCHAR(20), subtype VARCHAR(50), count INTEGER);",
]
for city, counts in subtype_counts.items():
    for s, c in sorted(counts.items(), key=lambda x: -x[1]):
        safe_s = s.replace("'", "''")
        lines.append(f"INSERT INTO public.ped_accident_subtype_stats VALUES ('{city}', '{safe_s}', {c});")

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
