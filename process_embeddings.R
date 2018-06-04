# one-time code for processing the embeddings derived from the VGG-16
# pre-trained CNN and cross-referencing them against the image and website urls
# scraped from the Rijskmuseum API.
#
# The resulting .RData file is the core data file used by the applciation.

library(tidyverse)
library(DBI)

db <- dbConnect(RSQLite::SQLite(), "../imgsim/data/embeddings.db.sqlite")
raw_embeddings <- tbl(db, "embeddings") %>% collect()
dbDisconnect(db)

rkmo <- read_csv("../imgsim/data/rkm_urls.csv", col_names = c("id", "date_early", "date_late", "url"))


rkm_objects <- rkmo %>%
  na.omit() %>%
  mutate(
    url = str_replace(url, "http:", "https:"),
    stripped_id = str_replace(id, "^nl-", ""),
    filename = str_c(stripped_id, "jpeg", sep = "."),
    object_url = str_c("https://www.rijksmuseum.nl/en/search?q=", stripped_id, sep = "")) %>%
  distinct(url, .keep_all = TRUE)

dbWriteTable(db, "rkm_objects", rkm_objects)
dbExecute(db, "create unique index filename_objects on rkm_objects(filename)")

rkm_paintings <- read_csv("../imgsim/data/rkm_paintings.csv", col_names = c("id")) %>%
  mutate(stripped_id = str_replace(id, "^nl-", ""),
         filename = str_c(stripped_id, "jpeg", sep = "."))

dbWriteTable(db, "rkm_paintings", rkm_paintings)
dbExecute(db, "create unique index filename_paintings on rkm_objects(filename)")

embeddings <- raw_embeddings %>%
  semi_join(rkm_objects, by = "filename") %>%
  column_to_rownames("filename") %>%
  as.matrix()
dim(embeddings)

available_objects <- rkm_objects %>%
  filter(filename %in% rownames(embeddings)) %>%
  mutate(is_painting = filename %in% rkm_paintings$filename) %>%
  select(filename, date_early, date_late, url, object_url, is_painting) %>%
  arrange(date_early)

# Reorder embeddings to sort by date
embeddings <- embeddings[available_objects$filename,]

save(embeddings, available_objects, file = "rkm_embeddings.RData", compress = "bzip2")
