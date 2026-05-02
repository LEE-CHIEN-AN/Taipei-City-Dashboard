# 雙北騎樓整平儀表板 — 設定說明

## 故事線脈絡

除了距離與安全性之外，**舒適度**也是影響民眾是否願意步行至公共運輸節點的重要因素。若騎樓高低落差大、步行空間不連續，即使距離不長，也可能降低民眾使用公共運輸的意願。

本模組以「騎樓整平累積長度」衡量雙北各行政區的步行環境品質，以四種視覺化角度呈現：
- **行政區圖（DistrictChart）**：空間熱區，顯示各行政區整平強度
- **橫向長條圖（BarChart）**：行政區排名比較
- **圓餅圖（DonutChart）**：各行政區佔比分佈
- **地圖比例符號（MapLegend）**：點大小與顏色反映整平總量

---

## 組件總覽（1 個雙北組件）

| index | 名稱 | 圖表類型 | 地圖圖層 |
|---|---|---|---|
| `arcade_total_district` | 雙北騎樓整平累積量 | DistrictChart + BarChart + DonutChart + **MapLegend** | **circle（比例符號）** |

城市版本：taipei、newtaipei、metrotaipei 三個 city 版本。

### 地圖圖層說明

| map index | 說明 | GeoJSON 檔案 |
|---|---|---|
| `arcade_total_district_taipei` | 台北市 12 行政區質心點（紅色漸層） | `public/mapData/arcade_total_district_taipei.geojson` |
| `arcade_total_district` | 雙北 32 行政區質心點（台北紅/新北藍） | `public/mapData/arcade_total_district.geojson` |

> **規範要求**：`component_maps` 中台北版（`arcade_total_district_taipei`）必須先於雙北版（`arcade_total_district`）建立。SQL 腳本已確保此順序。

---

## 設定步驟

### Step 1：在 postgres-data 建立資料表並匯入資料

```bash
docker cp setup_arcade_tables.sql postgres-data:/tmp/
docker exec postgres-data psql -U postgres -d dashboard -f /tmp/setup_arcade_tables.sql

docker cp arcade_all_utf8.sql postgres-data:/tmp/
docker exec postgres-data psql -U postgres -d dashboard -f /tmp/arcade_all_utf8.sql
```

### Step 2：在 postgres-manager 建立組件設定

```bash
docker cp setup_arcade_components.sql postgres-manager:/tmp/
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_arcade_components.sql
```

---

## 資料說明

### 資料表

| 資料表 | 說明 |
|---|---|
| `arcade_total_by_district` | 各行政區累積整平總量（32 筆） |
| `arcade_yearly_by_city` | 各縣市逐年整平量（備用，未使用於組件） |
| `arcade_yearly_by_district` | 各行政區逐年整平量（備用，未使用於組件） |

### GeoJSON 檔案

```
Taipei-City-Dashboard-FE/public/mapData/
├── arcade_total_district_taipei.geojson   # 台北市 12 行政區質心點
└── arcade_total_district.geojson          # 雙北 32 行政區質心點
```

### 資料特性
- **台北市**：1990 年代大規模整平運動，部分行政區逾 60 萬公尺（萬華、中山、大同、大安）。
- **新北市**：2010–2024 年持續性整平，多數行政區每年不超過 5000 公尺，板橋為最高（約 2.7 萬公尺）。

---

## 驗證

```sql
SELECT c.index, c.name, cc.types, qc.city,
       array_length(qc.map_config_ids, 1) AS has_map
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc ON c.index = qc.index
WHERE c.index LIKE 'arcade_%'
ORDER BY c.index, qc.city;
```

預期 **3 筆**（1 組件 × 3 cities），taipei 與 metrotaipei 版本 `has_map = 1`。
