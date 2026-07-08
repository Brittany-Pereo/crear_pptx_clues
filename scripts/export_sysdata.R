# Exporta R/sysdata.rda (clues_info, metas, choices_etiquetas) a Parquet
# para que la app Python los lea directamente.
#
# Uso: Rscript scripts/export_sysdata.R <ruta_sysdata.rda> <carpeta_salida>

args <- commandArgs(trailingOnly = TRUE)
ruta_rda <- args[1]
carpeta_salida <- args[2]

if (!requireNamespace("arrow", quietly = TRUE)) {
  stop("El paquete 'arrow' no está instalado.")
}

load(ruta_rda)

dir.create(carpeta_salida, showWarnings = FALSE, recursive = TRUE)

arrow::write_parquet(clues_info, file.path(carpeta_salida, "clues_info.parquet"))
arrow::write_parquet(metas, file.path(carpeta_salida, "metas.parquet"))

choices_df <- data.frame(
  label = names(choices_etiquetas),
  value = as.character(choices_etiquetas),
  stringsAsFactors = FALSE
)
arrow::write_parquet(choices_df, file.path(carpeta_salida, "choices_etiquetas.parquet"))

cat("clues_info:", nrow(clues_info), "filas\n")
cat("metas:", nrow(metas), "filas\n")
cat("choices_etiquetas:", nrow(choices_df), "filas\n")
