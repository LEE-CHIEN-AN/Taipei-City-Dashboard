-- 雙北騎樓整平儀表板 — dashboardmanager DB 組件設定腳本
-- 連線：localhost:5432 / dashboardmanager DB（postgres-manager）
-- 僅保留單一組件 arcade_total_district，整合四種視覺化：
--   DistrictChart + BarChart + DonutChart + MapLegend

-- ============================================================
-- 0. 清除舊有已不使用的組件
-- ============================================================

DELETE FROM public.query_charts
WHERE index IN (
    'arcade_yearly_city_trend',
    'arcade_yearly_district_trend',
    'arcade_district_share'
);

DELETE FROM public.component_charts
WHERE index IN (
    'arcade_yearly_city_trend',
    'arcade_yearly_district_trend',
    'arcade_district_share'
);

DELETE FROM public.components
WHERE index IN (
    'arcade_yearly_city_trend',
    'arcade_yearly_district_trend',
    'arcade_district_share'
);


-- ============================================================
-- 1. components 表
-- ============================================================

INSERT INTO public.components (index, name) VALUES
    ('arcade_total_district', '雙北騎樓整平累積量')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;


-- ============================================================
-- 2. component_charts 表
-- ============================================================
-- color 陣列說明：
--   [0] '#FFF9C4'  ← DistrictChart 漸層低值（淡黃）
--   [1] '#B71C1C'  ← DistrictChart 漸層高值（深紅）
--   [2..11]        ← DonutChart 行政區分類色（依序循環）

INSERT INTO public.component_charts (index, color, types, unit) VALUES
    ('arcade_total_district',
        ARRAY[
            '#FFF9C4', '#B71C1C',
            '#F4511E', '#FB8C00', '#FDD835',
            '#43A047', '#00ACC1', '#1E88E5',
            '#5E35B1', '#D81B60', '#8D6E63', '#FF7043'
        ],
        ARRAY['DistrictChart', 'BarChart', 'DonutChart', 'MapLegend'],
        '公尺')
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;


-- ============================================================
-- 3. component_maps 表（比例符號圖層）
-- 注意：taipei 版本必須先於 metrotaipei 版本存在
-- ============================================================

DELETE FROM public.component_maps
WHERE index IN ('arcade_total_district_taipei', 'arcade_total_district');

-- 3-1. 台北市版本
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'arcade_total_district_taipei',
    '騎樓整平總量',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{
        "circle-color": [
            "interpolate", ["linear"],
            ["get", "total_length_m"],
            0,      "#FFF9C4",
            30000,  "#FFB300",
            150000, "#E65100",
            500000, "#B71C1C"
        ],
        "circle-radius": [
            "interpolate", ["linear"], ["zoom"],
            10, ["interpolate", ["linear"], ["get", "total_length_m"],
                  0, 3,   30000, 6,   150000, 10,   500000, 16],
            14, ["interpolate", ["linear"], ["get", "total_length_m"],
                  0, 5,   30000, 10,  150000, 16,   500000, 24]
        ],
        "circle-opacity": 0.85,
        "circle-stroke-width": 1,
        "circle-stroke-color": "#ffffff"
    }',
    '[
        {"key": "district",       "name": "行政區"},
        {"key": "city",           "name": "城市"},
        {"key": "total_length_m", "name": "累積整平長度（公尺）"}
    ]'
);

-- 3-2. 雙北版本（統一黃→紅漸層，與 DistrictChart 一致）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'arcade_total_district',
    '騎樓整平總量（雙北）',
    'circle',
    'geojson',
    NULL,
    NULL,
    '{
        "circle-color": [
            "interpolate", ["linear"],
            ["get", "total_length_m"],
            0,      "#FFF9C4",
            10000,  "#FFB300",
            100000, "#E65100",
            500000, "#B71C1C"
        ],
        "circle-radius": [
            "interpolate", ["linear"], ["zoom"],
            10, ["interpolate", ["linear"], ["get", "total_length_m"],
                  0, 3,   10000, 6,   100000, 10,   500000, 16],
            14, ["interpolate", ["linear"], ["get", "total_length_m"],
                  0, 5,   10000, 10,  100000, 16,   500000, 24]
        ],
        "circle-opacity": 0.85,
        "circle-stroke-width": 1,
        "circle-stroke-color": "#ffffff"
    }',
    '[
        {"key": "district",       "name": "行政區"},
        {"key": "city",           "name": "城市"},
        {"key": "total_length_m", "name": "累積整平長度（公尺）"}
    ]'
);


-- ============================================================
-- 4. query_charts 表
-- ============================================================

DELETE FROM public.query_charts WHERE index LIKE 'arcade_%';

-- ── 台北市版本（附台北地圖圖層）────────────────────────────────
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_total_district',
    NULL,
    (SELECT ARRAY[id] FROM public.component_maps
     WHERE index = 'arcade_total_district_taipei' LIMIT 1),
    '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局',
    '台北市各行政區騎樓整平累積長度。',
    '以行政區圖、長條圖、圓餅圖與地圖比例符號，呈現台北市12個行政區的騎樓整平累積公尺數。萬華、中山、大同、大安為整平量最高的行政區，合計佔全市整平量逾六成。',
    '識別台北市騎樓整平集中的行政區，協助評估步行空間品質的空間均衡性，並作為後續改善政策規劃的依據。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis,\n       ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nWHERE city = ''台北市''\nORDER BY data DESC',
    NULL,
    'taipei'
);

-- ── 新北市版本（無地圖圖層）────────────────────────────────────
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_total_district',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '新北市政府工務局',
    '新北市各行政區騎樓整平累積長度。',
    '以行政區圖、長條圖與圓餅圖呈現新北市各行政區的騎樓整平累積公尺數。板橋、中和、永和為整平量前三大行政區，合計佔全市整平量超過三成。',
    '識別新北市騎樓整平集中的行政區，評估步行空間改善的空間均衡性，找出整平量偏低的行政區優先改善。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis,\n       ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nWHERE city = ''新北市''\nORDER BY data DESC',
    NULL,
    'newtaipei'
);

-- ── 雙北版本（附雙北地圖圖層，Top 20）─────────────────────────
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_total_district',
    NULL,
    (SELECT ARRAY[id] FROM public.component_maps
     WHERE index = 'arcade_total_district' LIMIT 1),
    '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局、新北市政府工務局',
    '雙北各行政區騎樓整平累積長度。',
    '以行政區圖、長條圖、圓餅圖與地圖比例符號呈現雙北所有行政區的騎樓整平累積公尺數。台北市因1990年代大規模整平運動，整體量遠高於新北市持續性整平推進的結果，空間分佈高度集中於台北核心區。',
    '比較雙北各行政區騎樓整平投入程度，識別步行空間改善的空間重點，協助政府規劃更均衡的整平資源分配。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis,\n       ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nORDER BY data DESC',
    NULL,
    'metrotaipei'
);


-- ============================================================
-- 5. arcade_map_legend 獨立圖例組件
-- 說明：MapLegend 需要 map_legend query type，無法與 two_d 同組件
--       因此獨立為一個純圖例卡片，顯示圓點色階說明
-- ============================================================

-- 清除舊有（冪等）
DELETE FROM public.query_charts   WHERE index = 'arcade_map_legend';
DELETE FROM public.component_charts WHERE index = 'arcade_map_legend';
DELETE FROM public.components      WHERE index = 'arcade_map_legend';

INSERT INTO public.components (index, name) VALUES
    ('arcade_map_legend', '騎樓整平地圖圖例')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;

-- 4 色對應 4 個圖例項目（index 順序須與 query 的 unnest 順序一致）
INSERT INTO public.component_charts (index, color, types, unit) VALUES
    ('arcade_map_legend',
        ARRAY['#FFF9C4', '#FFB300', '#E65100', '#B71C1C'],
        ARRAY['MapLegend'],
        '公尺')
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;

-- 三個 city 版本共用同一個靜態圖例（無地圖圖層）
DELETE FROM public.query_charts WHERE index = 'arcade_map_legend';

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
)
SELECT
    'arcade_map_legend',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局、新北市政府工務局',
    '地圖圓點色階對照表。',
    '說明地圖上各行政區圓點顏色與大小所對應的騎樓整平累積長度範圍。顏色由淡黃至深紅表示整平量由少至多，圓點大小亦隨整平量等比例縮放。',
    '協助使用者快速判讀地圖上各行政區圓點所代表的整平量級別。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'map_legend',
    $SQL$SELECT
    unnest(ARRAY[
        '< 10,000 公尺',
        '10,000 – 100,000 公尺',
        '100,000 – 500,000 公尺',
        '≥ 500,000 公尺'
    ]) AS name,
    NULL::float AS value,
    'circle'    AS type$SQL$,
    NULL,
    city_val
FROM (VALUES ('taipei'), ('newtaipei'), ('metrotaipei')) AS t(city_val);


-- ============================================================
-- 6. arcade_leveling_ratio 組件（騎樓整平涵蓋率）
-- 指標：arcade_total_length / walk_length × 100（%）
-- ============================================================

DELETE FROM public.query_charts   WHERE index = 'arcade_leveling_ratio';
DELETE FROM public.component_charts WHERE index = 'arcade_leveling_ratio';
DELETE FROM public.components      WHERE index = 'arcade_leveling_ratio';

INSERT INTO public.components (index, name) VALUES
    ('arcade_leveling_ratio', '騎樓整平涵蓋率')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit) VALUES
    ('arcade_leveling_ratio',
        ARRAY[
            '#FFF9C4', '#B71C1C',
            '#F4511E', '#FB8C00', '#FDD835',
            '#43A047', '#00ACC1', '#1E88E5',
            '#5E35B1', '#D81B60', '#8D6E63', '#FF7043'
        ],
        ARRAY['DistrictChart', 'BarChart'],
        '%')
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;

DELETE FROM public.query_charts WHERE index = 'arcade_leveling_ratio';

-- ── 台北市版本 ────────────────────────────────────────────────
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_leveling_ratio',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局',
    '台北市各行政區騎樓整平長度佔人行道總長度比例。',
    '以行政區圖與長條圖呈現台北市各行政區騎樓整平累積長度佔 OSM 人行道網絡總長度的比例。萬華、大同等核心舊城區比例超過 100%，反映 1990 年代大規模整平政策的高密度執行。士林、北投、內湖等面積較大行政區的人行道網絡廣，比例相對較低。',
    '評估台北市各行政區的騎樓整平覆蓋程度，識別整平密度高與覆蓋不足的行政區，協助優化步行空間資源分配。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT p.district AS x_axis,\n       ROUND((COALESCE(a.total_length_m, 0) / p.walk_length_m * 100)::numeric, 1)::FLOAT AS data\nFROM public.pedestrian_length_by_district p\nLEFT JOIN public.arcade_total_by_district a\n    ON p.district = a.district AND a.city = ''台北市''\nWHERE p.city = ''台北市'' AND p.walk_length_m > 0\nORDER BY data DESC',
    NULL,
    'taipei'
);

-- ── 新北市版本 ────────────────────────────────────────────────
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_leveling_ratio',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '新北市政府工務局',
    '新北市各行政區騎樓整平長度佔人行道總長度比例。',
    '以行政區圖與長條圖呈現新北市各行政區騎樓整平累積長度佔 OSM 人行道網絡總長度的比例。永和（83%）、中和（34%）為比例最高的行政區，烏來、坪林等山區行政區人行道廣但整平量為零。',
    '評估新北市各行政區的騎樓整平覆蓋程度，識別整平密度高與覆蓋不足的行政區，協助政府優化步行改善資源的空間分配。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT p.district AS x_axis,\n       ROUND((COALESCE(a.total_length_m, 0) / p.walk_length_m * 100)::numeric, 1)::FLOAT AS data\nFROM public.pedestrian_length_by_district p\nLEFT JOIN public.arcade_total_by_district a\n    ON p.district = a.district AND a.city = ''新北市''\nWHERE p.city = ''新北市'' AND p.walk_length_m > 0\nORDER BY data DESC',
    NULL,
    'newtaipei'
);

-- ── 雙北版本（城市內相對比例，改善 DistrictChart 色差）──────────
-- 注意：直接比較雙北的原始比例時，台北（0–1113%）遠大於新北（0–83%），
--       DistrictChart 色階會讓新北各區幾乎透明。
--       改以各城市內的最大比例作分母（city-max normalized），
--       讓兩市均能清楚呈現空間分佈差異。
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_leveling_ratio',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局、新北市政府工務局',
    '雙北各行政區騎樓整平涵蓋率（城市內相對值）。',
    '以行政區圖與長條圖呈現雙北各行政區騎樓整平長度相對於所屬城市最高行政區的比例。台北以萬華（最高）、新北以永和（最高）為基準，設為 100；其他行政區依比例遞減。台北舊城核心（萬華、大同、大安）與新北永和呈現最高涵蓋率。',
    '比較雙北兩市在各行政區的騎樓整平相對涵蓋程度，識別整平政策執行力強弱的空間分佈差異。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'WITH ratios AS (\n    SELECT p.district,\n           p.city,\n           COALESCE(a.total_length_m, 0) / p.walk_length_m * 100 AS ratio\n    FROM public.pedestrian_length_by_district p\n    LEFT JOIN public.arcade_total_by_district a\n        ON p.district = a.district AND p.city = a.city\n    WHERE p.walk_length_m > 0\n),\ncity_max AS (\n    SELECT city, MAX(ratio) AS max_ratio\n    FROM ratios\n    GROUP BY city\n)\nSELECT r.district AS x_axis,\n       ROUND((r.ratio / cm.max_ratio * 100)::numeric, 1)::FLOAT AS data\nFROM ratios r\nJOIN city_max cm ON r.city = cm.city\nORDER BY r.ratio DESC',
    NULL,
    'metrotaipei'
);


-- ============================================================
-- 7. dashboards 表
-- ============================================================

INSERT INTO public.dashboards (index, name, components, icon, created_at, updated_at)
SELECT
    'arcade-leveling',
    '騎樓整平指標',
    ARRAY(
        SELECT id FROM public.components
        WHERE index IN (
            'arcade_total_district',
            'arcade_leveling_ratio'
        )
        ORDER BY ARRAY_POSITION(
            ARRAY[
                'arcade_total_district',
                'arcade_leveling_ratio'
            ],
            index
        )
    ),
    'storefront',
    NOW(),
    NOW()
ON CONFLICT (index) DO UPDATE
    SET name       = EXCLUDED.name,
        components = EXCLUDED.components,
        icon       = EXCLUDED.icon,
        updated_at = NOW();


-- ============================================================
-- 8. dashboard_groups 表
-- ============================================================

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
CROSS JOIN public.groups g
WHERE d.index = 'arcade-leveling'
  AND g.name IN ('public', 'metrotaipei')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 驗證
-- ============================================================
SELECT
    c.id,
    c.index,
    c.name,
    cc.types,
    qc.city,
    qc.query_type,
    array_length(qc.map_config_ids, 1) AS has_map
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc     ON c.index = qc.index
WHERE c.index LIKE 'arcade_%'
ORDER BY c.index, qc.city;
-- 預期：9 筆（3 組件 × 3 cities）
