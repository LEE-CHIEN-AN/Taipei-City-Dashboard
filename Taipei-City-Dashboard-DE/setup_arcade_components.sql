-- 雙北騎樓整平儀表板 — dashboardmanager DB 組件設定腳本
-- 連線：localhost:5432 / dashboardmanager DB（postgres-manager）
-- 執行前請確認：
--   1. setup_arcade_tables.sql 已在 postgres-data 執行
--   2. import_arcade_csv.py 已執行完畢（資料已匯入）
--   3. arcade_total_district.geojson 已放至 FE/public/mapData/

-- ============================================================
-- 1. components 表（組件基本資訊）
-- ============================================================

INSERT INTO public.components (index, name) VALUES
    ('arcade_total_district',        '雙北騎樓整平累積量'),
    ('arcade_yearly_city_trend',     '雙北騎樓整平逐年趨勢'),
    ('arcade_yearly_district_trend', '各行政區騎樓整平逐年趨勢'),
    ('arcade_district_share',        '騎樓整平行政區佔比')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;


-- ============================================================
-- 2. component_charts 表（圖表設定）
-- ============================================================

INSERT INTO public.component_charts (index, color, types, unit) VALUES
    -- C1：行政區圖（漸層熱區）+ 橫向長條圖 + 地圖圖例
    ('arcade_total_district',
        ARRAY['#FFF9C4', '#FFB300', '#E65100', '#B71C1C'],
        ARRAY['DistrictChart', 'BarChart', 'MapLegend'],
        '公尺'),
    -- C2：雙軸折線圖（台北 vs 新北）
    ('arcade_yearly_city_trend',
        ARRAY['#E53935', '#1E88E5'],
        ARRAY['TimelineSeparateChart'],
        '公尺'),
    -- C3：多線折線圖（各行政區）
    ('arcade_yearly_district_trend',
        ARRAY['#E53935', '#F4511E', '#FB8C00', '#FDD835',
              '#43A047', '#00ACC1', '#1E88E5', '#5E35B1',
              '#D81B60', '#8D6E63', '#546E7A', '#FF7043'],
        ARRAY['TimelineSeparateChart'],
        '公尺'),
    -- C4：圓餅圖（行政區佔比）+ 長條百分比圖
    ('arcade_district_share',
        ARRAY['#E53935', '#F4511E', '#FB8C00', '#FDD835',
              '#43A047', '#00ACC1', '#1E88E5', '#5E35B1',
              '#D81B60', '#8D6E63', '#546E7A', '#FF7043'],
        ARRAY['DonutChart', 'BarPercentChart'],
        '%')
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;


-- ============================================================
-- 3. component_maps 表（地圖圖層 — 各行政區整平量比例符號）
-- 注意：規範要求 taipei 版本必須先於 metrotaipei 版本存在
-- ============================================================

-- 先刪除舊設定以確保冪等
DELETE FROM public.component_maps
WHERE index IN ('arcade_total_district_taipei', 'arcade_total_district');

-- 3-1. 台北市版本（taipei）— 對應 GeoJSON 檔名：arcade_total_district_taipei.geojson
--      因 fetchLocalGeoJson 以 index 為檔名，台北版圖層另存一個 index
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

-- 3-2. 雙北版本（metrotaipei）— 同一份 GeoJSON 包含台北+新北所有行政區
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
            "match", ["get", "city"],
            "台北市", [
                "interpolate", ["linear"],
                ["get", "total_length_m"],
                0,      "#FFF9C4",
                150000, "#E65100",
                500000, "#B71C1C"
            ],
            [
                "interpolate", ["linear"],
                ["get", "total_length_m"],
                0,     "#E3F2FD",
                10000, "#42A5F5",
                25000, "#1565C0"
            ]
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

-- 清除既有的 arcade query_charts 避免重複
DELETE FROM public.query_charts WHERE index LIKE 'arcade_%';

-- ── C1：雙北騎樓整平累積量 ────────────────────────────────────

-- C1-taipei（台北市，引用 taipei 版 map layer）
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_total_district',
    NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'arcade_total_district_taipei' LIMIT 1),
    '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局',
    '台北市各行政區騎樓整平累積長度。',
    '以行政區圖、長條圖與地圖比例符號，呈現台北市各行政區騎樓整平的累積公尺數，反映不同地區步行環境改善的投入程度。',
    '識別騎樓整平優先區域，協助政府評估步行空間品質並規劃後續改善計畫。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis, ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nWHERE city = ''台北市''\nORDER BY data DESC',
    NULL,
    'taipei'
);

-- C1-newtaipei
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
    '以行政區圖與長條圖呈現新北市各行政區騎樓整平的累積公尺數，反映不同地區步行環境改善的投入程度。',
    '識別騎樓整平優先區域，協助政府評估步行空間品質並規劃後續改善計畫。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis, ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nWHERE city = ''新北市''\nORDER BY data DESC',
    NULL,
    'newtaipei'
);

-- C1-metrotaipei（雙北，引用 metrotaipei 版 map layer）
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_total_district',
    NULL,
    (SELECT ARRAY[id] FROM public.component_maps WHERE index = 'arcade_total_district' LIMIT 1),
    '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局、新北市政府工務局',
    '雙北各行政區騎樓整平累積長度（Top 20 排名）。',
    '以行政區圖、長條圖與地圖比例符號呈現雙北各行政區騎樓整平的累積公尺數，台北（紅）與新北（藍）分色標示，反映整體大台北地區步行環境的空間分佈差異。',
    '比較雙北各行政區整平進度，找出整平量最高與最低的行政區，識別步行環境改善的優先地區。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT district AS x_axis, ROUND(total_length_m)::INT AS data\nFROM public.arcade_total_by_district\nORDER BY data DESC\nLIMIT 20',
    NULL,
    'metrotaipei'
);

-- ── C2：雙北騎樓整平逐年趨勢 ─────────────────────────────────

-- C2-taipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_city_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '臺北市政府工務局',
    '台北市騎樓整平逐年公尺數（1991–1999）。',
    '以折線圖呈現台北市騎樓整平的年度整平長度，觀察1990年代大規模整平政策的推動波動。',
    '評估台北市騎樓整平政策推動時程，了解整平力道的年度分佈。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'SELECT make_date(year::int, 1, 1) AS x_axis,\n       city AS y_axis,\n       ROUND(city_total_m)::INT AS data\nFROM public.arcade_yearly_by_city\nWHERE city = ''台北市''\nORDER BY year',
    NULL,
    'taipei'
);

-- C2-newtaipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_city_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '新北市政府工務局',
    '新北市騎樓整平逐年公尺數（2010–2024）。',
    '以折線圖呈現新北市騎樓整平的年度整平長度，觀察近年整平政策推動的持續性與趨勢。',
    '評估新北市騎樓整平政策效果，了解哪些年度整平量較大，協助研擬後續改善重點。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'SELECT make_date(year::int, 1, 1) AS x_axis,\n       city AS y_axis,\n       ROUND(city_total_m)::INT AS data\nFROM public.arcade_yearly_by_city\nWHERE city = ''新北市''\nORDER BY year',
    NULL,
    'newtaipei'
);

-- C2-metrotaipei：雙北對比折線圖
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_city_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '臺北市政府工務局、新北市政府工務局',
    '雙北騎樓整平逐年趨勢對比（台北1991–1999、新北2010–2024）。',
    '以雙線折線圖呈現台北市（紅）與新北市（藍）的年度騎樓整平長度，比較兩市整平政策的推動節奏。台北市集中在1990年代大規模整平，新北市則在2010年代後持續穩定推進，兩者呈現截然不同的政策時程。',
    '比較雙北騎樓整平政策的執行節奏，了解各市整平高峰期，評估現階段整平資源是否充足。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'SELECT make_date(year::int, 1, 1) AS x_axis,\n       city AS y_axis,\n       ROUND(city_total_m)::INT AS data\nFROM public.arcade_yearly_by_city\nORDER BY year, city',
    NULL,
    'metrotaipei'
);

-- ── C3：各行政區騎樓整平逐年趨勢 ─────────────────────────────

-- C3-taipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_district_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '臺北市政府工務局',
    '台北市各行政區騎樓整平逐年長度。',
    '以多線折線圖呈現台北市12個行政區的騎樓整平年度進度，可觀察各區整平時序的差異，識別整平較慢的行政區。',
    '比較台北市各行政區整平推動速度，找出哪些行政區整平量集中在特定年份，協助評估政策落實均衡度。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'SELECT make_date(year::int, 1, 1) AS x_axis,\n       district AS y_axis,\n       ROUND(length_m)::INT AS data\nFROM public.arcade_yearly_by_district\nWHERE city = ''台北市'' AND length_m > 0\nORDER BY year, district',
    NULL,
    'taipei'
);

-- C3-newtaipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_district_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '新北市政府工務局',
    '新北市各行政區騎樓整平逐年長度（2010–2024）。',
    '以多線折線圖呈現新北市各行政區的騎樓整平年度進度，可觀察板橋、中和、永和等人口密集區整平推動情況。',
    '比較新北市各行政區整平推動速度，找出整平量下滑的行政區，建議政府加強改善。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'SELECT make_date(year::int, 1, 1) AS x_axis,\n       district AS y_axis,\n       ROUND(length_m)::INT AS data\nFROM public.arcade_yearly_by_district\nWHERE city = ''新北市'' AND length_m > 0\nORDER BY year, district',
    NULL,
    'newtaipei'
);

-- C3-metrotaipei：整平量前8行政區
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_yearly_district_trend',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '臺北市政府工務局、新北市政府工務局',
    '雙北整平量前8行政區逐年趨勢。',
    '以多線折線圖呈現雙北累積整平量最高的8個行政區的逐年整平進度（台北萬華、中山、大同、大安；新北板橋、中和、新莊、永和），呈現各重點行政區整平政策推動的時序差異。',
    '識別雙北整平推動最積極的行政區，作為步行環境改善政策的參考依據。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'time',
    E'WITH top_districts AS (\n    SELECT district\n    FROM public.arcade_total_by_district\n    ORDER BY total_length_m DESC\n    LIMIT 8\n)\nSELECT make_date(d.year::int, 1, 1) AS x_axis,\n       d.district AS y_axis,\n       ROUND(d.length_m)::INT AS data\nFROM public.arcade_yearly_by_district d\nJOIN top_districts t ON d.district = t.district\nWHERE d.length_m > 0\nORDER BY d.year, d.district',
    NULL,
    'metrotaipei'
);

-- ── C4：騎樓整平行政區佔比 ────────────────────────────────────

-- C4-taipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_district_share',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局',
    '台北市各行政區騎樓整平佔全市比例。',
    '以圓餅圖與長條百分比圖呈現台北市各行政區在全市騎樓整平總量中的比重，識別整平資源的空間集中程度。萬華、中山、大安為整平量前三大行政區。',
    '評估台北市騎樓整平的空間均衡性，找出整平過度集中或不足的行政區，引導政策資源合理分配。',
    ARRAY['https://data.taipei/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'WITH city_total AS (\n    SELECT SUM(total_length_m) AS total\n    FROM public.arcade_total_by_district\n    WHERE city = ''台北市''\n)\nSELECT\n    a.district AS x_axis,\n    ROUND((a.total_length_m / c.total * 100)::numeric, 1)::FLOAT AS data\nFROM public.arcade_total_by_district a\nCROSS JOIN city_total c\nWHERE a.city = ''台北市''\nORDER BY data DESC',
    NULL,
    'taipei'
);

-- C4-newtaipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_district_share',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '新北市政府工務局',
    '新北市各行政區騎樓整平佔全市比例。',
    '以圓餅圖與長條百分比圖呈現新北市各行政區在全市騎樓整平總量中的比重。板橋、中和、永和為整平量前三大行政區，合計佔新北整體整平量超過三成。',
    '評估新北市騎樓整平的空間均衡性，找出整平過度集中或不足的行政區，引導政策資源合理分配。',
    ARRAY['https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'WITH city_total AS (\n    SELECT SUM(total_length_m) AS total\n    FROM public.arcade_total_by_district\n    WHERE city = ''新北市''\n)\nSELECT\n    a.district AS x_axis,\n    ROUND((a.total_length_m / c.total * 100)::numeric, 1)::FLOAT AS data\nFROM public.arcade_total_by_district a\nCROSS JOIN city_total c\nWHERE a.city = ''新北市'' AND a.total_length_m > 0\nORDER BY data DESC',
    NULL,
    'newtaipei'
);

-- C4-metrotaipei
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'arcade_district_share',
    NULL, '{}', '{}',
    'static', NULL, NULL, NULL,
    '臺北市政府工務局、新北市政府工務局',
    '雙北各行政區騎樓整平佔雙北合計比例（Top 12）。',
    '以圓餅圖與長條百分比圖呈現雙北整平量前12行政區在整體雙北騎樓整平中的比重，反映整平資源的城市與行政區分佈集中程度。',
    '評估雙北騎樓整平的空間均衡性，識別資源高度集中於特定行政區的現象，協助政策研擬更均衡的整平計畫。',
    ARRAY['https://data.taipei/', 'https://data.ntpc.gov.tw/'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'WITH total AS (\n    SELECT SUM(total_length_m) AS grand_total\n    FROM public.arcade_total_by_district\n)\nSELECT\n    a.district AS x_axis,\n    ROUND((a.total_length_m / t.grand_total * 100)::numeric, 1)::FLOAT AS data\nFROM public.arcade_total_by_district a\nCROSS JOIN total t\nWHERE a.total_length_m > 0\nORDER BY data DESC\nLIMIT 12',
    NULL,
    'metrotaipei'
);


-- ============================================================
-- 5. dashboards 表（建立騎樓整平儀表板）
-- ============================================================

INSERT INTO public.dashboards (index, name, components, icon, created_at, updated_at)
SELECT
    'arcade-leveling',
    '騎樓整平指標',
    ARRAY(
        SELECT id FROM public.components
        WHERE index IN (
            'arcade_total_district',
            'arcade_yearly_city_trend',
            'arcade_yearly_district_trend',
            'arcade_district_share'
        )
        ORDER BY ARRAY_POSITION(
            ARRAY[
                'arcade_total_district',
                'arcade_yearly_city_trend',
                'arcade_yearly_district_trend',
                'arcade_district_share'
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
-- 6. dashboard_groups 表（加入 metrotaipei group）
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
-- 預期：12 筆（4 組件 × 3 cities）
-- arcade_total_district 之 taipei 和 metrotaipei 版本的 has_map 應為 1
