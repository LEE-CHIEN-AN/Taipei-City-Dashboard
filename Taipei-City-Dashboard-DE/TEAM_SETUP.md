# 雙北程式設計節黑客松 — 環境設定指南

> 適用分支：`feature/transit-isochrone`
> 前提：已完成官方 Docker 環境設定（能跑起來基本 Dashboard）

---

## 一、拉最新程式碼

```powershell
git fetch origin
git checkout feature/transit-isochrone
git pull origin feature/transit-isochrone
```

---

## 二、Import 行人安全儀表板資料

### 2-1. Import 事故資料（dump 檔，約 12MB）

> dump 本身會自動建表，不需要先跑 setup_pedestrian_tables.sql

```powershell
docker exec -i postgres-data psql -U postgres -d dashboard < Taipei-City-Dashboard-DE/pedestrian_all.sql
```

看到下面這樣就成功了（有些 `already exists` 警告可以忽略）：
```
SET
SET
...
COPY 29
COPY 12
```

### 2-2. 設定儀表板組件

```powershell
docker exec -i postgres-manager psql -U postgres -d dashboardmanager < Taipei-City-Dashboard-DE/setup_pedestrian_components.sql
```

---

## 三、建立大眾運輸步行等時圈儀表板

### 3-1. 設定組件（地圖層 + 圖表）

```powershell
docker exec -i postgres-manager psql -U postgres -d dashboardmanager < Taipei-City-Dashboard-DE/setup_isochrone_components.sql
```

### 3-2. 計算各行政區覆蓋率並寫入 DB

> 需要 Python 環境，安裝依賴：
> ```powershell
> pip install shapely pyproj psycopg2-binary
> ```

```powershell
python Taipei-City-Dashboard-DE/compute_isochrone_coverage.py
```

成功會看到：
```
讀取行政區邊界...
  台北: 12 區，新北: 29 區
=== 公車 ===
  [台北] 載入等時圈...
  ...
共 123 筆，寫入 DB...
完成！
```

---

## 四、重新整理瀏覽器

以上步驟都完成後，在瀏覽器按 **Ctrl+Shift+R**（強制重新整理）。

進入以下路徑確認：

| 功能 | 網址 |
|------|------|
| 行人安全地圖 | `http://localhost:8080/mapview?index=pedestrian-safety&city=metrotaipei` |
| 大眾運輸等時圈（地圖） | `http://localhost:8080/mapview?index=transit-isochrone&city=metrotaipei` |
| 等時圈儀表板（圖表） | `http://localhost:8080/dashboard?index=transit-isochrone&city=metrotaipei` |

---

## 常見問題

**Q：跑 pedestrian_all.sql 出現 `already exists` 錯誤？**
- 正常！dump 會建表，若表已存在就跳過，資料仍會正確匯入
- 確認最後有出現 `COPY xxx` 訊息代表資料有進去

**Q：行政區圖（DistrictChart）是空的？**
- 確認 `metro_district_boundaries` 有資料：
  ```powershell
  docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.metro_district_boundaries;"
  ```
  應該要是 41（台北 12 + 新北 29）。若是 0，重新跑 step 2-1

**Q：組件顯示 400 錯誤？**
- 確認 step 2-2 / 3-1 的組件設定 SQL 有跑過
- 確認資料表有資料：
  ```powershell
  docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.traffic_pedestrian_accident_taipei;"
  docker exec postgres-data psql -U postgres -d dashboard -c "SELECT COUNT(*) FROM public.isochrone_district_coverage;"
  ```

**Q：熱點圖有但其他圖表沒有？**
- step 2-2 的 `setup_pedestrian_components.sql` 可能沒跑，補跑一次

**Q：`compute_isochrone_coverage.py` 連不上 DB？**
- 確認 Docker 有在跑：`docker ps`
- 確認 `docker/.env` 裡有 `DB_DASHBOARD_PASSWORD`
