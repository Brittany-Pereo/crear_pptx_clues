

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
    uiOutput(ns("ui_graficas_productividad")),

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

    productividades_disponibles <- reactive({
      req(datos_personas_grafica())

      df <- datos_personas_grafica()

      disponibles <- c()

      if (sum(df$consulta_general, na.rm = TRUE) > 0) {
        disponibles <- c(disponibles, "general")
      }

      if (sum(df$consulta_especialidad, na.rm = TRUE) > 0) {
        disponibles <- c(disponibles, "especialidad")
      }

      if (sum(df$procedimientos_qx, na.rm = TRUE) > 0) {
        disponibles <- c(disponibles, "qx")
      }

      if (sum(df$egresos, na.rm = TRUE) > 0) {
        disponibles <- c(disponibles, "egresos")
      }

      if (length(disponibles) == 0) {
        disponibles <- "general"
      }

      disponibles
    })

    output$ui_graficas_productividad <- renderUI({
      req(productividades_disponibles())

      ns <- session$ns
      prod <- productividades_disponibles()
      n <- length(prod)

      mapa_outputs <- list(
        general = plotOutput(ns("grafica_general"), height = ifelse(n == 1, "520px", "320px")),
        especialidad = plotOutput(ns("grafica_especialidad"), height = ifelse(n == 1, "520px", "320px")),
        qx = plotOutput(ns("grafica_qx"), height = ifelse(n == 1, "520px", "320px")),
        egresos = plotOutput(ns("grafica_egresos"), height = ifelse(n == 1, "520px", "320px"))
      )

      plots <- mapa_outputs[prod]

      if (n == 1) {
        return(
          fluidRow(
            column(2),
            column(8, plots[[1]]),
            column(2)
          )
        )
      }

      if (n == 2) {
        return(
          fluidRow(
            column(6, plots[[1]]),
            column(6, plots[[2]])
          )
        )
      }

      if (n == 3) {
        return(
          tagList(
            fluidRow(
              column(6, plots[[1]]),
              column(6, plots[[2]])
            ),
            fluidRow(
              column(3),
              column(6, plots[[3]]),
              column(3)
            )
          )
        )
      }

      tagList(
        fluidRow(
          column(6, plots[[1]]),
          column(6, plots[[2]])
        ),
        fluidRow(
          column(6, plots[[3]]),
          column(6, plots[[4]])
        )
      )
    })


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
      path <- system.file("app", "data", "resumen_prod_2020_2025.parquet",
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
        selected =  "NACIONAL",
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

            print(val_personas$datos)
            str(val_personas$datos)
            #View(as.data.frame(val_personas$datos))

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

      anios_base <- tibble::tibble(anio = c(2024, 2025, 2026))

      datos_resumen <- valores$datos %>%
        dplyr::mutate(
          fecha = clock::as_date(fecha),
          anio = clock::get_year(fecha)
        ) %>%
        dplyr::filter(anio %in% c(2024, 2025, 2026)) %>%
        dplyr::group_by(anio) %>%
        dplyr::summarise(
          consulta_general_anual = sum(consulta_general, na.rm = TRUE),
          consulta_especialidad_anual = sum(consulta_especialidad, na.rm = TRUE),
          procedimientos_qx_anual = sum(procedimientos_qx, na.rm = TRUE),
          egresos_anual = sum(egresos, na.rm = TRUE),
          .groups = "drop"
        )

      anios_base %>%
        dplyr::left_join(datos_resumen, by = "anio") %>%
        dplyr::mutate(
          dplyr::across(where(is.numeric), ~ tidyr::replace_na(.x, 0))
        )
    })

    metas_filtrado_grafica <- reactive({
      req(input$clues_select)

      metas %>%
        dplyr::filter(clues_imb == input$clues_select)
    })

    crear_grafica_clues <- function(df, variable_sel, titulo,
                                    datos_anual_grafica, metas_filtrado) {

      anios_base <- tibble::tibble(anio = c(2024, 2025, 2026))

      df <- df %>%
        dplyr::mutate(fecha = clock::as_date(fecha))

      fecha_corte <- max(df$fecha, na.rm = TRUE)
      mes_corte <- clock::get_month(fecha_corte)
      dia_corte <- clock::get_day(fecha_corte)

      col_anual <- dplyr::case_when(
        variable_sel == "consulta_general" ~ "consulta_general_anual",
        variable_sel == "consulta_especialidad" ~ "consulta_especialidad_anual",
        variable_sel == "procedimientos_qx" ~ "procedimientos_qx_anual",
        variable_sel == "egresos" ~ "egresos_anual",
        TRUE ~ NA_character_
      )

      df_avance_raw <- df %>%
        dplyr::mutate(
          anio = clock::get_year(fecha),
          fecha_corte_anio = clock::date_build(
            year = anio,
            month = mes_corte,
            day = dia_corte
          )
        ) %>%
        dplyr::filter(anio %in% c(2024, 2025, 2026)) %>%
        dplyr::group_by(anio) %>%
        dplyr::summarise(
          avance = sum(.data[[variable_sel]][fecha <= fecha_corte_anio], na.rm = TRUE),
          .groups = "drop"
        )

      df_avance <- anios_base %>%
        dplyr::left_join(df_avance_raw, by = "anio") %>%
        dplyr::mutate(avance = tidyr::replace_na(avance, 0))

      hay_2026 <- df %>%
        dplyr::mutate(anio = clock::get_year(fecha)) %>%
        dplyr::filter(anio == 2026) %>%
        dplyr::summarise(
          hay = any(.data[[variable_sel]] > 0, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::pull(hay)

      if (length(hay_2026) == 0 || is.na(hay_2026)) {
        hay_2026 <- FALSE
      }

      df_total_raw <- datos_anual_grafica %>%
        dplyr::mutate(anio = as.numeric(anio)) %>%
        dplyr::filter(anio %in% c(2024, 2025, 2026)) %>%
        dplyr::transmute(
          anio,
          total_anual = .data[[col_anual]]
        )

      df_total <- anios_base %>%
        dplyr::left_join(df_total_raw, by = "anio") %>%
        dplyr::mutate(
          total_anual = tidyr::replace_na(total_anual, 0),
          total_anual = dplyr::case_when(
            hay_2026 & anio == 2026 & variable_sel == "consulta_general" ~
              sum(metas_filtrado$meta_general_anual, na.rm = TRUE),
            hay_2026 & anio == 2026 & variable_sel == "consulta_especialidad" ~
              sum(metas_filtrado$meta_especialidad_anual, na.rm = TRUE),
            hay_2026 & anio == 2026 & variable_sel == "procedimientos_qx" ~
              sum(metas_filtrado$meta_cirugia_anual, na.rm = TRUE),
            hay_2026 & anio == 2026 & variable_sel == "egresos" ~
              sum(metas_filtrado$meta_egresos_anual, na.rm = TRUE),
            TRUE ~ total_anual
          )
        )

      df_base <- df_avance %>%
        dplyr::left_join(df_total, by = "anio") %>%
        dplyr::mutate(
          avance = tidyr::replace_na(avance, 0),
          total_anual = tidyr::replace_na(total_anual, 0),
          pendiente = pmax(total_anual - avance, 0),
          pct_avance = dplyr::if_else(total_anual > 0, avance / total_anual, 0),
          anio = as.character(anio),
          etiqueta_pct = dplyr::if_else(
            total_anual > 0,
            scales::percent(pct_avance, accuracy = 1),
            "0%"
          ),
          etiqueta_avance = scales::comma(avance)
        )

      df_plot <- df_base %>%
        dplyr::select(anio, avance, pendiente, total_anual) %>%
        tidyr::pivot_longer(
          cols = c(avance, pendiente),
          names_to = "tipo",
          values_to = "valor"
        ) %>%
        dplyr::mutate(
          tipo = factor(
            tipo,
            levels = c("avance", "pendiente"),
            labels = c("Avance al corte", "Resto del año")
          ),
          color_barra = dplyr::case_when(
            anio == "2026" & tipo == "Resto del año" ~ "#B08D57",
            tipo == "Resto del año" ~ "#D9D2BE",
            TRUE ~ "#1E5B4F"
          )
        )

      etiquetas <- df_base %>%
        dplyr::transmute(
          anio,
          total_anual,
          etiqueta_total = scales::comma(total_anual)
        )

      ymax <- max(df_base$total_anual, df_base$avance, na.rm = TRUE)

      if (!is.finite(ymax) || ymax == 0) {
        ymax <- 1
      }

      ggplot2::ggplot(df_plot, ggplot2::aes(x = anio, y = valor, fill = color_barra)) +
        ggplot2::geom_col(
          width = 0.65,
          position = ggplot2::position_stack(reverse = TRUE)
        ) +
        ggplot2::geom_text(
          data = etiquetas,
          ggplot2::aes(
            x = anio,
            y = total_anual,
            label = etiqueta_total
          ),
          inherit.aes = FALSE,
          vjust = -0.4,
          fontface = "bold",
          size = 5
        ) +
        ggplot2::geom_text(
          data = df_base,
          ggplot2::aes(
            x = anio,
            y = avance / 2,
            label = etiqueta_avance
          ),
          inherit.aes = FALSE,
          color = "white",
          fontface = "bold",
          size = 5
        ) +
        ggplot2::geom_text(
          data = df_base,
          ggplot2::aes(
            x = anio,
            y = avance + (pendiente * 0.1),
            label = etiqueta_pct
          ),
          inherit.aes = FALSE,
          color = "black",
          fontface = "bold",
          size = 5
        ) +
        ggplot2::scale_fill_identity(
          guide = "legend",
          breaks = c("#D9D2BE", "#1E5B4F", "#B08D57"),
          labels = c("Resto del año", "Avance al corte", "Meta")
        ) +
        ggplot2::scale_y_continuous(
          limits = c(0, ymax * 1.18),
          labels = scales::comma,
          expand = ggplot2::expansion(mult = c(0, 0.05))
        ) +
        ggplot2::labs(title = titulo, x = NULL, y = NULL, fill = NULL) +
        ggplot2::theme_minimal(base_family = "Noto Sans") +
        ggplot2::theme(
          plot.title = ggplot2::element_text(
            hjust = 0.5,
            face = "bold",
            size = 18,
            color = "#6B7280"
          ),
          axis.text.x = ggplot2::element_text(
            size = 13,
            face = "bold",
            color = "#6B7280"
          ),
          axis.text.y = ggplot2::element_text(
            size = 11,
            color = "#6B7280"
          ),
          legend.position = "bottom",
          legend.text = ggplot2::element_text(
            size = 14,
            face = "bold"
          ),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.minor = ggplot2::element_blank()
        )
    }

    datos_personas_grafica <- reactive({
      req(val_personas$datos)

      anios_base <- tibble::tibble(
        fecha = as.Date(c("2024-12-31", "2025-12-31", "2026-12-31"))
      )

      datos_raw <- val_personas$datos %>%
        dplyr::mutate(
          anio = as.numeric(fecha),
          fecha = clock::date_build(anio, 12, 31),
          tipo_procedimiento = dplyr::case_when(
            tipo_procedimiento == "consulta total" ~ "consulta_total",
            tipo_procedimiento == "general" ~ "consulta_general",
            tipo_procedimiento == "especialidad" ~ "consulta_especialidad",
            tipo_procedimiento == "qx" ~ "procedimientos_qx",
            tipo_procedimiento == "egresos" ~ "egresos",
            TRUE ~ tipo_procedimiento
          )
        ) %>%
        dplyr::filter(tipo_procedimiento %in% c(
          "consulta_general",
          "consulta_especialidad",
          "procedimientos_qx",
          "egresos"
        )) %>%
        dplyr::select(fecha, tipo_procedimiento, procedimientos) %>%
        tidyr::pivot_wider(
          names_from = tipo_procedimiento,
          values_from = procedimientos,
          values_fill = 0
        )

      anios_base %>%
        dplyr::left_join(datos_raw, by = "fecha") %>%
        {
          cols_necesarias <- c(
            "consulta_general",
            "consulta_especialidad",
            "procedimientos_qx",
            "egresos"
          )

          faltantes <- setdiff(cols_necesarias, names(.))

          if (length(faltantes) > 0) {
            .[faltantes] <- 0
          }

          dplyr::mutate(
            .,
            dplyr::across(
              dplyr::all_of(cols_necesarias),
              ~ tidyr::replace_na(.x, 0)
            )
          )
        }
    })

    datos_anual_grafica_personas <- reactive({
      req(datos_personas_grafica())
      req(datos_anual_grafica())

      anios_base <- tibble::tibble(anio = c(2024, 2025, 2026))

      anual_personas <- datos_personas_grafica() %>%
        dplyr::mutate(anio = clock::get_year(fecha)) %>%
        dplyr::group_by(anio) %>%
        dplyr::summarise(
          consulta_general_anual = sum(consulta_general, na.rm = TRUE),
          consulta_especialidad_anual = sum(consulta_especialidad, na.rm = TRUE),
          procedimientos_qx_anual = sum(procedimientos_qx, na.rm = TRUE),
          egresos_anual = sum(egresos, na.rm = TRUE),
          .groups = "drop"
        )

      historico_2024_2025 <- datos_anual_grafica() %>%
        dplyr::filter(anio %in% c(2024, 2025))

      anios_base %>%
        dplyr::left_join(
          dplyr::bind_rows(
            historico_2024_2025,
            anual_personas %>% dplyr::filter(anio == 2026)
          ),
          by = "anio"
        ) %>%
        dplyr::mutate(
          dplyr::across(where(is.numeric), ~ tidyr::replace_na(.x, 0))
        )
    })

    output$grafica_general <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "consulta_general",
        "Consulta general",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_especialidad <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "consulta_especialidad",
        "Consulta de especialidad",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_qx <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "procedimientos_qx",
        "Procedimientos quirúrgicos",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_egresos <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "egresos",
        "Egresos",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_general <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "consulta_general",
        "Consulta general",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_especialidad <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "consulta_especialidad",
        "Consulta de especialidad",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_qx <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "procedimientos_qx",
        "Procedimientos quirúrgicos",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
    })

    output$grafica_egresos <- renderPlot({
      req(datos_personas_grafica(), datos_anual_grafica_personas(), metas_filtrado_grafica())

      crear_grafica_clues(
        datos_personas_grafica(),
        "egresos",
        "Egresos",
        datos_anual_grafica_personas(),
        metas_filtrado_grafica()
      )
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
      contentType = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      content = function(file) {
        req(valores$datos)
        req(val_personas$datos)
        req(valores$clues_seleccionada)

        showNotification(
          "Generando informe en PowerPoint...",
          type = "default",
          duration = 3,
          session = session
        )

        datos_consulta <- list(
          datos = valores$datos,
          resumen = val_personas$datos,
          clues_seleccionada = valores$clues_seleccionada,
          consulta = valores$consulta_actual
        )

        presentacion <- crear_reporte_productividad(
          codigo_clues = datos_consulta$clues_seleccionada,
          clues_info = clues_info,
          metas = metas,
          historicos = datos_consulta$datos,
          procedimientos_personas = datos_consulta$resumen,
          ruta_master = system.file(
            "app", "data", "master_presentacion.pptx",
            package = "pptx"
          )
        )

        archivo_tmp <- tempfile(fileext = ".pptx")

        print(presentacion, target = archivo_tmp)

        file.copy(archivo_tmp, file, overwrite = TRUE)

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
