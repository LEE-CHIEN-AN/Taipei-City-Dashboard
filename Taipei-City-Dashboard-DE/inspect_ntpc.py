import requests, zipfile, io, pandas as pd

url = "https://opdadm.moi.gov.tw/api/v1/no-auth/resource/api/dataset/986931B3-0E46-4F94-BF52-A2911499301F/resource/08109526-C593-415A-9841-68F6CEE64302/download"
print("Downloading...")
resp = requests.get(url, timeout=300)
z = zipfile.ZipFile(io.BytesIO(resp.content))

# 只讀主要資料 CSV
df = pd.read_csv(z.open("NPA_TMA2_1.csv"), low_memory=False)
print(f"Total rows: {len(df)}")

city_col = "處理單位名稱警局層"
ped_col = "當事者行動狀態大類別名稱"

# 城市分布
print("\n城市分布 (top 5):")
print(df[city_col].value_counts().head(5))

# 行動狀態大類別名稱分布
print("\n行動狀態大類 (top 10):")
print(df[ped_col].value_counts().head(10))

# 新北市有幾筆？
ntpc = df[df[city_col].str.contains("新北市", na=False)]
print(f"\n新北市總行: {len(ntpc)}")

# 「人的狀態」子類別分布
person_rows = ntpc[ntpc[ped_col] == "人的狀態"]
print(f"\n新北市「人的狀態」rows: {len(person_rows)}")
sub_col = "當事者行動狀態子類別名稱"
print("\n子類別 (top 15):")
print(person_rows[sub_col].value_counts().head(15))

# 估計行人：「人的狀態」且不是「騎腳踏車」等
ped_sub_keywords = ["穿越", "路段", "等候", "路旁", "行人"]
mask = person_rows[sub_col].astype(str).str.contains("|".join(ped_sub_keywords), na=False)
print(f"\n含行人關鍵字的子類別 rows: {mask.sum()}")
print(person_rows[sub_col][mask].value_counts())
