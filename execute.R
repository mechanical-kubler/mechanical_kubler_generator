source("explore_rkm.R")

load("rkm_embeddings.RData")

git2r::config(global = TRUE, user.name = "Matthew Lincoln", user.email = "matthew.d.lincoln@gmail.com")

wait_time <- 20 * 60

repeat {
  pth <- generate_path(embeddings, available_objects, n = 8)
  write_post(pth)
  push_post()
  send_tweet(pth)

  Sys.sleep(time = wait_time)
}
