# 行人安全 + 雙北人行道路網 — 環境設定指南

> 適用分支：`feature/sidewalk`
> 前提：已完成官方 Docker 環境設定（能跑起來基本 Dashboard，`localhost` 有畫面）

---

## 這個分支加了什麼

| 功能 | 說明 |
|------|------|
| 行人安全地圖 | 雙北行人事故熱區、時段分析、年度趨勢、高風險路口排名、AI 報告 |
| 雙北人行道路網圖資 | 地圖交叉比對頁 → 圖資資訊，以金黃色線條顯示 OSM 人行道路網 |

---

## 第一次設定（從來沒跑過這個分支）

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

### 步驟四：設定人行道路網圖資組件

```powershell
docker cp Taipei-City-Dashboard-DE/setup_sidewalk_components.sql postgres-manager:/tmp/setup_sidewalk.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_sidewalk.sql
```

驗證輸出最後應出現：

```
 id  |         index          |   name   |  components
-----+------------------------+----------+-------------
 106 | map-layers-taipei      | 圖資資訊 | {217,42}
 359 | map-layers-metrotaipei | 圖資資訊 | {217,42}
```

---

### 步驟五：重啟後端與前端

```powershell
docker restart dashboard-be
docker restart dashboard-fe
```

> **為什麼要重啟 `dashboard-fe`？**
> Vite dev server 在容器啟動時會掃描 `public/` 目錄。若 geojson 檔案在容器啟動前就已存在（透過 git pull 進來），Vite 有時會快取一個 404 fallback，導致路徑返回 `text/html` 而非 JSON。重啟可強制 Vite 重新掃描，讓 `pedestrian_osm_taipei.geojson` 與 `pedestrian_osm_new_taipei.geojson` 正常被識別。

---

### 步驟六：重新整理瀏覽器

按 **Ctrl+Shift+R**（強制清除快取重整，不是一般 F5）

---

## 已有舊設定，只需要更新

若之前已跑過 `feature/pedestrian-safety` 的設定，只需要：

```powershell
git fetch origin
git checkout feature/sidewalk
git pull origin feature/sidewalk

docker cp Taipei-City-Dashboard-DE/setup_sidewalk_components.sql postgres-manager:/tmp/setup_sidewalk.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/setup_sidewalk.sql

docker restart dashboard-fe
```

最後 **Ctrl+Shift+R** 重整瀏覽器。

---

## 確認功能

### 行人安全地圖

網址：`http://localhost/mapview?index=pedestrian-safety&city=metrotaipei`

應看到：
- 雙北行人事故熱區（行政區分布圖，有顏色深淺）
- 雙北行人事故時段分析（熱力格）
- 雙北行人事故年度趨勢（折線圖）
- 行人事故高風險路口排名 + AI 路口安全報告

---

### 雙北人行道路網圖資

網址：`http://localhost/mapview?index=map-layers-metrotaipei&city=metrotaipei`

1. 左側選單點擊「**雙北人行道路網圖資**」的 toggle
2. 地圖上應出現**金黃色線條**（`#d4a85b`）覆蓋雙北人行道路網
3. 下拉選單應只有「**雙北**」與「**臺北市**」兩個選項

---

## 快速驗證資料是否正確進入 DB

```powershell
# 行人事故資料
docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.traffic_pedestrian_accident_taipei;"
docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.traffic_pedestrian_accident_ntpc;"

# 人行道路網組件
docker exec postgres-manager psql -U postgres -d dashboardmanager -c "SELECT c.index, qc.city, cm.index AS map_index, cm.type FROM public.components c JOIN public.query_charts qc ON c.index = qc.index JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids) WHERE c.index = 'sidewalk_osm' ORDER BY qc.city;"
```

預期結果：
- `traffic_pedestrian_accident_taipei`：數千筆
- `traffic_pedestrian_accident_ntpc`：數千筆
- `sidewalk_osm` 查詢：應出現 3 列，city 為 `metrotaipei`（兩個 map_index）和 `taipei`（一個 map_index），type 均為 `line`

---

## 常見問題

**Q：人行道路網 toggle 打開後地圖沒有出現金黃色線條？**
- 確認有執行步驟四（setup_sidewalk_components.sql）
- 確認有重啟 `dashboard-fe`（`docker restart dashboard-fe`）
- 重整後等待約 3–10 秒讓 21 MB GeoJSON 載入完成

**Q：下拉選單出現「新北市」第三個選項？**
- 確認 `cityManager.ts` 的 metrotaipei `selectList` 只有 `["metrotaipei", "taipei"]`
- 執行 `docker restart dashboard-fe` 讓 Vite HMR 重新載入 `.ts` 設定

**Q：行政區圖顯示 NaN 或全灰？**
- 步驟三的 SQL 中文字元損毀（PowerShell 直接 `<` 重導向會亂碼）
- 重新用 `docker cp` 方式重跑步驟三

**Q：組件全部顯示問號（?????）？**
- 同上，重跑步驟三

**Q：跑步驟二出現 `already exists` 錯誤？**
- 正常，可忽略。確認最後有 `COPY xxx` 即代表資料成功匯入

**Q：AI 分析按鈕沒有回應？**
- 確認 `docker/.env` 裡有設定 `ANTHROPIC_API_KEY`

**Q：PowerShell 跑 SQL 出現 `'<' 運算子保留供未來使用` 錯誤？**
- PowerShell 不支援 `<` 重導向到 native 指令，必須用 `docker cp` + `psql -f` 方式（本文件所有指令皆已採用此方式）
