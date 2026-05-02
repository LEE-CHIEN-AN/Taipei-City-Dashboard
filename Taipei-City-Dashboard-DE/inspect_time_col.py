"""Quick script to inspect the time column format in NPA CSV."""
import io, zipfile, requests, pandas as pd

url = "https://opdadm.moi.gov.tw/api/v1/no-auth/resource/api/dataset/E68DFD97-92B3-4A78-A447-87F1390B54B0/resource/C0876EEB-9468-4B23-8E67-AB57E3563A1B/download"
print("Downloading 2023 NPA data...")
resp = requests.get(url, timeout=120)
z = zipfile.ZipFile(io.BytesIO(resp.content))
csv_files = [f for f in z.namelist() if f.lower().endswith(".csv") and "A2" in f][:1]
print("CSV files:", csv_files)
for csv_f in csv_files:
    df = pd.read_csv(z.open(csv_f), encoding="utf-8-sig", low_memory=False, nrows=10)
    time_cols = [c for c in df.columns if "時" in c]
    print("Time-related columns:", time_cols)
    for c in time_cols[:6]:
        vals = list(df[c].head(5))
        print(f"  {c}: {vals}")
