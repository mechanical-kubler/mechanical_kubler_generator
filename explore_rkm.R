# devtools::install_github("mdlincoln/pathway")
library(pathway)
library(stringr)
library(fs)
library(digest)
library(yaml)
library(rtweet)
library(git2r)

# Decide start and end points
mark_pathway <- function(em, obj) {
  # Randomly pick between a path without any ordering, and a chronological path
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

# When chronologically constrained, make sure that p1 is either in the 10%
# earliest or latest objects, and that p2 is on the opposite end of the
# timeline, so that we have a comfortable search space when looking for real
# images near the ideal intermediate points.
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

# From a given filename, pull up the proper url and download the content to a
# temporary file. Return the path of the temporary file.
pull_file <- function(filename, obj) {
  url <- str_replace(obj[["url"]][which(obj$filename == filename)], "=s0", "=s600")
  localpath <- file_temp(ext = ".jpeg")
  res <- download.file(url, localpath)
  if (res != 0)
    stop(filename, ": image download issue at ", url)
  return(localpath)
}

# Given a path, download the images of each object to an intermediate file, then
# use imagemagick to produce a GIF looping through all of them. Save that gif to
# an intermediate file, and return the gif filepath
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

# Produce a plot with the first two dimensions of a PCA of the image embeddings,
# plotting the start & end points along with the intermediate path found by the
# nearest neighbor search.
path_image <- function(em, pth) {
  path_path <- file_temp(ext = ".png")
  png(filename = path_path, width = 800, height = 600)
  plot_pathway(em, pth, pca = TRUE)
  dev.off()
  path_path
}

# MasterTop-level function that generates a start and end point, calculates a
# path, and then builds a list with all the necessary data (including web image
# paths, object urls on the museum site, path of the PCA plot, and a uniquely
# identifying hash) to build a unique webpage for the calculation and then also
# send a tweet about it.
generate_path <- function(em, obj, n = 8) {
  candidates <- mark_pathway(em, obj)
  message(str_glue("p1: {candidates$p1}, p2: {candidates$p2}, nav: {candidates$type}"))
  pth <- pathway(em, candidates$p1, candidates$p2, n, navigator = candidates$nav, verbose = TRUE)
  gif_path <- gif_path(pth, obj)
  path_path <- path_image(em, pth)
  weblinks <- obj$object_url[pth$i]
  path_hash <- digest(weblinks)
  imglinks <- str_replace(obj[["url"]][pth$i], "=s0", "=s200")
  imgdates <- obj$date_early[pth$i]

  list(
    type = candidates$type,
    path_hash = path_hash,
    weblink = weblinks,
    imglinks = imglinks,
    gif_path = gif_path,
    path_path = path_path,
    imgdates = imgdates,
    date = as.character(Sys.time())
  )
}

# Assert the path of the Jekyll static site
jekyll_path <- function() "../mechanical_kubler"

# Produce a markdown document comprising one big YAML header with all the data
# from the calculated path. Copy this markdown along with the generated GIF and
# PCA plot into the adjacent directory where the GitHub pages site repo is
# located.
write_post <- function(path_data, basepath = jekyll_path()) {
  # Reshape the parallel lists into a nested list, which is easier to query in
  # the Jekyll templating language.
  transposed_links <- mapply(function(x, y, z) list(weblink = x, imglink = y, year = z), path_data$weblink, path_data$imglinks, path_data$imgdates, SIMPLIFY = FALSE, USE.NAMES = FALSE)

  frontmatter <- c(
    list(layout = "pathway", title = path_data$path_hash),
    path_data[c("type", "path_hash", "date")],
    list(objects = transposed_links))

  # Render the data list as YAML and write it as well as the images to the
  # Jekyll repository
  post_text <- str_c("---", as.yaml(frontmatter), "---", sep = "\n")
  post_path <- path(basepath, "_pathways", path_data$path_hash, ext = "md")

  writeLines(post_text, con = post_path)
  file_copy(path_data$path_path, path(basepath, "assets/images", path_data$path_hash, ext = "png"), overwrite = TRUE)
  file_copy(path_data$gif_path, path(basepath, "assets/images", path_data$path_hash, ext = "gif"))
}

# Code to authenticate the github personal access token (stored in an .Renviron
# file) thus giving this program push access to the GitHub Pages site
push_post <- function(repo_path = jekyll_path()) {
  r <- repository(repo_path)
  tok <- cred_token()
  pull(r, credentials = tok)
  add(r, ".")
  commit(r, "Commiting new path")
  push(r, credentials = tok)
}

# Compose the tweet, attach the gif, and send.
send_tweet <- function(path_data) {
  if (path_data$type == "chronological-forwards") {
    tmsg <- str_glue("A walk forwards through time between two objects @rijksmuseum, from {path_data$imgdates[1]} to {path_data$imgdates[2]}")
  } else if (path_data$type == "chronological-backwards") {
    tmsg <- str_glue("A walk backwards through time between two objects @rijksmuseum, from {path_data$imgdates[1]} to {path_data$imgdates[2]}")
  } else {
    tmsg <- "A unique walk between two objects @rijksmuseum"
  }

  post_tweet(
    status = str_glue("{tmsg}: https://mechanical-kubler.github.io/pathways/{path_data$path_hash}.html"),
    media = path_data$gif_path
  )
}
