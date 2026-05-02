-- 雙北人行道路網 — dashboard DB 資料表建立腳本
-- 連線：localhost:5433 / dashboard DB（postgres-data）
-- 執行前請確認 PostGIS extension 已啟用

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.sidewalk_metrotaipei (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(200),
    pstart       VARCHAR(200),
    pend         VARCHAR(200),
    sw_direct    VARCHAR(10),
    sw_leng      DOUBLE PRECISION,
    sw_wth       DOUBLE PRECISION,
    sww_wth      DOUBLE PRECISION,
    sw_ramp      INTEGER,
    county_na    VARCHAR(20),
    vill_name    VARCHAR(50),
    wkb_geometry GEOMETRY(MultiPolygon, 4326)
);

CREATE INDEX IF NOT EXISTS idx_sidewalk_metrotaipei_geom
    ON public.sidewalk_metrotaipei USING GIST(wkb_geometry);

CREATE INDEX IF NOT EXISTS idx_sidewalk_metrotaipei_county
    ON public.sidewalk_metrotaipei(county_na);
