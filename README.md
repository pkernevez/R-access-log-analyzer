R-access-log-analyzer
=====================

Simple R script for accesslog analysis.

This script produce a quick analysis of your access log when you don't have a more sophisticated tool.
It is usefull to do analysis for performance analysis of the past.
This script is usefull for a one time or rare anlaysis done by ingeneer that have access on the plateform. 
If you want to do a daily analysis with a more friendly tool, you should look at solution like [Google Anlytics](http://analytics.google.com/) or [Piwik (Open Source).](http://piwik.org/).

## Supported format
Accept 2 accesslog format : 
* Default Apache accesslog format : "%h %l %u %t \"%r\" %>s %b"
* Same format with duration in microseconds (better to have duration report) : "%h %l %u %t \"%r\" %>s %b %D"
More information there : [Apache docs](http://httpd.apache.org/docs/2.2/logs.html#accesslog).

## Samples
You have example of report in the folder [Samples]
* [Simple short report with duration](Samples/)
* [Simple short report without duration](Samples/) :

## Install
Download zip in the folder [downloads](downloads) and unzip files.

## Configure
You may change parameters is the head of the sript [accessLogAnalyzer.R] :
```
FILE_DATE_FORMAT="[%d/%b/%Y:%H:%M:%S"                   # Use to parse accesslog
RENDER_DATE_FORMAT="%Y/%m/%d %H:%M:%S"                  # Date format for the report 
INTERVAL_IN_SECONDS = 3600                              # Interval use for computing throughput (ie groupby)
URL_EXTRACT_SIZE=40                                     # Size of URL extract for report
S_WIDTH=6                                               # Width of Small graphs (pies)
S_HEIGHT=6                                              # Height of Small graphs (pies)
B_WIDTH=11                                              # Width of Big graphs 
B_HEIGHT=7                                              # Height of Big graphs
PERCENTILE_FOR_DISTRIBUTION=0.995                       # Percentile use for cuting the distribution graph (due to extreme values)
ERROR_PATTERN='(5..|4.[^1])'                            # Pattern use to identifie HTTP Error, all 5xx and 4xx but 401.
CATEGORIES=list(                                        # Patterns use to define Categories (analysis axes)
  "PAC"=".*\\.pac HTTP/",
  "Image"=".*\\.(png|jpg|jpeg|gif|ico) HTTP/",
  "JS"=".*\\.js HTTP/",
  "CSS"=".*\\.css HTTP/",
  "HTML"=".*\\.html HTTP/"
)
```




## Run
Go to installation folder then run :
Rscript accessLogAnalyzer.R $PATH $FILE_PATTERN 

$PATH is optionnal.

Example :
- Rscript accessLogAnalyzer.R access.log
- Rscript accessLogAnalyzer.R /var/log/apache2 access_log
- Rscript accessLogAnalyzer.R /var/log/apache2 'access.*'

Some execution times 
* 33Mo log file with 269'909 lines, duration 10 hours sampled by minute => processing time = 1 min 20s
* 660Mo log file with 4'979'032 lines, duration 7 days sampled by hour => processing time = 20min
