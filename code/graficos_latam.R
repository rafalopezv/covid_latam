library(janitor)
library(futurevisions)
library(highcharter)
library(EpiEstim)
library(tidyverse)
library(magrittr)
library(furrr)
library(future)

plan(multiprocess) # activar procesamiento paralelo

source("code/limpieza_bases.R")
source("code/funciones.R")

#----------------------------------------------
# aplanamiento de curvas
#----------------------------------------------
# vector de países a remover
quitar <- c("Antigua and Barbuda", "Bahamas", "Barbados", "Belize", "Guyana", "Suriname", 
            "Trinidad and Tobago", "Dominica", "Grenada", "Saint Kitts and Nevis", "Saint Lucia",
            "Saint Vincent and the Grenadines", "Jamaica")


codigos <- read_csv("input/codigos_covid_paises.csv") %>% 
  remove_empty() %>% 
  filter(
    region_es == "América Latina y el Caribe",
    !country_region %in% quitar
  ) %>% 
  dplyr::select(
    pais = pais_region,
    pais_region = country_region,
    pais_nombre_corto,
    continente
  ) 

# preparación de base: confirmados
df_mundo %>%
  filter(
    base == "confirmados",
    pais_region %in% codigos$pais_region
  ) %>% 
  left_join(., codigos) %>% 
  group_by(pais_region, semana) %>% 
  mutate(n = n()) %>% 
  filter(n >= 6) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(
    ., casos = sum(incidencia),
    ult_semana = pull(., incidencia) %>% last)) %>% 
  bind_rows() %>% 
  group_by(pais_region, semana) %>% 
  mutate(
    ult_semana = sum(incidencia)
  ) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(., 
                 ult_semana = pull(., ult_semana) %>% last
  )) %>% 
  bind_rows() %>% 
  ungroup() %>% 
  mutate(
    titulo = paste0(pais_nombre_corto, ", ", casos, " casos", "\n", total_semanas,  
                    " semanas desde paciente 0", "\n", " Nuevos casos última semana:", ult_semana)
  ) -> temp


temp %>% 
  dplyr::select(pais_region, casos) %>% 
  unique() %>% 
  arrange(casos) %>% 
  mutate(num = 1:nrow(.)) -> temp_1

# grafico incidencia confirmados
temp %>% 
  group_by(titulo, pais_region, semana) %>% 
  summarise(incidencia = sum(incidencia)) %>% 
  left_join(., temp_1) %>% 
  ggplot(aes(semana, incidencia, fill = continente)) + 
  geom_col(color = NA, alpha = 0.9, fill = "#CB1724") + 
  facet_wrap(vars(fct_reorder(titulo, num, .desc = T)), scales = "free", ncol = 4) +
  hrbrthemes::theme_ipsum_rc(grid = F, base_family = "Source Code Pro Medium", strip_text_size = 15) +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.background = element_rect(fill = "#F8F8F8", colour = NA),
    strip.background = element_rect(fill = "#F8F8F8", colour = NA),
  )  + 
  ggsave("img/confirmados_latam.svg", width = 20, height = 21, limitsize = F)


# preparación de base: confirmados
df_mundo %>%
  filter(
    base == "fallecidos",
    pais_region %in% codigos$pais_region
  ) %>% 
  left_join(., codigos) %>% 
  group_by(pais_region, semana) %>% 
  mutate(n = n()) %>% 
  filter(n >= 6) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(
    ., casos = sum(incidencia),
    ult_semana = pull(., incidencia) %>% last)) %>% 
  bind_rows() %>% 
  group_by(pais_region, semana) %>% 
  mutate(
    ult_semana = sum(incidencia)
  ) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(., 
                 ult_semana = pull(., ult_semana) %>% last
  )) %>% 
  bind_rows() %>% 
  ungroup() %>% 
  mutate(
    titulo = paste0(pais_nombre_corto, ", ", casos, " fallecidos", "\n", total_semanas,  
                    " semanas desde fallecido 0", "\n", " Nuevos fallecidos última semana:", ult_semana)
  ) -> temp


temp %>% 
  dplyr::select(pais_region, casos) %>% 
  unique() %>% 
  arrange(casos) %>% 
  mutate(num = 1:nrow(.)) -> temp_1

# grafico incidencia fallecidos
temp %>% 
  group_by(titulo, pais_region, semana) %>% 
  summarise(incidencia = sum(incidencia)) %>% 
  left_join(., temp_1) %>% 
  ggplot(aes(semana, incidencia, fill = continente)) + 
  geom_col(color = NA, alpha = 0.9, fill = "#09283C") + 
  facet_wrap(vars(fct_reorder(titulo, num, .desc = T)), scales = "free", ncol = 4) +
  hrbrthemes::theme_ipsum_rc(grid = F, base_family = "Source Code Pro Medium", strip_text_size = 15) +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.background = element_rect(fill = "#F8F8F8", colour = NA),
    strip.background = element_rect(fill = "#F8F8F8", colour = NA),
  )  + 
  ggsave("img/fallecidos_latam.svg", width = 20, height = 21, limitsize = F)



#------------------------------------
# streamgraph de confirmados
#------------------------------------
df_mundo %>%
  filter(
    base == "confirmados",
    pais_region %in% codigos$pais_region
  ) %>% 
  left_join(codigos, .) %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(
    ., casos = sum(incidencia),
    ult_semana = pull(., incidencia) %>% last)) %>% 
  bind_rows() %>% 
  group_by(pais_region, semana) %>% 
  mutate(
    ult_semana = sum(incidencia)
  ) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(., 
                 ult_semana = pull(., ult_semana) %>% last
  )) %>% 
  bind_rows() %>% 
  ungroup() -> temp

# cambio de lenguage en fechas
lang <- getOption("highcharter.lang")
lang$months <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", 
                 "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre")

lang$shortMonths <- c("En", "Feb", "Mar", "Abr", "Mayo", "Jun", 
                 "Jul", "Ag", "Sep", "Oct", "Nov", "Dic")

lang$weekdays <- c("Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", 
                      "Sábado", "Domingo")

options(highcharter.lang = lang)

# prevalencia latam confirmados
hchart(temp, "streamgraph", hcaes(fecha, casos_acumulados, group = pais_nombre_corto),
       label = list(
         enabled = TRUE, minFontSize = 10, maxFontSize = 20,
         style = list(
           fontWeight = 100,
           textOutline = "1px gray",
           color = hex_to_rgba("white", 0.9)
         )
       )
     ) %>% 
  hc_tooltip(shared = T, table = T, sort = T, borderWidth = 0.01) %>% 
  hc_yAxis(visible = F) %>% 
  hc_xAxis(title = list(text = "")) %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    series = list(
      marker = list(radius = 3, enabled = FALSE, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_legend(
    align = "right",
    verticalAlign = "top",
    layout = "vertical",
    itemMarginBottom = 10,
    x = -1,
    y = 105
  ) %>% 
  htmlwidgets::saveWidget(here::here("img/prevalencia_confirmados_latam.html"))
  
# incidencia latam
hchart(temp, "streamgraph", hcaes(fecha, incidencia, group = pais_nombre_corto),
       label = list(
         enabled = TRUE, minFontSize = 10, maxFontSize = 20,
         style = list(
           fontWeight = 100,
           textOutline = "1px gray",
           color = hex_to_rgba("white", 0.9)
         )
       )
) %>% 
  hc_tooltip(shared = T, table = T, sort = T, outside = T, borderWidth = 0.01) %>% 
  hc_yAxis(visible = F) %>% 
  hc_xAxis(title = list(text = "")) %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    series = list(
      marker = list(radius = 3, enabled = FALSE, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_legend(
    align = "right",
    verticalAlign = "top",
    layout = "vertical",
    itemMarginBottom = 10,
    x = -1,
    y = 105
  ) %>% 
  htmlwidgets::saveWidget(here::here("img/incidencia_confirmados_latam.html"))


# streamgraph de fallecidos
df_mundo %>%
  filter(
    base == "fallecidos",
    pais_region %in% codigos$pais_region
  ) %>% 
  left_join(codigos, .) %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(
    ., casos = sum(incidencia),
    ult_semana = pull(., incidencia) %>% last)) %>% 
  bind_rows() %>% 
  group_by(pais_region, semana) %>% 
  mutate(
    ult_semana = sum(incidencia)
  ) %>% 
  ungroup() %>% 
  group_split(pais_region) %>% 
  map(., ~mutate(., 
                 ult_semana = pull(., ult_semana) %>% last
  )) %>% 
  bind_rows() %>% 
  ungroup() -> temp

# cambiar colores para diferenciar de confirmados: paleta 
show_palette("pegasi")[[1]] # orden manuel de esta paleta

colores <- c("#698E7C", "#552F31", "#EE5D36", "#EFCF40", "#DC363B", "#315886", "#552F31", "#EFCF40", "#CBB193",
             "#698E7C", "#DC363B", "#EE5D36", "#315886", "#2B2D2D", "#EE5D36", "#DC363B", "#EFCF40", "#2B2D2D",
             "#552F31", "#CBB193")

# prevalencia latam confirmados
hchart(temp, "streamgraph", hcaes(fecha, casos_acumulados, group = pais_nombre_corto),
       label = list(
         enabled = TRUE, minFontSize = 10, maxFontSize = 20,
         style = list(
           fontWeight = 100,
           textOutline = "1px gray",
           color = hex_to_rgba("white", 0.9)
         )
       )
) %>% 
  hc_tooltip(shared = T, table = T, sort = T, borderWidth = 0.01) %>% 
  hc_yAxis(visible = F) %>% 
  hc_xAxis(title = list(text = "")) %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    series = list(
      marker = list(radius = 3, enabled = FALSE, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_colors(colores) %>% 
  hc_legend(
    align = "right",
    verticalAlign = "top",
    layout = "vertical",
    itemMarginBottom = 10,
    x = -1,
    y = 105
  ) %>% 
  htmlwidgets::saveWidget(here::here("img/prevalencia_fallecidos_latam.html"))

# incidencia latam
hchart(temp, "streamgraph", hcaes(fecha, incidencia, group = pais_nombre_corto),
       label = list(
         enabled = TRUE, minFontSize = 10, maxFontSize = 20,
         style = list(
           fontWeight = 100,
           textOutline = "1px gray",
           color = hex_to_rgba("white", 0.9)
         )
       )
) %>% 
  hc_tooltip(shared = T, table = T, sort = T, outside = T, borderWidth = 0.01) %>% 
  hc_yAxis(visible = F) %>% 
  hc_xAxis(title = list(text = "")) %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    series = list(
      marker = list(radius = 3, enabled = FALSE, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_colors(colores) %>% 
  hc_legend(
    align = "right",
    verticalAlign = "top",
    layout = "vertical",
    itemMarginBottom = 10,
    x = -1,
    y = 105
  ) %>% 
  htmlwidgets::saveWidget(here::here("img/incidencia_fallecidos_latam.html"))

#----------------------------------
# Rt
#----------------------------------
df_mundo %>% 
  filter(pais_region %in% codigos$pais_region) %>% 
  filter(base == "confirmados") -> temp


# partir bases para aplicar funciones
temp %>% 
  group_split(base, pais_region) -> temp_latam

# aplicar funciones: epistim_intervalo_1 == ICL
furrr::future_map(temp_latam, epistim_intervalo_1, .progress = T) %>% bind_rows() -> estim_1_latam

estim_1_latam %>% 
  group_split(`País o Región`) %>% 
  map(., ~arrange(., `Día de cierre`)) %>% 
  map(., ~slice(., nrow(.))) %>% 
  bind_rows() %>% 
  arrange(Promedio) %>% 
  clean_names() -> aa

codigos %>% 
  dplyr::select(pais_o_region = pais_region, pais_nombre_corto) %>% 
  left_join(aa, .) -> aa

# grafico rt para confirmados
highchart() %>% 
  hc_add_series(data = aa, type = "errorbar",
                hcaes(x = pais_o_region, low = limite_inferior, high = limite_superior),
                color = "#CB1724",  id = "error",
                stemWidth = 3,  whiskerLength = 0) %>% 
  hc_add_series(data = aa, "scatter", hcaes(x = pais_o_region, y = promedio), 
                color = "#CB1724", name = "Rt", linkedTo = "error") %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    scatter = list(
      marker = list(radius = 5, enabled = T, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_xAxis(title = list(text = ""), 
           categories = aa$pais_nombre_corto) %>% 
  hc_yAxis(title = list(text = "Rt"), min = 0, 
           plotLines = list(
             list(label = list(text = "Objetivo"),
                  color = "#09283C",
                  width = 2,
                  value = 1))) %>% 
  hc_tooltip(enabled = T, valueDecimals = 3, borderWidth = 0.01,
             pointFormat=paste("<b>{point.pais_nombre_corto}</b><br>
                               Rt última semana: <b>{point.promedio}</b><br>
                               Límite superior: <b>{point.limite_superior}</b><br>
                               Límite inferior: <b>{point.limite_inferior}</b><br>
                               Día de inicio de medición: <b>{point.dia_de_inicio}</b><br>
                               Día de cierre de medición: <b>{point.dia_de_cierre}</b><br>"), 
             headerFormat = "<b>{point.pais_o_region}</b>") %>% 
  htmlwidgets::saveWidget(here::here("img/rt_latam_confirmados.html"))

# rt para fallecidos
df_mundo %>% 
  filter(pais_region %in% codigos$pais_region) %>% 
  filter(base == "fallecidos") -> temp

# partir bases para aplicar funciones
temp %>% 
  group_split(base, pais_region) -> temp_latam

# aplicar funciones: epistim_intervalo_1 == ICL
furrr::future_map(temp_latam, epistim_intervalo_1, .progress = T) %>% bind_rows() -> estim_1_latam

estim_1_latam %>% 
  group_split(`País o Región`) %>% 
  map(., ~arrange(., `Día de cierre`)) %>% 
  map(., ~slice(., nrow(.))) %>% 
  bind_rows() %>% 
  arrange(Promedio) %>% 
  clean_names() -> aa

codigos %>% 
  dplyr::select(pais_o_region = pais_region, pais_nombre_corto) %>% 
  left_join(aa, .) -> aa

# grafico rt fallecidos
highchart() %>% 
  hc_add_series(data = aa, type = "errorbar",
                hcaes(x = pais_o_region, low = limite_inferior, high = limite_superior),
                color = "#09283C",  id = "error",
                stemWidth = 3,  whiskerLength = 0) %>% 
  hc_add_series(data = aa, "scatter", hcaes(x = pais_o_region, y = promedio), 
                color = "#09283C", name = "Rt", linkedTo = "error") %>% 
  hc_chart(style = list(fontFamily = "Source Code Pro")) %>% 
  hc_plotOptions(
    scatter = list(
      marker = list(radius = 5, enabled = T, symbol = "circle"),
      states = list(hover = list(halo = list(size = 1)))
    )
  ) %>% 
  hc_xAxis(title = list(text = ""), 
           categories = aa$pais_nombre_corto) %>% 
  hc_yAxis(title = list(text = "Rt"), min = 0, 
           plotLines = list(
             list(label = list(text = "Objetivo"),
                  color = "#CB1724",
                  width = 2,
                  value = 1))) %>% 
  hc_tooltip(enabled = T, valueDecimals = 3, borderWidth = 0.01,
             pointFormat=paste("<b>{point.pais_nombre_corto}</b><br>
                               Rt última semana: <b>{point.promedio}</b><br>
                               Límite superior: <b>{point.limite_superior}</b><br>
                               Límite inferior: <b>{point.limite_inferior}</b><br>
                               Día de inicio de medición: <b>{point.dia_de_inicio}</b><br>
                               Día de cierre de medición: <b>{point.dia_de_cierre}</b><br>"), 
             headerFormat = "<b>{point.pais_o_region}</b>") %>% 
  htmlwidgets::saveWidget(here::here("img/rt_latam_fallecidos.html"))

# serie de tiempo de Rt
df_mundo %>% 
  filter(pais_region %in% codigos$pais_region) -> temp 

# partir bases para aplicar funciones
temp %>% 
  group_split(base, pais_region) -> temp_latam

# aplicar funciones: epistim_intervalo_1 == ICL
furrr::future_map(temp_latam, epistim_intervalo_1, .progress = T) %>% bind_rows() -> estim_1_latam

codigos %>% 
  dplyr::select(`País o Región` = pais_region, pais_nombre_corto) %>% 
  left_join(estim_1_latam, .) %>% 
  clean_names() %>% 
  group_split(pais_nombre_corto) -> estim_1_latam

# graficar
map(estim_1_latam, rt_tiempo) -> graficos

map(estim_1_latam, "pais_nombre_corto") %>% 
  unlist() %>% 
  unique() %>% 
  tolower() -> nombres

nombres %<>% gsub("é", "e", .)
nombres %<>% gsub("ú", "u", .)
nombres %<>% gsub("í", "i", .)
nombres %<>% gsub("á", "a", .)
nombres %<>% gsub(" ", "_", .)

nombres <- paste0(nombres, ".html")

directorio <- here::here()
directorio <- paste0(directorio, "/")

for(i in 1:length(graficos)) {
  htmlwidgets::saveWidget(widget = graficos[[i]], here::here("img", nombres[i]))
}

