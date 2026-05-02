#!/usr/bin/env python3
"""
生成捷運 + 台鐵站點 GeoJSON（point 格式，含站名）
輸出：
  isochrone_mrt_stations.geojson  （雙北所有捷運站）
  isochrone_tra_stations.geojson  （雙北所有台鐵站）
"""
import json, os, sys
from pyproj import Transformer
from shapely.geometry import Point
from shapely.ops import unary_union as su
from shapely.geometry import shape

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MAP_DIR    = os.path.join(SCRIPT_DIR, "..", "Taipei-City-Dashboard-FE", "public", "mapData")
DATA_DIR   = os.path.join(SCRIPT_DIR, "data")

tr_to_wgs = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)

# ── TRA 站點（直接定義）─────────────────────────────────────────────────────────
TRA_METRO = [
    ("五堵",   121.66758, 25.07799, "newtaipei"),
    ("汐止",   121.66113, 25.06790, "newtaipei"),
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

# ── 新北捷運（NTMCC 環狀線，無站名資料，用編號代替）─────────────────────────────
NTMCC_STATIONS = [
    ("環狀線-新埔民生", 121.54134,  24.98272),
    ("環狀線-幸福",     121.527698, 24.984333),
    ("環狀線-十四張",   121.525051, 24.990549),
    ("環狀線-秀朗橋",   121.516386, 24.992143),
    ("環狀線-景平",     121.505114, 24.99392),
    ("環狀線-景安",     121.495978, 25.002382),
    ("環狀線-中和",     121.490461, 25.004413),
    ("環狀線-橋和",     121.484159, 25.00841),
    ("環狀線-中原",     121.472269, 25.014436),
    ("環狀線-板新",     121.464825, 25.015156),
    ("環狀線-板橋",     121.466831, 25.026282),
    ("環狀線-新埔",     121.460479, 25.039862),
    ("環狀線-頭前庄",   121.45998,  25.049984),
    ("環狀線-新莊",     121.459926, 25.061548),
]


def load_boundary():
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
    return su(tpe_polys), su(ntpc_polys)


def load_mrt_stations(tpe_boundary, ntpc_boundary):
    json_path = os.path.join(DATA_DIR, "TpeMrtStations_TWD97_FIDCODE.json")
    with open(json_path, "rb") as f:
        raw = json.loads(f.read().decode("utf-8"))

    features = []
    for feat in raw["features"]:
        x, y = feat["geometry"]["coordinates"]
        lng, lat = tr_to_wgs.transform(x, y)
        name = feat["properties"]["NAME"]
        pt = Point(lng, lat)
        if tpe_boundary.contains(pt):
            city = "taipei"
        elif ntpc_boundary.contains(pt):
            city = "newtaipei"
        else:
            continue
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(lng, 6), round(lat, 6)]},
            "properties": {"name": name, "city": city, "type": "mrt"}
        })

    # 加入環狀線
    for name, lng, lat in NTMCC_STATIONS:
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(lng, 6), round(lat, 6)]},
            "properties": {"name": name, "city": "newtaipei", "type": "mrt"}
        })

    print(f"捷運站：{len(features)} 站")
    return features


def make_tra_features():
    features = []
    for name, lng, lat, city in TRA_METRO:
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(lng, 6), round(lat, 6)]},
            "properties": {"name": name, "city": city, "type": "tra"}
        })
    print(f"台鐵站：{len(features)} 站")
    return features


def write_geojson(path, features):
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f,
                  ensure_ascii=False, indent=2)
    print(f"  → {path}")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"

    print("讀取邊界...")
    tpe_boundary, ntpc_boundary = load_boundary()

    if target in ("mrt", "all"):
        print("生成捷運站點...")
        mrt_features = load_mrt_stations(tpe_boundary, ntpc_boundary)
        write_geojson(os.path.join(MAP_DIR, "isochrone_mrt_stations.geojson"), mrt_features)
        write_geojson(os.path.join(MAP_DIR, "isochrone_mrt_stations_taipei.geojson"),
                      [f for f in mrt_features if f["properties"]["city"] == "taipei"])

    if target in ("tra", "all"):
        print("生成台鐵站點...")
        tra_features = make_tra_features()
        write_geojson(os.path.join(MAP_DIR, "isochrone_tra_stations.geojson"), tra_features)
        write_geojson(os.path.join(MAP_DIR, "isochrone_tra_stations_taipei.geojson"),
                      [f for f in tra_features if f["properties"]["city"] == "taipei"])

    print("\n完成！")
