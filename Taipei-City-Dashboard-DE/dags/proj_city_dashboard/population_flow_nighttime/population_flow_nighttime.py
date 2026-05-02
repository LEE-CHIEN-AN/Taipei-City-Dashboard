import os

import pandas as pd
from operators.common_pipeline import CommonDag
from sqlalchemy import create_engine
from utils.load_stage import (
    save_dataframe_to_postgresql,
    update_lasttime_in_data_to_dataset_info,
)


def _transfer(**kwargs):
    """
    Nationwide telecom signal nighttime staying population by town/district.
    Source CSV: 162908-全國各鄉鎮市區電信信令人口統計資料夜間停留人口.csv
    Place the CSV in the same directory as this DAG file before running.
    """
    ready_data_db_uri = kwargs.get("ready_data_db_uri")
    dag_infos = kwargs.get("dag_infos")
    dag_id = dag_infos.get("dag_id")
    load_behavior = dag_infos.get("load_behavior")
    default_table = dag_infos.get("ready_data_default_table")

    csv_path = os.path.join(
        os.path.dirname(__file__),
        "162908-全國各鄉鎮市區電信信令人口統計資料夜間停留人口.csv",
    )

    # Row 0: Chinese headers (direct column names)
    df = pd.read_csv(csv_path, dtype=str)

    col_map = {
        "縣市代碼": "county_id",
        "縣市名稱": "county",
        "鄉鎮市區代碼": "town_id",
        "鄉鎮市區名稱": "town",
        "平日夜間停留人數_統計": "weekday_nighttime_pop",
        "假日夜間停留人數_統計": "weekend_nighttime_pop",
        "資料時間_統計": "info_time",
    }
    df = df.rename(columns=col_map)

    num_cols = ["weekday_nighttime_pop", "weekend_nighttime_pop"]
    df[num_cols] = df[num_cols].apply(pd.to_numeric, errors="coerce")

    def parse_roc_time(roc_str):
        """Convert ROC time string '109Y11M' to timezone-aware Timestamp."""
        year = int(roc_str.split("Y")[0]) + 1911
        month = int(roc_str.split("Y")[1].replace("M", ""))
        return pd.Timestamp(f"{year}-{month:02d}-01", tz="Asia/Taipei")

    df["data_time"] = df["info_time"].apply(parse_roc_time)

    engine = create_engine(ready_data_db_uri)
    save_dataframe_to_postgresql(
        engine, data=df, load_behavior=load_behavior, default_table=default_table
    )

    lasttime_in_data = df["data_time"].max()
    update_lasttime_in_data_to_dataset_info(
        engine, airflow_dag_id=dag_id, lasttime_in_data=lasttime_in_data
    )


dag = CommonDag(
    proj_folder="proj_city_dashboard", dag_folder="population_flow_nighttime"
)
dag.create_dag(etl_func=_transfer)
