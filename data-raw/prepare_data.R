library(tidyverse)
library(jsonlite)

model_preds_files <- 
  list.files("data-raw/Data_and_Results", full.names = TRUE, recursive = TRUE)

model_preds_raw <-
  tibble(
    path = model_preds_files,
    contents = map(model_preds_files, fromJSON)
  )

model_preds <-
  model_preds_raw %>%
  filter(!grepl("data\\.json|name\\.json", path)) %>%
  rowwise() %>%
  mutate(contents = list(tibble(contents)),
         dir = gsub(basename(path), "", path)) 

model_metadata <-
  model_preds_raw %>%
  filter(grepl("name\\.json", path)) %>% 
  rowwise() %>%
  mutate(contents = list(enframe(contents))) %>% 
  unnest(contents) %>%
  mutate(value = unlist(value)) %>%
  pivot_wider(id_cols = path, names_from = name, values_from = value) %>%
  mutate(dir = gsub("name.json", "", path)) %>%
  select(-path)

model_input <-
  model_preds_raw %>%
  filter(grepl("data\\.json", path))

set.seed(2023)

detectors <- 
  full_join(model_preds, model_metadata, "dir") %>%
  mutate(contents = list(select(contents, document, score))) %>%
  unnest(contents) %>%
  mutate(detector = basename(path),
         detector = gsub(".json", "", detector),
         document_id = as.numeric(factor(document))) %>%
  mutate(prompt = case_when(
    grepl("CollegeEssay_gpt3_31", dir, fixed = TRUE) ~ "Plain",
    grepl("CollegeEssay_gpt3PromptEng_31", dir, fixed = TRUE) ~ "Elevate using literary",
    grepl("CS224N_gpt3_145", dir, fixed = TRUE) ~ "Plain",
    grepl("CS224N_gpt3PromptEng_145", dir, fixed = TRUE) ~ "Elevate using technical",
    grepl("HewlettStudentEssay_GPTsimplify_88", dir, fixed = TRUE) ~ "Simplify like non-native",
    grepl("TOEFL_gpt4polished_91", dir, fixed = TRUE) ~ "Enhance like native",
    .default = NA_character_
  )) %>%
  select(-document, -path, -dir) %>%
  rename(.pred_AI = score) %>%
  mutate(
    kind = if_else(kind == "Human-Written", "Human", "AI", NA_character_),
    .pred_class = if_else(.pred_AI > .5, "AI", "Human"),
    native = case_when(
      name %in% c("Real TOEFL") ~ "No",
      name %in% c("US 8th grade essay", "Real College Essays",
                  "Real CS224N") ~ "Yes",
      .default = NA_character_
    )
  ) %>%
  select(kind, .pred_AI, .pred_class, detector, native, everything()) %>%
  slice(sample(1:n()))

usethis::use_data(detectors, overwrite = TRUE)

