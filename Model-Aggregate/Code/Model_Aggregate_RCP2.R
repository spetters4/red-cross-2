## This script generates the weighted indicator of "risk" to plot for each census tract that will be used for the map visualization.
## This data will be stored in /data/risk_tract.csv.


## libraries
library('data.table')
library('bit64') # per warning in data.table from model_1b output
library('readxl') 
library(RCurl)
library('UScensus2010')
library('UScensus2010tract') 
#install.tract("osx") # need to run this if running for first time

getwd()

#Load model outputs

dt1a_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/smoke-alarm-risk-scores_1a.csv') 
dt1a_prep2 <-read.csv(text=dt1a_prep1)
dt1a <- as.data.table(dt1a_prep2)

dt1b_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/tracts_74k_weighted_linear_preds_upsampled.csv')
dt1b_prep2 <-read.csv(text=dt1b_prep1, colClasses=c('tractid'='character'))
dt1b <- as.data.table(dt1b_prep2)

dt1c_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/smoke-alarm-risk-scores_1c.csv')
dt1c_prep2 <-read.csv(text=dt1c_prep1)
dt1c <- as.data.table(dt1c_prep2, colClasses=c('tractid'='character'))

dt2a_2009_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/2009_tract_building_fire_per_1k.csv')
dt2a_2009_prep2 <-read.csv(text=dt2a_2009_prep1)
dt2a_2009 <- as.data.table(dt2a_2009_prep2)

dt2a_2010_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/2010_tract_building_fire_per_1k.csv')
dt2a_2010_prep2 <-read.csv(text=dt2a_2010_prep1)
dt2a_2010 <- as.data.table(dt2a_2010_prep2)

dt2a_2011_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/2011_tract_building_fire_per_1k.csv')
dt2a_2011_prep2 <-read.csv(text=dt2a_2011_prep1)
dt2a_2011 <- as.data.table(dt2a_2011_prep2)

dt2a_2012_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/2012_tract_building_fire_per_1k.csv')
dt2a_2012_prep2 <-read.csv(text=dt2a_2012_prep1)
dt2a_2012 <- as.data.table(dt2a_2012_prep2)

dt2a_2013_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/2013_tract_building_fire_per_1k.csv')
dt2a_2013_prep2 <-read.csv(text=dt2a_2013_prep1)
dt2a_2013 <- as.data.table(dt2a_2013_prep2)


dt2c_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/fires_per_tract.csv')
dt2c_prep2 <-read.csv(text=dt2c_prep1, colClasses=c('x'='character'))
dt2c <- as.data.table(dt2c_prep2)


#Currently from old model 
dt3a_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-3A/phase1-results/results_tract.csv')
dt3a_prep2 <-read.csv(text=dt3a_prep1)
dt3a <- as.data.table(dt3a_prep2)


# functions used to normalize risk scores
normalize <- function(x) (x - min(x, na.rm=T)) / (max(x, na.rm=T)- min(x, na.rm=T))
balscale <- function(x, w_logit=0.75, w_normalized=0.25) plogis(scale(x))*w_logit + normalize(x)*w_normalized

#######################################
## Processing results from Model 1.A ##
#######################################

dt1a[, tract_geoid:=paste0(state, cnty, tract)]
dt1a[, risk_1a:=balscale(risk_1a)*100]

#######################################
## Processing results from Model 1.B ##
#######################################

setnames(dt1b, 'tractid', 'tract_geoid')
dt1b[nchar(tract_geoid)==10, tract_geoid:=paste0('0', tract_geoid)] # adding leading 0 to tract_geoid

# creating normalized risk score
dt1b[, risk_1b := balscale(weighted_linear_pred)*100]

#######################################
## Processing results from Model 1.C ##
#######################################

## separating out geographies. block from census tract
dt1c[,bg_geoid:=as.character(bg_geoid)]

dt1c[,state:=substr(bg_geoid, 1,2)]
dt1c[,cnty:=substr(bg_geoid, 3,5)]
dt1c[,tract:=substr(bg_geoid, 6,11)]
dt1c[,block:=substr(bg_geoid, 12,12)]

## calculating census tract-level risk.
dt1c_tract <- dt1c[,.(
  risk_1c=mean(smoke_alarm_risk)*100,
  blocks_per_tract=.N
), by=.(state, cnty, tract)]

dt1c_tract[,risk_1c := balscale(risk_1c)*100]

dt1c_tract[, tract_geoid:=paste0(state, cnty, tract)]


#######################################
## Processing results from Model 2.A ##
#######################################

dt2a <- merge(dt2a_2009[,.(tractid, id, N, population)], dt2a_2010[,.(tractid, N)], by='tractid', all=T, suffixes=c('_2009', '_2010'))
dt2a <- merge(dt2a, dt2a_2011[,.(tractid, N)], by='tractid', all=T)
dt2a <- merge(dt2a, dt2a_2012[,.(tractid, N)], by='tractid', all=T, suffixes=c('_2011', '_2012'))
dt2a <- merge(dt2a, dt2a_2013[,.(tractid, N)], by='tractid', all=T)
setnames(dt2a, 'N', 'N_2013')
setnames(dt2a, 'tractid', 'tract_geoid')
dt2a <- dt2a[, tract_geoid:=as.character(tract_geoid)]

## getting complete list of census tracts.  needed to fill in zeros
dt2a <- merge(dt2a, dt1c_tract[, .(tract_geoid, blocks_per_tract)], by='tract_geoid', all=T) 

## getting population per tract
dtpopL <- mapply(function(st) demographics(dem='P0010001', level='tract', state=st), st=c(state.abb, 'DC')) # 38 seconds
dtpop <- rbindlist(lapply(dtpopL, function(x) as.data.table(x, keep.rownames=T)))
setnames(dtpop, 'rn', 'tract_geoid')
rm(dtpopL) # cleanup
rm(list=grep('\\.tract10', ls(), value=T)) # clean up

# setting fire NAs to 0
for(y in paste0('N_', 2009:2013)) set(dt2a, i=dt2a[,which(is.na(get(y)))], j=y, value=0) 
dt2a[, N := N_2009 + N_2010 + N_2011 + N_2012 + N_2013] # total number of fires over 2009-2013

# filling in population where missing
dt2a <- merge(dt2a, dtpop, by='tract_geoid', all=T)
dt2a[is.na(population), population:=as.integer(P0010001)]
dt2a[is.na(population), population:=0]
dt2a[,firesPer1000:=N/(population+1)*1000] # stabilizing denominator
dt2a[population>200, risk_2a:=balscale(firesPer1000)*100] # risk metric.  subsetting by population > 200 is important to remove outliers from scaling.

rm(list=paste0('dt2a_', 2009:2013)) # cleaning up

#######################################
## Processing results from Model 2.C ##
#######################################

dt2c[, V1:=NULL]
setnames(dt2c, 'x', 'tract_geoid')

# correcting geoid by getting back leading 0s
dt2c[nchar(tract_geoid)=='10', tract_geoid:=paste0('0', tract_geoid)] 

## creating indicator for RC responses per 1000 people.
# downweghting tracts with smaller populations to stabilize ratio using log transform
dt2c <- merge(dt2c, dtpop, by='tract_geoid', all=T)
dt2c[is.na(freq), freq:=0]
dt2c[is.na(P0010001), P0010001:=0]
dt2c[,firesPer1000:=freq/(P0010001+100)*1000]

dt2c[,firesPer1000_scaled:=firesPer1000*log(P0010001+1)] # adjusting ratio by log of population 
dt2c[P0010001>200, risk_2c:=balscale(firesPer1000_scaled)*100]  # creating final risk metric

#######################################
## Processing results from Model 3.A ##
#######################################

# probabilities are low, so forcing normalization of scores to be between 0 and 1.  this could be improved later per feedback from ARC
dt3a[, risk_3a := balscale(risk_3a)*100]
setnames(dt3a, 'geoid', 'tract_geoid')
dt3a <- dt3a[, tract_geoid:=as.character(tract_geoid)]

#######################################
## AGGREGATING RESULTS ################
#######################################

# setting key for merge
setkey(dt1a, tract_geoid)
setkey(dt1b, tract_geoid)
setkey(dt1c_tract, tract_geoid)
setkey(dt2a, tract_geoid)
setkey(dt2c, tract_geoid)
setkey(dt3a, tract_geoid)

# merging risk scores together
dt <- merge(dt1a[,.(tract_geoid, risk_1a)], dt1b, all=T)
dt <- merge(dt, dt1c_tract[,.(tract_geoid, risk_1c, cnty, state, tract)], all=T)
dt <- merge(dt, dt2a[,.(tract_geoid, risk_2a)], all=T)
dt <- merge(dt, dt2c[,.(tract_geoid, risk_2c, P0010001)], all=T)
dt <- merge(dt, dt3a[,.(tract_geoid, risk_3a)], all=T)

# calculating aggregated risk score.  simple average now. will be built into function with ability to weight each indicator differently.
dt$risk <- rowMeans(dt[, .(risk_1a, risk_1b, risk_1c, risk_2a, risk_2c, risk_3a)], na.rm=T)

#Creating County Average 
dt[, risk_cnty:=mean(risk), by=.(state, cnty)]

#######################################
## MERGING ARC REGIONS ################
#######################################

####################################################################################################
# CODE ISSUES START HERE
###################################################################################################


# reading in crosswalk ARC region <=> FIPS data

reg_prep1 <- getURL('https://raw.githubusercontent.com/DataKind-DC/red-cross-2/master/Model-Aggregate/Inputs/Zip%20to%20ARC%20Geographies%20(as%20of%207.1.2018).csv') 
reg_prep2 <-read.csv(text=reg_prep1)
reg <- as.data.table(reg_prep2)
setnames(reg, names(reg), tolower(gsub(' ', '_', names(reg))))
setnames(reg, old="fips", new="county_fips")
reg <- reg[, county_fips:=as.character(county_fips)]

# deduping
reg <- reg[,head(.SD, 1), by='fips']




# cross-walking
dt[, county_fips:=substr(tract_geoid, 0, 5)]
dt <- merge(dt, reg[,.(county_fips, chap_code, chap_short_name, county_name)], by='county_fips', all.x=T, all.y=F)


#######################################
## WRITING OUT RESULTS ################
#######################################

dt[, risk1_agg := (risk_1a + risk_1b + risk_1c)/3]
dt[, risk2_agg := (risk_2a + risk_2c)/2]
dt[, risk3_agg := risk_3a]

write.table(dt[,.(state, cnty, tract, tract_geoid, risk_cnty, risk, risk_1a, risk_1b, risk_1c, risk_2a, risk_2c, risk_3a, risk1_agg, risk2_agg, risk3_agg)], file='risk_tract.csv', sep=',', row.names=F)
