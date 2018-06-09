library(fs)
library(git2r)
source("explore_rkm.R")

load("rkm_embeddings.RData")

# Configure git/github access for pushing HTML pages that will be linked to in tweets
config(global = TRUE, user.name = "Matthew Lincoln", user.email = "matthew.d.lincoln@gmail.com")
if (!dir_exists(jekyll_path()))
  clone(url = "https://github.com/mechanical-kubler/rkm.git", jekyll_path())

# Tweet once an hour
wait_time <- 60 * 60

generate_set <- function(embeddings, available_objects, rkm_object_types) {
  scenarios <- c("all" = 3,
                 "paintings" = 2,
                 "nofoto" = 8)

  selected_scenario <- sample(names(scenarios), 1, prob = scenarios)

  if (selected_scenario == "all") {
    list(embeddings = embeddings, available_objects = available_objects, type = selected_scenario)
  } else if (selected_scenario == "paintings") {
    allowed_filenames <- unique(rkm_object_types$filename[which(rkm_object_types$object_types == "schilderij")])
    file_indices <- which(available_objects$filename %in% allowed_filenames)

    ao <- available_objects[file_indices,]
    em <- embeddings[file_indices,]
    list(embeddings = em, available_objects = ao, type = selected_scenario)
  } else if (selected_scenario == "nofoto") {
    allowed_filenames <- unique(rkm_object_types$filename[which(rkm_object_types$object_types != "foto")])

    file_indices <- which(available_objects$filename %in% allowed_filenames)

    ao <- available_objects[file_indices,]
    em <- embeddings[file_indices,]
    list(embeddings = em, available_objects = ao, type = selected_scenario)
  }
}

# Generate a path, make the post, push the post to GitHub Pages, tweet the gif,
# and then wait the appointed amount of time before doing it all again.
repeat {
  selected_data <- generate_set(embeddings, available_objects, rkm_object_types)

  pth <- generate_path(selected_data$embeddings, selected_data$available_objects, n = 8)
  write_post(pth)
  push_post()
  send_tweet(pth)

  Sys.sleep(time = wait_time)
}
