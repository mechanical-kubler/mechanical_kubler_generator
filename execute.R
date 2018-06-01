library(git2r)
source("explore_rkm.R")

load("rkm_embeddings.RData")

# Configure git/github access for pushing HTML pages that will be linked to in tweets
config(global = TRUE, user.name = "Matthew Lincoln", user.email = "matthew.d.lincoln@gmail.com")
clone(url = "https://github.com/mechanical-kubler/rkm.git", jekyll_path())

# Tweet once an hour
wait_time <- 60 * 60

# Generate a path, make the post, push the post to GitHub Pages, tweet the gif,
# and then wait the appointed amount of time before doing it all again.
repeat {
  pth <- generate_path(embeddings, available_objects, n = 8)
  write_post(pth)
  push_post()
  send_tweet(pth)

  Sys.sleep(time = wait_time)
}
