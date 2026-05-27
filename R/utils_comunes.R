#' comunes
#'
#' @description A utils function
#'
#' @return The return value, if any, from executing the utility.
#' funcion de fecha de corte
#' @export
fecha_corte <- if(lubridate::wday(Sys.Date())==4) {
  Sys.Date()-7
} else {Sys.Date() - ((as.POSIXlt(Sys.Date())$wday + 4) %% 7)}
#' @noRd
