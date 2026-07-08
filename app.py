"""App de consulta de productividad IMSS Bienestar por CLUES (migración de Shiny/golem a Streamlit)."""

import io

import pandas as pd
import streamlit as st

from py.charts import (
    crear_grafica_clues,
    datos_anual_grafica,
    datos_anual_grafica_personas,
    datos_personas_grafica,
    productividades_disponibles,
)
from py.data_loader import (
    CUBOS_PARQUET,
    MASTER_PPTX,
    PERSONAS_PARQUET,
    get_connection,
    load_choices,
    load_clues_info,
    load_metas,
)
from py.excel_export import crear_excel
from py.pptx_report import crear_reporte_productividad
from py.queries import construir_consulta_clues, construir_consulta_personas, obtener_clues_relacionadas

st.set_page_config(
    page_title="Productividad IMSS Bienestar",
    page_icon="🏥",
    layout="wide",
)


@st.cache_data(show_spinner="Ejecutando consulta en DuckDB...")
def cargar_datos_clues(clues_seleccionada: str):
    con = get_connection()
    clues_info = load_clues_info()

    error = None
    historico = pd.DataFrame()
    personas = pd.DataFrame()

    try:
        historico = construir_consulta_clues(
            con, clues_seleccionada, clues_info, str(CUBOS_PARQUET), limite=1000
        )
    except Exception as e:
        error = f"Error al ejecutar consulta: {e}"

    try:
        personas = construir_consulta_personas(con, clues_seleccionada, str(PERSONAS_PARQUET))
    except Exception as e:
        error = error or f"Error al ejecutar consulta personas: {e}"

    if historico.empty and personas.empty and error is None:
        clues_rel = obtener_clues_relacionadas(clues_seleccionada, clues_info)
        error = f"No se encontraron datos para las CLUES: {', '.join(clues_rel)}"

    return historico, personas, error


@st.cache_data(show_spinner="Generando informe en PowerPoint...")
def generar_pptx_bytes(clues_seleccionada: str) -> bytes:
    clues_info = load_clues_info()
    metas = load_metas()
    historico, personas, error = cargar_datos_clues(clues_seleccionada)
    if error:
        raise RuntimeError(error)

    presentacion = crear_reporte_productividad(
        codigo_clues=clues_seleccionada,
        clues_info=clues_info,
        metas=metas,
        historicos=historico,
        procedimientos_personas=personas,
        ruta_master=str(MASTER_PPTX),
    )
    buf = io.BytesIO()
    presentacion.save(buf)
    return buf.getvalue()


def render_sidebar():
    with st.sidebar:
        st.markdown("### 🏥 Productividad IMSS Bienestar")
        seccion = st.radio("Navegación", ["Consulta", "Ayuda"], label_visibility="collapsed")
        st.divider()
        st.markdown("📊 Información 2020 a la fecha")
        st.markdown("🔀 Productividad por CLUES")
        st.divider()
        st.caption("ℹ️ Incluye información 2020 a la fecha")
    return seccion


def render_graficas(dpg: pd.DataFrame, dagp: pd.DataFrame, metas_filtrado: pd.DataFrame):
    titulos = {
        "general": ("consulta_general", "Consulta general"),
        "especialidad": ("consulta_especialidad", "Consulta de especialidad"),
        "qx": ("procedimientos_qx", "Procedimientos quirúrgicos"),
        "egresos": ("egresos", "Egresos"),
    }

    disponibles = productividades_disponibles(dpg)
    figuras = []
    for clave in disponibles:
        variable, titulo = titulos[clave]
        fig = crear_grafica_clues(dpg, variable, titulo, dagp, metas_filtrado)
        figuras.append(fig)

    n = len(figuras)
    if n == 1:
        cols = st.columns([1, 2, 1])
        with cols[1]:
            st.pyplot(figuras[0])
    elif n == 2:
        cols = st.columns(2)
        for c, fig in zip(cols, figuras):
            with c:
                st.pyplot(fig)
    elif n == 3:
        cols = st.columns(2)
        with cols[0]:
            st.pyplot(figuras[0])
        with cols[1]:
            st.pyplot(figuras[1])
        cols2 = st.columns([1, 2, 1])
        with cols2[1]:
            st.pyplot(figuras[2])
    else:
        cols = st.columns(2)
        for i, fig in enumerate(figuras):
            with cols[i % 2]:
                st.pyplot(fig)


def render_consulta(clues_info: pd.DataFrame, metas: pd.DataFrame, choices: pd.DataFrame):
    st.header("Consulta de Unidades Médicas")

    label_map = dict(zip(choices["value"], choices["label"]))
    valores = choices["value"].tolist()
    default_idx = valores.index("NACIONAL") if "NACIONAL" in valores else 0

    clues_seleccionada = st.selectbox(
        "Selecciona una unidad médica:",
        options=valores,
        index=default_idx,
        format_func=lambda v: label_map.get(v, v),
    )

    if not clues_seleccionada:
        return

    historico, personas, error = cargar_datos_clues(clues_seleccionada)

    if error:
        st.error(error, icon="⚠️")
        return

    clues_rel = obtener_clues_relacionadas(clues_seleccionada, clues_info)
    st.success(
        f"✅ Consulta exitosa: {len(personas)} registros de resumen encontrados para CLUES: "
        f"{', '.join(clues_rel)}",
        icon="✅",
    )

    dpg = datos_personas_grafica(personas)
    dag = datos_anual_grafica(historico)
    dagp = datos_anual_grafica_personas(dpg, dag)
    metas_filtrado = metas[metas["clues_imb"] == clues_seleccionada]

    render_graficas(dpg, dagp, metas_filtrado)

    col1, col2 = st.columns(2)

    with col1:
        excel_wb = crear_excel(clues_seleccionada, clues_info, historico, personas)
        buf = io.BytesIO()
        excel_wb.save(buf)
        st.download_button(
            "⬇️ Descargar datos",
            data=buf.getvalue(),
            file_name=f"datos_clues_{clues_seleccionada}_{pd.Timestamp.today().date()}.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            use_container_width=True,
        )

    with col2:
        try:
            pptx_bytes = generar_pptx_bytes(clues_seleccionada)
            st.download_button(
                "⬇️ Descargar informe (PowerPoint)",
                data=pptx_bytes,
                file_name=f"datos_clues_{clues_seleccionada}_{pd.Timestamp.today().date()}.pptx",
                mime="application/vnd.openxmlformats-officedocument.presentationml.presentation",
                use_container_width=True,
            )
        except Exception as e:
            st.error(f"No se pudo generar el informe PowerPoint: {e}", icon="⚠️")


def render_ayuda():
    st.header("Instrucciones de uso")
    st.subheader("¿Cómo usar esta aplicación?")
    st.markdown(
        """
        1. Selecciona una unidad médica (CLUES) del buscador
        2. El sistema automáticamente buscará la información disponible
        3. Los resultados se mostrarán en las gráficas
        4. Puedes descargar los datos en formato Excel
        """
    )
    st.subheader("¿Qué incluye?")
    st.write("Información del tipo de unidad y productividad")
    st.subheader("Formato de datos")
    st.write("Los datos se pueden descargar en un archivo Excel.")


def main():
    clues_info = load_clues_info()
    metas = load_metas()
    choices = load_choices()

    seccion = render_sidebar()

    if seccion == "Consulta":
        render_consulta(clues_info, metas, choices)
    else:
        render_ayuda()


if __name__ == "__main__":
    main()
