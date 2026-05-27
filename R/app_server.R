# R/app_server.R
#' @title Servidor de la aplicación
#' @description Define la lógica del servidor Shiny
#' @import shiny
#' @import duckdb
#' @import DBI
#' @import arrow
#' @import dplyr
#' @import grid
#' @import ggplot2
#' @import clock

#'
#' @noRd

app_server <- function(input, output, session) {
  Sys.setlocale("LC_TIME", "es_ES.UTF-8")
  # 1. Cargar datos internos de CLUES
  # Estos datos deben estar en R/sysdata.rda
  # clues_info <- get("clues_info", envir = asNamespace("pptx"))

  # 2. Configurar conexión a DuckDB
  con <- reactive({
    tryCatch({
      # Conectar en modo solo lectura
      dbConnect(
        duckdb::duckdb(),
        read_only = TRUE
      )
    }, error = function(e) {
      showNotification(
        paste("Error al conectar a DuckDB:", e$message),
        type = "error"
      )
      NULL
    })
  })

  # 3. Módulo principal de consulta CLUES
  datos_consulta <- mod_clues_query_server(
    id = "consulta_clues",
    con = con,
    clues_info = clues_info
  )

  # 4. UI del módulo (se renderiza en app_ui.R)
  output$modulo_consulta <- renderUI({
    mod_clues_query_ui("consulta_clues")
  })

  boton_consulta <-
  mod_crear_pptx_server("mi_pptx")
  output$modulo_boton <- renderUI({
    mod_clues_query_ui("btn_crear_pptx")
  })
  # 5. Observador para cuando se cargan datos
  observe({
    datos <- datos_consulta()
    if (!is.null(datos$datos) && nrow(datos$datos) > 0) {
      # Mostrar información en consola
      cat("\n📊 Datos cargados en la aplicación:\n")
      cat("  - CLUES seleccionada:", datos$clues_seleccionada, "\n")
      cat("  - Total registros:", nrow(datos$datos), "\n")
      cat("  - Columnas:", paste(names(datos$datos), collapse = ", "), "\n")

      # Aquí puedes agregar lógica adicional
      # Por ejemplo, actualizar otros módulos con los datos
    }
  })

  # 6. Cerrar conexión al finalizar
  # session$onSessionEnded(function() {
  #   if (!is.null(con())) {
  #     dbDisconnect(con(), shutdown = TRUE)
  #     cat("🦆 Conexión DuckDB cerrada\n")
  #   }
  # })

  # 7. Mensaje de inicio
  cat("\n🚀 Aplicación iniciada\n")
  # cat("📁 Paquete:", utils::packageName(), "\n")
  # cat("🦆 DuckDB:", if(!is.null(con())) "Conectado" else "No conectado", "\n")

}
