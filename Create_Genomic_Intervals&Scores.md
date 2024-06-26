#### title: Cumulative Regional Impact (CRI) Analysis Pipeline
###### Author: Nickie Safarian      
###### Date: 2023-07-12

## **Background**
Cumulative Regional Impact (CRI) presents a statistical methodology that proves useful interpreting WGS/WES data. Through CRI analysis, genomic intervals are delineated, accounting for overlaps if necessary, and the burden of single nucleotide polymorphisms (SNPs) per region/interval is quantified through zscores. Subsequently, correlations are performed to pinpoint groups of genomic regions exhibiting significant excess burden scores, alongside beta coefficients and other genomic annotations.
In this example, we use summary statistics from the Psychiatric Genomics Consortium (PGC) for schizophrenia, which were originally published in **2014**:*
*<pubMedIDlink: https://pubmed.ncbi.nlm.nih.gov/25056061; download link: https://doi.org/10.6084/m9.figshare.14672163>.* The provided step-by-step tutorial facilitates facilitates the execution of such analyses. While this method demands computational resources, it remains feasible to conduct locally on standard computers for the majority of summary statistics datasets.

### **1. How to run this example**

#### **1.1. Obtain the .Rmd file**
To run this example yourself, download the .Rmd for this analysis from the main branch. 
Make sure to move this .Rmd file from your download folder to where you would like this example and its files to be stored.

#### **1.2.Set up analysis folders**
Set up a folder structure to organize your data analysis.
```{r}
# Create the data folder if it doesn't exist
if (!dir.exists("data")) {
  dir.create("data")
}

# Define the file path to the plots directory
plots_dir <- "plots"

# Create the plots folder if it doesn't exist
if (!dir.exists(plots_dir)) {
  dir.create(plots_dir)
}

# Define the file path to the results directory
results_dir <- "results"

# Create the results folder if it doesn't exist
if (!dir.exists(results_dir)) {
  dir.create(results_dir)
}
```
In the same place you put this .Rmd file, you should now have three new empty folders called data, plots, and results!

#### **1.3. Download the summary statistics data**
```{r}
# Create a subfolder in the newly created **data** folder and named it **SCZ2014**.
# Now, put the downloaded summary stats in this subfolder. 
```

#### **1.4.  Define the file path to the data directory**
```{r]
# Replace with the path of the folder the files will be in
data_dir <- file.path("data", "SCZ2014")

# Declare the file path to the sum.stats file
# inside directory saved as `data_dir`
# Replace with the path to your dataset file
data_file <- file.path(data_dir, "daner_PGC_SCZ52_0513a.hq2.gz")
```

    
#### **1.5. Import and set up data**
```{r}
SCZ = readr::read_tsv(data_file)

# Select and rename columns (if necessary), and retain only valid rsIDs
SCZ.df = SCZ %>% as.data.frame()%>% 
  dplyr::select(c("CHR", "BP", "SNP", "OR", "P"))%>%
  dplyr::rename(c(BETA="OR"))%>%
  dplyr::filter(str_detect(SNP, 'rs'))

# Order by chromosome and position
data = SCZ.df[order(SCZ.df$CHR, SCZ.df$BP),]
```

### **2. Create genomic intervals (equal-in-size and overlapping)**
Note: here, the first and the last snp position per chromosome are set as start and end coordinates.
The length of segments (or the interval) is set to 1Mbp, the overlap is set at 50%. You may choose to work with different window and overlap sizes.

```{r}
# Initialize a list to store intVs for each group
intVs_list <- list()  

# Loop it over each chromosome
for (chr in unique(data$CHR)) {
  first <- min(data$BP[data$CHR == chr], na.rm = TRUE)
  last <- max(data$BP[data$CHR == chr], na.rm = TRUE)
  interval <- 1000000
  overlap <- 500000
  
  intVs <- c()  # Create an empty vector for the current group
  
  inc <- ceiling((last - first) / (interval - overlap))
  start <- first
  
  for (i in 1:inc) {
    end <- start + interval
    intV <- paste(start, end, sep = ':')
    
    intVs <- c(intVs, intV)
    start <- end - overlap
  }
  
  intVs_list[[chr]] <- intVs  # Store intVs for the current group in the list
}

# Convert the list of vectors to a list of data frames
coord_list <- lapply(intVs_list, function(vector) {
  split_vector <- strsplit(vector, ":")
  coord_df <- do.call(rbind, lapply(split_vector, function(x) data.frame(seg_start = x[1], seg_end = x[2])))
  return(coord_df)
})

# Rbind all data frames in the list with ID (index)
coord_df <- do.call(rbind, Map(cbind, index = seq_along(coord_list), coord_list))
table(coord_df$index) # check the indices match the chromosome number

# Save
write.table(coord_df, file = file.path("results",'coordinates_for_PGC_SCZ_2014_sumstats.txt', sep = "\t"))
                      
```
Now you have a data frame containing coorinates columns for start and end of arbiteray segments per chromosome.

### **3. Calculate Regional Burden Scores**                   
Here, the number of snps and the average beta values per region per chromosome is calculated. 
```{r}
# Create an empty data frame
result <- data.frame()

# Loop through conditions
for (chr in unique(data$CHR)){
  sub.dt <- subset(data, CHR==chr)
    sub.coord <- subset(coord_df, index==chr)
    for (j in 1:(nrow(sub.coord) -3)) {
      spot1 <- as.numeric(sub.coord[j, 2])  # Access value from dataset2
      spot2 <- as.numeric(sub.coord[j+3, 2])
      sub.dt_tmp <- sub.dt[which(sub.dt$BP>=spot1 & sub.dt$BP<spot2), ]
      if (nrow(sub.dt_tmp) >0){
        snp.counts <- length(sub.dt_tmp$BETA)
        sum.beta <- sum((sub.dt_tmp$BETA)) 
        Avg.beta <- sum((sub.dt_tmp$BETA))/length(sub.dt_tmp$BETA)
        start.pos <- min(sub.dt_tmp$BP)
        end.pos <- max(sub.dt_tmp$BP)
        stats <- data.frame(chr, start.pos, end.pos, snp.counts, sum.beta, Avg.beta)
        result <- rbind(result, stats)  
      }
    }
}

# Check the output
head(result)

# Save
write.csv("result", file = file.path("results", 'CRIResults_for_PGC_SCZ_2014_sumstats.txt', )
```
Next, we'll explore the cumulative regional impact of snps.

### **4. Explore the results**
The snp effect size, defined as the contribution of a SNP to the genetic variance of the trait, is measured as beta coefficient (beta). 
The higher the absolute value of the beta coefficient, the stronger the effect. 
Plotting beta values distribution can reveal any (left or right) skewness in the values, which propose 
Right skewed: The mean is greater than the median. The mean overestimates the most common values in a positively skewed distribution.

#### **4.1. Define functions**
```{r}
Quantil_Func <- function(x) {
  quantiles <- quantile(x, probs = seq(0, 1, 1/20)) 
  
  Iqr5_95 <- quantiles[20] - quantiles[2]
  Iqr25_75 <- quantiles[16] - quantiles[6]
  
  res <- c(quantiles, Iqr25_75, Iqr5_95)
  
  return(res)
}


HistPlot.Func <- function(x, Xlab, , Breaks){
  hist(x, probability = TRUE,
       breaks=Breaks,
       col="lightgrey",
       xlab = Xlab,
       ylab = 'Frequency',
       main = 'Quantiles Distribution')
  abline(v = mean(x), col='#2B0071', lwd = 3)
  lines(density(x), col = '#00416A', lwd = 3)
}

```

#### **4.2. Calculate quantiles and visualize**

```{r}
q_count <- Quantil_Func(result$snp.counts)
q_sum.beta <- Quantil_Func(result$sum.beta)
q_Avg.beta <- Quantil_Func(result$Avg.beta)

HistPlot.Func(q_count, Xlab="SNP Raw Counts", Breaks=100)
HistPlot.Func(q_sum.beta, Xlab="Beta Sum", Breaks=10)  
HistPlot.Func(q_Avg.beta, Xlab="Average Beta", Breaks=4)  
```

The areas with extremely high or low counts of snps could be representative of HLA regions and pre-centromeric areas, respectively. 
We can exclude those intervals from further analysis.

#### **4.3. Exclude ouliers (smallest 5% and biggest 5% counts)**

```{r}
filtr.dt <- result %>% 
  filter(snp.counts > quantile(snp.counts, 0.05) & snp.counts < quantile(snp.counts, 0.95)) 
```
Note that how many snps are removed.

#### **4.4. Calculate the counts zscore**

```{r}
filtr.dt  <- filtr.dt  %>% 
  mutate(ZCounts = as.numeric(scale(snp.counts)))
```

#### **4.5. plot**

```{r}
HistPlot.Func(filtr.dt$snp.counts, Xlab="SNP RAW Counts \n After Removing Outliers", Breaks=100)
HistPlot.Func(filtr.dt$ZCounts, Xlab="SNP Counts (scaled) \n After Filter", Breaks=10)
```

### **5. Regression Analysis**

#### **5.1. Do the snp counts coorelate with the average beta per interval?**

```{r}
library(broom)
library(knitr)

# Linear modeling
lm_df = filtr.dt%>%
  # each step performed after this line is done with each chromosome
  group_by(Chr) %>%
  # using the broom package to tidy the results 
  do(tidy(lm(Avg.beta ~ scale(snp.counts), data = .))) %>%
  # ungroup the data
  ungroup() %>%
  # adjust for multiple comparisons using the Benjamini-Hochberg method
  mutate(padj = p.adjust(`p.value`, method = 'BH')) %>%
  # clean up variable names 
  mutate(term = recode(term, 
                       `(Intercept)` = "Intercept", 
                       `scale(snp.counts)` = "SNP_ZCounts"))



# Print data frame for just age beta coefficients
kable(lm_df %>% filter(term == 'SNP_ZCounts'))

```
Check the direction of correlation for each chromosome.


#### **5.2. Plot the coefficient of correlation per chromosome**

```{r}

library(RColorBrewer)

beta_plot = lm_df %>% 
  filter(! term =="Intercept") %>% 
  ggplot(aes(x = chr, y=estimate)) + 
  geom_col()+ 
  ggtitle("Avergae Beta correlation with SNP counts") +
  ylab('Std. Beta coeff.') + 
  xlab('chromosome') + 
  theme(axis.text.x = element_text(size=10, 
                                   face='bold', 
                                   angle = 90, 
                                   vjust = 0.5, 
                                   hjust=1))+
  scale_x_continuous(limits = c(0, 24), breaks = c(1:22))+
  theme_bw()
beta_plot
```
Note that instead of per chromosome, you may run the regression analysis for the entire data (all chrmosomes at once).

```{r}
filtr.dt%>%do(tidy(lm(Avg.beta ~ scale(snp.counts), data = .))) %>%
  mutate(padj = p.adjust(`p.value`, method = 'BH')) %>%
  mutate(term = recode(term, 
                       `(Intercept)` = "Intercept", 
                       `scale(snp.counts)` = "SNP_ZCounts"))

# the reult would look like this:                   
#  <chr>     term        estimate     std.error      statistic      p.value       padj    
#   1      Intercept       1.00         0.00000984     101728.         0            0       
#   2      SNP_ZCounts    -0.0000715    0.00000984     -7.26         4.41e-13    4.41e-13
```

#### **5.3.Simple scatter plot**
You can simply check on the regression coeffcient by running the code below:
```{r}
library(ggpubr) # to add fitted regression equation inside

ggplot(data=filtr.dt, aes(x = scale(snp.counts), y = Avg.beta)) + 
  geom_point() +
  stat_smooth(method = "lm", se=FALSE) +
  stat_regline_equation(label.x.npc = "center")+
  theme_bw()
```

### **6. How removing outliers affected the association?**
One question I always ask is if/how removing outliers affect the regression analysis output.
To address this question I'll run the lm() on data before and after outliers removal.

#### **6.1. check it on the main data**
```{r}
model_effects = result %>% 
  do(tidy(lm(Avg.beta ~ snp.counts,  data = .))) %>%
  mutate(padj = p.adjust(`p.value`, method = 'BH')) 

print(model_effects)
```

#### **6.2. check it on the filtered data**
```{r}
model_effects2 = filtr.dt %>% 
  do(tidy(lm(Avg.beta ~ snp.counts,  data = .))) %>%
  mutate(padj = p.adjust(`p.value`, method = 'BH')) 

print(model_effects2)
```
Note that removing outliers (windows with extrem low or high SNP counts),
does affect the significance of the correlation of beta and snp.counts. 









    

