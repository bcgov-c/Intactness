# Copyright 2017 Province of British Columbia
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

source("header.R")

library(dplyr)
library(ggplot2)
library(devtools)
library(tidyverse)
library(rgdal)
library(RColorBrewer)
library(gapminder)
library(gridExtra)
#library(pryr)
library(grid)
library(gridGraphics)
library(rasterVis)
library(igraph)

#Set/Read in provincial map
roadsSC <- raster(file.path(dataOutDir,"roadsSC.tif"), format="GTiff")
#Get ha of each grid cell based on cell size
areaIN<-res(roadsSC)[1]*res(roadsSC)[2]/10000 #e.g. for 200m grid 4 ha

#define some categorical variables and plotting labels based on distance breaks
#DistanceCls<-c(0,500,1000,2000,5000,1000000)
#Group 4 are the clumps
DistanceCls<-c(0,1,2,3,4)
#DistLbls<-c('0-500','500-1000','1000-2000','2000-5000','>5000')
DistLbls<-c('0-500','500-5000','>5000','Other')
CumLbls<-gsub(".*-","<",DistLbls)

#Set up a standard set of colours for graphs and maps
nclr<-length(DistLbls)
col_vec<-c(brewer.pal(nclr,"RdYlGn"))

## raster_by_poly with parallelization from Andy Teucher:
#Generate a list of rasters, one for each strata - Slow for entire Province
#strata to evaluate
#Strata <- bcmaps::ecosections(class = "sp") # from bcmaps
#SrataName <-"ECOSECTION_NAME"
Strata <- bcmaps::ecoregions(class = "sp") # from bcmaps
SrataName <-"ECOREGION_NAME"
#save strata as a shape for checking
#writeOGR(obj=Strata, dsn=dataOutDir, layer="Strata", driver="ESRI Shapefile") # this is in geographical projection

#Crop strata to raster extent
ClipS<-crop(Strata,roadsSC)

## raster_by_poly with parallelization from Andy Teucher:
#Generate a list of rasters, one for each strata - Slow for entire Province
rbyp_par <- raster_by_poly(roadsSC, ClipS, SrataName, parallel = TRUE)
rbyp_par<-c(roadsSC,rbyp_par)
rbyp_par_summary <- summarize_raster_list(rbyp_par)
names(rbyp_par_summary)[1]<-'Province'

#Check if there is data in strata, if none then drop strata from list
rbyp_par<-rbyp_par[lapply(rbyp_par_summary,length)>0]
rbyp_par_summary<-rbyp_par_summary[lapply(rbyp_par_summary,length)>0] 
#write out summaries for output routine
dir.create("tmp")
saveRDS(rbyp_par, file = "tmp/rbyp_par")
saveRDS(rbyp_par_summary, file = "tmp/rbyp_par_summary")

#clean up the workspace
gc()

#### FUNCTIONS
#A set of functions that will be called for displaying table, map and graphs

#Mapping function
RdClsMap<-function(dat, Lbl, MCol, title=""){
  ggplot(data=dat, aes(x=x,y=y))+
    geom_raster(aes(fill=factor(rdcls, labels=Lbl )), alpha=0.8) +
    ggtitle(title)+
    coord_equal()+ 
    scale_x_continuous(expand = c(0,0)) + 
    scale_y_continuous(expand = c(0,0)) +
    scale_fill_manual(values= MCol, 
                      name= "Distance Class",
                      guide = guide_legend(
                        direction = "horizontal",
                        keyheight = unit(2, units = "mm"),
                        keywidth = unit(70/length(labels), units = "mm"),
                        title.position = 'top',
                        title.hjust = 0.5,
                        label.hjust = 1,
                        nrow = 1,
                        byrow = T,
                        reverse = T,
                        label.position = "bottom"
                      )) +
    theme(
      #plot.title = element_text(size = 24, colour = "black"),
      axis.text=element_blank(),
      axis.title=element_blank(),
      # legend.position="right",
      #legend.key.height=unit(2,"line"),
      # legend.key=element_blank(),
      #legend.text=element_text(size = 24, colour = "black"),
      #legend.title=element_text(size = 24, colour = "black")
    )
}

#Graphing function - from the summarized data
plotCummulativeFn = function(data, Yvar, ScaleLabels, title){
  ggplot(data, aes(x = DistCls, y = Yvar, fill=DistCls)) +
    scale_fill_manual(values=col_vec) +
    geom_bar(stat="identity") +
    geom_text(label=paste(round(Yvar,2),'%',sep=''),  vjust = -0.25, size=3, alpha=0.8) +
    scale_x_discrete(label=ScaleLabels) +
    theme(legend.position="none") +
    theme(axis.text.x = element_text(face="bold", size=6),
          axis.text.y = element_text(face="bold", size=10)) +
  ylab("% Area") +
  xlab(title) }

###### END of FUNCTIONS

#Loop through each strata and generate a pdf of summary table, map and graphs
j<-1
for (j in 1:length(rbyp_par_summary)) {
  
  #map of strata - clip raster to strata extent and colour consistent with graphs
  Strata1<-rbyp_par[[j]]
  
  #get the name of the strata for plotting
  StrataName<-names(rbyp_par_summary[j])
  
  #Subset Provincial preprocessed distance map for plotting
  RdClsdf<-mask(roadsSC, Strata1)
  #Quick check on percent that is un-roaded
  #tt<-freq(RdClsdf)*areaIN
  #pSum<-sum(tt[,2])-tt[5,2]
  #round(tt[3,2]/pSum*100,2)
  
#Make a data frame of the strata info
  xDF<-data.frame(Distance=rbyp_par_summary[[j]],
            DistCls=cut(rbyp_par_summary[[j]], breaks = DistanceCls, labels=DistLbls),#, right=FALSE, include.lowest=TRUE),
             AreaHa=areaIN
            ) 

#Group by Distance Class 
  xDFGroup<-xDF %>%
    dplyr::select(DistCls, Distance, AreaHa) %>%
    group_by(DistCls)  %>%
    summarise(AreaHa=sum(AreaHa), Distance=sum(Distance))
#Calculate percent of area in each class 
  xDFGroup<-mutate(xDFGroup, pcDistCls=AreaHa/sum(AreaHa)*100)
#Calculate cummulative percent and area  
  nCases<-length(unique(xDF$DistCls))
  totArea<-sum(xDFGroup$AreaHa)
  distCumCls<-NULL
  areaCumCls<-NULL
  for (i in 1:nCases) {
    distCumCls<-c(distCumCls,(sum(xDF$Distance>DistanceCls[i]))/nrow(xDF)*100)
    areaCumCls<-c(areaCumCls,distCumCls[i]*totArea/100)
  }
#Merge all the data into a single data frame.  
  xDFGroup2<-cbind(xDFGroup,distCumCls,areaCumCls)
  
#Create a table object of the data frame
  tblIN<-data.frame(Distance=xDFGroup2$DistCls, pcDistance=round(xDFGroup2$pcDistCls,2), AreaDistance=round(xDFGroup2$AreaHa,2), pcCumDistance=round(xDFGroup2$distCumCls,2), AreaCumDistance=round(xDFGroup2$areaCumCls,2) )
  tt <- ttheme_default(colhead=list(fg_params = list(parse=TRUE)), padding=unit(c(1, 1), "mm"))
  tbl <- tableGrob(format(tblIN,big.mark=","), rows=NULL, theme=tt)
   
#Call graph function for distance and cummulative distance
  plotCumm<-plotCummulativeFn(xDFGroup2, xDFGroup2$distCumCls, CumLbls, 'Cumulative Distance Class')
  plotDist<-plotCummulativeFn(xDFGroup2, xDFGroup2$pcDistCls, DistLbls, 'Distance Class')

#Map of distances
  #Set variables for passing to the mapping function
  nUnique<-length(unique(RdClsdf))
  Lbl<-DistLbls[1:nUnique]
  MapCol<-col_vec[1:nUnique]
  
  #Change the raster to points for plotting at higher resolution
  PRdClsdf <- data.frame(rasterToPoints(RdClsdf))
  colnames(PRdClsdf) <- c('x', 'y', 'rdcls')

  plotMap<-RdClsMap(PRdClsdf,Lbl,MapCol, title=StrataName)
  
#write Strata to a pdf: table, map, distance and cummulative graphs
  pdf(file=file.path(figsOutDir,paste0(StrataName,"_Graphs.pdf")))
    lay <- rbind(c(1,1,2,2), c(1,1,2,2),c(3,3,3,3))
    #Alternatives to grid.arrange patchwork and cowplot
    grid.arrange(plotDist, plotCumm, tbl, layout_matrix=lay,top=names(rbyp_par_summary[j]))
    #+theme(plot.margin=unit(c(1,1,1,1), "cm"))
    dev.off()
   
    x_res=ncol(RdClsdf)
    y_res=nrow(RdClsdf)
    png(file=file.path(figsOutDir,paste0(StrataName,".png")),width=x_res,height=y_res)
    print(plotMap)
    dev.off()
}