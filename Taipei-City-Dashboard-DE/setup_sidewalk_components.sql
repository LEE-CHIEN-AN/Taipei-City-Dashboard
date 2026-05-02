-- 雙北人行道路網圖資 — dashboardmanager DB 組件設定腳本
-- 連線：localhost:5432 / dashboardmanager DB（postgres-manager）
-- 架構：仿照自行車路網圖資（bike_map），以 OSM 線狀圖層呈現雙北人行道路網
-- GeoJSON：pedestrian_osm_taipei.geojson、pedestrian_osm_new_taipei.geojson

-- ============================================================
-- 1. component_maps（兩個分城市圖層）
-- ============================================================
DELETE FROM public.component_maps
WHERE index IN ('pedestrian_osm_taipei', 'pedestrian_osm_new_taipei');

INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'pedestrian_osm_taipei',
    '人行道路網',
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

INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'pedestrian_osm_new_taipei',
    '人行道路網',
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


-- ============================================================
-- 2. components（組件基本資訊）
-- ============================================================
INSERT INTO public.components (index, name)
VALUES ('sidewalk_osm', '雙北人行道路網圖資')
ON CONFLICT (index) DO UPDATE SET name = EXCLUDED.name;


-- ============================================================
-- 3. component_charts（圖例設定）
-- ============================================================
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'sidewalk_osm',
    ARRAY['#d4a85b'],
    ARRAY['MapLegend'],
    '條'
)
ON CONFLICT (index) DO UPDATE
    SET color = EXCLUDED.color,
        types = EXCLUDED.types,
        unit  = EXCLUDED.unit;


-- ============================================================
-- 4. query_charts（metrotaipei：臺北 + 新北兩圖層；taipei：僅臺北）
-- ============================================================
DELETE FROM public.query_charts WHERE index = 'sidewalk_osm';

-- metrotaipei：同時顯示臺北 + 新北圖層
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'sidewalk_osm',
    NULL,
    ARRAY[
        (SELECT id FROM public.component_maps WHERE index = 'pedestrian_osm_taipei'),
        (SELECT id FROM public.component_maps WHERE index = 'pedestrian_osm_new_taipei')
    ],
    '{}',
    'static',
    NULL,
    0,
    NULL,
    'OpenStreetMap',
    '雙北人行道路網分布，以線狀呈現人行道路徑。',
    '資料來源為 OpenStreetMap，以線狀圖層呈現雙北（臺北市與新北市）人行道路網空間範圍，包含人行道（footway）、行人徒步區（pedestrian）、階梯（steps）及步道（path）等，含路面、照明等屬性，適合與其他圖資套疊進行步行環境分析。',
    '可與事故熱點、公車站、捷運站等圖資套疊，分析步行環境的完整性與可及性。',
    ARRAY['https://www.openstreetmap.org/'],
    ARRAY['doit', 'ntpc'],
    NOW(),
    NOW(),
    'map_legend',
    E'SELECT unnest(ARRAY[''人行道路網'']) AS name, ''line'' AS type',
    NULL,
    'metrotaipei'
);

-- taipei：只顯示臺北市圖層
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case,
    links, contributors, created_at, updated_at,
    query_type, query_chart, query_history, city
) VALUES (
    'sidewalk_osm',
    NULL,
    ARRAY[
        (SELECT id FROM public.component_maps WHERE index = 'pedestrian_osm_taipei')
    ],
    '{}',
    'static',
    NULL,
    0,
    NULL,
    'OpenStreetMap',
    '臺北市人行道路網分布，以線狀呈現人行道路徑。',
    '資料來源為 OpenStreetMap，以線狀圖層呈現臺北市人行道路網空間範圍，包含人行道（footway）、行人徒步區（pedestrian）、階梯（steps）及步道（path）等，含路面、照明等屬性。',
    '可與事故熱點、公車站、捷運站等圖資套疊，分析步行環境的完整性與可及性。',
    ARRAY['https://www.openstreetmap.org/'],
    ARRAY['doit'],
    NOW(),
    NOW(),
    'map_legend',
    E'SELECT unnest(ARRAY[''人行道路網'']) AS name, ''line'' AS type',
    NULL,
    'taipei'
);


-- ============================================================
-- 5. 將組件加入 map-layers-metrotaipei 與 map-layers-taipei 儀表板
-- ============================================================
UPDATE public.dashboards
SET
    components = array_append(
        components,
        (SELECT id FROM public.components WHERE index = 'sidewalk_osm')
    ),
    updated_at = NOW()
WHERE index = 'map-layers-metrotaipei'
  AND NOT (
      (SELECT id FROM public.components WHERE index = 'sidewalk_osm')
      = ANY(components)
  );

UPDATE public.dashboards
SET
    components = array_append(
        components,
        (SELECT id FROM public.components WHERE index = 'sidewalk_osm')
    ),
    updated_at = NOW()
WHERE index = 'map-layers-taipei'
  AND NOT (
      (SELECT id FROM public.components WHERE index = 'sidewalk_osm')
      = ANY(components)
  );


-- ============================================================
-- 驗證
-- ============================================================
SELECT
    c.id, c.index, c.name,
    qc.city,
    qc.map_config_ids,
    cm.index AS map_index,
    cm.type  AS map_type
FROM public.components c
JOIN public.query_charts qc ON c.index = qc.index
JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids)
WHERE c.index = 'sidewalk_osm'
ORDER BY qc.city, cm.index;

SELECT id, index, name, components
FROM public.dashboards
WHERE index IN ('map-layers-metrotaipei', 'map-layers-taipei');
