"""Funciones auxiliares para manejo de CLUES: CLUES relacionadas y consultas SQL sobre Parquet."""

import duckdb
import pandas as pd


def obtener_clues_relacionadas(clues_seleccionada: str, clues_info: pd.DataFrame) -> list[str]:
    """Obtiene la CLUES SSA asociada, si existe."""
    fila = clues_info.loc[clues_info["clues_imb"] == clues_seleccionada, "clues_ssa_y_sme"]

    if fila.empty or pd.isna(fila.iloc[0]):
        return [clues_seleccionada]

    return [clues_seleccionada, fila.iloc[0]]


def construir_consulta_clues(
    con: duckdb.DuckDBPyConnection,
    clues_seleccionada: str,
    clues_info: pd.DataFrame,
    parquet_path: str,
    limite: int | None = 1000,
) -> pd.DataFrame:
    """Consulta la productividad diaria (histórico) para una CLUES y su relacionada."""
    clues_vector = obtener_clues_relacionadas(clues_seleccionada, clues_info)

    sql = f"""
        SELECT
            fecha,
            SUM(CAST(consultas_totales AS INT)) AS consulta_total,
            SUM(CAST(consultas_generales AS INT)) AS consulta_general,
            SUM(CAST(consultas_de_especialidad AS INT)) AS consulta_especialidad,
            SUM(CAST(procedimientos_quirurgicos AS INT)) AS procedimientos_qx,
            SUM(CAST(egresos AS INT)) AS egresos
        FROM parquet_scan(?)
        WHERE clues = ANY(?)
          AND fecha IS NOT NULL
        GROUP BY fecha
        ORDER BY fecha
        {"LIMIT " + str(limite) if limite is not None else ""}
    """

    return con.execute(sql, [parquet_path, clues_vector]).fetchdf()


def construir_consulta_personas(
    con: duckdb.DuckDBPyConnection,
    clues_seleccionada: str,
    parquet_path: str,
) -> pd.DataFrame:
    """Consulta el resumen anual de procedimientos/personas para una CLUES."""
    if not clues_seleccionada:
        raise ValueError("clues_seleccionada no puede estar vacío")

    sql = """
        SELECT
            anio_insert AS fecha,
            tipo_procedimiento,
            procedimientos,
            personas
        FROM parquet_scan(?)
        WHERE id = ?
        ORDER BY tipo_procedimiento, fecha
    """

    return con.execute(sql, [parquet_path, clues_seleccionada]).fetchdf()
