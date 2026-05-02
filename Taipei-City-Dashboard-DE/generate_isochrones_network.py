#!/usr/bin/env python3
"""
網路路徑等時圈生成器（捷運 + 台鐵）
以實際人行道路網（OSM）計算步行可達範圍，取代圓形 buffer 方法。

依賴套件：shapely、pyproj、numpy（均已安裝）、heapq / math / json（stdlib）

Usage:
    python generate_isochrones_network.py [mrt|tra|all]

輸出至帶 _network 後綴的新檔案，不覆蓋原有圓形 buffer 版本：
    isochrone_mrt_walk_network.geojson / _taipei / _newtaipei
    isochrone_tra_walk_network.geojson / _taipei / _newtaipei
"""

import heapq
import json
import math
import os
import sys
from collections import defaultdict

import numpy as np
from pyproj import Transformer
from shapely import STRtree, buffer as shp_buffer, unary_union
from shapely import points as shp_points
from shapely.geometry import Point, mapping, shape
from shapely.ops import transform, unary_union as su

# ── 路徑設定 ──────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MAP_DIR    = os.path.join(SCRIPT_DIR, "..", "Taipei-City-Dashboard-FE", "public", "mapData")
DATA_DIR   = os.path.join(SCRIPT_DIR, "data")

# (geojson路徑, 步行速度倍率)：人行道 1.0、巷弄 0.75
WALKABLE_TAIPEI = [
    (os.path.join(MAP_DIR, "walkable_pedestrian.geojson"),       1.00),
    (os.path.join(MAP_DIR, "walkable_shared.geojson"),           0.75),
]
WALKABLE_NTPC = [
    (os.path.join(MAP_DIR, "walkable_pedestrian_newtaipei.geojson"), 1.00),
    (os.path.join(MAP_DIR, "walkable_shared_newtaipei.geojson"),     0.75),
]

# 連通性不足時 fallback 到圓形 buffer（節點數低於此值視為孤立站點）
MIN_REACHABLE_5MIN = 3

# ── 步行參數 ──────────────────────────────────────────────────────────────────
WALK_RADII = {5: 400, 10: 800, 15: 1200}  # 5/10/15 分鐘 → 400/800/1200 m

# ── 座標轉換器 ────────────────────────────────────────────────────────────────
_to_proj = Transformer.from_crs("EPSG:4326", "EPSG:3826", always_xy=True)
_to_geo  = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)

# ── 圖建構參數 ────────────────────────────────────────────────────────────────
SNAP_M     = 2   # 相距 <2m 的端點視為同一節點
BUFFER_M   = 80  # 節點 buffer 半徑（填補相鄰路段間空隙）
CLOSE_M    = 60  # 形態學閉合半徑：先膨脹再侵蝕，填洞＋圓滑邊緣
SIMPLIFY_M = 15  # 最終輪廓簡化容差

# ── 捷運站座標 ────────────────────────────────────────────────────────────────
NTMCC_STATIONS = [
    (121.54134,  24.98272),
    (121.527698, 24.984333),
    (121.525051, 24.990549),
    (121.516386, 24.992143),
    (121.505114, 24.99392),
    (121.495978, 25.002382),
    (121.490461, 25.004413),
    (121.484159, 25.00841),
    (121.472269, 25.014436),
    (121.464825, 25.015156),
    (121.466831, 25.026282),
    (121.460479, 25.039862),
    (121.45998,  25.049984),
    (121.459926, 25.061548),
]

TRA_METRO = [
    ("五堵",   121.66758, 25.07799, "newtaipei"),
    ("汐止",   121.66113, 25.0679,  "newtaipei"),
    ("汐科",   121.65233, 25.06406, "newtaipei"),
    ("南港",   121.60706, 25.05348, "taipei"),
    ("松山",   121.57906, 25.04927, "taipei"),
    ("台北",   121.51711, 25.04775, "taipei"),
    ("萬華",   121.49996, 25.03339, "taipei"),
    ("板橋",   121.46377, 25.01434, "newtaipei"),
    ("浮洲",   121.44477, 25.00419, "newtaipei"),
    ("樹林",   121.42442, 24.99123, "newtaipei"),
    ("南樹林",  121.40884, 24.98044, "newtaipei"),
    ("山佳",   121.39254, 24.97273, "newtaipei"),
    ("鶯歌",   121.35517, 24.95455, "newtaipei"),
    ("鳳鳴",   121.33658, 24.97268, "newtaipei"),
]


# ══════════════════════════════════════════════════════════════════════════════
# 圖建構
# ══════════════════════════════════════════════════════════════════════════════

def build_network(sources: list):
    """
    從多個 GeoJSON 路網檔（WGS84）合併建立步行路網圖（EPSG:3826 公尺座標）。
    sources: [(geojson_path, speed_factor), ...]
             speed_factor < 1 表示此類型路段步行較慢（邊權重除以 speed_factor）
    返回 (graph, node_coords, strtree, tree_node_ids)
    """
    coord_to_id: dict = {}
    node_coords: dict = {}
    graph: dict = defaultdict(list)
    counter = [0]

    def get_node(x: float, y: float) -> int:
        key = (round(x / SNAP_M), round(y / SNAP_M))
        if key not in coord_to_id:
            nid = counter[0]
            counter[0] += 1
            coord_to_id[key] = nid
            node_coords[nid] = (x, y)
        return coord_to_id[key]

    def add_linestring(coords_wgs84, speed: float):
        proj_coords = [_to_proj.transform(c[0], c[1]) for c in coords_wgs84]
        for i in range(len(proj_coords) - 1):
            x1, y1 = proj_coords[i]
            x2, y2 = proj_coords[i + 1]
            n1, n2 = get_node(x1, y1), get_node(x2, y2)
            if n1 != n2:
                d = math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2) / speed
                graph[n1].append((n2, d))
                graph[n2].append((n1, d))

    total_feats = 0
    for path, speed in sources:
        print(f"  讀取：{os.path.basename(path)} (速度倍率 {speed})")
        with open(path, encoding="utf-8") as f:
            features = json.load(f)["features"]
        total_feats += len(features)
        for feat in features:
            geom = feat.get("geometry", {})
            gtype = geom.get("type", "")
            if gtype == "LineString":
                add_linestring(geom["coordinates"], speed)
            elif gtype == "MultiLineString":
                for line in geom["coordinates"]:
                    add_linestring(line, speed)

    graph = dict(graph)
    n_nodes = len(node_coords)
    n_edges = sum(len(v) for v in graph.values()) // 2
    print(f"  圖建構完成：{total_feats} 路段 → {n_nodes} 節點，{n_edges} 條邊")

    node_ids_list = list(node_coords.keys())
    xs = np.array([node_coords[nid][0] for nid in node_ids_list])
    ys = np.array([node_coords[nid][1] for nid in node_ids_list])
    strtree = STRtree(shp_points(xs, ys))

    return graph, node_coords, strtree, node_ids_list


# ══════════════════════════════════════════════════════════════════════════════
# Dijkstra
# ══════════════════════════════════════════════════════════════════════════════

def dijkstra(graph: dict, start: int, max_dist: float) -> dict:
    """返回 {node_id: dist_m}，僅包含距離 ≤ max_dist 的可達節點。"""
    dist = {start: 0.0}
    heap = [(0.0, start)]
    while heap:
        d, u = heapq.heappop(heap)
        if d > dist.get(u, float("inf")):
            continue
        for v, w in graph.get(u, []):
            nd = d + w
            if nd <= max_dist and nd < dist.get(v, float("inf")):
                dist[v] = nd
                heapq.heappush(heap, (nd, v))
    return dist


# ══════════════════════════════════════════════════════════════════════════════
# 等時圈計算
# ══════════════════════════════════════════════════════════════════════════════

def compute_isochrones(
    stops_wgs84: list,
    graph: dict,
    node_coords: dict,
    strtree: STRtree,
    tree_node_ids: list,
    radii: dict = WALK_RADII,
) -> dict:
    """輸入 WGS84 站點座標列表，返回 {minutes: shapely_polygon_WGS84}"""
    max_r = max(radii.values())
    band_nodes = {m: set() for m in radii}

    total = len(stops_wgs84)
    fallback_count = 0
    fallback_circles = {m: [] for m in radii}  # 孤立站點的圓形 buffer polygons（投影座標）

    for i, (lng, lat) in enumerate(stops_wgs84):
        if (i + 1) % 10 == 0 or i == total - 1:
            print(f"    {i + 1}/{total} 站...", end="\r")

        px, py = _to_proj.transform(lng, lat)
        nearest_idx = strtree.nearest(Point(px, py))
        start_node = tree_node_ids[nearest_idx]

        reached = dijkstra(graph, start_node, max_r)

        # fallback：站點孤立則改用圓形 buffer
        if sum(1 for d in reached.values() if d <= radii[5]) < MIN_REACHABLE_5MIN:
            fallback_count += 1
            pt = Point(px, py)
            for minutes, radius in radii.items():
                fallback_circles[minutes].append(pt.buffer(radius))
            continue

        for minutes, radius in radii.items():
            for nid, d in reached.items():
                if d <= radius:
                    band_nodes[minutes].add(nid)

    if fallback_count:
        print(f"\n    (fallback 圓形 buffer: {fallback_count} 站)")


    print()

    result = {}
    for minutes, node_set in band_nodes.items():
        polys = []
        if node_set:
            ids = list(node_set)
            xs = np.array([node_coords[nid][0] for nid in ids])
            ys = np.array([node_coords[nid][1] for nid in ids])
            pts = shp_points(xs, ys)
            buffered = unary_union(shp_buffer(pts, BUFFER_M))
            # 形態學閉合：膨脹再侵蝕 → 填洞 + 圓滑邊緣
            polys.append(buffered.buffer(CLOSE_M).buffer(-CLOSE_M))
        if fallback_circles[minutes]:
            polys.append(unary_union(fallback_circles[minutes]))
        if not polys:
            continue
        poly_proj = unary_union(polys).simplify(SIMPLIFY_M)
        poly_geo = transform(lambda x, y: _to_geo.transform(x, y), poly_proj)
        result[minutes] = poly_geo
        print(f"    {minutes} 分鐘：{len(node_set)} 網路節點 + {len(fallback_circles[minutes])} fallback 站")

    return result


# ══════════════════════════════════════════════════════════════════════════════
# GeoJSON 輸出
# ══════════════════════════════════════════════════════════════════════════════

def build_features(city: str, isochrones: dict) -> list:
    features = []
    for minutes in sorted(isochrones.keys(), reverse=True):
        geom = isochrones[minutes]
        if geom is None or geom.is_empty:
            continue
        features.append({
            "type": "Feature",
            "geometry": mapping(geom),
            "properties": {
                "city": city,
                "minutes": minutes,
                "minutes_label": f"{minutes}分鐘",
            },
        })
    return features


def save_geojson(features: list, stem: str):
    """stem: 不含副檔名的路徑前綴。輸出 stem.geojson / stem_taipei.geojson / stem_newtaipei.geojson"""
    os.makedirs(os.path.dirname(stem), exist_ok=True)

    def _write(p, feats):
        with open(p, "w", encoding="utf-8") as f:
            json.dump({"type": "FeatureCollection", "features": feats},
                      f, ensure_ascii=False, separators=(",", ":"))

    path = stem + ".geojson"
    _write(path, features)
    print(f"  → {path} ({os.path.getsize(path)//1024} KB, {len(features)} features)")

    for city in ("taipei", "newtaipei"):
        city_feats = [ft for ft in features if ft["properties"].get("city") == city]
        city_path = f"{stem}_{city}.geojson"
        _write(city_path, city_feats)
        print(f"  → {city_path} ({os.path.getsize(city_path)//1024} KB, {len(city_feats)} features)")


# ══════════════════════════════════════════════════════════════════════════════
# 捷運（MRT）
# ══════════════════════════════════════════════════════════════════════════════

def load_mrt_stations():
    """返回 (taipei_stops, ntpc_stops)，WGS84 座標。"""
    boundary_path = os.path.join(MAP_DIR, "metrotaipei_town.geojson")
    with open(boundary_path, encoding="utf-8") as f:
        d = json.load(f)
    tpe_polys, ntpc_polys = [], []
    for feat in d["features"]:
        poly = shape(feat["geometry"])
        if feat["properties"]["COUNTYID"] == "A":
            tpe_polys.append(poly)
        else:
            ntpc_polys.append(poly)
    tpe_boundary  = su(tpe_polys)
    ntpc_boundary = su(ntpc_polys)

    tr = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)
    json_path = os.path.join(DATA_DIR, "TpeMrtStations_TWD97_FIDCODE.json")
    with open(json_path, "rb") as f:
        raw = json.loads(f.read().decode("utf-8"))

    taipei_stops, ntpc_stops = [], []
    for feat in raw["features"]:
        x, y = feat["geometry"]["coordinates"]
        lng, lat = tr.transform(x, y)
        pt = Point(lng, lat)
        if tpe_boundary.contains(pt):
            taipei_stops.append((lng, lat))
        elif ntpc_boundary.contains(pt):
            ntpc_stops.append((lng, lat))

    ntpc_stops.extend(NTMCC_STATIONS)
    taipei_stops = list({(round(lng, 5), round(lat, 5)) for lng, lat in taipei_stops})
    ntpc_stops   = list({(round(lng, 5), round(lat, 5)) for lng, lat in ntpc_stops})
    print(f"  台北捷運：{len(taipei_stops)} 站")
    print(f"  新北捷運（含 NTMCC）：{len(ntpc_stops)} 站")
    return taipei_stops, ntpc_stops


def generate_mrt():
    print("\n===== 捷運網路等時圈 =====")
    taipei_stops, ntpc_stops = load_mrt_stations()
    all_features = []

    print("建構台北路網圖...")
    tpe_graph, tpe_nodes, tpe_tree, tpe_ids = build_network(WALKABLE_TAIPEI)
    print("計算台北捷運等時圈...")
    iso = compute_isochrones(taipei_stops, tpe_graph, tpe_nodes, tpe_tree, tpe_ids)
    all_features += build_features("taipei", iso)

    print("建構新北路網圖...")
    ntpc_graph, ntpc_nodes, ntpc_tree, ntpc_ids = build_network(WALKABLE_NTPC)
    print("計算新北捷運等時圈...")
    iso = compute_isochrones(ntpc_stops, ntpc_graph, ntpc_nodes, ntpc_tree, ntpc_ids)
    all_features += build_features("newtaipei", iso)

    save_geojson(all_features, os.path.join(MAP_DIR, "isochrone_mrt_walk_network"))


# ══════════════════════════════════════════════════════════════════════════════
# 台鐵（TRA）
# ══════════════════════════════════════════════════════════════════════════════

def generate_tra():
    print("\n===== 台鐵網路等時圈 =====")
    taipei_stops = [(lng, lat) for _, lng, lat, city in TRA_METRO if city == "taipei"]
    ntpc_stops   = [(lng, lat) for _, lng, lat, city in TRA_METRO if city == "newtaipei"]
    all_features = []

    print(f"台北台鐵：{len(taipei_stops)} 站，建構台北路網圖...")
    tpe_graph, tpe_nodes, tpe_tree, tpe_ids = build_network(WALKABLE_TAIPEI)
    iso = compute_isochrones(taipei_stops, tpe_graph, tpe_nodes, tpe_tree, tpe_ids)
    all_features += build_features("taipei", iso)

    print(f"新北台鐵：{len(ntpc_stops)} 站，建構新北路網圖...")
    ntpc_graph, ntpc_nodes, ntpc_tree, ntpc_ids = build_network(WALKABLE_NTPC)
    iso = compute_isochrones(ntpc_stops, ntpc_graph, ntpc_nodes, ntpc_tree, ntpc_ids)
    all_features += build_features("newtaipei", iso)

    save_geojson(all_features, os.path.join(MAP_DIR, "isochrone_tra_walk_network"))


# ══════════════════════════════════════════════════════════════════════════════
# 主程式
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"

    if target in ("mrt", "all"):
        generate_mrt()
    if target in ("tra", "all"):
        generate_tra()

    print("\n完成！")
