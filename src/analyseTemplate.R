load_and_install = function(lib){
  if(!lib %in% installed.packages()[,"Package"]) install.packages(lib)
  suppressPackageStartupMessages(library(lib,character.only=TRUE))
}
load_and_install("stringr")
load_and_install("ggplot2")
load_and_install("colorspace")
load_and_install("ascii")
load_and_install("knitr")
load_and_install("rmarkdown")

source("accessLogAnalyse.R")

rmarkdown::render("analyseTemplate.Rmd")
markdownToHTML