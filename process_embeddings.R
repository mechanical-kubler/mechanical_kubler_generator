library(tidyverse)
library(DBI)

db <- dbConnect(RSQLite::SQLite(), "embeddings.db.sqlite")
raw_embeddings <- tbl(db, "embeddings") %>%
  collect()
db_disconnect(db)

rkmo <- read_csv("rkm_urls.csv", col_names = c("id", "date_early", "date_late", "url"))

rkm_objects <- rkmo %>%
  na.omit() %>%
  mutate(
    stripped_id = str_replace(id, "^nl-", ""),
    filename = str_c(stripped_id, "jpeg", sep = "."),
    object_url = str_c("https://www.rijksmuseum.nl/en/search?q=", stripped_id, sep = ""))


embeddings <- raw_embeddings %>%
  semi_join(rkm_objects, by = "filename") %>%
  column_to_rownames("filename") %>%
  as.matrix()
dim(embeddings)

available_objects <- rkm_objects %>%
  filter(filename %in% rownames(embeddings)) %>%
  arrange(date_early)

# Reorder embeddings to sort by date
embeddings <- embeddings[available_objects$filename,]

save(embeddings, available_objects, file = "rkm_embeddings.RData", compress = "xz")
