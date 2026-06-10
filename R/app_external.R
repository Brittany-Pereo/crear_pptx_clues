# R/app_external.R
#' Recursos externos de la aplicación
#'
#' Esta función agrega todos los recursos externos necesarios
#' como CSS, JS, fuentes, etc.
#'
#' @return Lista de tags HTML
#' @noRd
#' @importFrom shiny addResourcePath
#' @importFrom shiny tags
#' @importFrom golem activate_js favicon
#' @import openxlsx
#' @import lubridate
golem_add_external_resources <- function() {

  # 1. Agregar ruta de recursos estáticos
  www_path <- app_sys("app/www")

  if (www_path == "" || !dir.exists(www_path)) {
    www_path <- file.path(getwd(), "inst", "app", "www")
  }

  if (dir.exists(www_path)) {
    addResourcePath(
      "www",
      www_path
    )
  }

  # 2. Activar JavaScript de golem
  golem::activate_js()

  # 3. Favicon
  favicon <- golem::favicon()

  # 4. CSS personalizado si existe
  css_file <- app_sys("app/www/styles.css")
  if (file.exists(css_file)) {
    custom_css <- tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "www/styles.css"
    )
  } else {
    custom_css <- NULL
  }
#1E5B4F
  # 5. CSS adicional para DuckDB y tablas
  duckdb_css <- tags$style(HTML("
  .alert-success,.bg-green,.callout.callout-success,.label-success,.modal-success .modal-body {
    background-color: #1E5B4F !important;
    }
  .skin-blue .main-header .navbar {
    background-color: #1E5B4F;
    }
    .skin-blue .main-header .logo {
    background-color: #1E5B4F;
    color: #fff;
    border-bottom: 0 solid transparent
    }
    .btn-success {
    background-color: #A57F2C;
    border-color: #A57F2C;
    }
    .box.box-solid.box-primary>.box-header {
    color: #fff;
    background: #94b7cb;
    background-color: #1E5B4F;
    }
    .dataTables_wrapper {
      font-size: 12px;
    }
    .duckdb-status {
      padding: 10px;
      margin: 10px 0;
      border-radius: 4px;
    }
    .duckdb-connected {
      background-color: #d4edda;
      color: #1e5b4f;
      border: 1px solid #c3e6cb;
    }
    .duckdb-error {
      background-color: #f8d7da;
      color: #721c24;
      border: 1px solid #f5c6cb;
    }
    .loading-spinner {
      display: inline-block;
      width: 20px;
      height: 20px;
      border: 3px solid #f3f3f3;
      border-top: 3px solid #3498db;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  "))

  # 6. JavaScript personalizado si existe
  js_file <- app_sys("app/www/app.js")
  if (file.exists(js_file)) {
    custom_js <- tags$script(src = "www/app.js")
  } else {
    custom_js <- NULL
  }

  # 7. Combinar todos los recursos
  tagList(
    favicon,
    custom_css,
    duckdb_css,
    custom_js,
    # Asegurar que Shiny está listo
    tags$script(HTML("
      $(document).ready(function() {
        console.log('Aplicación iniciada con DuckDB');
      });
    "))
  )
}
