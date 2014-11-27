FILE_DATE_FORMAT="[%d/%b/%Y:%H:%M:%S"                   # Use to parse accesslog
RENDER_DATE_FORMAT="%Y/%m/%d %H:%M:%S"                  # Date format for the report 
#DEFAULT_FILE_NAME="data/access_generic.log"             # Default accesslog file (when no cmd line parameter)
DEFAULT_FILE_NAME="data/NASA_access_log_Jul95"
#DEFAULT_FILE_NAME="data/access_generic_extract_small.log"
INTERVAL_IN_SECONDS = 3600 # 3600 !                     # Interval used for computing throughput (ie groupby)
URL_EXTRACT_SIZE=60                                     # Size of URL extract for report
S_WIDTH=6                                               # Width of Small graphs (pies)
S_HEIGHT=6                                              # Height of Small graphs (pies)
B_WIDTH=11                                              # Width of Big graphs 
B_HEIGHT=7                                              # Height of Big graphs
PERCENTILE_FOR_DISTRIBUTION=0.995                       # Percentile used for cutting the distribution graph (due to extreme values)
ERROR_PATTERN='(5..|4.[^1])'                            # Pattern used to identify HTTP Errors, all 5xx and 4xx but 401.
  
#CATEGORIES=list(                                        # Patterns used to define Categories (analysis axes)
#   "Confluence"="[A-Z]+\ /confluence/.*",
#   "Archiva"="[A-Z]+\ /archiva/.*",
#   "Svn"="[A-Z]+\ /svn/.*",
#   "Daniela"="[A-Z]+\ /daniela/.*",
#   "Archirepo"="[A-Z]+\ /archirepo/.*",
#   "Nexus"="[A-Z]+\ /nexus/.*",
#   "MavenRepo"="[A-Z]+\ /mavenrepository/.*",
#   "Jira"="[A-Z]+\ /jira/.*"
# )
CATEGORIES=list(                                        # Patterns used to define Categories (analysis axes)
  "Image"=".*\\.(png|jpg|jpeg|gif|ico) HTTP/",
  "HTML"=".*\\.html HTTP/",
  "CGI"="GET /cgi"
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
if (length(cmd)>1) {
  PATH=cmd[1]
  FILE_NAMES = list.files(path=cmd[1], pattern = cmd[2], recursive=TRUE)
} else if(length(cmd) == 1) {
  PATH="."
  FILE_NAMES = list.files(pattern = cmd[1], recursive=TRUE)
} else {
  PATH="."
  FILE_NAMES = DEFAULT_FILE_NAME
}

if (length(FILE_NAMES)==0) {
  log("No file found with parameters")
} else {
  log("Files to load : ", FILE_NAMES)
}

if (INTERVAL_IN_SECONDS>=3600) {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS/3600,2), "hour(s)")
} else if (INTERVAL_IN_SECONDS>=60) {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS/60,2), "minute(s)")
} else {
  INTERVAL_AS_TEXT = paste(round(INTERVAL_IN_SECONDS,2), "second(s)")
}

CATEGORY_NAMES = c(names(CATEGORIES),"Other")

"%!in%" <- function(x,table) match(x,table, nomatch = 0) == 0

cleanStr = function(str){
  str = gsub("\\\\", "&#92;", str)
  str = gsub("\\|", "&#124;", str)
  str = gsub("<", "&#60;", str)
  str = gsub(">", "&#62;", str)
  return(str)
}

countToken <- function(char, s) {
  s = gsub('"[^"]*"',"X", s) 
  s2 <- gsub(char,"",s)
  return (nchar(s) - nchar(s2) + 1)
}

#countToken(" ", '10.8.254.101 - - [07/Sep/2011:03:10:02 +0200] "GET /ValidBigIpConnexion" 200 663 194477')
extract = function(url){
  urlChar = as.character(url)
  if (nchar(urlChar)>URL_EXTRACT_SIZE) {
    return(cleanStr(paste0(substr(urlChar, 1, URL_EXTRACT_SIZE), "...")))
  } else {
    return(cleanStr(urlChar))
  }
}

ReadLogFile <- function(file ) {
  # http://en.wikipedia.org/wiki/Common_Log_Format
  fullFileName = paste0(PATH, .Platform$file.sep, file)
  log("Loading file : ", fullFileName)
  titleLine <- readLines(fullFileName,n = 1)
  if (countToken(" ", titleLine) == 8){ # No duration
    log("Find 8 columns, add an empty duration to measure")
    access_log <- read.table(fullFileName, col.names = c("ip", "client", "user", "ts",
       "time_zone", "request", "status", "response.size"), comment.char="")
    access_log$response.time_microsec = 0
  } else {
    access_log <- read.table(fullFileName, col.names = c("ip", "client", "user", "ts",
       "time_zone", "request", "status", "response.size", "response.time_microsec"), comment.char="")
  }
  
  access_log$ts <- strptime(access_log$ts, format = FILE_DATE_FORMAT)
  access_log$time_zone <- as.factor(sub("\\]", "", access_log$time_zone))
  access_log$status <- as.factor(sub("\\]", "", access_log$status))
  access_log$response.size = suppressWarnings(as.numeric(as.character(access_log$response.size)))
  log("Create category")
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
  log("File loaded ( ", nrow(access_log), " rows )")
  return(access_log)
}

analyseDistribution = function(allData, distrib, label) {
  distrib[sapply(distrib, is.null)] <- NULL
  displ = data.frame(matrix(NA,ncol=9,nrow=length(distrib)+1))
  names(displ)=c("Category", label, "%age", names(distrib[[1]][[2]]))
  displ[nrow(displ),] = c("All requests", 0, 0, summary(allData))
  total=0
  for (i in 1:length(distrib)) {
    displ[i,"Category"] = names(distrib)[[i]]
    info = distrib[[i]]
    displ[i,label] = info[[1]]
    displ[i,4:9] = info[[2]]
    total = total + info[[1]]
  }
  displ[,label] = as.numeric(displ[,label])
  displ[nrow(displ),label]=total
  displ$'%age' = paste(round(displ[,label] / total * 100,1),"%")
  tmp_order = c(order(head(displ[,label],-1), decreasing = TRUE), nrow(displ))
  displ = displ[tmp_order,]
  rownames(displ) = NULL
  return(displ)
}
tmpAccess = lapply(FILE_NAMES, ReadLogFile)
access_log = Reduce(function(...) merge(..., all=T), tmpAccess)
rm(tmpAccess)
str(access_log)

opts_knit$set(aliases=c(h = 'fig.height', w = 'fig.width'))
knit("analyseTemplate.Rmd", quiet = TRUE)
markdownToHTML("analyseTemplate.md","analyse.html", title="Access log analysis", stylesheet="analyse.css",  options=c(markdownHTMLOptions(defaults = TRUE), "toc"))
#rmarkdown::render("analyseTemplate.md")
#markdownExtensions()
#cat(markdownToHTML(text = "## Next Steps {:id ID}", options=c("")))

