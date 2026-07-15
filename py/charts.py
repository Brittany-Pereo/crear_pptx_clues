"""Preparación de datos y gráficas de productividad (avance vs. meta), portadas de ggplot2 a matplotlib."""

from matplotlib.patches import Patch
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd

COL_VERDE = "#1E5B4F"
COL_BEIGE = "#D9D2BE"
COL_DORADO = "#B08D57"

VARIABLES_PRODUCTIVIDAD = ["consulta_general", "consulta_especialidad", "procedimientos_qx", "egresos"]

_COL_ANUAL_MAP = {
    "consulta_general": "consulta_general_anual",
    "consulta_especialidad": "consulta_especialidad_anual",
    "procedimientos_qx": "procedimientos_qx_anual",
    "egresos": "egresos_anual",
}

_META_COL_MAP = {
    "consulta_general": "meta_general_anual",
    "consulta_especialidad": "meta_especialidad_anual",
    "procedimientos_qx": "meta_cirugia_anual",
    "egresos": "meta_egresos_anual",
}

_TIPO_PROCEDIMIENTO_MAP = {
    "consulta total": "consulta_total",
    "general": "consulta_general",
    "especialidad": "consulta_especialidad",
    "qx": "procedimientos_qx",
    "egresos": "egresos",
}


def datos_personas_grafica(val_personas_datos: pd.DataFrame) -> pd.DataFrame:
    """Pivotea el resultado de construir_consulta_personas a una fila por año."""
    anios_base = pd.DataFrame({"fecha": pd.to_datetime(["2024-12-31", "2025-12-31", "2026-12-31"])})

    df = val_personas_datos.copy()
    df["anio"] = df["fecha"].astype(float).astype(int)
    df["fecha"] = pd.to_datetime(df["anio"].astype(str) + "-12-31")
    df["tipo_procedimiento"] = df["tipo_procedimiento"].map(_TIPO_PROCEDIMIENTO_MAP).fillna(df["tipo_procedimiento"])

    df = df[df["tipo_procedimiento"].isin(VARIABLES_PRODUCTIVIDAD)]

    datos_raw = df.pivot_table(
        index="fecha", columns="tipo_procedimiento", values="procedimientos", aggfunc="sum", fill_value=0
    ).reset_index()

    resultado = anios_base.merge(datos_raw, on="fecha", how="left")

    for col in VARIABLES_PRODUCTIVIDAD:
        if col not in resultado.columns:
            resultado[col] = 0
        resultado[col] = resultado[col].fillna(0)

    return resultado


def datos_anual_grafica(valores_datos: pd.DataFrame) -> pd.DataFrame:
    """Resumen anual (2024-2026) del histórico diario de consultas/procedimientos."""
    anios_base = pd.DataFrame({"anio": [2024, 2025, 2026]})

    df = valores_datos.copy()
    df["fecha"] = pd.to_datetime(df["fecha"])
    df["anio"] = df["fecha"].dt.year
    df = df[df["anio"].isin([2024, 2025, 2026])]

    resumen = df.groupby("anio").agg(
        consulta_general_anual=("consulta_general", "sum"),
        consulta_especialidad_anual=("consulta_especialidad", "sum"),
        procedimientos_qx_anual=("procedimientos_qx", "sum"),
        egresos_anual=("egresos", "sum"),
    ).reset_index()

    resultado = anios_base.merge(resumen, on="anio", how="left")
    numeric_cols = resultado.select_dtypes(include="number").columns
    resultado[numeric_cols] = resultado[numeric_cols].fillna(0)
    return resultado


def datos_anual_grafica_personas(df_personas_grafica: pd.DataFrame, df_anual_grafica: pd.DataFrame) -> pd.DataFrame:
    """Combina el histórico 2024-2025 con el resumen 2026 basado en procedimientos_personas."""
    anios_base = pd.DataFrame({"anio": [2024, 2025, 2026]})

    df = df_personas_grafica.copy()
    df["anio"] = df["fecha"].dt.year
    anual_personas = df.groupby("anio").agg(
        consulta_general_anual=("consulta_general", "sum"),
        consulta_especialidad_anual=("consulta_especialidad", "sum"),
        procedimientos_qx_anual=("procedimientos_qx", "sum"),
        egresos_anual=("egresos", "sum"),
    ).reset_index()

    historico_2024_2025 = df_anual_grafica[df_anual_grafica["anio"].isin([2024, 2025])]
    combinado = pd.concat(
        [historico_2024_2025, anual_personas[anual_personas["anio"] == 2026]],
        ignore_index=True,
    )

    resultado = anios_base.merge(combinado, on="anio", how="left")
    numeric_cols = resultado.select_dtypes(include="number").columns
    resultado[numeric_cols] = resultado[numeric_cols].fillna(0)
    return resultado


def productividades_disponibles(df_personas_grafica: pd.DataFrame) -> list[str]:
    """Determina qué tipos de productividad tienen datos (>0) para decidir cuántas gráficas mostrar."""
    disponibles = []
    if df_personas_grafica["consulta_general"].sum() > 0:
        disponibles.append("general")
    if df_personas_grafica["consulta_especialidad"].sum() > 0:
        disponibles.append("especialidad")
    if df_personas_grafica["procedimientos_qx"].sum() > 0:
        disponibles.append("qx")
    if df_personas_grafica["egresos"].sum() > 0:
        disponibles.append("egresos")
    if not disponibles:
        disponibles = ["general"]
    return disponibles


def _fecha_corte_anio(anio: int, mes: int, dia: int) -> pd.Timestamp:
    try:
        return pd.Timestamp(year=anio, month=mes, day=dia)
    except ValueError:
        return pd.Timestamp(year=anio, month=mes, day=1) + pd.offsets.MonthEnd(0)


def crear_grafica_clues(
    df: pd.DataFrame,
    variable_sel: str,
    titulo: str,
    datos_anual_grafica_df: pd.DataFrame,
    metas_filtrado: pd.DataFrame,
):
    """Gráfica de barras apiladas (avance al corte vs. resto del año) para 2024-2026."""
    anios_base = [2024, 2025, 2026]

    df = df.copy()
    df["fecha"] = pd.to_datetime(df["fecha"])
    fecha_corte = df["fecha"].max()
    mes_corte, dia_corte = fecha_corte.month, fecha_corte.day

    col_anual = _COL_ANUAL_MAP[variable_sel]

    df["anio"] = df["fecha"].dt.year
    df_f = df[df["anio"].isin(anios_base)].copy()
    df_f["fecha_corte_anio"] = df_f["anio"].apply(lambda a: _fecha_corte_anio(a, mes_corte, dia_corte))

    avance = (
        df_f[df_f["fecha"] <= df_f["fecha_corte_anio"]]
        .groupby("anio")[variable_sel]
        .sum()
        .reindex(anios_base, fill_value=0)
    )

    hay_2026 = bool((df_f.loc[df_f["anio"] == 2026, variable_sel] > 0).any())

    df_total_raw = (
        datos_anual_grafica_df.assign(anio=datos_anual_grafica_df["anio"].astype(int))
        .set_index("anio")[col_anual]
        .reindex(anios_base, fill_value=0)
    )

    meta_valor = metas_filtrado[_META_COL_MAP[variable_sel]].sum() if not metas_filtrado.empty else 0

    total_anual = df_total_raw.fillna(0).copy()
    if hay_2026:
        total_anual.loc[2026] = meta_valor

    avance = avance.fillna(0)
    pendiente = (total_anual - avance).clip(lower=0)
    pct_avance = (avance / total_anual).where(total_anual > 0, 0)

    ymax = max(total_anual.max(), avance.max())
    if not np.isfinite(ymax) or ymax == 0:
        ymax = 1

    fig, ax = plt.subplots(figsize=(6, 5))
    x = np.arange(len(anios_base))
    colores_pendiente = [COL_DORADO if a == 2026 else COL_BEIGE for a in anios_base]

    ax.bar(x, avance.reindex(anios_base).values, width=0.65, color=COL_VERDE, zorder=3)
    ax.bar(
        x,
        pendiente.reindex(anios_base).values,
        width=0.65,
        bottom=avance.reindex(anios_base).values,
        color=colores_pendiente,
        zorder=3,
    )

    for i, anio in enumerate(anios_base):
        ax.text(
            i, total_anual[anio], f"{total_anual[anio]:,.0f}",
            ha="center", va="bottom", fontweight="bold", fontsize=11,
        )
        ax.text(
            i, avance[anio] / 2, f"{avance[anio]:,.0f}",
            ha="center", va="center", color="white", fontweight="bold", fontsize=11,
        )
        etiqueta_pct = f"{pct_avance[anio] * 100:.0f}%" if total_anual[anio] > 0 else "0%"
        ax.text(
            i, avance[anio] + pendiente[anio] * 0.1, etiqueta_pct,
            ha="center", va="bottom", fontweight="bold", fontsize=11, color="black",
        )

    ax.set_xticks(x)
    ax.set_xticklabels([str(a) for a in anios_base], fontweight="bold", fontsize=13, color="#6B7280")
    ax.set_ylim(0, ymax * 1.18)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.set_title(titulo, fontweight="bold", fontsize=18, color="#6B7280", pad=15)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.tick_params(axis="y", colors="#6B7280", labelsize=11)
    ax.grid(False)

    handles = [
        Patch(facecolor=COL_BEIGE, label="Resto del año"),
        Patch(facecolor=COL_VERDE, label="Avance al corte"),
        Patch(facecolor=COL_DORADO, label="Meta"),
    ]
    ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.5, -0.12), ncol=3, frameon=False, fontsize=10)

    fig.tight_layout()
    return fig


_MESES_ES = {
    1: "enero", 2: "febrero", 3: "marzo", 4: "abril", 5: "mayo", 6: "junio",
    7: "julio", 8: "agosto", 9: "septiembre", 10: "octubre", 11: "noviembre", 12: "diciembre",
}


def mes_anio_es(fecha) -> str:
    fecha = pd.Timestamp(fecha)
    return f"{_MESES_ES[fecha.month]} {fecha.year}"


def fecha_larga_es(fecha) -> str:
    fecha = pd.Timestamp(fecha)
    return f"{fecha.day:02d} de {_MESES_ES[fecha.month]} de {fecha.year}"


# Nota: grafica_planeacion_historica, grafica_planeacion_2024_2026 y
# grafica_consultas_periodos (las 3 gráficas del reporte PPTX) se movieron a
# py/pptx_report.py como formas nativas de PowerPoint (editables), en vez de
# imágenes matplotlib. Las que quedan en este archivo son solo las que se
# muestran en pantalla dentro de Streamlit.
