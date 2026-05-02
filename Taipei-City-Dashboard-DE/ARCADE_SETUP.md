# 雙北騎樓整平儀表板 — 設定說明

## 故事線脈絡

除了距離與安全性之外，**舒適度**也是影響民眾是否願意步行至公共運輸節點的重要因素。若騎樓高低落差大、步行空間不連續，即使距離不長，也可能降低民眾使用公共運輸的意願。

本模組以「騎樓整平長度」衡量雙北各行政區的步行環境品質，呈現：
- 各行政區累積整平量（含地圖比例符號圖層）
- 雙北整體逐年趨勢（比較兩市政策推動節奏）
- 各行政區逐年趨勢（找出整平量下滑或停滯的行政區）
- 各行政區整平佔比（識別資源集中程度）

---

## 組件總覽（4 個雙北組件）

| # | 組件 index | 名稱 | 圖表類型 | 地圖圖層 |
|---|---|---|---|---|
| 1 | `arcade_total_district` | 雙北騎樓整平累積量 | DistrictChart + BarChart + **MapLegend** | **circle（比例符號）** |
| 2 | `arcade_yearly_city_trend` | 雙北騎樓整平逐年趨勢 | TimelineSeparateChart | — |
| 3 | `arcade_yearly_district_trend` | 各行政區騎樓整平逐年趨勢 | TimelineSeparateChart | — |
| 4 | `arcade_district_share` | 騎樓整平行政區佔比 | DonutChart + BarPercentChart | — |

城市版本：每個組件均提供 `taipei`、`newtaipei`、`metrotaipei` 三個 city 版本。

### 地圖圖層說明（組件 1）

| map index | 說明 | GeoJSON 檔案 |
|---|---|---|
| `arcade_total_district_taipei` | 台北市 12 行政區質心點（紅色漸層） | `public/mapData/arcade_total_district_taipei.geojson` |
| `arcade_total_district` | 雙北 32 行政區質心點（台北紅/新北藍） | `public/mapData/arcade_total_district.geojson` |

> **規範要求**：`component_maps` 中台北版（`arcade_total_district_taipei`）必須先於雙北版（`arcade_total_district`）建立。SQL 腳本已確保此順序。

---

## 設定步驟

### Step 0：安裝 Python 依賴

```bash
pip install psycopg2-binary
```

### Step 1：在 postgres-data（port 5433）建立資料表

```bash
psql -h localhost -p 5433 -U postgres -d dashboard \
  -f setup_arcade_tables.sql
```

### Step 2：匯入 CSV 資料

```bash
python import_arcade_csv.py
```

環境變數（可選，預設值如下）：

| 變數 | 預設 |
|---|---|
| `DATA_DB_HOST` | `localhost` |
| `DATA_DB_PORT` | `5433` |
| `DATA_DB_NAME` | `dashboard` |
| `DATA_DB_USER` | `postgres` |
| `DATA_DB_PASSWORD` | `password` |

### Step 3：在 postgres-manager（port 5432）建立組件設定

```bash
psql -h localhost -p 5432 -U postgres -d dashboardmanager \
  -f setup_arcade_components.sql
```

---

## 資料說明

### CSV / GeoJSON 檔案位置
```
Taipei-City-Dashboard-FE/public/mapData/
├── arcade_total_by_district.csv              # 各行政區累積整平總量（資料庫用）
├── arcade_yearly_by_city.csv                 # 各縣市逐年整平量（資料庫用）
├── arcade_yearly_by_district.csv             # 各行政區逐年整平量（資料庫用）
├── arcade_total_district_taipei.geojson      # 台北地圖圖層（質心點）
└── arcade_total_district.geojson             # 雙北地圖圖層（質心點）
```

### 資料特性
- **台北市**：資料集中在 1991–1999 年，當時進行大規模騎樓整平運動（部分行政區逾 60 萬公尺）。
- **新北市**：資料為 2010–2024 年，持續穩定推進（多數行政區每年不超過 5000 公尺）。
- 兩市資料時間範圍**不重疊**，TimelineSeparateChart 會分別顯示各自的時間區段。

---

## 驗證

執行後在 dashboardmanager DB 確認：

```sql
SELECT c.index, c.name, cc.types, qc.city, qc.query_type,
       array_length(qc.map_config_ids, 1) AS has_map
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc ON c.index = qc.index
WHERE c.index LIKE 'arcade_%'
ORDER BY c.index, qc.city;
```

預期 **12 筆**（4 組件 × 3 cities），`arcade_total_district` 的 `taipei` 與 `metrotaipei` 版本 `has_map = 1`。
