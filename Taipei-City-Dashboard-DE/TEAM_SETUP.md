# 行人安全 + 大眾運輸等時圈 + 雙北人行道路網 — 環境設定指南

> 適用分支：`feature/sidewalk`
> 前提：已完成官方 Docker 環境設定（能跑起來基本 Dashboard，`localhost` 有畫面）

---

## 這個分支加了什麼

| 功能 | 說明 |
|------|------|
| 行人安全地圖 | 雙北行人事故熱區、時段分析、年度趨勢、高風險路口排名、AI 報告 |
| 大眾運輸步行等時圈 | 捷運／公車／台鐵站 5/10/15 分鐘步行覆蓋等時圈，可點圖例篩選 |
| 雙北人行道路網圖資 | 地圖交叉比對頁 → 圖資資訊，以金黃色線條顯示 OSM 人行道路網 |

---

## 第一次設定（從來沒跑過這個分支）

> 注意：所有指令都在 **PowerShell** 執行。本文件使用 `docker cp` 而非 `<` 重導向，原因是 PowerShell 的 `<` 會造成中文亂碼。

### 步驟一：拉程式碼

```powershell
git fetch origin
git checkout feature/sidewalk
git pull origin feature/sidewalk
```

---

### 步驟二：匯入行人事故資料（約 12 MB）

> 這份 dump 會自動建表，**不需要**先跑 `setup_pedestrian_tables.sql`

```powershell
docker cp Taipei-City-Dashboard-DE/pedestrian_all.sql postgres-data:/tmp/pedestrian.sql
docker exec postgres-data psql -U postgres -d dashboard -f /tmp/pedestrian.sql
```

成功時最後會出現多行 `COPY xxx`；出現 `already exists` 警告可忽略。

---

### 步驟三：設定行人安全儀表板組件

```powershell
docker cp Taipei-City-Dashboard-DE/setup_pedestrian_components.sql postgres-manager:/tmp/setup_pedestrian.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_pedestrian.sql
```

---

### 步驟四：設定大眾運輸等時圈組件

```powershell
docker cp Taipei-City-Dashboard-DE/setup_isochrone_components.sql postgres-manager:/tmp/setup_iso.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_iso.sql
```

接著計算各行政區覆蓋率（需要 Python）：

```powershell
pip install shapely pyproj psycopg2-binary
python Taipei-City-Dashboard-DE/compute_isochrone_coverage.py
```

成功會看到：
```
讀取行政區邊界...
  台北: 12 區，新北: 29 區
=== 公車 ===
  ...
共 123 筆，寫入 DB...
完成！
```

---

### 步驟五：設定人行道路網圖資組件

```powershell
docker cp Taipei-City-Dashboard-DE/setup_sidewalk_components.sql postgres-manager:/tmp/setup_sidewalk.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_sidewalk.sql
```

---

### 步驟六：重啟後端與前端

```powershell
docker restart dashboard-be
docker restart dashboard-fe
```

> **為什麼要重啟 `dashboard-fe`？**
> Vite dev server 在容器啟動時會掃描 `public/` 目錄。若 geojson 檔案在容器啟動前就已存在（透過 git pull 進來），Vite 有時會快取一個 404 fallback。重啟可強制 Vite 重新掃描，讓所有 GeoJSON 正常被識別。

---

### 步驟七：重新整理瀏覽器

按 **Ctrl+Shift+R**（強制清除快取重整，不是一般 F5）

---

## 已有舊設定，只需要更新

```powershell
git fetch origin
git checkout feature/sidewalk
git pull origin feature/sidewalk

docker cp Taipei-City-Dashboard-DE/setup_pedestrian_components.sql postgres-manager:/tmp/setup_pedestrian.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_pedestrian.sql

docker cp Taipei-City-Dashboard-DE/setup_isochrone_components.sql postgres-manager:/tmp/setup_iso.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_iso.sql

docker cp Taipei-City-Dashboard-DE/setup_sidewalk_components.sql postgres-manager:/tmp/setup_sidewalk.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_sidewalk.sql

docker restart dashboard-fe
```

最後 **Ctrl+Shift+R** 重整瀏覽器。

---

## 確認功能

| 功能 | 網址 |
|------|------|
| 行人安全地圖 | `http://localhost/mapview?index=pedestrian-safety&city=metrotaipei` |
| 大眾運輸等時圈（地圖） | `http://localhost/mapview?index=transit-isochrone&city=metrotaipei` |
| 等時圈儀表板（圖表） | `http://localhost/dashboard?index=transit-isochrone&city=metrotaipei` |
| 人行道路網圖資 | `http://localhost/mapview?index=map-layers-metrotaipei&city=metrotaipei` |

---

## 快速驗證資料是否正確進入 DB

```powershell
# 行人事故資料
docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.traffic_pedestrian_accident_taipei;"
docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.traffic_pedestrian_accident_ntpc;"

# 等時圈覆蓋率
docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.isochrone_district_coverage;"

# 人行道路網組件
docker exec postgres-manager psql -U postgres -d dashboardmanager -c "SELECT c.index, qc.city, cm.index AS map_index FROM public.components c JOIN public.query_charts qc ON c.index = qc.index JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids) WHERE c.index = 'sidewalk_osm' ORDER BY qc.city;"
```

預期結果：
- `traffic_pedestrian_accident_taipei`：數千筆
- `traffic_pedestrian_accident_ntpc`：數千筆
- `isochrone_district_coverage`：123 筆（台北 12 區 × 3 交通工具 + 雙北 41 區 × 3）
- `sidewalk_osm`：應出現 3 列（metrotaipei 兩個、taipei 一個）

---

## 常見問題

**Q：跑步驟二出現 `already exists` 錯誤？**
- 正常，可忽略。確認最後有 `COPY xxx` 即代表資料成功匯入

**Q：行政區圖（DistrictChart）是空的？**
- 確認 `metro_district_boundaries` 有資料：
  ```powershell
  docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.metro_district_boundaries;"
  ```
  應該要是 41（台北 12 + 新北 29）。若是 0，重新跑步驟二

**Q：`compute_isochrone_coverage.py` 連不上 DB？**
- 確認 Docker 有在跑：`docker ps`
- 確認 `docker/.env` 裡有 `DB_DASHBOARD_PASSWORD`

**Q：人行道路網 toggle 打開後地圖沒有出現金黃色線條？**
- 確認有執行步驟五（setup_sidewalk_components.sql）
- 確認有重啟 `dashboard-fe`（`docker restart dashboard-fe`）
- 重整後等待約 3–10 秒讓 21 MB GeoJSON 載入完成

**Q：組件全部顯示問號（?????）或 400 錯誤？**
- SQL 中文字元損毀（PowerShell 直接 `<` 重導向會亂碼），重新用 `docker cp` 方式重跑對應步驟

**Q：AI 分析按鈕沒有回應？**
- 確認 `docker/.env` 裡有設定 `ANTHROPIC_API_KEY`

**Q：ColumnChart 疊加順序錯誤（5分鐘不在底層）？**
- 重新跑步驟四的 `setup_isochrone_components.sql` 即可
