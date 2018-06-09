# one-time code for processing the embeddings derived from the VGG-16
# pre-trained CNN and cross-referencing them against the image and website urls
# scraped from the Rijskmuseum API.
#
# The resulting .RData file is the core data file used by the applciation.

library(tidyverse)
library(DBI)

db <- dbConnect(RSQLite::SQLite(), "data/embeddings.db.sqlite")
raw_embeddings <- tbl(db, "embeddings") %>% collect()
dbDisconnect()

rkmo <- read_csv("data/rkm_images.csv", col_names = c("id", "date_early", "date_late", "object_types", "url"))

rkm_objects_fixed <- rkmo %>%
  na.omit() %>%
  mutate(
    url = str_replace(url, "http:", "https:"),
    stripped_id = str_replace(id, "^nl-", ""),
    filename = str_c(stripped_id, "jpeg", sep = "."),
    object_url = str_c("https://www.rijksmuseum.nl/en/search?q=", stripped_id, sep = "")) %>%
  distinct(url, .keep_all = TRUE)

rkm_objects <- rkm_objects_fixed %>% select(-object_types)

rkm_object_types <- rkm_objects_fixed %>%
  select(filename, object_types) %>%
  separate_rows(object_types, sep = ";")

embeddings <- raw_embeddings %>%
  semi_join(rkm_objects, by = "filename") %>%
  column_to_rownames("filename") %>%
  as.matrix()
dim(embeddings)

available_objects <- rkm_objects %>%
  filter(filename %in% rownames(embeddings)) %>%
  select(filename, date_early, date_late, url, object_url) %>%
  arrange(date_early)

# Reorder embeddings to sort by date
embeddings <- embeddings[available_objects$filename,]

save(embeddings, available_objects, rkm_object_types, file = "rkm_embeddings.RData", compress = "bzip2")
