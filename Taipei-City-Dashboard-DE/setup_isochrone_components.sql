-- 大眾運輸步行等時圈組件設定
-- 連線：localhost:5432 / dashboardmanager DB
-- 需先確認 isochrone_*_walk*.geojson 已放至 FE/public/mapData/

-- ============================================================
-- 0. 確保 component_charts 有 stacked / scrollable 欄位
--    （冪等，已存在時不報錯）
-- ============================================================
ALTER TABLE public.component_charts ADD COLUMN IF NOT EXISTS stacked    boolean DEFAULT false;
ALTER TABLE public.component_charts ADD COLUMN IF NOT EXISTS scrollable boolean DEFAULT false;


-- ============================================================
-- 1. components
-- ============================================================

INSERT INTO public.components (index, name) VALUES
    ('transit_isochrone_bus', '公車站步行覆蓋等時圈'),
    ('transit_isochrone_mrt', '捷運站步行覆蓋等時圈'),
    ('transit_isochrone_tra', '台鐵站步行覆蓋等時圈')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;


-- ============================================================
-- 2. component_charts（MapLegend 等時圈圖例（可點擊篩選）+ ColumnChart 長條圖 + DistrictChart 行政區覆蓋圖）
-- ============================================================

INSERT INTO public.component_charts (index, color, types, unit, stacked, scrollable) VALUES
    ('transit_isochrone_bus',
        ARRAY['#FFF176', '#FF9800', '#E53935'],
        ARRAY['MapLegend','ColumnChart','DistrictChart'],
        '%', true, false),
    ('transit_isochrone_mrt',
        ARRAY['#80DEEA', '#0097A7', '#004D40'],
        ARRAY['MapLegend','ColumnChart','DistrictChart'],
        '%', true, false),
    ('transit_isochrone_tra',
        ARRAY['#CE93D8', '#7B1FA2', '#311B92'],
        ARRAY['MapLegend','ColumnChart','DistrictChart'],
        '%', true, false)
ON CONFLICT (index) DO UPDATE
    SET color      = EXCLUDED.color,
        types      = EXCLUDED.types,
        unit       = EXCLUDED.unit,
        stacked    = EXCLUDED.stacked,
        scrollable = EXCLUDED.scrollable;


-- ============================================================
-- 3. component_maps
--    index 必須對應 /public/mapData/{index}.geojson 檔名
--    各城市用不同 index（各自的 GeoJSON 只含該城市 features）
-- ============================================================

-- 冪等處理：刪除所有等時圈地圖層後重新插入（component_maps 無 index unique constraint）
DELETE FROM public.component_maps WHERE index LIKE 'isochrone_%';

-- 公車
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property) VALUES
    ('isochrone_bus_walk',        '公車步行等時圈（雙北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#FFF176",
                ["==", ["get", "minutes"], 10], "#FF9800",
                "#E53935"
            ],
            "fill-opacity": 0.45,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]'),
    ('isochrone_bus_walk_taipei', '公車步行等時圈（台北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#FFF176",
                ["==", ["get", "minutes"], 10], "#FF9800",
                "#E53935"
            ],
            "fill-opacity": 0.45,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]');

-- 捷運
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property) VALUES
    ('isochrone_mrt_walk',        '捷運步行等時圈（雙北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#80DEEA",
                ["==", ["get", "minutes"], 10], "#0097A7",
                "#004D40"
            ],
            "fill-opacity": 0.5,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]'),
    ('isochrone_mrt_walk_taipei', '捷運步行等時圈（台北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#80DEEA",
                ["==", ["get", "minutes"], 10], "#0097A7",
                "#004D40"
            ],
            "fill-opacity": 0.5,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]');

-- 台鐵
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property) VALUES
    ('isochrone_tra_walk',        '台鐵步行等時圈（雙北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#CE93D8",
                ["==", ["get", "minutes"], 10], "#7B1FA2",
                "#311B92"
            ],
            "fill-opacity": 0.55,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]'),
    ('isochrone_tra_walk_taipei', '台鐵步行等時圈（台北）', 'fill', 'geojson', NULL, NULL,
        '{
            "fill-color": [
                "case",
                ["==", ["get", "minutes"], 5],  "#CE93D8",
                ["==", ["get", "minutes"], 10], "#7B1FA2",
                "#311B92"
            ],
            "fill-opacity": 0.55,
            "fill-outline-color": "rgba(0,0,0,0)"
        }',
        '[{"key":"minutes","name":"步行時間（分鐘）"}]');


-- ============================================================
-- 4. query_charts（二城市 × 三交通工具 = 6 rows）
--    query_type = 'three_d'：x_axis=行政區, y_axis=時段, data=增量覆蓋率(%)
--    子查詢包裝確保 UNION ALL 後可用 CASE 排序，5分鐘→10分鐘→15分鐘 由下而上疊加
-- ============================================================

-- 冪等處理：先刪除舊資料再插入，避免重複執行時產生重複列
DELETE FROM public.query_charts WHERE index LIKE 'transit_isochrone%';

-- ── 公車 ──

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES
(
    'transit_isochrone_bus', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_bus_walk_taipei' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台北市公共運輸處', '台北市公車站 5/10/15 分鐘步行覆蓋範圍。',
    '以台北市 3,396 個公車站為基礎，分別計算 5、10、15 分鐘步行距離（400/800/1200 公尺）的等時圈覆蓋範圍，展示台北市公車服務的步行可及性。',
    '評估各區公車服務的步行可及性，識別覆蓋不足地區，輔助公車路線調整或新設站決策。',
    ARRAY['https://data.taipei/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''bus'' AND city=''taipei''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''bus'' AND city=''taipei''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''bus'' AND city=''taipei''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'taipei'
),
(
    'transit_isochrone_bus', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_bus_walk' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台北市公共運輸處、新北市交通局', '雙北公車站 5/10/15 分鐘步行覆蓋範圍。',
    '以雙北共 10,882 個公車站為基礎，計算步行等時圈覆蓋範圍，展示大台北地區公車服務的整體步行可及性。',
    '比較雙北公車覆蓋差異，輔助跨城市交通政策規劃。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''bus''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''bus''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''bus''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'metrotaipei'
);

-- ── 捷運 ──

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES
(
    'transit_isochrone_mrt', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_mrt_walk_taipei' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台北捷運公司（TRTC）', '台北捷運站 5/10/15 分鐘步行覆蓋範圍。',
    '以台北市境內 75 個捷運站為基礎，計算各站步行等時圈，展示台北捷運系統的步行可及性。',
    '評估捷運服務覆蓋率，識別捷運沙漠，輔助都市發展或最後一哩解決方案規劃。',
    ARRAY['https://data.taipei/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''mrt'' AND city=''taipei''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''mrt'' AND city=''taipei''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''mrt'' AND city=''taipei''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'taipei'
),
(
    'transit_isochrone_mrt', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_mrt_walk' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台北捷運公司（TRTC）、新北捷運公司（NTMC）', '雙北捷運站 5/10/15 分鐘步行覆蓋範圍。',
    '以雙北共 132 個捷運站（含環狀線）為基礎，計算步行等時圈，展示大台北捷運系統整體覆蓋。',
    '比較雙北捷運覆蓋差異，輔助都市計畫與交通網路擴展決策。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''mrt''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''mrt''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''mrt''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'metrotaipei'
);

-- ── 台鐵 ──

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES
(
    'transit_isochrone_tra', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_tra_walk_taipei' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台灣鐵路管理局（TRA）', '台鐵台北市境內各站 5/10/15 分鐘步行覆蓋範圍。',
    '以台北市境內 4 個台鐵站（南港、松山、台北、萬華）為基礎，計算各站步行等時圈，展示城際鐵路在台北市的步行可及性。',
    '評估台鐵車站對周邊社區的服務覆蓋，辨識與捷運系統的互補關係。',
    ARRAY['https://www.railway.gov.tw/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''tra'' AND city=''taipei''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''tra'' AND city=''taipei''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''tra'' AND city=''taipei''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'taipei'
),
(
    'transit_isochrone_tra', NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'isochrone_tra_walk' LIMIT 1),
    '{"mode":"byParam","byParam":{"xParam":"minutes_label"}}', 'static', NULL, 1, 'year',
    '台灣鐵路管理局（TRA）', '雙北台鐵各站 5/10/15 分鐘步行覆蓋範圍。',
    '以雙北共 14 個台鐵站為基礎，計算步行等時圈，展示台鐵在大台北地區的整體步行可及性。',
    '比較台鐵在雙北的覆蓋分布，評估東西走廊台鐵服務效益。',
    ARRAY['https://www.railway.gov.tw/'], ARRAY['b12705030'],
    NOW(), NOW(), 'three_d',
    E'SELECT x_axis, y_axis, data FROM (SELECT district_name AS x_axis,''5分鐘'' AS y_axis,ROUND(incremental_5min)::int AS data FROM public.isochrone_district_coverage WHERE transport_type=''tra''\nUNION ALL SELECT district_name,''10分鐘'',ROUND(incremental_10min)::int FROM public.isochrone_district_coverage WHERE transport_type=''tra''\nUNION ALL SELECT district_name,''15分鐘'',ROUND(incremental_15min)::int FROM public.isochrone_district_coverage WHERE transport_type=''tra''\n) sub ORDER BY x_axis, CASE y_axis WHEN ''5分鐘'' THEN 1 WHEN ''10分鐘'' THEN 2 WHEN ''15分鐘'' THEN 3 ELSE 4 END',
    NULL, 'metrotaipei'
);


-- ============================================================
-- 5. dashboards（大眾運輸等時圈儀表板）
-- ============================================================

INSERT INTO public.dashboards (index, name, components, icon, created_at, updated_at)
SELECT
    'transit-isochrone',
    '大眾運輸步行等時圈',
    ARRAY(
        SELECT id FROM public.components
        WHERE index IN (
            'transit_isochrone_bus',
            'transit_isochrone_mrt',
            'transit_isochrone_tra'
        )
        ORDER BY ARRAY_POSITION(
            ARRAY['transit_isochrone_bus','transit_isochrone_mrt','transit_isochrone_tra'],
            index
        )
    ),
    'directions_transit',
    NOW(), NOW()
ON CONFLICT (index) DO UPDATE
    SET name       = EXCLUDED.name,
        components = EXCLUDED.components,
        icon       = EXCLUDED.icon,
        updated_at = NOW();


-- ============================================================
-- 6. dashboard_groups（加入 metrotaipei group）
-- ============================================================

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
CROSS JOIN public.groups g
WHERE d.index = 'transit-isochrone'
  AND g.name IN ('public', 'metrotaipei')
ON CONFLICT DO NOTHING;


-- 也加入 map-layers-* 這兩個特殊儀表板，讓圖層出現在地圖疊加選單
DO $$
DECLARE
    v_comp_ids int[];
    v_dash_id  int;
BEGIN
    SELECT ARRAY(
        SELECT id FROM public.components
        WHERE index IN ('transit_isochrone_bus','transit_isochrone_mrt','transit_isochrone_tra')
    ) INTO v_comp_ids;

    -- map-layers-taipei
    SELECT id INTO v_dash_id FROM public.dashboards WHERE index = 'map-layers-taipei';
    IF FOUND THEN
        UPDATE public.dashboards
        SET components = array_cat(components, v_comp_ids), updated_at = NOW()
        WHERE id = v_dash_id
          AND NOT (components && v_comp_ids);
    END IF;

    -- map-layers-metrotaipei
    SELECT id INTO v_dash_id FROM public.dashboards WHERE index = 'map-layers-metrotaipei';
    IF FOUND THEN
        UPDATE public.dashboards
        SET components = array_cat(components, v_comp_ids), updated_at = NOW()
        WHERE id = v_dash_id
          AND NOT (components && v_comp_ids);
    END IF;
END $$;


-- ============================================================
-- 驗證
-- ============================================================
SELECT
    c.index,
    c.name,
    cc.types,
    qc.city,
    cm.index AS map_index
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc ON c.index = qc.index
JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids)
WHERE c.index LIKE 'transit_isochrone%'
ORDER BY c.index, qc.city;
