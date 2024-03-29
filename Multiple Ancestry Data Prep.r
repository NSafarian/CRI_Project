#! usr/bin/env Rscript

## load the reuired packages
library(tidyverse)
library(data.table)
library(readr)
library(purrr)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## A) import data

#1. define path to data 
data_dir <- "~/path/to/summary_stats_data"
data_list <- list.files(path=data_dir,
                        pattern="*auto.gz",
                        full.names = F)

#2. define a read-select function
read.Fun <- function(data_dir, name){
  temp.dt1 <-  data.table::fread(data_dir)
  temp.dt2 <- temp.dt1%>% as.data.frame()
  temp.dt3 <- temp.dt2%>% dplyr::select(c("CHR","BP", "SNP", "OR", "P"))
  temp.dt4 <- temp.dt3%>% dplyr::rename(BETA="OR")
  return(temp.dt4)
}

#3. loop over the list 
for (i in 1:length(data_list)){
  names <- data_list[i]
  assign(names, read.Fun(data_list[i]))
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## B) pre-process

#keep common rsIDs between data frames and sort
#1. make a list of data frames
df.list <- list(PGC_AFR_auto.gz, PGC_EAS_auto.gz, PGC_EUR_auto.gz)

#2. Define common rsIDs 
commonIDs <- Reduce(intersect, Map("[[", df.list, "ID"))

#3. subset the list elements.
cID.df.list <- lapply(df.list, function(x) x[x$ID %in% commonIDs, ])

#4. order the list elements by chromosome number and position by column index
ord.df.list <- lapply(cID.df.list, function(x) x[order(x[,1], x[,3]), ])

#5. rename data frames in the list

new_names <- c("df.af", "df.as", "df.eu")

for (i in 1:length(ord.df.list)) {
  assign(new_names[i], ord.df.list[[i]])
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## C) create a combined data frame

df.sz = df.eu
df.sz$b.af =  df.af$BETA
df.sz$b.as =  df.as$BETA
df.sz$p.af =  df.af$P
df.sz$p.as =  df.as$P

#filter
df.sz.s = subset(df.sz,df.sz$P<= 1)  # check whether this is necessary 
df.sz.s = df.sz.s[which(substr(df.sz.s$ID ,1,2)=='rs'),]  # use only verified rs numbers, allowing comparing MAF in next steps (#5310784 rsID)

## creating working data frame
df.tot = as.data.frame(df.sz.s) #5310784 rsIDs

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## D) save the final file
write.table(df.tot, file = 'sumstats_cri.txt', sep = "\t")










