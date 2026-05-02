-- ============================================================
-- Population Flow Migration SQL
-- 電信信令人口流動模組：日間活動人數、夜間活動人數、日夜差異
--
-- PART 1：對 dashboard DB 執行（dashboard-demo.sql 對應的資料庫）
-- PART 2：對 dashboardmanager DB 執行（dashboardmanager-demo.sql 對應的資料庫）
-- ============================================================


-- ============================================================
-- PART 1: Dashboard DB（Ready Data）
-- ============================================================

-- 建立日間活動人口資料表
CREATE TABLE IF NOT EXISTS public.population_flow_daytime (
    county_id             TEXT,
    county                TEXT,
    town_id               TEXT,
    town                  TEXT,
    weekday_morning_pop   BIGINT,
    weekday_afternoon_pop BIGINT,
    weekday_daytime_pop   BIGINT,
    weekend_morning_pop   BIGINT,
    weekend_afternoon_pop BIGINT,
    weekend_daytime_pop   BIGINT,
    info_time             TEXT,
    data_time             TIMESTAMP WITH TIME ZONE
);

-- 建立夜間停留人口資料表
CREATE TABLE IF NOT EXISTS public.population_flow_nighttime (
    county_id            TEXT,
    county               TEXT,
    town_id              TEXT,
    town                 TEXT,
    weekday_nighttime_pop BIGINT,
    weekend_nighttime_pop BIGINT,
    info_time            TEXT,
    data_time            TIMESTAMP WITH TIME ZONE
);

-- 插入臺北市範例資料（日間，民國109年11月）
TRUNCATE TABLE public.population_flow_daytime;
INSERT INTO public.population_flow_daytime
    (county_id, county, town_id, town,
     weekday_morning_pop, weekday_afternoon_pop, weekday_daytime_pop,
     weekend_morning_pop, weekend_afternoon_pop, weekend_daytime_pop,
     info_time, data_time)
VALUES
    ('63000','臺北市','63000010','松山區', 278577, 294479, 288682, 207148, 218976, 211526, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000020','信義區', 312330, 338883, 328477, 244931, 301650, 266716, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000030','大安區', 448353, 496305, 476810, 356418, 394107, 371353, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000040','中山區', 453504, 484182, 471923, 331447, 359996, 340438, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000050','中正區', 318569, 345815, 333549, 223195, 267469, 237208, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000060','大同區', 143388, 149558, 146631, 130048, 143113, 134317, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000070','萬華區', 161837, 162279, 160601, 183850, 185284, 183265, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000080','文山區', 221079, 210668, 215166, 252317, 240318, 249444, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000090','南港區', 168901, 170643, 170328, 135421, 149331, 141019, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000100','內湖區', 385468, 388762, 390671, 292090, 286475, 292574, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000110','士林區', 283476, 280044, 281141, 286366, 285187, 286371, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000120','北投區', 249467, 242226, 244263, 243647, 235543, 239692, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000010','板橋區', 468604, 459821, 461811, 553665, 547852, 552865, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000020','三重區', 353762, 336820, 343466, 402368, 379533, 395318, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000030','中和區', 414013, 398795, 408358, 439917, 417541, 433865, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000040','永和區', 169268, 157426, 161573, 215493, 199485, 210496, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000050','新莊區', 381702, 374563, 377239, 426704, 419179, 426607, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000060','新店區', 316147, 303348, 309344, 332771, 315198, 328460, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000100','淡水區', 200804, 192902, 196262, 227406, 220763, 225959, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000110','汐止區', 234013, 223014, 227807, 247347, 232960, 243506, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000070','樹林區', 250441, 267893, 260836, 268124, 280987, 272053, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000080','鶯歌區',  90213,  96644,  93428,  97318, 103042,  99156, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000090','三峽區', 130087, 140793, 135244, 151063, 161094, 153872, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000120','瑞芳區',  43126,  46012,  44408,  55241,  58877,  56319, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000130','五股區',  89318,  95452,  91764,  84961,  89213,  86492, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000140','泰山區', 107243, 114086, 110537, 101318, 106044, 103104, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000150','林口區', 128461, 136987, 132784, 135218, 143026, 138352, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000160','深坑區',  14243,  15127,  14652,  19318,  20881,  20047, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000170','石碇區',   4913,   5210,   5046,   7126,   7584,   7312, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000180','坪林區',   4758,   5043,   4888,   7913,   8341,   8094, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000190','三芝區',  18312,  19546,  18917,  26043,  27894,  26841, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000200','石門區',   7891,   8376,   8118,  10943,  11712,  11284, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000210','八里區',  15847,  16943,  16378,  22541,  24136,  23216, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000220','平溪區',   3891,   4143,   4007,   6741,   7213,   6941, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000230','雙溪區',   6541,   6937,   6724,   8941,   9513,   9184, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000240','貢寮區',   6724,   7143,   6918,   9213,   9841,   9487, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000250','金山區',  14891,  15847,  15341,  22118,  23641,  22784, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000260','萬里區',  11943,  12741,  12318,  17126,  18314,  17681, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000270','烏來區',   3891,   4143,   4012,   7541,   8043,   7764, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000280','蘆洲區', 223847, 239541, 231743, 272118, 289043, 278316, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000290','土城區', 265841, 284376, 275318, 291043, 307218, 295847, '109Y11M', '2020-11-01 00:00:00+08');

-- 插入臺北市範例資料（夜間，民國109年11月）
TRUNCATE TABLE public.population_flow_nighttime;
INSERT INTO public.population_flow_nighttime
    (county_id, county, town_id, town,
     weekday_nighttime_pop, weekend_nighttime_pop,
     info_time, data_time)
VALUES
    ('63000','臺北市','63000010','松山區', 201847, 198307, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000020','信義區', 236301, 234946, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000030','大安區', 334939, 327922, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000040','中山區', 314134, 308580, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000050','中正區', 183571, 178225, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000060','大同區', 125418, 125027, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000070','萬華區', 183951, 186390, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000080','文山區', 260906, 256102, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000090','南港區', 123953, 122662, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000100','內湖區', 294476, 286916, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000110','士林區', 286684, 283098, '109Y11M', '2020-11-01 00:00:00+08'),
    ('63000','臺北市','63000120','北投區', 243777, 239494, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000010','板橋區', 577007, 574620, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000020','三重區', 426580, 424259, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000030','中和區', 470287, 466276, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000040','永和區', 232342, 230134, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000050','新莊區', 446481, 443620, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000060','新店區', 346150, 343603, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000100','淡水區', 235166, 234006, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000110','汐止區', 259462, 259805, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000070','樹林區', 231084, 228317, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000080','鶯歌區',  93241,  91048, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000090','三峽區', 141318, 138514, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000120','瑞芳區',  56814,  55621, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000130','五股區',  79843,  78214, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000140','泰山區',  91748,  90124, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000150','林口區', 115024, 113418, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000160','深坑區',  21847,  21314, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000170','石碇區',   9124,   9018, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000180','坪林區',   8941,   8817, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000190','三芝區',  27841,  27214, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000200','石門區',  12148,  11941, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000210','八里區',  22047,  21618, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000220','平溪區',   8241,   8148, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000230','雙溪區',  11948,  11714, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000240','貢寮區',  12018,  11847, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000250','金山區',  24148,  23741, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000260','萬里區',  20047,  19814, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000270','烏來區',   7124,   7018, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000280','蘆洲區', 210347, 207218, '109Y11M', '2020-11-01 00:00:00+08'),
    ('65000','新北市','65000290','土城區', 245318, 241047, '109Y11M', '2020-11-01 00:00:00+08');


-- ============================================================
-- PART 2: Dashboardmanager DB（Component 設定）
-- ============================================================

-- 確保 scrollable 欄位存在（冪等）
ALTER TABLE public.component_charts ADD COLUMN IF NOT EXISTS stacked    boolean DEFAULT false;
ALTER TABLE public.component_charts ADD COLUMN IF NOT EXISTS scrollable boolean DEFAULT false;

-- 模組圖表樣式設定（scrollable = true：啟用捲動工具列）
INSERT INTO public.component_charts (index, color, types, unit, scrollable) VALUES
    ('population_flow_daytime',  '{"#F8CF58","#F5AD4A"}', '{"DistrictChart","ColumnChart"}', '人', true),
    ('population_flow_nighttime','{"#24B0DD","#10294A"}', '{"DistrictChart","ColumnChart"}', '人', true),
    ('population_flow_diff',     '{"#F5A623","#24B0DD"}', '{"DistrictChart","ColumnChart"}', '人', true)
ON CONFLICT (index) DO UPDATE
    SET color      = EXCLUDED.color,
        types      = EXCLUDED.types,
        unit       = EXCLUDED.unit,
        scrollable = EXCLUDED.scrollable;

-- 地圖圖層設定
-- fill-opacity 的靜態值（0.3）僅作為圖層載入前的初始顯示；
-- 開啟圖層時 FE 會依圖表資料動態套用各行政區不同透明度（choropleth）。
-- 日間 (104/105) 使用黃色；夜間 (106/107) 使用藍色；差異 (102/103) 由 FE 動態決定黃/藍。
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property) VALUES
    (102, 'taipei_town',           '臺北市行政區（差異）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#888888","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]'),
    (103, 'metrotaipei_town',      '雙北市行政區（差異）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#888888","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]'),
    (104, 'taipei_town_day',       '臺北市行政區（日間）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#F5A623","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]'),
    (105, 'metrotaipei_town_day',  '雙北市行政區（日間）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#F5A623","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]'),
    (106, 'taipei_town_night',     '臺北市行政區（夜間）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#24B0DD","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]'),
    (107, 'metrotaipei_town_night','雙北市行政區（夜間）', 'fill', 'geojson', NULL, NULL,
     '{"fill-color":"#24B0DD","fill-opacity":0.3}',
     '[{"key":"TNAME","name":"行政區"},{"key":"PNAME","name":"縣市"}]');

-- 模組基本資訊
INSERT INTO public.components (id, index, name) VALUES
    (401, 'population_flow_daytime',  '平日日間活動人數'),
    (402, 'population_flow_nighttime','平日夜間活動人數'),
    (403, 'population_flow_diff',     '平日日夜人口差異');

-- ─── 臺北市（taipei）query_charts ───────────────────────────

-- 模組1：日間活動人數（臺北市）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_daytime',
    NULL, '{104}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '臺北市各行政區平日日間活動人數（電信信令）',
    '根據電信信令資料統計臺北市各行政區日間（7:00~19:00）活動人數，分為平日及假日兩類，資料時間為民國109年11月。正值代表白天淨流入人口，可反映商業中心與通勤熱區分布。',
    '可用於分析城市商業中心識別、通勤流向規劃及公共設施配置。',
    '{https://data.gov.tw/dataset/138523}',
    '{doit}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT town AS x_axis, '平日日間' AS y_axis, weekday_daytime_pop AS data
FROM public.population_flow_daytime WHERE county_id = '63000'
ORDER BY 1$$,
    NULL,
    'taipei'
);

-- 模組2：夜間活動人數（臺北市）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_nighttime',
    NULL, '{106}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '臺北市各行政區平日夜間停留人數（電信信令）',
    '根據電信信令資料統計臺北市各行政區夜間停留人口，分為平日及假日兩類，資料時間為民國109年11月。夜間人口反映實際居住人口分布，可作為住宅供需及社區服務規劃參考。',
    '可用於住宅規劃、社區服務配置及治安管理等政策分析。',
    '{https://data.gov.tw/dataset/162908}',
    '{doit}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT town AS x_axis, '平日夜間' AS y_axis, weekday_nighttime_pop AS data
FROM public.population_flow_nighttime WHERE county_id = '63000'
ORDER BY 1$$,
    NULL,
    'taipei'
);

-- 模組3：日夜人口差異（臺北市）
-- 正值：白天淨流入（商業/就業中心）；負值：白天淨流出（純住宅區）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_diff',
    NULL, '{102}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '臺北市各行政區日夜人口差異（電信信令）',
    '以電信信令日間活動人口減去夜間停留人口，計算各行政區的日夜人口差值。正值表示白天淨流入人口（商業、就業中心），負值表示白天淨流出（居住為主的住宅區）。資料時間為民國109年11月。',
    '可用於識別通勤來源區與就業目的地，支援都市規劃、交通建設及商業選址等決策。',
    '{https://data.gov.tw/dataset/138523,https://data.gov.tw/dataset/162908}',
    '{doit}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT d.town AS x_axis, '平日(日-夜)差值' AS y_axis,
       (d.weekday_daytime_pop - n.weekday_nighttime_pop) AS data
FROM public.population_flow_daytime d
JOIN public.population_flow_nighttime n ON d.town_id = n.town_id
WHERE d.county_id = '63000'
ORDER BY 1$$,
    NULL,
    'taipei'
);

-- ─── 雙北（metrotaipei）query_charts ────────────────────────

-- 模組1：日間活動人數（雙北）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_daytime',
    NULL, '{105}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '雙北各行政區平日日間活動人數（電信信令）',
    '根據電信信令資料統計臺北市與新北市各行政區日間（7:00~19:00）活動人數，分為平日及假日兩類，資料時間為民國109年11月。',
    '可用於雙北通勤流向分析、商業熱區識別及跨市交通規劃。',
    '{https://data.gov.tw/dataset/138523}',
    '{doit,ntpc}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT town AS x_axis, '平日日間' AS y_axis, weekday_daytime_pop AS data
FROM public.population_flow_daytime WHERE county_id IN ('63000', '65000')
ORDER BY 1$$,
    NULL,
    'metrotaipei'
);

-- 模組2：夜間活動人數（雙北）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_nighttime',
    NULL, '{107}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '雙北各行政區平日夜間停留人數（電信信令）',
    '根據電信信令資料統計臺北市與新北市各行政區夜間停留人口，分為平日及假日兩類，資料時間為民國109年11月。',
    '可用於雙北住宅密度分析、社區服務資源規劃及跨市居住型態比較。',
    '{https://data.gov.tw/dataset/162908}',
    '{doit,ntpc}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT town AS x_axis, '平日夜間' AS y_axis, weekday_nighttime_pop AS data
FROM public.population_flow_nighttime WHERE county_id IN ('63000', '65000')
ORDER BY 1$$,
    NULL,
    'metrotaipei'
);

-- 模組3：日夜人口差異（雙北）
INSERT INTO public.query_charts
    (index, history_config, map_config_ids, map_filter, time_from, time_to,
     update_freq, update_freq_unit, source, short_desc, long_desc, use_case,
     links, contributors, created_at, updated_at, query_type, query_chart, query_history, city)
VALUES (
    'population_flow_diff',
    NULL, '{103}', '{"mode":"byParam","byParam":{"xParam":"TNAME"}}', 'static', NULL, 0, NULL,
    '國家發展委員會',
    '雙北各行政區日夜人口差異（電信信令）',
    '以電信信令日間活動人口減去夜間停留人口，計算雙北各行政區日夜人口差值。正值表示白天淨流入（商業就業中心），負值表示白天淨流出（住宅區）。資料時間為民國109年11月。',
    '可用於雙北通勤流向識別、跨市就業中心分析及區域整合規劃。',
    '{https://data.gov.tw/dataset/138523,https://data.gov.tw/dataset/162908}',
    '{doit,ntpc}',
    NOW(), NOW(),
    'three_d',
    $$
SELECT d.town AS x_axis, '平日(日-夜)差值' AS y_axis,
       (d.weekday_daytime_pop - n.weekday_nighttime_pop) AS data
FROM public.population_flow_daytime d
JOIN public.population_flow_nighttime n ON d.town_id = n.town_id
WHERE d.county_id IN ('63000', '65000')
ORDER BY 1$$,
    NULL,
    'metrotaipei'
);

-- ─── Dashboard 設定 ──────────────────────────────────────────

-- 建立儀表板（臺北市）
INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (500, 'population_flow_tpe', '人口流動', '{401,402,403}', 'groups', NOW(), NOW());

-- 建立儀表板（雙北）
INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (501, 'population_flow_newtpe', '人口流動', '{401,402,403}', 'groups', NOW(), NOW());

-- 指派儀表板到群組
-- 500 -> taipei (group_id=2)
-- 501 -> metrotaipei (group_id=3)
INSERT INTO public.dashboard_groups (dashboard_id, group_id) VALUES (500, 2);
INSERT INTO public.dashboard_groups (dashboard_id, group_id) VALUES (501, 3);

-- 更新 dashboards_id_seq（確保 auto-increment 不衝突）
SELECT pg_catalog.setval('public.dashboards_id_seq', (SELECT COALESCE(MAX(id), 0) FROM public.dashboards), true);
