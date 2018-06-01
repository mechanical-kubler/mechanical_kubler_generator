FROM rocker/tidyverse
RUN apt-get -y install imagemagick
RUN R -e 'install.packages(c("rtweet", "fs", "yaml"))'
RUN R -e 'devtools::install_github("mdlincoln/pathway")'
COPY *.R rkm_embeddings.RData /home/rstudio/mechanical_kubler_generator/
WORKDIR /home/rstudio/mechanical_kubler_generator
CMD ["/usr/local/bin/R", "-f execute.R"]
