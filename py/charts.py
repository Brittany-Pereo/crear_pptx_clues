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


def grafica_planeacion_historica(
    df: pd.DataFrame,
    col_total: str,
    col_avance: str,
    titulo: str,
    beige: str = "#D9D2BE",
    verde: str = "#2F6F63",
    figsize=(6.5, 4.4),
):
    """Barras total (fondo) vs. avance (frente) por año, 2020-2025."""
    anios = list(range(2020, 2026))
    d = df.copy()
    d["anio_num"] = d["anio"].astype(int)
    d = d[d["anio_num"].isin(anios)].set_index("anio_num").reindex(anios)

    total = d[col_total].fillna(0)
    avance = d[col_avance].fillna(0)

    fig, ax = plt.subplots(figsize=figsize)
    x = np.arange(len(anios))

    ax.bar(x, total.values, width=0.82, color=beige, zorder=3)
    ax.bar(x, avance.values, width=0.82, color=verde, zorder=3)

    for i in range(len(anios)):
        ax.text(i, total.iloc[i], f"{total.iloc[i]:,.0f}", ha="center", va="bottom", fontweight="bold", fontsize=9)
        ax.text(i, avance.iloc[i], f"{avance.iloc[i]:,.0f}", ha="center", va="top", color="white", fontweight="bold", fontsize=8)

    ax.set_xticks(x)
    ax.set_xticklabels([str(a) for a in anios], fontweight="bold", color="#6B7280")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.set_title(titulo, fontweight="bold", fontsize=18, color="#6B7280", pad=15)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(axis="y", colors="#6B7280")
    ax.set_ylim(0, max(total.max(), avance.max(), 1) * 1.16)
    fig.tight_layout()
    return fig


def grafica_planeacion_2024_2026(
    df: pd.DataFrame,
    col_total: str,
    col_avance: str,
    titulo: str,
    beige: str = "#D9D2BE",
    verde: str = "#2F6F63",
    beige_2026: str = "#A99F86",
    verde_2026: str = "#1E5B4F",
    figsize=(5.5, 4.4),
):
    """Barras total (meta) vs. avance por año, 2024-2026, con formato especial para 2026."""
    anios = [2024, 2025, 2026]
    d = df.copy()
    d["anio_num"] = d["anio"].astype(int)
    d = d[d["anio_num"].isin(anios)].set_index("anio_num").reindex(anios)

    total = d[col_total].fillna(0)
    avance = d[col_avance].fillna(0)
    pct = (avance / total).where(total > 0, np.nan)

    colores_total = [beige_2026 if a == 2026 else beige for a in anios]
    colores_avance = [verde_2026 if a == 2026 else verde for a in anios]

    fig, ax = plt.subplots(figsize=figsize)
    x = np.arange(3)

    ax.bar(x, total.values, width=0.82, color=colores_total, zorder=3)
    ax.bar(x, avance.values, width=0.82, color=colores_avance, zorder=3)

    for i, anio in enumerate(anios):
        if anio == 2026:
            pct_str = f"{pct.iloc[i] * 100:.0f}%" if pd.notna(pct.iloc[i]) else "s/d"
            etiqueta_total = f"Meta 2026\n{total.iloc[i]:,.0f}"
            etiqueta_avance = f"Avance\n{avance.iloc[i]:,.0f}\n({pct_str})"
        else:
            etiqueta_total = f"{total.iloc[i]:,.0f}"
            etiqueta_avance = f"{avance.iloc[i]:,.0f}"
        ax.text(i, total.iloc[i], etiqueta_total, ha="center", va="bottom", fontweight="bold", fontsize=9, linespacing=1.1)
        ax.text(i, avance.iloc[i], etiqueta_avance, ha="center", va="top", color="white", fontweight="bold", fontsize=8, linespacing=1.1)

    ax.set_xticks(x)
    ax.set_xticklabels([str(a) for a in anios], fontweight="bold", color="#6B7280")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.set_title(titulo, fontweight="bold", fontsize=18, color="#6B7280", pad=15)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(axis="y", colors="#6B7280")
    ax.set_ylim(0, max(total.max(), avance.max(), 1) * 1.25)
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


def grafica_consultas_periodos(
    df: pd.DataFrame,
    fecha_inicio: str = "2022-08-01",
    fecha_fin: str | None = None,
    titulo: str = "Consultas totales del IMSS Bienestar",
    color_linea: str = "#6B6B6B",
    verde_punto: str = "#1F5B50",
    fill_2223: str = "#EFEFEF",
    fill_2024: str = "#E9DDCC",
    fill_2025: str = "#F4F0EA",
    fill_2026: str = "#E9DDCC",
    fill_valuebox: str = "#B99C6D",
    figsize=(13, 5.5),
):
    """Serie mensual de consultas totales con bandas por periodo y anotaciones."""
    hoy = pd.Timestamp.today().normalize()
    inicio_mes_actual = hoy.replace(day=1)

    if fecha_fin is None:
        fecha_fin = inicio_mes_actual
    else:
        fecha_fin = pd.Timestamp(fecha_fin)

    d = df.copy()
    d["fecha"] = pd.to_datetime(d["fecha"])
    d = d[
        (d["fecha"] >= pd.Timestamp(fecha_inicio))
        & (d["fecha"] <= fecha_fin)
        & (d["fecha"] < inicio_mes_actual)
    ].sort_values("fecha")

    if d.empty:
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_title(titulo, fontweight="bold")
        return fig

    ymax = d["consultas_totales"].max()
    ymin = d["consultas_totales"].min()

    bandas = pd.DataFrame({
        "xmin": pd.to_datetime(["2022-08-01", "2024-01-01", "2025-01-01", "2026-01-01"]),
        "xmax": pd.to_datetime([
            "2024-01-01", "2025-01-01", "2026-01-01",
            (fecha_fin + pd.offsets.MonthBegin(1)).normalize(),
        ]),
        "fill": [fill_2223, fill_2024, fill_2025, fill_2026],
        "label": [
            "2022–2023\nAños de transición",
            "2024\nPrimer año de operación",
            "2025\nSegundo año de operación",
            "2026\nTercer año de operación",
        ],
    })

    mes_destacado = fecha_fin.month

    puntos_destacados = d[(d["fecha"].dt.month == mes_destacado) & (d["fecha"].dt.year < 2026)]
    fecha_ultimo_valor = d["fecha"].max()
    valor_ultimo = d.loc[d["fecha"] == fecha_ultimo_valor, "consultas_totales"].iloc[0]

    fig, ax = plt.subplots(figsize=figsize)

    for _, banda in bandas.iterrows():
        ax.axvspan(banda["xmin"], banda["xmax"], color=banda["fill"], zorder=0)

    ultimos_3 = d.tail(3)
    if not ultimos_3.empty:
        xmin_sub = ultimos_3["fecha"].min() - pd.Timedelta(days=15)
        xmax_sub = ultimos_3["fecha"].max() + pd.Timedelta(days=15)
        ax.axvspan(xmin_sub, xmax_sub, color="#B22222", alpha=0.18, zorder=1)
        ax.text(
            d["fecha"].max() - pd.Timedelta(days=25), ymax * 0.9,
            "Posible subregistro\ntemporal", color="#7A1E3A", fontweight="bold",
            fontsize=9, ha="center", linespacing=1.1, zorder=5,
        )

    ax.plot(d["fecha"], d["consultas_totales"], color=color_linea, linewidth=1.6, zorder=3)
    ax.scatter(d["fecha"], d["consultas_totales"], color=color_linea, s=18, zorder=3)

    if not puntos_destacados.empty:
        ax.scatter(
            puntos_destacados["fecha"], puntos_destacados["consultas_totales"],
            color=verde_punto, s=60, zorder=4,
        )
        for _, fila in puntos_destacados.iterrows():
            ax.annotate(
                f"{fila['consultas_totales']:,.0f}\n{fila['fecha'].strftime('%b-%Y').title()}",
                (fila["fecha"], fila["consultas_totales"]),
                textcoords="offset points", xytext=(0, 10), ha="center",
                fontweight="bold", fontsize=8, linespacing=1.1,
            )

    for _, banda in bandas.iterrows():
        centro = banda["xmin"] + (banda["xmax"] - banda["xmin"]) / 2
        ax.text(
            centro, ymax * 1.30, banda["label"], ha="center", fontweight="bold",
            fontsize=8, linespacing=1.1,
        )

    ax.annotate(
        "", xy=(pd.Timestamp("2022-08-15"), ymax * 1.02), xytext=(pd.Timestamp("2022-08-15"), ymin * 0.95),
        arrowprops=dict(arrowstyle="->", color=verde_punto, linewidth=1.5),
    )
    ax.text(
        pd.Timestamp("2022-09-20"), ymax * 1.05,
        "Decreto de creación\ndel IMSS Bienestar", ha="left", fontweight="bold",
        fontsize=8, linespacing=1.1,
    )

    ax.annotate(
        f"{valor_ultimo:,.0f}\n{fecha_ultimo_valor.strftime('%b %Y').title()}",
        (fecha_ultimo_valor, valor_ultimo),
        textcoords="offset points", xytext=(0, -32), ha="center",
        fontweight="bold", fontsize=9, color="white", linespacing=1.1,
        bbox=dict(boxstyle="round,pad=0.4", facecolor=fill_valuebox, edgecolor="none"),
    )

    ax.set_ylim(0, ymax * 1.45)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    ax.set_title(titulo, fontweight="bold", fontsize=15, pad=14)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(False)
    fig.autofmt_xdate(rotation=45)
    fig.tight_layout()
    return fig
