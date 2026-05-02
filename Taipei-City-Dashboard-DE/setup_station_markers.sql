-- 大眾運輸站點標記圖層（circle）
-- 在等時圈地圖上顯示捷運 / 台鐵站位置

-- ============================================================
-- 1. component_maps
-- ============================================================
DELETE FROM public.component_maps
WHERE index IN (
    'isochrone_mrt_stations',
    'isochrone_mrt_stations_taipei',
    'isochrone_tra_stations',
    'isochrone_tra_stations_taipei'
);

-- 捷運站（雙北）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'isochrone_mrt_stations',
    '捷運站',
    'circle',
    'geojson',
    NULL, NULL,
    '{
        "circle-color": "rgba(0,0,0,0)",
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 8, 1, 11, 2.5, 14, 5, 17, 7],
        "circle-stroke-color": "#80DEEA",
        "circle-stroke-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 11, 1, 14, 2],
        "circle-opacity": ["interpolate", ["linear"], ["zoom"], 8, 0.6, 11, 0.75, 14, 0.9]
    }',
    '[{"key": "name", "name": "站名"}, {"key": "city", "name": "城市"}]'
);

-- 捷運站（台北）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'isochrone_mrt_stations_taipei',
    '捷運站',
    'circle',
    'geojson',
    NULL, NULL,
    '{
        "circle-color": "rgba(0,0,0,0)",
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 8, 1, 11, 2.5, 14, 5, 17, 7],
        "circle-stroke-color": "#80DEEA",
        "circle-stroke-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 11, 1, 14, 2],
        "circle-opacity": ["interpolate", ["linear"], ["zoom"], 8, 0.6, 11, 0.75, 14, 0.9]
    }',
    '[{"key": "name", "name": "站名"}, {"key": "city", "name": "城市"}]'
);

-- 台鐵站（雙北）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'isochrone_tra_stations',
    '台鐵站',
    'circle',
    'geojson',
    NULL, NULL,
    '{
        "circle-color": "rgba(0,0,0,0)",
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 8, 1, 11, 2.5, 14, 5, 17, 7],
        "circle-stroke-color": "#FFAB40",
        "circle-stroke-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 11, 1, 14, 2],
        "circle-opacity": ["interpolate", ["linear"], ["zoom"], 8, 0.6, 11, 0.75, 14, 0.9]
    }',
    '[{"key": "name", "name": "站名"}, {"key": "city", "name": "城市"}]'
);

-- 台鐵站（台北）
INSERT INTO public.component_maps (index, title, type, source, size, icon, paint, property)
VALUES (
    'isochrone_tra_stations_taipei',
    '台鐵站',
    'circle',
    'geojson',
    NULL, NULL,
    '{
        "circle-color": "rgba(0,0,0,0)",
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 8, 1, 11, 2.5, 14, 5, 17, 7],
        "circle-stroke-color": "#FFAB40",
        "circle-stroke-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 11, 1, 14, 2],
        "circle-opacity": ["interpolate", ["linear"], ["zoom"], 8, 0.6, 11, 0.75, 14, 0.9]
    }',
    '[{"key": "name", "name": "站名"}, {"key": "city", "name": "城市"}]'
);


-- ============================================================
-- 2. 把站點圖層加進等時圈組件的 map_config_ids
-- ============================================================

-- 捷運 metrotaipei：等時圈 + 捷運站（雙北）
UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_mrt_walk'),
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_mrt_stations')
]
WHERE index = 'transit_isochrone_mrt' AND city = 'metrotaipei';

-- 捷運 taipei：等時圈 + 捷運站（台北）
UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_mrt_walk_taipei'),
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_mrt_stations_taipei')
]
WHERE index = 'transit_isochrone_mrt' AND city = 'taipei';

-- 台鐵 metrotaipei：等時圈 + 台鐵站（雙北）
UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_tra_walk'),
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_tra_stations')
]
WHERE index = 'transit_isochrone_tra' AND city = 'metrotaipei';

-- 台鐵 taipei：等時圈 + 台鐵站（台北）
UPDATE public.query_charts
SET map_config_ids = ARRAY[
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_tra_walk_taipei'),
    (SELECT id FROM public.component_maps WHERE index = 'isochrone_tra_stations_taipei')
]
WHERE index = 'transit_isochrone_tra' AND city = 'taipei';


-- ============================================================
-- 驗證
-- ============================================================
SELECT qc.index, qc.city, array_agg(cm.index ORDER BY cm.id) AS map_layers
FROM public.query_charts qc
JOIN public.component_maps cm ON cm.id = ANY(qc.map_config_ids)
WHERE qc.index IN ('transit_isochrone_mrt','transit_isochrone_tra')
GROUP BY qc.index, qc.city ORDER BY qc.index, qc.city;
