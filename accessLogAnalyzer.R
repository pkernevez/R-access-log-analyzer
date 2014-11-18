load_and_install = function(lib){
  if(!lib %in% installed.packages()[,"Package"]) install.packages(lib)
  suppressPackageStartupMessages(library(lib,character.only=TRUE))
}
load_and_install("stringr")
load_and_install("ggplot2")
load_and_install("colorspace")
load_and_install("knitr")
load_and_install("markdown")
load_and_install("pander")

source("accessLogAnalyse.R")
log <- function(data, ..., sep=""){
  write(paste(data, ..., sep=sep), stderr())
}

opts_knit$set(aliases=c(h = 'fig.height', w = 'fig.width'))
knit("analyseTemplate.Rmd")
markdownToHTML("analyseTemplate.md","analyse.html", title="Access log analysis", stylesheet="analyse.css",  options=c(markdownHTMLOptions(defaults = TRUE), "toc"))
#rmarkdown::render("analyseTemplate.md")
#markdownExtensions()
#cat(markdownToHTML(text = "## Next Steps {:id ID}", options=c("")))


