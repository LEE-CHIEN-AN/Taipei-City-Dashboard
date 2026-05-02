#!/usr/bin/env python3
"""
預生成雙北大眾運輸步行等時圈 GeoJSON
輸出至 Taipei-City-Dashboard-FE/public/mapData/

Usage:
    python generate_isochrones.py [bus|mrt|tra|all]
"""

import json
import csv
import math
import os
import sys
import time
import zipfile
import glob
import shapefile
import requests
from pyproj import Transformer
from shapely.geometry import Point, mapping, shape
from shapely.ops import unary_union, transform

# ── 路徑設定 ──────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "Taipei-City-Dashboard-FE", "public", "mapData")

# ── 步行等時圈半徑（公尺）──────────────────────────────────────
WALK_RADII = {5: 400, 10: 800, 15: 1200}

# ── 雙北範圍 bounding box ────────────────────────────────────
METRO_BBOX = (121.28, 24.85, 121.75, 25.22)  # (min_lon, min_lat, max_lon, max_lat)

# ── 座標轉換器：WGS84 ↔ TWD97 TM2 (EPSG:3826) ────────────────
_to_proj = Transformer.from_crs("EPSG:4326", "EPSG:3826", always_xy=True)
_to_geo  = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)


def make_buffer(lng: float, lat: float, radius_m: float):
    """以投影座標建立圓形 buffer，再轉回 WGS84"""
    px, py = _to_proj.transform(lng, lat)
    circle_proj = Point(px, py).buffer(radius_m, resolution=16)
    return transform(lambda x, y: _to_geo.transform(x, y), circle_proj)


def in_bbox(lng, lat, bbox=METRO_BBOX):
    return bbox[0] <= lng <= bbox[2] and bbox[1] <= lat <= bbox[3]


def union_buffers(stops: list[tuple], radii: dict) -> dict:
    """
    stops: [(lng, lat), ...]
    返回 {minutes: unioned_shapely_geometry}
    """
    total = len(stops)
    print(f"  共 {total} 個站點，開始建立 buffer...")

    bufs = {m: [] for m in radii}
    for i, (lng, lat) in enumerate(stops):
        if i % 500 == 0:
            print(f"    {i}/{total}...", end="\r")
        for minutes, radius in radii.items():
            bufs[minutes].append(make_buffer(lng, lat, radius))

    print(f"    {total}/{total}... 完成，開始 union（可能需要幾分鐘）")
    result = {}
    for minutes, polys in bufs.items():
        print(f"  union {minutes} 分鐘 ({len(polys)} 個多邊形)...")
        result[minutes] = unary_union(polys).simplify(0.0001)
    return result


def build_features(city: str, isochrones: dict) -> list:
    """把每個時間帶包成 GeoJSON Feature"""
    features = []
    for minutes in sorted(isochrones.keys(), reverse=True):  # 大到小，讓小的蓋在上面
        geom = isochrones[minutes]
        if geom.is_empty:
            continue
        features.append({
            "type": "Feature",
            "geometry": mapping(geom),
            "properties": {"city": city, "minutes": minutes}
        })
    return features


def save_geojson(features: list, path: str):
    """儲存合併版 GeoJSON，並同步輸出各城市分割版（_taipei / _newtaipei）"""
    os.makedirs(os.path.dirname(path), exist_ok=True)

    def _write(p, feats):
        with open(p, "w", encoding="utf-8") as f:
            json.dump({"type": "FeatureCollection", "features": feats},
                      f, ensure_ascii=False, separators=(",", ":"))

    # 合併版（metrotaipei 用）
    _write(path, features)
    size_kb = os.path.getsize(path) // 1024
    print(f"  → 已儲存 {path} ({size_kb} KB, {len(features)} 個 feature)")

    # 城市分割版
    base, ext = os.path.splitext(path)
    for city in ("taipei", "newtaipei"):
        city_feats = [f for f in features if f["properties"].get("city") == city]
        city_path = f"{base}_{city}{ext}"
        _write(city_path, city_feats)
        city_kb = os.path.getsize(city_path) // 1024
        print(f"  → 已儲存 {city_path} ({city_kb} KB, {len(city_feats)} 個 feature)")


# ═══════════════════════════════════════════════════════════════
# 公車站牌
# ═══════════════════════════════════════════════════════════════

def load_taipei_bus_stops() -> list[tuple]:
    """讀取台北市公車站牌 Shapefile"""
    shp_path = os.path.join(DATA_DIR, "busstop_tpe", "busstop", "busstop")
    if not os.path.exists(shp_path + ".shp"):
        print("  [WARN] 找不到台北公車 Shapefile，跳過")
        return []
    sf = shapefile.Reader(shp_path, encoding="utf-8")
    stops = []
    for sr in sf.iterShapeRecords():
        if sr.shape.points:
            lng, lat = sr.shape.points[0]
            if in_bbox(lng, lat):
                stops.append((lng, lat))
    # deduplicate by rounded position
    stops = list({(round(lng, 5), round(lat, 5)) for lng, lat in stops})
    print(f"  台北公車：{len(stops)} 個唯一站點")
    return stops


def load_ntpc_bus_stops() -> list[tuple]:
    """讀取新北市公車站牌 CSV"""
    csv_files = glob.glob(os.path.join(DATA_DIR, "busstop_ntpc", "*.csv"))
    if not csv_files:
        print("  [WARN] 找不到新北公車 CSV，跳過")
        return []
    stops = []
    with open(csv_files[0], encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                lng = float(row["longitude"])
                lat = float(row["latitude"])
                if in_bbox(lng, lat):
                    stops.append((lng, lat))
            except (ValueError, KeyError):
                pass
    stops = list({(round(lng, 5), round(lat, 5)) for lng, lat in stops})
    print(f"  新北公車：{len(stops)} 個唯一站點")
    return stops


def generate_bus():
    print("\n===== 公車等時圈 =====")
    taipei_stops = load_taipei_bus_stops()
    ntpc_stops   = load_ntpc_bus_stops()

    all_features = []

    if taipei_stops:
        print("生成台北公車等時圈...")
        iso = union_buffers(taipei_stops, WALK_RADII)
        all_features += build_features("taipei", iso)

    if ntpc_stops:
        print("生成新北公車等時圈...")
        iso = union_buffers(ntpc_stops, WALK_RADII)
        all_features += build_features("newtaipei", iso)

    if all_features:
        out = os.path.join(OUTPUT_DIR, "isochrone_bus_walk.geojson")
        save_geojson(all_features, out)
    else:
        print("  沒有資料，跳過")


# ═══════════════════════════════════════════════════════════════
# 捷運站
# ═══════════════════════════════════════════════════════════════

# 新北捷運 NTMCC 環狀線 Y07-Y20（座標來源：TDX，WGS84）
NTMCC_STATIONS = [
    (121.54134,  24.98272),   # Y07 大坪林
    (121.527698, 24.984333),  # Y08 十四張
    (121.525051, 24.990549),  # Y09 秀朗橋
    (121.516386, 24.992143),  # Y10 景平
    (121.505114, 24.99392),   # Y11 景安
    (121.495978, 25.002382),  # Y12 中和
    (121.490461, 25.004413),  # Y13 橋和
    (121.484159, 25.00841),   # Y14 中原
    (121.472269, 25.014436),  # Y15 板新
    (121.464825, 25.015156),  # Y16 板橋
    (121.466831, 25.026282),  # Y17 新埔民生
    (121.460479, 25.039862),  # Y18 頭前庄
    (121.45998,  25.049984),  # Y19 幸福
    (121.459926, 25.061548),  # Y20 新北產業園區
]


def load_city_boundaries():
    """讀取 metrotaipei_town.geojson，返回 (taipei_poly, newtaipei_poly)"""
    geojson_path = os.path.join(
        SCRIPT_DIR, "..", "Taipei-City-Dashboard-FE", "public", "mapData",
        "metrotaipei_town.geojson"
    )
    with open(geojson_path, encoding="utf-8") as f:
        d = json.load(f)
    taipei_polys = []
    ntpc_polys = []
    for feat in d["features"]:
        poly = shape(feat["geometry"])
        if feat["properties"]["COUNTYID"] == "A":
            taipei_polys.append(poly)
        else:
            ntpc_polys.append(poly)
    return unary_union(taipei_polys), unary_union(ntpc_polys)


def load_mrt_stations():
    """
    讀取 TpeMrtStations_TWD97_FIDCODE.json（EPSG:3826）並轉換至 WGS84，
    以行政區邊界判斷城市；再加入 NTMCC 新北環狀線站點。
    返回 (taipei_stops, ntpc_stops)
    """
    json_path = os.path.join(DATA_DIR, "TpeMrtStations_TWD97_FIDCODE.json")
    print("  讀取行政區邊界...")
    taipei_boundary, ntpc_boundary = load_city_boundaries()

    tr = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)

    taipei_stops = []
    ntpc_stops = []

    with open(json_path, "rb") as f:
        raw = f.read()
    d = json.loads(raw.decode("utf-8"))

    for feat in d["features"]:
        x, y = feat["geometry"]["coordinates"]
        lng, lat = tr.transform(x, y)
        if not in_bbox(lng, lat):
            continue
        pt = Point(lng, lat)
        if taipei_boundary.contains(pt):
            taipei_stops.append((lng, lat))
        elif ntpc_boundary.contains(pt):
            ntpc_stops.append((lng, lat))

    # 加入 NTMCC 環狀線（全在新北市）
    ntpc_stops.extend(NTMCC_STATIONS)

    taipei_stops = list({(round(lng, 5), round(lat, 5)) for lng, lat in taipei_stops})
    ntpc_stops   = list({(round(lng, 5), round(lat, 5)) for lng, lat in ntpc_stops})
    print(f"  台北捷運：{len(taipei_stops)} 站")
    print(f"  新北捷運（含 NTMCC）：{len(ntpc_stops)} 站")
    return taipei_stops, ntpc_stops


def generate_mrt():
    print("\n===== 捷運等時圈 =====")
    taipei_stops, ntpc_stops = load_mrt_stations()

    all_features = []

    print("生成台北捷運等時圈...")
    iso = union_buffers(taipei_stops, WALK_RADII)
    all_features += build_features("taipei", iso)

    print("生成新北捷運等時圈...")
    iso = union_buffers(ntpc_stops, WALK_RADII)
    all_features += build_features("newtaipei", iso)

    out = os.path.join(OUTPUT_DIR, "isochrone_mrt_walk.geojson")
    save_geojson(all_features, out)


# ═══════════════════════════════════════════════════════════════
# 台鐵（雙北範圍）
# ═══════════════════════════════════════════════════════════════

TRA_METRO = [
    # (name, lng, lat, city)
    ("五堵",  121.66758, 25.07799, "newtaipei"),
    ("汐止",  121.66113, 25.0679,  "newtaipei"),
    ("汐科",  121.65233, 25.06406, "newtaipei"),
    ("南港",  121.60706, 25.05348, "taipei"),
    ("松山",  121.57906, 25.04927, "taipei"),
    ("台北",  121.51711, 25.04775, "taipei"),
    ("萬華",  121.49996, 25.03339, "taipei"),
    ("板橋",  121.46377, 25.01434, "newtaipei"),
    ("浮洲",  121.44477, 25.00419, "newtaipei"),
    ("樹林",  121.42442, 24.99123, "newtaipei"),
    ("南樹林", 121.40884, 24.98044, "newtaipei"),
    ("山佳",  121.39254, 24.97273, "newtaipei"),
    ("鶯歌",  121.35517, 24.95455, "newtaipei"),
    ("鳳鳴",  121.33658, 24.97268, "newtaipei"),
]


def generate_tra():
    print("\n===== 台鐵等時圈 =====")
    taipei_stops = [(lng, lat) for _, lng, lat, city in TRA_METRO if city == "taipei"]
    ntpc_stops   = [(lng, lat) for _, lng, lat, city in TRA_METRO if city == "newtaipei"]

    all_features = []

    print(f"台北台鐵：{len(taipei_stops)} 站")
    iso = union_buffers(taipei_stops, WALK_RADII)
    all_features += build_features("taipei", iso)

    print(f"新北台鐵：{len(ntpc_stops)} 站")
    iso = union_buffers(ntpc_stops, WALK_RADII)
    all_features += build_features("newtaipei", iso)

    out = os.path.join(OUTPUT_DIR, "isochrone_tra_walk.geojson")
    save_geojson(all_features, out)


# ═══════════════════════════════════════════════════════════════
# 主程式
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    if target in ("bus", "all"):
        generate_bus()
    if target in ("mrt", "all"):
        generate_mrt()
    if target in ("tra", "all"):
        generate_tra()

    print("\n全部完成！")
