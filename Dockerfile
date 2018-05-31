FROM rocker/tidyverse
CMD apt-get install imagemagick
CMD R -e 'install.packages("rtweet")
CMD R -e 'devtools::install_github("mdlincoln/pathway")
COPY embeddings.db.sqlite /root/tweet
COPY rkm_objects.csv /root/tweet
