-- 更新雙北步行路網組件名稱、顏色、圖例

-- 1. 組件名稱
UPDATE public.components
SET name = '雙北步行路網圖資'
WHERE index = 'walkable_osm_taipei';

-- 2. 圖層顏色 + 標題（人行道：黃色 #d4a85b）
UPDATE public.component_maps
SET title = '人行道',
    paint = '{"line-color": "#d4a85b", "line-width": ["interpolate", ["linear"], ["zoom"], 12, 0.8, 15, 2, 18, 4], "line-opacity": ["interpolate", ["linear"], ["zoom"], 10, 0.5, 14, 0.85]}'
WHERE index IN ('walkable_pedestrian', 'walkable_pedestrian_newtaipei');

-- 3. 圖層顏色 + 標題（巷弄道路：橘色 #FF9800）
UPDATE public.component_maps
SET title = '巷弄道路',
    paint = '{"line-color": "#FF9800", "line-width": ["interpolate", ["linear"], ["zoom"], 12, 0.6, 15, 1.5, 18, 3], "line-opacity": ["interpolate", ["linear"], ["zoom"], 10, 0.4, 14, 0.75]}'
WHERE index IN ('walkable_shared', 'walkable_shared_newtaipei');

-- 4. 圖例顏色
UPDATE public.component_charts
SET color = ARRAY['#d4a85b', '#FF9800']
WHERE index = 'walkable_osm_taipei';

-- 5. 圖例名稱
UPDATE public.query_charts
SET query_chart = E'SELECT unnest(ARRAY[''人行道'', ''巷弄道路'']) AS name, ''line'' AS type'
WHERE index = 'walkable_osm_taipei';

-- 6. 把 sidewalk_osm 從儀表板移除
UPDATE public.dashboards
SET components = array_remove(components, (SELECT id FROM public.components WHERE index = 'sidewalk_osm')),
    updated_at = NOW()
WHERE index IN ('map-layers-metrotaipei', 'map-layers-taipei');

-- 7. 刪除 sidewalk_osm 全部資料
DELETE FROM public.query_charts   WHERE index = 'sidewalk_osm';
DELETE FROM public.component_charts WHERE index = 'sidewalk_osm';
DELETE FROM public.component_maps WHERE index IN ('pedestrian_osm_taipei', 'pedestrian_osm_new_taipei');
DELETE FROM public.components     WHERE index = 'sidewalk_osm';

SELECT 'done' AS status;
