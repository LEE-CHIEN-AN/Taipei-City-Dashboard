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
    Nationwide telecom signal daytime activity population by town/district.
    Source CSV: 全國各鄉鎮市區電信信令人口統計資料日間活動人口.csv
    Place the CSV in the same directory as this DAG file before running.
    """
    ready_data_db_uri = kwargs.get("ready_data_db_uri")
    dag_infos = kwargs.get("dag_infos")
    dag_id = dag_infos.get("dag_id")
    load_behavior = dag_infos.get("load_behavior")
    default_table = dag_infos.get("ready_data_default_table")

    csv_path = os.path.join(
        os.path.dirname(__file__),
        "全國各鄉鎮市區電信信令人口統計資料日間活動人口.csv",
    )

    # Row 0: English headers; Row 1: Chinese description row (skip it)
    df = pd.read_csv(csv_path, skiprows=[1], dtype=str)

    col_map = {
        "COUNTY_ID": "county_id",
        "COUNTY": "county",
        "TOWN_ID": "town_id",
        "TOWN": "town",
        "DAY_WORK(7:00~13:00)": "weekday_morning_pop",
        "DAY_WORK(13:00~19:00)": "weekday_afternoon_pop",
        "DAY_WORK": "weekday_daytime_pop",
        "DAY_WEEKEND(7:00~13:00)": "weekend_morning_pop",
        "DAY_WEEKEND(13:00~19:00)": "weekend_afternoon_pop",
        "DAY_WEEKEND": "weekend_daytime_pop",
        "INFO_TIME": "info_time",
    }
    df = df.rename(columns=col_map)

    num_cols = [
        "weekday_morning_pop",
        "weekday_afternoon_pop",
        "weekday_daytime_pop",
        "weekend_morning_pop",
        "weekend_afternoon_pop",
        "weekend_daytime_pop",
    ]
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
    proj_folder="proj_city_dashboard", dag_folder="population_flow_daytime"
)
dag.create_dag(etl_func=_transfer)
