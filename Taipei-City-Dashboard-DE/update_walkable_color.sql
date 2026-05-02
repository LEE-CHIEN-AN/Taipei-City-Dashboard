UPDATE public.component_maps
SET paint = '{"line-color": "#795548", "line-width": ["interpolate", ["linear"], ["zoom"], 12, 0.6, 15, 1.5, 18, 3], "line-opacity": ["interpolate", ["linear"], ["zoom"], 10, 0.4, 14, 0.75]}'
WHERE index IN ('walkable_shared', 'walkable_shared_newtaipei');

UPDATE public.component_charts
SET color = ARRAY['#d4a85b', '#795548']
WHERE index = 'walkable_osm_taipei';
