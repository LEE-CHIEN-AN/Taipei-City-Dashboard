-- 新增行人事故圓餅圖組件：天氣分布 & 事故類型細項
-- 前提：ped_accident_weather_stats / ped_accident_subtype_stats 已在 dashboard DB 建好

-- ============================================================
-- 1. components
-- ============================================================
INSERT INTO public.components (index, name) VALUES
    ('traffic_pedestrian_weather',      '行人事故天氣分布'),
    ('traffic_pedestrian_subtype',      '人對車事故類型細項')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================
-- 2. component_charts
-- ============================================================
INSERT INTO public.component_charts (index, color, types, unit) VALUES
    ('traffic_pedestrian_weather',
        ARRAY['#FDD835','#42A5F5','#90A4AE','#78909C'],
        ARRAY['DonutChart'],
        '件'),
    ('traffic_pedestrian_subtype',
        ARRAY['#EF5350','#FF7043','#FFA726','#FFCA28','#66BB6A','#26C6DA','#5C6BC0','#AB47BC','#EC407A'],
        ARRAY['DonutChart'],
        '件')
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;

-- ============================================================
-- 3. query_charts
-- ============================================================
DELETE FROM public.query_charts
WHERE index IN ('traffic_pedestrian_weather','traffic_pedestrian_subtype');

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES
(
    'traffic_pedestrian_weather',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '內政部警政署',
    '2026年1-4月雙北人與車事故的天氣分布。',
    '以圓餅圖呈現 2026 年 1–4 月台北市與新北市「人與車」類事故發生當下的天氣條件比例，反映晴天、雨天等不同天氣下的事故分布情況。',
    '了解天氣對行人事故的影響，協助決策雨天執法或道路防滑設施規劃。',
    ARRAY['https://data.gov.tw/dataset/13139'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT weather AS x_axis, count::INT AS data\nFROM public.ped_accident_weather_stats\nWHERE city = ''metrotaipei''\nORDER BY count DESC',
    NULL,
    'metrotaipei'
),
(
    'traffic_pedestrian_weather',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '內政部警政署',
    '2026年1-4月臺北市人與車事故的天氣分布。',
    '以圓餅圖呈現 2026 年 1–4 月臺北市「人與車」類事故發生當下的天氣條件比例。',
    '了解天氣對行人事故的影響，協助決策雨天執法或道路防滑設施規劃。',
    ARRAY['https://data.gov.tw/dataset/13139'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT weather AS x_axis, count::INT AS data\nFROM public.ped_accident_weather_stats\nWHERE city = ''taipei''\nORDER BY count DESC',
    NULL,
    'taipei'
),
(
    'traffic_pedestrian_subtype',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '內政部警政署',
    '2026年1-4月雙北人與車事故類型細項比例。',
    '以圓餅圖呈現 2026 年 1–4 月台北市與新北市「人與車」類事故中各細項型態的比例分布。',
    '識別最危險的行人行為情境，作為行人安全教育宣導與設施改善的依據。',
    ARRAY['https://data.gov.tw/dataset/13139'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT subtype AS x_axis, count::INT AS data\nFROM public.ped_accident_subtype_stats\nWHERE city = ''metrotaipei''\nORDER BY count DESC',
    NULL,
    'metrotaipei'
),
(
    'traffic_pedestrian_subtype',
    NULL, '{}', '{}',
    'static', NULL, 1, 'year',
    '內政部警政署',
    '2026年1-4月臺北市人與車事故類型細項比例。',
    '以圓餅圖呈現 2026 年 1–4 月臺北市「人與車」類事故中各細項型態的比例分布。',
    '識別最危險的行人行為情境，作為行人安全教育宣導與設施改善的依據。',
    ARRAY['https://data.gov.tw/dataset/13139'],
    ARRAY['b12705030'],
    NOW(), NOW(),
    'two_d',
    E'SELECT subtype AS x_axis, count::INT AS data\nFROM public.ped_accident_subtype_stats\nWHERE city = ''taipei''\nORDER BY count DESC',
    NULL,
    'taipei'
);

-- ============================================================
-- 4. 加入 pedestrian-safety dashboard
-- ============================================================
UPDATE public.dashboards
SET components = components ||
    ARRAY(
        SELECT id FROM public.components
        WHERE index IN ('traffic_pedestrian_weather','traffic_pedestrian_subtype')
        AND id != ALL(
            COALESCE(
                (SELECT components FROM public.dashboards WHERE index = 'pedestrian-safety'),
                '{}'
            )
        )
    ),
    updated_at = NOW()
WHERE index = 'pedestrian-safety';

-- 驗證
SELECT c.index, c.name, cc.types, qc.city, qc.query_type
FROM public.components c
JOIN public.component_charts cc ON c.index = cc.index
JOIN public.query_charts qc ON c.index = qc.index
WHERE c.index IN ('traffic_pedestrian_weather','traffic_pedestrian_subtype');
