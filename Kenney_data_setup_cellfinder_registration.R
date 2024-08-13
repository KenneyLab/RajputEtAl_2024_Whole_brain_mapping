########################################################
# Setup script for combining cell finder and image registration data
########################################################

library(RNifti) #For reading in nii.gz file output from ANTS
library(stringr) #For string search
library(dplyr) #For bind_rows

#Custom function
cellfinder.to.registration <- function(fish.id, df.cell.class, dir.reg.images,
                                       x.downsample = 4.24, y.downsample = 4.24,
                                       z.downsample = 1.002){
  #Inputs:
  #fish.id: id number for subject, used to search cell class and reg image directories
  #df.cell.class: dataframe for the x,y,z coordinates for the cell classification (cellfinder output)
  #dir.reg.images: directory for registered segmentation images
  #x,y,z.downsample is the downsampling factor. THIS MUST BE CHANGED BASED ON IMAGE RESOLUTION (i.e., magnification)
  #the default values of 4.24, 4.24 and 1.002 are for 6.4x magnification. 
  
  #Output: list of two dataframes, [[1]] with the index for each cell from the cellfinder output and the fish.id 
  #[[2]], counts and volumes per brain region
  
  print(fish.id)
  
  #Use fish id to get registered image
  filename.img.registered <- paste(dir.reg.images, fish.id, '*.nii.gz',sep='')
  img.registered <- readNifti(Sys.glob(filename.img.registered))
  
  #Change orientation of image to RPI
  orientation(img.registered) <- 'RPI'

  #Get the index for each cell in the cellfinder dataframe
  df.cell.class$IDX <- apply(df.cell.class, 1, function(df) {img.registered[round(df['x']/x.downsample, digits=0),
                                                                            round(df['y']/y.downsample, digits=0),
                                                                            round(df['z']/z.downsample, digits=0)]})
  
  df.cell.class <- cbind(fish.id = fish.id, df.cell.class)
  
  #Get volume of each brain region
  df.volume <- table(img.registered) * (4^3)
  df.volume <- as.data.frame(df.volume)
  colnames(df.volume) <- c('IDX','volume(um^3)')
  
  #Get counts of cells per brain region
  df.counts <- table(df.cell.class$IDX)
  df.counts <- as.data.frame(df.counts)
  colnames(df.counts) <- c('IDX','num.cells')
  
  #Bring together volume and counts, add in fish id
  df.counts.volume <- merge(df.counts, df.volume)
  df.counts.volume <- cbind(fish.id = fish.id, df.counts.volume)
  
  return(list('all.cells' = df.cell.class, 'summary' = df.counts.volume))
}

#Set directory that the current file is in as the working directory
current_path = rstudioapi::getActiveDocumentContext()$path 
setwd(dirname(current_path ))


#Get cellfinder output filenames
l.cellfinder.filenames <- Sys.glob('../data/Cell_classification/*.csv')

#Extract fish.ids
l.fish.ids <- lapply(l.cellfinder.filenames, function(x) {str_extract(x, pattern='[0-9]+-[0-9]++[A-Z]')})

#Bring in cellfinder data
l.df.cell.class <- lapply(l.cellfinder.filenames, read.csv, colClasses='integer')

#Keep only cells (type == 2)
l.df.cell.class <- lapply(l.df.cell.class, function(x) {out <- subset(x, type==2); out})
#Get rid of 'X' column of the number (important, this MUST be a capital X)
l.df.cell.class <- lapply(l.df.cell.class, function(df) {out <- subset(df, select=-1); out})


#Generate list of dataframes that combine the cellfinder output with registration
l.df.cell.class <- mapply(function(fish.id, df) {cellfinder.to.registration(fish.id, df, dir.reg.images = '../Data/Registration/')},
                          l.fish.ids, l.df.cell.class, SIMPLIFY=FALSE)



#Pull out cell counts and volumes for downstream analysis
l.df.cell.counts <- lapply(l.df.cell.class, function(x) {x[['summary']]})
l.df.cell.counts <- lapply(l.df.cell.counts, function(x) {x$cell.density <- x$num.cells / x$`volume(um^3)`; x})


#Pull out individual cells only, good for double checking everything worked as expected
l.df.cell.class <- lapply(l.df.cell.class, function(x) {x[['all.cells']]})
names(l.df.cell.class) <- l.fish.ids

#Grab puncta vs cytoplasmic info and merge with cell info
l.df.punct.cyt <- lapply(l.df.cell.class, function(x) {out <- table(x$IDX, x$label); out})
l.df.punct.cyt <- lapply(l.df.punct.cyt, function(x) {out <- data.frame(IDX=rownames(x), puncta = x[,1], cyto = x[,2]); out})

l.df.cell.counts <- mapply(function(df1, df2) {out <- merge(df1, df2, by='IDX')}, l.df.cell.counts, l.df.punct.cyt, SIMPLIFY=FALSE)


#Add in region and ontology information
df.idx.ontology <- read.csv('../Data/AZBA_abbreviations_names_ontologies.csv')

l.df.cell.class <- lapply(l.df.cell.class, function(x) {merge(x,df.idx.ontology)})

l.df.cell.counts <- lapply(l.df.cell.counts, function(x) {merge(x, df.idx.ontology)})

df.cell.counts <- bind_rows(l.df.cell.counts)
df.cell.counts <- relocate(df.cell.counts, fish.id)

#Bring in info about groups
df.zfish.groups <- read.csv('../Data/TU_timecourse_zfish_database.csv')

df.cell.counts <- merge(df.cell.counts, df.zfish.groups)

saveRDS(df.cell.counts, 'Analysis_output/Kenney_df_cell_counts_per_region.RDS')
saveRDS(l.df.cell.class, 'Analysis_output/Kenney_l_df_individual_cell_region.RDS')



