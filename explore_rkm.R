# devtools::install_github("mdlincoln/pathway")
library(pathway)
library(stringr)
library(fs)

#load("rkm_embeddings.RData")

# Identify two indices to build a path between
collect_candidates <- function(em, obj) {
  p1 <- sample.int(nrow(obj), 1)
  # Find another object
  p2 <- sample(1:nrow(embeddings)[-p1], 1)

  get_nav_constraint(p1, p2)
}

# Determine constraints on that pathway
get_nav_constraint <- function(p1, p2) {
  cst <- c("any-unique" = 5,
          "chronological" = 5)

  choice <- sample(names(cst), size = 1, prob = cst)

  if (p1 > p2 & choice == "chronological") {
    list(
      p1 = p1,
      p2 = p2,
      nav = navigate_ordered_desc
    )
  } else if (p1 < p2 & choice == "chronological") {
    list(
      p1 = p1,
      p2 = p2,
      nav = navigate_ordered
    )
  } else {
    list(
      p1 = p1,
      p2 = p2,
      nav = navigate_unique
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

generate_tweet <- function(em, obj, n = 8) {
  candidates <- collect_candidates(em, obj)
  pth <- pathway(em, candidates$p1, candidates$p2, n, navigator = candidates$nav, verbose = TRUE)
  gif_path(pth, obj)
}

file_copy(generate_tweet(embeddings, available_objects), new_path = "path.gif", overwrite = TRUE)

