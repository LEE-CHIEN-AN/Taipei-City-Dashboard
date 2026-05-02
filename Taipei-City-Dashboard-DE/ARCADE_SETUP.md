# 雙北騎樓整平儀表板 — 設定說明

## 故事線脈絡

除了距離與安全性之外，**舒適度**也是影響民眾是否願意步行至公共運輸節點的重要因素。若騎樓高低落差大、步行空間不連續，即使距離不長，也可能降低民眾使用公共運輸的意願。

本模組以「騎樓整平長度」衡量雙北各行政區的步行環境品質，呈現：
- 各行政區累積整平量（識別整平優先區域）
- 雙北整體逐年趨勢（比較兩市政策推動節奏）
- 各行政區逐年趨勢（找出整平量下滑或停滯的行政區）

---

## 組件總覽

| 組件 index | 名稱 | 圖表類型 | 資料來源表 |
|---|---|---|---|
| `arcade_total_district` | 雙北騎樓整平累積量 | DistrictChart + BarChart | arcade_total_by_district |
| `arcade_yearly_city_trend` | 雙北騎樓整平逐年趨勢 | TimelineSeparateChart | arcade_yearly_by_city |
| `arcade_yearly_district_trend` | 各行政區騎樓整平逐年趨勢 | TimelineSeparateChart | arcade_yearly_by_district |

城市版本：每個組件均提供 `taipei`、`newtaipei`、`metrotaipei` 三個 city 版本。

---

## 設定步驟

### Step 1：在 postgres-data（port 5433）建立資料表

```bash
psql -h localhost -p 5433 -U postgres -d dashboard \
  -f setup_arcade_tables.sql
```

### Step 2：匯入 CSV 資料

```bash
# 確認 CSV 檔案位於 Taipei-City-Dashboard-FE/public/mapData/
python import_arcade_csv.py
```

環境變數（可選）：

| 變數 | 預設值 | 說明 |
|---|---|---|
| `DATA_DB_HOST` | `localhost` | postgres-data 主機 |
| `DATA_DB_PORT` | `5433` | postgres-data 連接埠 |
| `DATA_DB_NAME` | `dashboard` | 資料庫名稱 |
| `DATA_DB_USER` | `postgres` | 使用者 |
| `DATA_DB_PASSWORD` | `password` | 密碼 |

### Step 3：在 postgres-manager（port 5432）建立組件設定

```bash
psql -h localhost -p 5432 -U postgres -d dashboardmanager \
  -f setup_arcade_components.sql
```

---

## 資料說明

### CSV 檔案位置
```
Taipei-City-Dashboard-FE/public/mapData/
├── arcade_total_by_district.csv   # 各行政區累積整平總量
├── arcade_yearly_by_city.csv      # 各縣市逐年整平量
└── arcade_yearly_by_district.csv  # 各行政區逐年整平量
```

### 資料特性
- **台北市**：資料集中在 1991–1999 年，當時進行大規模騎樓整平運動，整平量極大（部分行政區逾 60 萬公尺）。
- **新北市**：資料為 2010–2024 年，持續穩定推進，規模相對較小（多數行政區每年不超過 5000 公尺）。
- 兩市資料時間範圍**不重疊**，`TimelineSeparateChart` 會分別顯示各自的時間區段。

---

## 驗證

執行後可用以下 SQL 確認組件設定：

```sql
-- 在 dashboardmanager DB 執行
SELECT c.index, c.name, cc.types, qc.city, qc.query_type
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc ON c.index = qc.index
WHERE c.index LIKE 'arcade_%'
ORDER BY c.index, qc.city;
```

預期出現 9 筆（3 組件 × 3 cities）。
