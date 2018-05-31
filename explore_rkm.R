library(tidyverse)
# Not yet published on CRAN - source available at https://github.com/mdlincoln/pathway
library(pathway)
library(DBI)

db <- dbConnect(RSQLite::SQLite(), "embeddings.db.sqlite")
raw_embeddings <- tbl(db, "embeddings") %>%
  collect()
db_disconnect(db)

rkmo <- read_csv("rkm_urls.csv", col_names = c("id", "url"))

rkm_objects <- rkmo %>%
  distinct(id, url) %>%
  na.omit() %>%
  mutate(
    stripped_id = str_replace(id, "^nl-", ""),
    filename = str_c(stripped_id, "jpeg", sep = "."),
    object_url = str_c("https://rijksmuseum.nl/en/collection", stripped_id, sep = "/"))


display_embed <- raw_embeddings %>% select(filename)

embeddings <- raw_embeddings %>%
  semi_join(rkm_objects, by = "filename") %>%
  column_to_rownames("filename") %>%
  as.matrix()
dim(embeddings)

available_objects <- rkm_objects %>%
  filter(filename %in% rownames(embeddings))

p1 <- sample.int(nrow(embeddings), 1)
p2 <- sample(1:nrow(embeddings)[-p1], 1)

pth <- pathway(embeddings, p1, p2, n = 8, verbose = TRUE)
fs::file_copy(gif_path(pth), "path.gif", overwrite = TRUE)

# From a given filename, pull up the proper url and download the content to a temporary file. Return the path of the temporary file.
pull_file <- function(filename) {
  url <- str_replace(rkm_objects[["url"]][which(rkm_objects$filename == filename)], "=s0", "=s600")
  localpath <- tempfile(fileext = ".jpeg")
  res <- download.file(url, localpath)
  if (res != 0)
    stop(filename, ": image download issue at ", url)
  return(localpath)
}

gif_path <- function(pth) {
  filenames <- rkm_objects$filename[pth$i]
  localpaths <- map_chr(filenames, pull_file)
  bound_paths <- str_c(localpaths, collapse = " ")
  rev_bound_paths <- str_c(rev(localpaths), collapse = " ")
  system(str_glue("mogrify -resize 500x500 -gravity center -background black -extent 500x500 {bound_paths}"))
  #system("convert -size 500x500 xc:black blank.jpeg")
  gifpath <- tempfile(fileext = ".gif")
  system(str_glue("convert -dispose previous -delay 125 -loop 0 {bound_paths} {rev_bound_paths} {gifpath}"))
  return(gifpath)
}


plot_pathway(embeddings, pth, pca = TRUE)


