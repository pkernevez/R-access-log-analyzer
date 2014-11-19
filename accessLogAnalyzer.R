FILE_DATE_FORMAT="[%d/%b/%Y:%H:%M:%S"                   # Use to parse accesslog
RENDER_DATE_FORMAT="%Y/%m/%d %H:%M:%S"                  # Date format for the report 
#DEFAULT_FILE_NAME="data/access_generic.log"             # Default accesslog file (when no cmd line parameter)
#DEFAULT_FILE_NAME="data/access_generic_extract.log"
DEFAULT_FILE_NAME="data/access_generic_extract_small.log"
INTERVAL_IN_SECONDS = 3600 # 3600 !                     # Interval use for computing throughput
URL_EXTRACT_SIZE=40                                     # Size of URL extract for report
S_WIDTH=6                                               # Width of Small graphs (pies)
S_HEIGHT=6                                              # Width of Small graphs (pies)
B_WIDTH=11                                              # Width of Big graphs 
B_HEIGHT=7                                              # Width of Big graphs
PERCENTILE_FOR_DISTRIBUTION=0.995                       # Percentile use for cuting the distribution graph (due to extreme values)
ERROR_PATTERN='(5..|404)'                               # Pattern use to identifie HTTP Error
CATEGORIES=list(                                        # Patterns use to define Categories
  "PAC"=".*\\.pac HTTP/",
  "Image"=".*\\.(png|jpg|jpeg|gif|ico) HTTP/",
  "JS"=".*\\.js HTTP/",
  "CSS"=".*\\.css HTTP/",
  "HTML"=".*\\.html HTTP/"
)


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
load_and_install("data.table")

log <- function(data, ..., sep=""){
  write(paste(data, ..., sep=sep), stderr())
}

# Lecture du fichier CSV 

print("Start")
cmd = commandArgs(trailingOnly = TRUE)
#if (length(cmd)>0) {
#  SLIDING_IN_MIN = as.numeric(cmd[1])  
#} else {
FILE_NAME = DEFAULT_FILE_NAME
#}

if (INTERVAL_IN_SECONDS>=3600) {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS/3600,2), "hour(s)")
} else if (INTERVAL_IN_SECONDS>=60) {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS/60,2), "minute(s)")
} else {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS,2), "second(s)")
}

CATEGORY_NAMES = c(names(CATEGORIES),"Other")

extract = function(url){
  urlChar = as.character(url)
  if (nchar(urlChar)>URL_EXTRACT_SIZE) {
    return(paste0(substr(urlChar, 1, URL_EXTRACT_SIZE), "..."))
  } else {
    return(urlChar)
  }
}

cleanStr = function(str){
  str = gsub("\\\\", "&#92;", str)
  str = gsub("\\|", "&#124;", str)
  return(str)
}

ReadLogFile <- function(file ) {
  # http://en.wikipedia.org/wiki/Common_Log_Format
  print("Loading file")
  access_log <- read.table(file, col.names = c("ip", "client", "user", "ts",
                                               "time_zone", "request", "status", "response.size", "response.time_microsec"))
  
  
  access_log$ts <- strptime(access_log$ts, format = FILE_DATE_FORMAT)
  access_log$time_zone <- as.factor(sub("\\]", "", access_log$time_zone))
  access_log$status <- as.factor(sub("\\]", "", access_log$status))
  print("Create category")
  access_log$response.time_millis = round(access_log$response.time_microsec/1000)
  access_log$category="Other"
  access_log$method = str_match(access_log$request, "^([A-Za-z]+)")[,1]
  
  for (i in 1:length( CATEGORIES)){
    pattern = CATEGORIES[[i]]
    name = names(CATEGORIES)[i]
    access_log[ with( access_log, grepl(pattern, request)), "category"] = name
  }
  access_log$category = factor(access_log$category, levels=CATEGORY_NAMES)
  access_log$url_extract = sapply(access_log$request, extract)
  print("File loaded")
  access_log
}

analyseDistribution = function(allData, distrib) {
  displ = data.frame(matrix(NA,ncol=9,nrow=length(distrib)+1))
  names(displ)=c("Category", "Number of Requests", "%age", names(distrib[[1]][[2]]))
  displ[nrow(displ),] = c("All requests", 0, 0, summary(allData))
  total=0
  for (i in 1:length(distrib)) {
    displ[i,"Category"] = names(distrib)[[i]]
    info = distrib[[i]]
    displ[i,"Number of Requests"] = info[[1]]
    displ[i,4:9] = info[[2]]
    total = total + info[[1]]
  }
  displ[nrow(displ),"Number of Requests"]=total
  displ$'%age' = paste(round(as.numeric(displ$Number) / total * 100,1),"%")
  return(displ)
}


if (!file.exists("out")) dir.create("out")
access_log <- ReadLogFile(FILE_NAME)
str(access_log)

opts_knit$set(aliases=c(h = 'fig.height', w = 'fig.width'))
knit("analyseTemplate.Rmd", quiet = TRUE)
markdownToHTML("analyseTemplate.md","analyse.html", title="Access log analysis", stylesheet="analyse.css",  options=c(markdownHTMLOptions(defaults = TRUE), "toc"))
#rmarkdown::render("analyseTemplate.md")
#markdownExtensions()
#cat(markdownToHTML(text = "## Next Steps {:id ID}", options=c("")))

