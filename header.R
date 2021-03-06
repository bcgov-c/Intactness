library(sf)
library(dplyr)
library(readr)
library(raster)
library(bcmaps)
library(fasterize)
require(SpaDES)
library(parallel)
library(doMC)

OutDir <- 'out'
dataOutDir <- file.path(OutDir,'data')
tileOutDir <- file.path(dataOutDir,'tile')
figsOutDir <- file.path(OutDir,'figures')
DataDir <- 'data'
dir.create(file.path(OutDir), showWarnings = FALSE)
dir.create(file.path(dataOutDir), showWarnings = FALSE)
dir.create(file.path(tileOutDir), showWarnings = FALSE)
dir.create(file.path(figsOutDir), showWarnings = FALSE)
dir.create(DataDir, showWarnings = FALSE)
dir.create("tmp", showWarnings = FALSE)

options("scipen"=100, "digits"=4)



