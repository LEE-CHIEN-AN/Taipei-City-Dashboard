# 雙北人行道路網 — 本機 Docker 環境設定指南

> Pull `feature/sidewalk` branch 後，請依以下步驟在本機 Docker 環境中還原雙北人行道路網資料集，使「雙北儀表板 → 圖資資訊 → 地圖交叉比對」頁面能正常顯示路網圖層。

## 架構說明

仿照自行車道路網（`bike_network_tpe` + `bike_network_metrotaipei`）的雙圖層模式：
- `sidewalk_tpe.geojson`（14 MB）— 臺北市，18,060 筆
- `sidewalk_newtaipei.geojson`（28 MB）— 新北市，13,984 筆
- 兩個檔案**並行載入**，取代原本單一 88 MB 的全台灣合併檔

---

## 前置條件

| 項目 | 說明 |
|------|------|
| Docker | 所有容器已啟動（`docker ps` 確認） |
| postgres-manager | `localhost:5432`，dashboardmanager DB |
| postgres-data | `localhost:5433`，dashboard DB |
| GDAL / ogr2ogr | 匯入 PostGIS 用（Windows：`choco install gdal`） |

---

## Step 1 — 將 GeoJSON 複製進 Docker 容器

前端靜態檔案存放在 `dashboard-fe` 容器內（`/opt/Taipei-City-Dashboard-FE/public/mapData/`），需手動複製：

```bash
# 複製到 /tmp（避免 permission denied）
docker cp "Taipei-City-Dashboard-FE/public/mapData/sidewalk_tpe.geojson"       dashboard-fe:/tmp/sidewalk_tpe.geojson
docker cp "Taipei-City-Dashboard-FE/public/mapData/sidewalk_newtaipei.geojson" dashboard-fe:/tmp/sidewalk_newtaipei.geojson

# 以 root 身份移到正確路徑
docker exec -u root dashboard-fe sh -c "
cp /tmp/sidewalk_tpe.geojson       /opt/Taipei-City-Dashboard-FE/public/mapData/sidewalk_tpe.geojson && \
cp /tmp/sidewalk_newtaipei.geojson /opt/Taipei-City-Dashboard-FE/public/mapData/sidewalk_newtaipei.geojson
"

# 確認（應顯示 ~14M 和 ~28M）
docker exec dashboard-fe sh -c "ls -lh /opt/Taipei-City-Dashboard-FE/public/mapData/sidewalk_*.geojson"
```

> 每次重建 `dashboard-fe` 容器後需重新執行此步驟。

---

## Step 2 — dashboard DB：建立 PostGIS 資料表

在 pgAdmin 連線至 **postgres-data（port 5433）**，執行：

```
檔案：Taipei-City-Dashboard-DE/setup_sidewalk_tables.sql
```

---

## Step 3 — dashboard DB：匯入 GeoJSON（ogr2ogr）

```bash
ogr2ogr -f "PostgreSQL" \
  PG:"host=localhost port=5433 dbname=dashboard user=postgres password=<YOUR_PW>" \
  "Taipei-City-Dashboard-FE/public/mapData/SIDEWALK_1_202412_WGS84.geojson" \
  -nln sidewalk_metrotaipei \
  -nlt MULTIPOLYGON \
  -t_srs EPSG:4326 \
  --config PG_USE_COPY YES \
  -lco GEOMETRY_NAME=wkb_geometry
```

---

## Step 4 — dashboardmanager DB：新增組件設定

在 pgAdmin 連線至 **postgres-manager（port 5432）**，執行：

```
檔案：Taipei-City-Dashboard-DE/setup_sidewalk_components.sql
```

此腳本會依序：
1. 新增兩個 `component_maps`（`sidewalk_tpe` + `sidewalk_newtaipei`）
2. 新增 `components`（組件名稱：雙北人行道路網）
3. 新增 `component_charts`（圖例：MapLegend）
4. 新增 `query_charts`（city = metrotaipei，`map_config_ids` 同時參照兩個圖層）
5. 將組件加入 `map-layers-metrotaipei` 儀表板

---

## Step 5 — 驗證

### DB 確認（dashboardmanager）

```sql
-- 兩個圖層都要在
SELECT id, index FROM public.component_maps WHERE index IN ('sidewalk_tpe', 'sidewalk_newtaipei');

-- map_config_ids 應有兩個 id
SELECT index, city, map_config_ids FROM public.query_charts WHERE index = 'sidewalk_metrotaipei';

-- 儀表板 components 應包含雙北人行道路網 id
SELECT id, index, components FROM public.dashboards WHERE index = 'map-layers-metrotaipei';
```

### 前端確認

1. 切換至「**雙北儀表板 → 圖資資訊 → 地圖交叉比對**」
2. 側欄出現「**雙北人行道路網**」卡片
3. 開啟開關後，Network 分頁可見兩筆並行請求：
   - `sidewalk_tpe.geojson`（14 MB）
   - `sidewalk_newtaipei.geojson`（28 MB）
4. 兩筆都回 200 後，地圖顯示金黃色人行道面狀圖層

---

## 常見問題

### Q: 切換開關後地圖沒有圖層
**A:** 在 Network 分頁確認 `sidewalk_tpe.geojson` 和 `sidewalk_newtaipei.geojson` 都回 200。若 404，代表 Step 1 的 Docker 複製未完成或容器被重建。

### Q: 前端沒有出現卡片
**A:** 確認 `query_charts.map_config_ids` 不是空陣列，且 `dashboards.components` 已包含組件 id（Step 4 驗證 SQL）。

---

## 相關檔案

| 檔案 | 說明 |
|------|------|
| `Taipei-City-Dashboard-FE/public/mapData/sidewalk_tpe.geojson` | 臺北市人行道（14 MB） |
| `Taipei-City-Dashboard-FE/public/mapData/sidewalk_newtaipei.geojson` | 新北市人行道（28 MB） |
| `Taipei-City-Dashboard-FE/public/mapData/SIDEWALK_1_202412_WGS84.geojson` | 原始資料（含桃園，供 ogr2ogr 匯入） |
| `Taipei-City-Dashboard-DE/setup_sidewalk_tables.sql` | dashboard DB 建表腳本 |
| `Taipei-City-Dashboard-DE/setup_sidewalk_components.sql` | dashboardmanager DB 組件設定腳本 |
