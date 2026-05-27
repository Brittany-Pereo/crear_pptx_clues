#' crear_pptx UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_crear_pptx_ui <- function(id) {
  ns <- NS(id)
  tagList(
    shinydashboard::box(
      title = "Generar Presentación",
      status = "primary",
      solidHeader = TRUE,
      width = 12,
      actionButton(
        ns("btn_crear_pptx"),
        label = "Crear PPTX",
        icon = icon("file-powerpoint"),
        class = "btn-success"
      ),
      p("Haz clic para generar la presentación en PowerPoint",
        style = "margin-top: 15px; color: #555;")
    )
  )
}

#' crear_pptx Server Functions
#'
#' @noRd
mod_crear_pptx_server <- function(id){
  moduleServer(id, function(input, output, session){
    ns <- session$ns

    observeEvent(input$btn_crear_pptx, {
      # Mostrar notificación de que el proceso ha comenzado
      showNotification(
        "Generando presentación en PowerPoint...",
        type = "info",
        duration = 10
      )

      # Llamar a la función que ya existe en el ambiente
      # tryCatch({
      #   resultado <- crear_pptx()
      #
      #   # Notificar éxito
      #   showNotification(
      #     "¡Presentación generada exitosamente!",
      #     type = "success",
      #     duration = 5
      #   )
      #
      #   # Si la función retorna la ruta del archivo, se puede ofrecer descarga
      #   if (is.character(resultado) && file.exists(resultado)) {
      #     showNotification(
      #       paste("Archivo guardado en:", resultado),
      #       type = "info",
      #       duration = 5
      #     )
      #   }
      #
      # }, error = function(e) {
      #   # Notificar error si la función falla
      #   showNotification(
      #     paste("Error al generar la presentación:", e$message),
      #     type = "error",
      #     duration = 8
      #   )
      # })
    })

  })
}

## To be copied in the UI
# mod_crear_pptx_ui("crear_pptx_1")

## To be copied in the server
# mod_crear_pptx_server("crear_pptx_1")
