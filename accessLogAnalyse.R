# Lecture du fichier CSV 

FILE_DATE_FORMAT="[%d/%b/%Y:%H:%M:%S"
RENDER_DATE_FORMAT="%Y/%m/%d %H:%M:%S"
#DEFAULT_FILE_NAME="data/access_generic.log"
#DEFAULT_FILE_NAME="data/access_generic_extract.log"
DEFAULT_FILE_NAME="data/access_generic_extract_small.log"
INTERVAL_IN_SECONDS = 30 # 3600 !
URL_EXTRACT_SIZE=30
#QQQ Adapter la legende du graph en fonction de la valeur de l'interval
S_WIDTH=8
S_HEIGHT=8
B_WIDTH=16
B_HEIGHT=8
PERCENTILE_FOR_DISTRIBUTION=0.995
ERROR_PATTERN='(5..|404)'
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

CATEGORIES=list(
    "PAC"=".*\\.pac HTTP/",
    "Image"=".*\\.(png|jpg|jpeg|gif|ico) HTTP/",
    "JS"=".*\\.js HTTP/",
    "CSS"=".*\\.css HTTP/",
    "HTML"=".*\\.html HTTP/"
  )
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
if (!file.exists("out")) dir.create("out")
access_log <- ReadLogFile(FILE_NAME)
head(access_log, 50)

#DISTRIBUTION
png("out/all_responsetime_distribution.png", width = WIDTH, height=HEIGHT)
print("Creating all_responsetime_distribution.png")
g = ggplot(access_log, aes(x = response.time_millis)) + 
  geom_density(colour = "black", fill = "darkgreen")  + xlab("Response time (milliseconds)") 
print(g)
dev.off()
max(access_log$response.time_microsec)

#DISTRIBUTION PAR TYPE
png("out/all_responsetime_distribution_by_type.png", width = WIDTH, height=HEIGHT)
print("Creating all_responsetime_distribution_by_type.png")
xmax = quantile(access_log$response.time_millis, c(PERCENTILE_FOR_DISTRIBUTION))
xmin = min(access_log$response.time_millis)
g = ggplot(access_log, aes(x = response.time_millis)) + 
  geom_density(aes(group=category, colour=category))  + 
  xlab(paste0("Response time (max=",max(access_log$response.time_millis),")")) +
  coord_cartesian(xlim=c(xmin, xmax))
print(g)
dev.off()

for (cat in CATEGORY_NAMES) {
  png(paste0("out/all_responsetime_distribution_by_type_", cat, ".png"), width = WIDTH, height=HEIGHT)
  print(paste0("Creating all_responsetime_distribution_by_type_", cat, ".png"))
  subdata = access_log[access_log$category==cat,]
  xmax = quantile(subdata$response.time_millis, c(PERCENTILE_FOR_DISTRIBUTION))
  xmin = min(subdata$response.time_millis)
  g = ggplot(subdata, aes(x = response.time_millis)) + 
    geom_density()  + xlab(paste0("Response time (max=",max(subdata$response.time_millis),")")) +
    coord_cartesian(xlim=c(xmin, xmax))
  print(g)
  dev.off()
}


#Temps de reponse global et un fichier par type : timeseries + smooth
png("out/response_time_by_time.png", width = WIDTH, height=HEIGHT)
print("Creating response_time_by_time.png")
g = ggplot(access_log, aes(ts)) + 
  xlab("Date") + ylab("response time (ms)") +
  geom_point(aes(y = response.time_millis), alpha=0.3) + 
  ggtitle("Response time evolution") +
  stat_smooth(data=access_log, aes(x=ts, y=response.time_millis), colour="red",method = "gam", formula = y ~ s(x, bs = "cs"))
#   scale_color_manual(values = c("actions_dossiers"="blue"))
print(g)
dev.off()

png("out/response_time_by_time_and_category.png", width = WIDTH, height=HEIGHT)
print("Creating response_time_by_time_and_category.png")
g = ggplot(access_log, aes(ts)) + 
  xlab("Date") + ylab("response time (ms)") +
  geom_point(aes(y = response.time_millis, color=category),alpha=0.3) + 
  ggtitle("Response time evolution by type") +
  stat_smooth(data=access_log, aes(x=ts, y=response.time_millis), colour="red",method = "gam", formula = y ~ s(x, bs = "cs"))
#   scale_color_manual(values = c("actions_dossiers"="blue"))
print(g)
dev.off()

for (cat in CATEGORY_NAMES) {
  png(paste0("out/response_time_by_time_and_", cat, ".png"), width = WIDTH, height=HEIGHT)
    print(paste0("Creating response_time_by_time_and_", cat, ".png"))
    subdata = access_log[access_log$category==cat ,]
    g = ggplot(subdata, aes(ts)) + 
      xlab("Date") + ylab("response time (ms)") +
      geom_point(aes(y = response.time_millis), alpha=0.3) + 
      ggtitle(paste0("Response time evolution for ", cat, " and HTTPCode=200")) +
      stat_smooth(data=subdata, aes(x=ts, y=response.time_millis), colour="red",method = "gam", formula = y ~ s(x, bs = "cs"))
    print(g)
  dev.off()
}

#TODO QQQ
#l'heure des requêtes les plus lentes 
# URL des 10 plus lentes,10 plus gros
# Les URLS des 10 plus fréquentes

