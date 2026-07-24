"""Carga de datos internos (clues_info, metas, choices_etiquetas) y conexión DuckDB."""

from pathlib import Path

import duckdb
import pandas as pd
import streamlit as st

DATA_DIR = Path(__file__).resolve().parent.parent / "data"

CUBOS_PARQUET = DATA_DIR / "resumen_prod_2020_2025.parquet"
PERSONAS_PARQUET = DATA_DIR / "procedimientos_personas.parquet"
MASTER_PPTX = DATA_DIR / "master_presentacion.pptx"


@st.cache_data
def load_clues_info() -> pd.DataFrame:
    return pd.read_parquet(DATA_DIR / "clues_info.parquet")


@st.cache_data
def load_metas() -> pd.DataFrame:
    return pd.read_parquet(DATA_DIR / "metas.parquet")


@st.cache_data
def load_choices() -> pd.DataFrame:
    return pd.read_parquet(DATA_DIR / "choices_etiquetas.parquet")


@st.cache_resource
def get_connection() -> duckdb.DuckDBPyConnection:
    return duckdb.connect(database=":memory:")
