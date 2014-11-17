# Lecture du fichier CSV 

DATE_FORMAT="[%d/%b/%Y:%H:%M:%S"
#DEFAULT_FILE_NAME="data/access_generic.log"
DEFAULT_FILE_NAME="data/access_generic_extract.log"
INTERVAL_IN_SECONDS = 3600 # 3600 !
#QQQ Adapter la legende du graph en fonction de la valeur de l'interval
WIDTH=800
HEIGHT=600
PERCENTILE_FOR_DISTRIBUTION=0.995
ERROR_PATTERN='(5..|404)'
print("Start")
cmd = commandArgs(trailingOnly = TRUE)
#if (length(cmd)>0) {
#  SLIDING_IN_MIN = as.numeric(cmd[1])  
#} else {
  FILE_NAME = DEFAULT_FILE_NAME
#}

load_and_install = function(lib){
  if(!lib %in% installed.packages()[,"Package"]) install.packages(lib)
  suppressPackageStartupMessages(library(lib,character.only=TRUE))
}
load_and_install("stringr")
load_and_install("ggplot2")
load_and_install("colorspace")
load_and_install("ascii")
load_and_install("knitr")
#library

CATEGORIES=list(
    "PAC"=".*\\.pac HTTP/",
    "Image"=".*\\.(png|jpg|jpeg|gif|ico) HTTP/",
    "JS"=".*\\.js HTTP/",
    "CSS"=".*\\.css HTTP/",
    "HTML"=".*\\.html HTTP/"
  )
CATEGORY_NAMES = c(names(CATEGORIES),"Other")

ReadLogFile <- function(file ) {
  # http://en.wikipedia.org/wiki/Common_Log_Format
  print("Loading file")
  access_log <- read.table(file, col.names = c("ip", "client", "user", "ts",
                                               "time_zone", "request", "status", "response.size", "response.time_microsec"))
  
  
  access_log$ts <- strptime(access_log$ts, format = DATE_FORMAT)
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
  print("File loaded")
  access_log
}
if (!file.exists("out")) dir.create("out")
access_log <- ReadLogFile(FILE_NAME)
head(access_log, 50)

png("out/all_request_per_hours.png", width = WIDTH, height=HEIGHT)
  print("Creating all_request_per_hours.png")
  g = ggplot(access_log, aes(x = ts)) + 
  #   geom_density( group="category",
  geom_density(stat = "bin", binwidth = INTERVAL_IN_SECONDS,
          colour = "black", fill = "darkgreen") + ylab("Requests/hour") + xlab("Time") 
#          stat_smooth(data=dataJourOuvre, aes(x= date, y=actions_dossiers), colour="red",method = "gam", formula = y ~ s(x, bs = "cs"))+
#scale_color_manual(values = c("actions_dossiers"="blue"))
  print(g)
dev.off()

png("out/all_request_per_hours_by_type.png", width = WIDTH, height=HEIGHT)
print("Creating all_request_per_hours_by_type.png")
#ggplot(access_log, aes(x = ts)) + geom_density(aes(fill=category,order=-as.numeric(category)), position="stack", size=2)
g = ggplot(access_log, aes(x = ts)) + 
  geom_density(stat = "bin", binwidth = INTERVAL_IN_SECONDS, position="stack", aes(fill = category, color=category, order=-as.numeric(category))) + 
     ylab("Requests/hour") + xlab("Time") 
print(g)
dev.off()

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

#Code retour
png("out/response_code.png", width = WIDTH, height=HEIGHT)
  print("Creating response_code.png")
  df <- as.data.frame(table(access_log$status))
  colnames(df) <- c('status','freq')
  g = ggplot(df, aes(x = "", y = freq, fill = status, color = status)) +
    geom_bar(width = 1, stat = "identity") +
    coord_polar("y", start = 0) +
    labs(title = "Répartition des codes retour HTTP") + xlab("")
  print(g)
dev.off()

#CODE D'erreur 5xx et 404 Camemberg
png("out/response_error.png", width = WIDTH, height=HEIGHT)
print("Creating response_error.png")
server.errors <- grep(ERROR_PATTERN,access_log$status)
g = ggplot(access_log[server.errors,], aes(x=status)) + geom_histogram(colour="black", fill="red") +
  labs(title = "Répartition des codes d'erreur HTTP")
print(g)
dev.off()

#HTTP Method Camemberg
png("out/http_method.png", width = WIDTH, height=HEIGHT)
print("Creating http_method.png")
df <- as.data.frame(table(access_log$method))
colnames(df) <- c('method','freq')
g = ggplot(df, aes(x = "", y = freq, fill = method, color = method)) +
  geom_bar(width = 1, stat = "identity") +
  coord_polar("y", start = 0) +
  labs(title = "HTTP Methods distribution") + xlab("")
  print(g)
dev.off()

#Code d'erreur en fonction du temps
png("out/response_error_by_time.png", width = WIDTH, height=HEIGHT)
print("Creating response_error_by_time.png")
g = ggplot(access_log[server.errors,], aes(x=ts)) +
  geom_density(stat='bin',binwidth=3600, position="stack") +
  aes(fill = status, color=status, order=-as.numeric(category)) +
  ylab('Errors/hour') + xlab('Time')
  print(g)
dev.off()

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

