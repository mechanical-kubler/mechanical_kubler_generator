# devtools::install_github("mdlincoln/pathway")
library(pathway)
library(stringr)
library(fs)
library(digest)
library(yaml)

#load("rkm_embeddings.RData")

# Decide start and end points
mark_pathway <- function(em, obj) {
  # Randomply pick between a path without any ordering, and a chronological path
  # that only goes forwards or backwards in time
  cst <- c("any-unique" = 0,
           "chronological" = 1)

  choice <- sample(names(cst), size = 1, prob = cst)

  # Based on the path ordering, dispatch different methods for picking p1 and p2
  marker <- switch(choice,
                 "any-unique" = mark_pathway_unique,
                 "chronological" = mark_pathway_chron)
  marker(em, obj)
}

# Picking p1 and p2 when there's no constraint
mark_pathway_unique <- function(em, obj) {
  p1 <- sample.int(nrow(obj), 1)
  # Find any other object that just isn't p1
  p2 <- sample(1:nrow(embeddings)[-p1], 1)

  list(
    p1 = p1,
    p2 = p2,
    nav = navigate_unique,
    type = "any-unique"
  )
}

# When chronologically constrained, make sure that p1 is either in the 25%
# earliest or latest objects, and that p2 is on the opposite end of the
# timeline, so that we have a comfortable search space.
mark_pathway_chron <- function(em, obj) {
  nobj <- nrow(obj)
  bins <- 10
  bottom_quartile <- 1:(nobj %/% bins)
  top_quartile <- (max(bottom_quartile) * (bins - 1)):nobj

  p1 <- sample(c(bottom_quartile, top_quartile), 1)

  if (p1 %in% bottom_quartile) {
    p2 <- sample(top_quartile, 1)
    list(
      p1 = p1,
      p2 = p2,
      nav = navigate_ordered,
      type = "chronological-forwards"
    )
  } else {
    p2 <- sample(bottom_quartile, 1)
    list(
      p1 = p1,
      p2 = p2,
      nav = navigate_ordered_desc,
      type = "chronological-backwards"
    )
  }
}

# From a given filename, pull up the proper url and download the content to a temporary file. Return the path of the temporary file.
pull_file <- function(filename, obj) {
  url <- str_replace(obj[["url"]][which(obj$filename == filename)], "=s0", "=s600")
  localpath <- file_temp(ext = ".jpeg")
  res <- download.file(url, localpath)
  if (res != 0)
    stop(filename, ": image download issue at ", url)
  return(localpath)
}

gif_path <- function(pth, obj) {
  filenames <- obj$filename[pth$i]
  localpaths <- vapply(filenames, pull_file, obj = obj, FUN.VALUE = character(1))
  bound_paths <- str_c(localpaths, collapse = " ")
  rev_bound_paths <- str_c(rev(localpaths), collapse = " ")

  system(str_glue("mogrify -resize 500x500 -gravity center -background black -extent 500x500 {bound_paths}"))
  gifpath <- file_temp(ext = ".gif")
  system(str_glue("convert -dispose previous -delay 125 -loop 0 {bound_paths} {rev_bound_paths} {gifpath}"))
  return(gifpath)
}

path_image <- function(em, pth) {
  path_path <- file_temp(ext = ".png")
  png(filename = path_path, width = 800, height = 600)
  plot_pathway(em, pth, pca = TRUE)
  dev.off()
  path_path
}

see <- function(path, viewer = getOption("viewer")) {
  viewer(path)
}

generate_tweet <- function(em, obj, n = 8) {
  candidates <- mark_pathway(em, obj)
  message(str_glue("p1: {candidates$p1}, p2: {candidates$p2}, nav: {candidates$type}"))
  pth <- pathway(em, candidates$p1, candidates$p2, n, navigator = candidates$nav, verbose = TRUE)
  gif_path <- gif_path(pth, obj)
  path_path <- path_image(em, pth)
  weblinks <- obj$object_url[pth$i]
  path_hash <- digest(weblinks)
  imglinks <- str_replace(obj[["url"]][pth$i], "=s0", "=s200")

  list(
    type = candidates$type,
    path_hash = path_hash,
    weblink = weblinks,
    imglinks = imglinks,
    gif_path = gif_path,
    path_path = path_path,
    date = as.character(Sys.time())
  )
}

path_data <- generate_tweet(embeddings, available_objects)

write_post <- function(path_data, basepath = "../rkm_pathways") {
  transposed_links <- mapply(function(x, y) list(weblink = x, imglink = y), path_data$weblink, path_data$imglinks, SIMPLIFY = FALSE, USE.NAMES = FALSE)

  frontmatter <- c(list(layout = "pathway", title = path_data$path_hash), path_data[c("type", "path_hash", "date")], list(objects = transposed_links))
  post_text <- str_c("---", as.yaml(frontmatter), "---", sep = "\n")
  post_path <- path(basepath, "_pathways", path_data$path_hash, ext = "md")
  writeLines(post_text, con = post_path)
  file_copy(path_data$path_path, path(basepath, "assets/images", path_data$path_hash, ext = "png"), overwrite = TRUE)
}

write_post(path_data)

walk(1:10, function(x) write_post(generate_tweet(embeddings, available_objects)))

