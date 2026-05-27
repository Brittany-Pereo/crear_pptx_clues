#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
# R/app_ui.R
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),

    shinydashboard::dashboardPage(
      shinydashboard::dashboardHeader(
        title = tags$div(
          icon("hospital"),
          tags$img(src = "www/logo_gob_mx.png", height = "30px")

        ),
        titleWidth = 350
      ),
      shinydashboard::dashboardSidebar(
        width = 350,
        shinydashboard::sidebarMenu(
          shinydashboard::menuItem("Consulta", tabName = "consulta",
                                   icon = icon("search")),
          shinydashboard::menuItem("Ayuda", tabName = "ayuda",
                                   icon = icon("question-circle"))
        ),
        hr(),
        # Información del sistema
        div(
          style = "padding: 15px;",
          p(icon("database"), " Información 2020 a la fecha"),
          p(icon("code-branch"), " Productividad por clues"),
          hr(),
          p(icon("info-circle"),
            " Incluye información 2020 a la fecha",
            style = "font-size: 12px; color: #7f8c8d;")
        )
      ),
      shinydashboard::dashboardBody(
        tags$head(
          tags$style(HTML("
            .alert {
              padding: 10px;
              border-radius: 4px;
              margin-bottom: 15px;
            }
            .alert-info {
              background-color: #d9edf7;
              border-color: #bce8f1;
              color: #31708f;
            }
            .alert-success {
              background-color: #1e5b4f;
              border-color: #002f2a;
              color: #1e5b4f;
            }
            .alert-danger {
              background-color: #f2dede;
              border-color: #ebccd1;
              color: #a94442;
            }
          "))
        ),

        shinydashboard::tabItems(

          # Tab de consulta
          shinydashboard::tabItem(
            tabName = "consulta",
            fluidRow(
              shinydashboard::box(
                title = "Consulta de Unidades Médicas",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                uiOutput("modulo_consulta")
              )
            )
          ),

          # Tab de ayuda
          shinydashboard::tabItem(
            tabName = "ayuda",
            fluidRow(
              shinydashboard::box(
                title = "Instrucciones de uso",
                status = "info",
                width = 12,
                h4("¿Cómo usar esta aplicación?"),
                tags$ol(
                  tags$li("Selecciona una unidad médica (CLUES) del buscador"),
                  tags$li("El sistema automáticamente buscará la información disponible"),
                  tags$li(" - o -"),
                  tags$li("Los resultados se mostrarán en la tabla"),
                  tags$li("Puedes descargar los datos en formato CSV")
                ),
                h4("¿Qué incluye?"),
                p("Información del tipo de unidad y productividad"),
                h4("Formato de datos"),
                p("Los datos se pueden descargar en un archivo excel.")
              )
            )
          )
        )
      )
    )
  )
}
