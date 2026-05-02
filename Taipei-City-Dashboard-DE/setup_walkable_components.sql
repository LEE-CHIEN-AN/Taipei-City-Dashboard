-- 臺北市步行路網圖資 — dashboardmanager DB 組件設定腳本
-- 連線：localhost:5432 / dashboardmanager DB（postgres-manager）
-- GeoJSON：walkable_pedestrian.geojson（步行專用）、walkable_shared.geojson（可步行車道）
-- 資料僅涵蓋臺北市（無新北市）

-- ============================================================
-- 1. component_maps（步行專用 + 可步行車道，臺北 + 新北各兩個圖層）
-- ============================================================
DELETE FROM public.component_maps
WHERE index IN ('walkable_pedestrian', 'walkable_shared', 'walkable_pedestrian_newtaipei', 'walkable_shared_newtaipei');

-- 人行道（footway / steps / path / pedestrian / corridor / elevator / platform）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'walkable_pedestrian',
    '人行道',
    'line',
    'geojson',
    NULL,
    NULL,
    '{
        "line-color": "#d4a85b",
        "line-width": [
            "interpolate", ["linear"], ["zoom"],
            12, 0.8,
            15, 2,
            18, 4
        ],
        "line-opacity": [
            "interpolate", ["linear"], ["zoom"],
            10, 0.5,
            14, 0.85
        ]
    }',
    '[
        {"key": "highway", "name": "類型"},
        {"key": "name",    "name": "名稱"},
        {"key": "surface", "name": "路面"},
        {"key": "lit",     "name": "照明"}
    ]'
);

-- 巷弄道路（residential / living_street / service / unclassified / track / cycleway）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'walkable_shared',
    '巷弄道路',
    'line',
    'geojson',
    NULL,
    NULL,
    '{
        "line-color": "#795548",
        "line-width": [
            "interpolate", ["linear"], ["zoom"],
            12, 0.6,
            15, 1.5,
            18, 3
        ],
        "line-opacity": [
            "interpolate", ["linear"], ["zoom"],
            10, 0.4,
            14, 0.75
        ]
    }',
    '[
        {"key": "highway", "name": "類型"},
        {"key": "name",    "name": "名稱"},
        {"key": "surface", "name": "路面"},
        {"key": "lit",     "name": "照明"}
    ]'
);


-- 新北：人行道
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'walkable_pedestrian_newtaipei',
    '人行道',
    'line',
    'geojson',
    NULL,
    NULL,
    '{
        "line-color": "#d4a85b",
        "line-width": [
            "interpolate", ["linear"], ["zoom"],
            12, 0.8,
            15, 2,
            18, 4
        ],
        "line-opacity": [
            "interpolate", ["linear"], ["zoom"],
            10, 0.5,
            14, 0.85
        ]
    }',
    '[
        {"key": "highway", "name": "類型"},
        {"key": "name",    "name": "名稱"},
        {"key": "surface", "name": "路面"},
        {"key": "lit",     "name": "照明"}
    ]'
);

-- 新北：巷弄道路
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'walkable_shared_newtaipei',
    '巷弄道路',
    'line',
    'geojson',
    NULL,
    NULL,
    '{
        "line-color": "#795548",
        "line-width": [
            "interpolate", ["linear"], ["zoom"],
            12, 0.6,
            15, 1.5,
            18, 3
        ],
        "line-opacity": [
            "interpolate", ["linear"], ["zoom"],
            10, 0.4,
            14, 0.75
        ]
    }',
    '[
        {"key": "highway", "name": "類型"},
        {"key": "name",    "name": "名稱"},
        {"key": "surface", "name": "路面"},
        {"key": "lit",     "name": "照明"}
    ]'
);


-- ============================================================
-- 2. components
-- ============================================================
INSERT INTO public.components (index, name)
VALUES ('walkable_osm_taipei', '雙北步行路網圖資')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;


-- ============================================================
-- 3. component_charts（兩色圖例：綠=步行專用、橘=可步行車道）
-- ============================================================
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'walkable_osm_taipei',
    ARRAY['#d4a85b', '#795548'],
    ARRAY['MapLegend'],
    '條'
)
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;


-- ============================================================
-- 4. query_charts（taipei / metrotaipei 共用同一組圖層，資料僅臺北市）
-- ============================================================
DELETE FROM public.query_charts WHERE index = 'walkable_osm_taipei';

INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'walkable_osm_taipei',
    NULL,
    ARRAY[
        (SELECT id FROM public.component_maps WHERE index = 'walkable_pedestrian'),
        (SELECT id FROM public.component_maps WHERE index = 'walkable_pedestrian_newtaipei'),
        (SELECT id FROM public.component_maps WHERE index = 'walkable_shared'),
        (SELECT id FROM public.component_maps WHERE index = 'walkable_shared_newtaipei')
    ],
    '{}',
    'static',
    NULL,
    0,
    NULL,
    'OpenStreetMap',
    '雙北步行路網，區分人行道與巷弄道路。',
    '資料來源為 OpenStreetMap，依路段類型分為兩層：金黃色為人行道（人行道、步道、階梯等），咖啡色為巷弄道路（巷弄、服務道路等）。涵蓋臺北市與新北市，可用於步行環境完整性與可及性分析。',
    '可與行人事故熱點、公車站、捷運站等圖資套疊，評估步行環境安全性與可達性。',
    ARRAY['https://www.openstreetmap.org/'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'map_legend',
    E'SELECT unnest(ARRAY[''人行道'', ''巷弄道路'']) AS name, ''line'' AS type',
    NULL,
    'metrotaipei'
),(
    'walkable_osm_taipei',
    NULL,
    ARRAY[
        (SELECT id FROM public.component_maps WHERE index = 'walkable_pedestrian'),
        (SELECT id FROM public.component_maps WHERE index = 'walkable_shared')
    ],
    '{}',
    'static',
    NULL,
    0,
    NULL,
    'OpenStreetMap',
    '臺北市步行路網，區分人行道與巷弄道路。',
    '資料來源為 OpenStreetMap，依路段類型分為兩層：金黃色為人行道（人行道、步道、階梯等），咖啡色為巷弄道路（巷弄、服務道路等）。',
    '可與行人事故熱點、公車站、捷運站等圖資套疊，評估步行環境安全性與可達性。',
    ARRAY['https://www.openstreetmap.org/'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'map_legend',
    E'SELECT unnest(ARRAY[''人行道'', ''巷弄道路'']) AS name, ''line'' AS type',
    NULL,
    'taipei'
);


-- ============================================================
-- 5. 加入 map-layers 儀表板
-- ============================================================
UPDATE public.dashboards
SET components = array_append(
        components,
        (SELECT id FROM public.components WHERE index = 'walkable_osm_taipei')
    ),
    updated_at = NOW()
WHERE index = 'map-layers-metrotaipei'
  AND NOT (
      (SELECT id FROM public.components WHERE index = 'walkable_osm_taipei')
      = ANY(components)
  );

UPDATE public.dashboards
SET components = array_append(
        components,
        (SELECT id FROM public.components WHERE index = 'walkable_osm_taipei')
    ),
    updated_at = NOW()
WHERE index = 'map-layers-taipei'
  AND NOT (
      (SELECT id FROM public.components WHERE index = 'walkable_osm_taipei')
      = ANY(components)
  );


-- ============================================================
-- 驗證
-- ============================================================
SELECT
    c.index, qc.city,
    cm.index AS map_index, cm.type
FROM public.components c
JOIN public.query_charts qc ON c.index = qc.index
JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids)
WHERE c.index = 'walkable_osm_taipei'
ORDER BY qc.city, cm.index;
