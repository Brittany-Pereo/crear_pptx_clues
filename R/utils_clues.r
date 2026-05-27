# R/utils_clues.R
#' Funciones auxiliares para manejo de CLUES
#'
#' Funciones para obtener CLUES relacionadas y construir consultas SQL

#' Obtener CLUES relacionadas (SSA)
#'
#' @param clues_seleccionada Código CLUES seleccionado
#' @param clues_info Data frame con información de CLUES (de datos internos)
#' @return Vector con la(s) CLUES a consultar
#'
#' @export
obtener_clues_relacionadas <- function(clues_seleccionada, clues_info) {
  # Buscar la CLUES SSA asociada
  ssa <- clues_info |>
    dplyr::filter(clues_imb == clues_seleccionada) |>
    dplyr::pull(clues_ssa_y_sme)

  if (is.na(ssa) || length(ssa) == 0) {
    # Si no hay SSA, retorna solo la CLUES original
    return(clues_seleccionada)
  } else {
    # Retorna ambas CLUES
    return(c(clues_seleccionada, ssa))
  }
}

#' Construir cláusula IN para SQL
#'
#' @param clues_seleccionada Código CLUES seleccionado
#' @param clues_info Data frame con información de CLUES
#' @return String con formato SQL para cláusula IN
#'
#' @export
construir_clausula_in <- function(clues_seleccionada, clues_info) {
  # Obtener CLUES relacionadas
  clues_vector <- obtener_clues_relacionadas(clues_seleccionada, clues_info)

  # Construir la cláusula IN con formato SQL
  # Ejemplo: ('CLUES1', 'CLUES2')
  valores <- paste0("'", clues_vector, "'", collapse = ", ")
  clausula <- paste0("(", valores, ")")

  return(clausula)
}

#' Construir consulta SQL completa
#'
#' @param clues_seleccionada Código CLUES seleccionado
#' @param clues_info Data frame con información de CLUES
#' @param parquet_path Ruta al archivo Parquet
#' @param columnas Columnas a seleccionar (NULL = todas)
#' @param limite Límite de registros (NULL = sin límite)
#' @return String con la consulta SQL
#'
#' @export
construir_consulta_clues <- function(clues_seleccionada,
                                     clues_info,
                                     parquet_path,
                                     # columnas = NULL,
                                     limite = NULL) {

  # Construir cláusula IN
  clausula_in <- construir_clausula_in(clues_seleccionada, clues_info)

  # # Definir columnas a seleccionar
  # columnas_str <- if (!is.null(columnas)) {
  #   paste(columnas, collapse = ", ")
  # } else {
  #   "*"
  # }

  # Construir la consulta SQL
  consulta <- sprintf("
    SELECT
    fecha,
    SUM(CAST(consultas_totales AS INT)) AS consulta_total,
    SUM(CAST(consultas_generales AS INT)) AS consulta_general,
    SUM(CAST(consultas_de_especialidad AS INT)) AS consulta_especialidad,
    SUM(CAST(procedimientos_quirurgicos AS INT)) AS procedimientos_qx,
        SUM(CAST(egresos AS INT)) AS egresos
    FROM parquet_scan('%s')
    WHERE clues IN %s
     AND fecha IS NOT NULL
    GROUP BY fecha
    ORDER BY fecha
  ",  parquet_path, clausula_in)

  # Agregar límite si se especifica
  if (!is.null(limite)) {
    consulta <- paste(consulta, sprintf("LIMIT %d", limite))
  }

  return(consulta)
}


construir_consulta_personas <- function(clues_seleccionada,
                                     clues_info,
                                     parquet_path) {

  if (length(clues_seleccionada) == 0 || is.null(clues_seleccionada)) {
    stop("clues_seleccionada no puede estar vacío")
  }
  clausula_in <- clues_seleccionada

  # Construir la consulta SQL
  consulta <- sprintf("
    SELECT
    anio_insert AS fecha,
    tipo_procedimiento,
    procedimientos,
    personas
    FROM parquet_scan('%s')
    WHERE id = '%s'
    ORDER BY tipo_procedimiento, fecha
  ",  parquet_path, clausula_in)

  # Agregar límite si se especifica
  return(consulta)
}





crear_excel <- function(CLUES, ampliado, resumen) {
  # Crear un nuevo libro de trabajo
  wb <- createWorkbook()

  # Agregar una hoja
  addWorksheet(wb, "resumen")
  # Escribir las tablas en la misma hoja en diferentes posiciones
  writeData(wb, sheet = "resumen", x = CLUES, startCol = 1, startRow = 1)
  writeData(wb, sheet = "resumen", x = clues_info[clues_info$clues_imb==CLUES,]$nombre_de_la_unidad, startCol = 1, startRow = 2)
  writeData(wb, sheet = "resumen", x = clues_info[clues_info$clues_imb==CLUES,]$entidad, startCol = 1, startRow = 3)
  writeData(wb, sheet = "resumen", x = clues_info[clues_info$clues_imb==CLUES,]$nivel_atencion, startCol = 1, startRow = 4)
  writeData(wb, sheet = "resumen", x = clues_info[clues_info$clues_imb==CLUES,]$categoria_gerencial_ampliada, startCol = 1, startRow = 5)
  writeData(wb, sheet = "resumen", x = format(fecha_corte, "Fecha de corte: %d/%m/%Y"),   startCol = 1, startRow = 5)

 writeData(wb, sheet = "resumen", x = resumen, startCol = 1, startRow = 8)



  addWorksheet(wb, "productividad detalle")

  writeData(wb, sheet="productividad detalle", x=ampliado)
  return(wb)


}


