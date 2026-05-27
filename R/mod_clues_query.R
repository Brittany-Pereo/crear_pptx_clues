# R/mod_clues_query.R
#' Módulo para consultas de CLUES con DuckDB
#'
#' Maneja la selección de CLUES y ejecuta consultas incluyendo
#' las CLUES relacionadas (SSA)

#' UI del módulo de consulta CLUES
#' @param id ID del módulo
mod_clues_query_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Selector de CLUES
    uiOutput(ns("selector_clues")),

    # Indicador de estado
    uiOutput(ns("estado_consulta")),

    # Tabla de resultados
    div(
      style = "margin-top: 20px;",
      DT::dataTableOutput(ns("tabla_resultados"))
    ),

    # Botones de acción
    fluidRow(
      column(6,
        downloadButton(ns("descargar_datos"),
                      "Descargar datos",
                      class = "btn-success btn-block")
      ),
      column(6,
             downloadButton(ns("btn_crear_pptx"),
                          "Descargar informe",
                          icon = icon("file-powerpoint"),
                          class = "btn-success btn-block")
      )
    )
  )
}

#' Server del módulo de consulta CLUES
#' @param id ID del módulo
#' @param con Conexión a DuckDB (reactiva)
#' @param clues_info Data frame con información de CLUES
mod_clues_query_server <- function(id, con, clues_info) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    valores <- reactiveValues(
      datos = NULL,
      clues_seleccionada = NULL,
      consulta_actual = NULL,
      cargando = FALSE,
      error = NULL
    )

    val_personas <- reactiveValues(
      datos = NULL,
      clues_seleccionada = NULL,
      consulta_actual = NULL,
      cargando = FALSE,
      error = NULL
    )


    # Obtener ruta al archivo Parquet
    parquet_path <- reactive({
      path <- system.file("app", "data", "Cubos_completos_2020_2025.parquet",
                         package = "pptx")
      if (path == "") {
        valores$error <- "No se encontró el archivo Parquet"
        return(NULL)
      }
      return(path)
    })

    personas_path <- reactive({
      path <- system.file("app", "data", "procedimientos_personas.parquet",
                          package = "pptx")
      if (path == "") {
        val_personas$error <- "No se encontró el archivo Parquet"
        return(NULL)
      }
      return(path)
    })

    # Crear choices para el selector
    output$selector_clues <- renderUI({
      req(clues_info)

      selectizeInput(
        inputId = session$ns("clues_select"),
        label = "Selecciona una unidad médica:",
        choices = choices_etiquetas,
        selected = NULL,
        options = list(
          placeholder = 'Escribe para buscar...',
          maxOptions = 100
        ),
        width = "100%"
      )
    })

    # Observar cuando se selecciona una CLUES
    observeEvent(input$clues_select, {
      req(input$clues_select)
      req(parquet_path())
      req(personas_path())
      req(con())

      # Guardar CLUES seleccionada
      valores$clues_seleccionada <- input$clues_select
      valores$cargando <- TRUE
      valores$error <- NULL

      val_personas$clues_seleccionada <- input$clues_select
      val_personas$cargando <- TRUE
      val_personas$error <- NULL
      # Obtener CLUES relacionadas para mostrar en consola
      clues_relacionadas <- obtener_clues_relacionadas(
        input$clues_select,
        clues_info
      )

      # Mensaje informativo
      # cat("\n🔍 Consultando datos para CLUES:", input$clues_select, "\n")
      # cat("📌 CLUES relacionadas:",
      #     paste(clues_relacionadas, collapse = ", "), "\n")

      # Construir consulta SQL
      consulta <- tryCatch({
        construir_consulta_clues(
          clues_seleccionada = input$clues_select,
          clues_info = clues_info,
          parquet_path = parquet_path(),
          # columnas = NULL,  # Todas las columnas
          limite = 1000     # Límite por rendimiento
        )
      }, error = function(e) {
        valores$error <- paste("Error al construir consulta:", e$message)
        NULL
      })




      if (!is.null(consulta)) {
        valores$consulta_actual <- consulta
        # Ejecutar consulta
        tryCatch({
          # Mostrar consulta en consola (para debugging)
          cat("\n📝 Consulta SQL ejecutada:\n")
          cat(consulta, "\n")

          # Ejecutar consulta
          resultados <- dbGetQuery(con(), consulta)

          if (nrow(resultados) > 0) {
            valores$datos <- resultados
            cat("✅ Consulta exitosa. Registros obtenidos:",
                nrow(resultados), "\n")
            cat("📊 Columnas:", paste(names(resultados), collapse = ", "), "\n")
          } else {
            valores$error <- paste(
              "No se encontraron datos para las CLUES:",
              paste(clues_relacionadas, collapse = ", ")
            )
            valores$datos <- NULL
          }

        }, error = function(e) {
          valores$error <- paste("Error al ejecutar consulta:", e$message)
          valores$datos <- NULL
          cat("❌", valores$error, "\n")
        })
      }

      personas <- tryCatch({
        construir_consulta_personas(
          clues_seleccionada = input$clues_select,
          clues_info = clues_info,
          parquet_path = personas_path()
        )
      }, error = function(e) {
        val_personas$error <- paste("Error al construir consulta personas:", e$message)
        NULL
      })
      if (!is.null(personas)) {
        val_personas$consulta_actual <- personas
        # Ejecutar consulta
        tryCatch({
          # Mostrar consulta en consola (para debugging)
          cat("\n📝 Consulta SQL ejecutada:\n")
          cat(personas, "\n")

          # Ejecutar consulta
          resultados <- dbGetQuery(con(), personas)

          if (nrow(resultados) > 0) {
            val_personas$datos <- resultados
            cat("✅ Consulta exitosa. Registros obtenidos:",
                nrow(resultados), "\n")
            cat("📊 Columnas:", paste(names(resultados), collapse = ", "), "\n")
          } else {
            val_personas$error <- paste(
              "No se encontraron datos para las CLUES:",
              paste(clues_relacionadas, collapse = ", ")
            )
            val_personas$datos <- NULL
          }

        }, error = function(e) {
          val_personas$error <- paste("Error al ejecutar consulta personas:", e$message)
          val_personas$datos <- NULL
          cat("❌", val_personas$error, "\n")
        })
      }

      val_personas$cargando <- FALSE
      valores$cargando <- FALSE

    })

    # Botón de refrescar
    observeEvent(input$refrescar, {
      if (!is.null(valores$clues_seleccionada)) {
        # Disparar el evento de selección nuevamente
        input$clues_select <- valores$clues_seleccionada
      }
    })

    # Mostrar estado de la consulta
    output$estado_consulta <- renderUI({
      if (valores$cargando) {
        div(
          class = "alert alert-info",
          icon("spinner", class = "fa-spin"),
          " Ejecutando consulta en DuckDB..."
        )
      } else if (!is.null(valores$error)) {
        div(
          class = "alert alert-danger",
          icon("exclamation-triangle"),
          " ", valores$error
        )
      } else if (!is.null(valores$datos) && nrow(valores$datos) > 0) {
        # Obtener información de CLUES relacionadas
        clues_rel <- obtener_clues_relacionadas(
          valores$clues_seleccionada,
          clues_info
        )

        div(
          class = "alert alert-success",
          icon("check-circle"),
          sprintf(
            " ✅ Consulta exitosa: %d registros encontrados para CLUES: %s",
            nrow(val_personas$datos),
            paste(clues_rel, collapse = ", ")
          )
        )
      }
    })

    # Renderizar tabla de resultados
    output$tabla_resultados <- DT::renderDataTable({
      req(val_personas$datos)
      req(nrow(val_personas$datos) > 0)

      # Formatear la tabla para mejor visualización
      DT::datatable(
        val_personas$datos,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          scrollY = "400px",
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf'),
          language = list(
            url = '//cdn.datatables.net/plug-ins/1.10.11/i18n/Spanish.json'
          )
        ),
        rownames = FALSE,
        filter = 'top',
        class = 'display compact'
      ) %>%
        # Formatear fechas si existen
        # { if ("fecha" %in% names(val_personas$datos))
        #     DT::formatDate(., columns = "fecha", method = 'toLocaleDateString')
        #   else . } %>%
        # Formatear números
        { if (any(sapply(val_personas$datos$datos, is.numeric)))
            DT::formatRound(., columns = which(sapply(val_personas$datos, is.numeric)), digits = 0)
          else . }
    })



    excel_exportado <- reactive({
      req(input$clues_select)

      clues_a_imprimir <- input$clues_select


      tabla_datos_imprimir <- crear_excel(clues_a_imprimir, valores$datos, val_personas$datos)

      return(tabla_datos_imprimir)
    })

    # Descargar datos
    output$descargar_datos <- downloadHandler(
      filename = function() {
        paste0("datos_clues_",
               valores$clues_seleccionada,
               "_",
               Sys.Date(),
               ".xlsx")
      },
      content = function(file) {
        req(valores$datos)
        # crear_excel(valores$clues_seleccionada)
        openxlsx::saveWorkbook(excel_exportado(), file)
        # openxlsx::write.xlsx(valores$datos, file)
      }
    )

    # Descargar datos
    output$btn_crear_pptx <- downloadHandler(
      filename = function() {
        paste0("datos_clues_",
               valores$clues_seleccionada,
               "_",
               Sys.Date(),
               ".pptx")
      },
      content = function(file) {
        showNotification(
          "Generando informe en PowerPoint...",
          type = "default",
          duration = 3,
          session = session
        )
        # Obtener los datos actuales
        datos_consulta <- list(
          datos = valores$datos,
          resumen = val_personas$datos,
          clues_seleccionada = valores$clues_seleccionada,
          consulta = valores$consulta_actual
        )

        # Generar la presentación
        presentacion <- crear_reporte_productividad(
          codigo_clues = datos_consulta$clues_seleccionada,
          clues_info = clues_info,
          metas = metas,
          historicos = datos_consulta$datos,
          procedimientos_personas = datos_consulta$resumen,
          ruta_master = system.file("app", "data", "master_presentacion.pptx",
                                    package = "pptx")
        )
                # crear_excel(valores$clues_seleccionada)
        print(presentacion, target=file)
        showNotification(
          "¡Informe generado exitosamente!",
          type = "default",
          duration = 5,
          session = session
        )
      }
    )
    # Retornar datos para uso en otros módulos
    return(reactive({
      list(
        datos = valores$datos,
        resumen = val_personas$datos,
        clues_seleccionada = valores$clues_seleccionada,
        consulta = valores$consulta_actual
      )
    }))
  })
}
