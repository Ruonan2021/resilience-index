# ---- Load ----
library(tidyverse)
library(sf)
library(geographr)

source("R/utils.R")

raw <-
  read_sf("data/on-disk/heat-hazard-raw/LSOA_England_Heat_Hazard_v1.shp")

# ---- Prep ----
lsoa_pop <-
  population_lsoa |>
  select(lsoa_code, total_population)

heat_hazard_raw <-
  raw |>
  st_drop_geometry() |>
  select(
    lsoa_code = LSOA11CD,
    mean_temp = mean_std_t
  ) |>
  filter(str_detect(lsoa_code, "^E"))

lookup_lsoa_lad <-
  lookup_lsoa_msoa |>
  select(ends_with("code")) |>
  filter(str_detect(lsoa_code, "^E")) |>
  left_join(lookup_msoa_lad) |>
  select(lsoa_code, lad_code)

# ---- Join ----
heat_hazard_raw_joined <-
  heat_hazard_raw |>
  left_join(lookup_lsoa_lad) |>
  relocate(lad_code, .after = lsoa_code) |>
  left_join(lsoa_pop) |>
  select(-lsoa_code)

# ---- Compute extent scores ----
extent <-
  heat_hazard_raw_joined |>
  calculate_extent_depreciated(
    var = mean_temp,
    higher_level_geography = lad_code,
    population = total_population
  )

# ---- Normalise, rank, & quantise ----
heat_hazard_quantiles <-
  extent |>
  normalise_indicators() |>
  mutate(rank = rank(extent)) |>
  mutate(quantiles = quantise(rank, 5)) |>
  select(lad_code, heat_hazard_quintiles = quantiles)

# ---- Save ----
heat_hazard_quantiles |>
write_rds("data/vulnerability/disasters-emergencies/england/heat-hazard.rds")