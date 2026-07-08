"""Utilidades comunes: cálculo de la fecha de corte semanal (miércoles)."""

from datetime import date, timedelta


def calcular_fecha_corte(today: date | None = None) -> date:
    """Réplica de R/utils_comunes.R: fecha_corte.

    Miércoles más reciente; si hoy es miércoles, retrocede al miércoles anterior
    (porque el reporte del propio miércoles aún no tiene datos completos).
    """
    today = today or date.today()
    python_wd = today.weekday()  # lunes=0 ... domingo=6
    lub_wday = ((python_wd + 1) % 7) + 1  # domingo=1 ... sábado=7 (lubridate::wday)

    if lub_wday == 4:  # miércoles
        return today - timedelta(days=7)

    base_wday = (python_wd + 1) % 7  # domingo=0 ... sábado=6 (POSIXlt$wday)
    return today - timedelta(days=(base_wday + 4) % 7)


# Se calcula una vez al importar, igual que el objeto global `fecha_corte` en R.
fecha_corte = calcular_fecha_corte()
