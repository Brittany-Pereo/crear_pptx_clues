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

    # graficas de productividad
    fluidRow(
      column(6, plotOutput(ns("grafica_general"), height = "380px")),
      column(6, plotOutput(ns("grafica_especialidad"), height = "380px"))
    ),
    fluidRow(
      column(6, plotOutput(ns("grafica_qx"), height = "380px")),
      column(6, plotOutput(ns("grafica_egresos"), height = "380px"))
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

            print(names(valores$datos))
            print(head(valores$datos))

            cat("\nColumnas de valores$datos:\n")
            print(names(valores$datos))

            cat("\nPrimeras filas:\n")
            print(head(valores$datos))

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


    excel_exportado <- reactive({
      req(input$clues_select)

      clues_a_imprimir <- input$clues_select


      tabla_datos_imprimir <- crear_excel(clues_a_imprimir, valores$datos, val_personas$datos)

      return(tabla_datos_imprimir)
    })

    datos_anual_grafica <- reactive({
      req(valores$datos)

      valores$datos %>%
        mutate(
          fecha = as.Date(fecha),
          anio = lubridate::year(fecha)
        ) %>%
        filter(anio %in% c(2024, 2025, 2026)) %>%
        group_by(anio) %>%
        summarise(
          consulta_general_anual = sum(consulta_general, na.rm = TRUE),
          consulta_especialidad_anual = sum(consulta_especialidad, na.rm = TRUE),
          procedimientos_qx_anual = sum(procedimientos_qx, na.rm = TRUE),
          egresos_anual = sum(egresos, na.rm = TRUE),
          .groups = "drop"
        )
    })

    metas_filtrado_grafica <- reactive({
      req(input$clues_select)

      metas %>%
        dplyr::filter(clues_imb == input$clues_select)
    })

crear_grafica_clues <- function(df, variable_sel, titulo, datos_anual_grafica, metas_filtrado) {

      fecha_corte <- max(as.Date(df$fecha), na.rm = TRUE)
      mes_corte <- lubridate::month(fecha_corte)
      dia_corte <- lubridate::day(fecha_corte)

      col_anual <- dplyr::case_when(
        variable_sel == "consulta_general" ~ "consulta_general_anual",
        variable_sel == "consulta_especialidad" ~ "consulta_especialidad_anual",
        variable_sel == "procedimientos_qx" ~ "procedimientos_qx_anual",
        variable_sel == "egresos" ~ "egresos_anual",
        TRUE ~ NA_character_
      )

      df_avance <- df %>%
        mutate(
          fecha = as.Date(fecha),
          anio = lubridate::year(fecha),
          fecha_corte_anio = lubridate::ymd(
            paste0(anio, "-", mes_corte, "-", dia_corte)
          )
        ) %>%
        filter(anio %in% c(2024, 2025, 2026)) %>%
        group_by(anio) %>%
        summarise(
          avance = sum(.data[[variable_sel]][fecha <= fecha_corte_anio], na.rm = TRUE),
          .groups = "drop"
        )

      df_total <- datos_anual_grafica %>%
        mutate(anio = as.numeric(anio)) %>%
        filter(anio %in% c(2024, 2025, 2026)) %>%
        transmute(
          anio,
          total_anual = .data[[col_anual]]
        ) %>%
        mutate(
          total_anual = dplyr::if_else(
            anio == 2026,
            dplyr::case_when(
              variable_sel == "consulta_general" ~ sum(metas_filtrado$meta_general_anual, na.rm = TRUE),
              variable_sel == "consulta_especialidad" ~ sum(metas_filtrado$meta_especialidad_anual, na.rm = TRUE),
              variable_sel == "procedimientos_qx" ~ sum(metas_filtrado$meta_qx_anual, na.rm = TRUE),
              variable_sel == "egresos" ~ sum(metas_filtrado$meta_egresos_anual, na.rm = TRUE),
              TRUE ~ total_anual
            ),
            total_anual
          )
        )

      df_plot <- df_avance %>%
        left_join(df_total, by = "anio") %>%
        mutate(
          pendiente = pmax(total_anual - avance, 0),
          anio = as.character(anio)
        ) %>%
        select(anio, avance, pendiente, total_anual) %>%
        tidyr::pivot_longer(
          cols = c(avance, pendiente),
          names_to = "tipo",
          values_to = "valor"
        ) %>%
        mutate(
          tipo = factor(
            tipo,
            levels = c("avance", "pendiente"),
            labels = c("Avance al corte", "Resto del año")
          )
        )

      df_plot <- df_plot %>%
        mutate(
          color_barra = case_when(
            anio == "2026" & tipo == "Resto del año" ~ "#B08D57",
            tipo == "Resto del año" ~ "#D9D2BE",
            TRUE ~ "#1E5B4F"
          )
        )

      etiquetas <- df_plot %>%
        group_by(anio) %>%
        summarise(
          total_anual = sum(valor, na.rm = TRUE),
          .groups = "drop"
        )

      etiquetas_valores <- df_avance %>%
        left_join(df_total, by = "anio") %>%
        mutate(
          pendiente = pmax(total_anual - avance, 0),
          pct_avance = avance / total_anual,
          anio = as.character(anio),
          etiqueta_pct = scales::percent(pct_avance, accuracy = 1),
          etiqueta_avance = scales::comma(avance)
        )

      ggplot(df_plot, aes(x = anio, y = valor, fill = color_barra)) +
        geom_col(
          width = 0.65,
          position = position_stack(reverse = TRUE)
        ) +
        geom_text(
          data = etiquetas,
          aes(
            x = anio,
            y = total_anual,
            label = scales::comma(total_anual)
          ),
          inherit.aes = FALSE,
          vjust = -0.4,
          fontface = "bold",
          size = 5
        ) +
        geom_text(
          data = etiquetas_valores,
          aes(
            x = anio,
            y = avance / 2,
            label = etiqueta_avance
          ),
          inherit.aes = FALSE,
          color = "white",
          fontface = "bold",
          size = 5
        ) +
        geom_text(
          data = etiquetas_valores,
          aes(
            x = anio,
            y = avance + (pendiente * 0.1),
            label = etiqueta_pct
          ),
          inherit.aes = FALSE,
          color = "black",
          fontface = "bold",
          size = 5
        ) +
        scale_fill_identity(
          guide = "legend",
          breaks = c("#D9D2BE", "#1E5B4F", "#B08D57"),
          labels = c("Resto del año", "Avance al corte", "Meta")
        ) +
        scale_y_continuous(
          labels = scales::comma,
          expand = expansion(mult = c(0, 0.18))
        ) +
        labs(title = titulo, x = NULL, y = NULL, fill = NULL) +
        theme_minimal(base_family = "Noto Sans") +
        theme(
          plot.title = element_text(
            hjust = 0.5,
            face = "bold",
            size = 18,
            color = "#6B7280"
          ),
          axis.text.x = element_text(
            size = 13,
            face = "bold",
            color = "#6B7280"
          ),
          axis.text.y = element_text(
            size = 11,
            color = "#6B7280"
          ),
          legend.position = "bottom",
          legend.text = element_text(
            size = 14,
            face = "bold"
          ),
          panel.grid.major.x = element_blank(),
          panel.grid.minor = element_blank()
        )
    }

output$grafica_general <- renderPlot({
  req(valores$datos, datos_anual_grafica(), metas_filtrado_grafica())
  crear_grafica_clues(
    valores$datos,
    "consulta_general",
    "Consulta general",
    datos_anual_grafica(),
    metas_filtrado_grafica()
  )
})

    output$grafica_especialidad <- renderPlot({
      req(valores$datos, datos_anual_grafica())
      crear_grafica_clues(
        valores$datos,
        "consulta_especialidad",
        "Consulta de especialidad",
        datos_anual_grafica(),
        metas_filtrado_grafica())
    })

    output$grafica_qx <- renderPlot({
      req(valores$datos, datos_anual_grafica())
      crear_grafica_clues(
        valores$datos,
        "procedimientos_qx",
        "Procedimientos quirúrgicos",
        datos_anual_grafica(),
        metas_filtrado_grafica())
    })

    output$grafica_egresos <- renderPlot({
      req(valores$datos, datos_anual_grafica())
      crear_grafica_clues(
        valores$datos,
        "egresos",
        "Egresos",
        datos_anual_grafica(),
        metas_filtrado_grafica())
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
