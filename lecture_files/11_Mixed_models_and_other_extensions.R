#lecture on mixed models and other lm extensions

team <- read.csv("https://sites.google.com/site/stephengosnell/teaching-resources/datasets/team_data_no_spaces.csv?attredirects=0&d=1")
names(team)
head(team)

#for ease just pull those out (not required, just for viewing here)
team_potential <- team[,colnames(team) %in% c(#site specific
  "Continent",
  #diversity
  "shannon", "wd.RaoQ", "maxdbh.RaoQ", "CWM.wd", "CWM.maxdbh", "PD",
  #environmental
  "Precip_mean.mm", "Elevation",
  #outcome
  "PlotCarbon.tonnes")]

stepAIC(team_model_full)

#mixed models####
#but we need to consider mixed model here, since each plot has 6+ sites at it
require(lme4) #nlme is another package thats good if you need covariance structures
#start with same full model
team_model_full_mm <- lmer(PlotCarbon.tonnes ~ 
                             #site specific
                             Continent +
                             #diversity
                             shannon + wd.RaoQ + maxdbh.RaoQ + CWM.wd + CWM.maxdbh +
                             PD +
                             #environmental
                             Precip_mean.mm + Elevation +
                             #random portion, new notation
                             (1|Site.Name), team)
summary(team_model_full_mm)

#now to do top-down test we have to use Chi-squared tests (not F)
require(car)
Anova(team_model_full_mm, type = "III")
stepAIC(team_model_full_mm) # won't work with mixed models, so have to do manually
drop1(team_model_full_mm)
drop1(team_model_full_mm, test = "Chi")

#dredge will work, but may be slow
auto <- dredge(team_model_full_mm)
#write to csv to observe if needed, its sorted by AICc values so top line is bst model
#still should check assumptions
write.csv(auto, "dredge_output.csv", row.names = F)
team_final_mm <- get.models(auto, subset = delta < 4, REML = T)  
#easy error, just take top
team_final_mm <- get.models(auto, subset = 1, Re)[[1]]
#use function check_mixed_model to evaluate mixed model

check_mixed_model <- function (model, model_name = NULL) {
  #collection of things you might check for mixed model
  par(mfrow = c(2,3))
  #not sure what this does with mutliple random effects, so stop with 1 for now
  if(length(names(ranef(model))<2)){
    qqnorm(ranef(model, drop = T)[[1]], pch = 19, las = 1, cex = 1.4, main= paste(model_name, 
                                                                                  "\n Random effects Q-Q plot"))
  }
  plot(fitted(model),residuals(model), main = paste(model_name, 
                                                    "\n residuals vs fitted"))
  qqnorm(residuals(model), main =paste(model_name, 
                                       "\nresiduals q-q plot"))
  qqline(residuals(model))
  hist(residuals(model), main = paste(model_name, 
                                      "\nresidual histogram"))
}

check_mixed_model(team_final_mm)

#generalized linear models
#what if the outcome isn't continuous but is either 0/1 (presence/absence) or 
#a proportion?
#We use a generalized linear model, aka logistic regression
#use glm command (instead or arcsin transform!)
#data from Needles et al 2014
otters <- read.csv("https://sites.google.com/site/stephengosnell/teaching-resources/datasets/needles_january.csv?attredirects=0&d=1")
head(otters)
#star, otters, and mussels are treatments (1 is present)
#WASU and notWASU are count data
otter_fit <- glm(cbind(WASU, notWASU)~ Star + Otters + Mussels, otters, family=binomial)
Anova(otter_fit, type = "III")
summary(otter_fit)
#same basic assumption
plot(otter_fit)
#can use drop1, stepAIC, etc

#glmm
#but this is a mixed-model again! multiple measures per piling
otter_fit_mm <- glmer(cbind(WASU, notWASU)~ Star + Otters + Mussels + (1|Piling), otters, family=binomial)
Anova(otter_fit_mm, type = "III") #uses chisq test
#check assumptions
#function belows passed from R-sig-ME discussion on checking for overdispersion  
dispersion_glmer <- function(modelglmer){
  ## computing  estimated scale  ( binomial model)
  #following  D. Bates :
  #That quantity is the square root of the penalized residual sum of
  #squares divided by n, the number of observations, evaluated as:
  n <- length(residuals(modelglmer))
  return(  sqrt( sum(c(residuals(modelglmer), modelglmer@u) ^2) / n ) )
}
dispersion_glmer(otter_fit_mm)
#not overdispered

drop1(otter_fit_mm, test = "Chi") 
otter_fit_mm_a <- update(otter_fit_mm, .~. - Star)
Anova(otter_fit_mm_a, type = "III") #uses chisq test
otter_fit_mm_b <- update(otter_fit_mm_a, .~. - Mussels)
Anova(otter_fit_mm_b, type = "III") #uses chisq test

#nls is used to fit specified functions in R####
whelk <- read.csv("https://sites.google.com/site/stephengosnell/teaching-resources/datasets/whelk.csv?attredirects=0&d=1")
head(whelk)
summary(whelk)
whelk_plot <- ggplot(whelk, aes_string(x="Shell.Length", y = "Mass")) +
  geom_point(aes_string(colour = "Location")) + 
  theme(axis.title.x = element_text(face="bold", size=28), 
        axis.title.y = element_text(face="bold", size=28), 
        axis.text.y  = element_text(size=20),
        axis.text.x  = element_text(size=20), 
        legend.text =element_text(size=20),
        legend.title = element_text(size=20, face="bold"),
        plot.title = element_text(hjust = 0.5, face="bold", size=32))
whelk_plot
#linear fit
whelk_lm <- lm(Mass ~ Shell.Length, whelk, na.action = na.omit)
#power fit
whelk_power <- nls(Mass ~ b0 * Shell.Length^b1, whelk, 
                   start = list(b0 = 1, b1=3), na.action = na.omit)
AICc(whelk_lm, whelk_power)
whelk_plot + geom_smooth(method = "lm", se = FALSE, size = 1.5, color = "orange")+ 
  geom_smooth(method="nls", 
              # look at whelk_power$call
              formula = y ~ b0 * x^b1, 
              method.args = list(start = list(b0 = 1, 
                                              b1 = 3)), 
              se=FALSE, size = 1.5, color = "blue") 

#generalized additive model (gam)####
#non-linear model

#compare fit to whelk mass-length to that produced by gam
require(mgcv)
require(MASS)
#this just produces an lm
whelk_gam_lm <- gam(Mass ~ Shell.Length, data = whelk)
summary(whelk_gam_lm)
plot(whelk_gam_lm)
#or we can specify using spline
whelk_gam_spline <- gam(Mass ~ s(Shell.Length), data = whelk)
summary(whelk_gam_spline)
#gam.check(whelk_gam_spline)
plot(whelk_gam_spline)
#or using ggplot2
whelk_plot + geom_smooth(method = "lm", se = FALSE, size = 1.5, color = "orange")+ 
  geom_smooth(method="nls", 
              # look at whelk_power$call
              formula = y ~ b0 * x^b1, 
              method.args = list(start = list(b0 = 1, 
                                              b1 = 3)), 
              se=FALSE, size = 1.5, color = "blue") + 
  geom_smooth(stat= "smooth", method = "gam", formula = y ~ s(x), 
                         color = "yellow")

#can compare fits with AIC
AICc(whelk_gam_spline, whelk_lm, whelk_power)

#trees are useful way of handling data visually and allow first look
#building the classification tree
#install if necessary
#example with famous iris dataset (built-in)
#good for species classification!
library(rpart)
iris_tree_initial <- rpart(Species ~ ., data = iris, method = "class", 
                           minsplit = 2, minbucket = 1)
plot(iris_tree_initial)
text(iris_tree_initial)
#or for a prettier graph
require(rattle)
fancyRpartPlot(iris_tree_initial, main="Iris")

#what if you want fewer splits (less complex model)
#can use defaults for buckets 
iris_tree_initial_auto <- rpart(Species ~ ., data = iris)
fancyRpartPlot(iris_tree_initial_auto, main="Iris")

#or minimize complexity parameter (good for larger models)
iris_tree_model_2<- prune(iris_tree_initial, 
                          cp =   iris_tree_initial$cptable[which.min(iris_tree_initial$cptable[,"xerror"]),"CP"])
#is using this to make decisions
iris_tree_initial$cptable
fancyRpartPlot(iris_tree_model_2)

#validation techniques
#UNDER CONSTRUCTION
#need 0/1 column for for prediction
iris$virginica <- iris$Species
levels(iris$virginica)[levels(iris$virginica) == "virginica"]  <- "1"
levels(iris$virginica)[levels(iris$virginica) %in% c("setosa", "versicolor")] <- "0"
iris$virginica <- as.numeric(as.character(iris$virginica))

#compare glm and gam 
iris_glm <- glm(virginica ~ . - Species, iris, family = binomial)
summary(iris_glm)
iris_glm_final <- stepAIC(iris_glm)

iris_gam <- gam(virginica ~ s(Sepal.Length) + s(Sepal.Width) + 
                  s(Petal.Length) + s(Petal.Width), data = iris)
summary(iris_gam)
iris_gam_a <-update(iris_gam, . ~ . - s(Petal.Width))
summary(iris_gam_a)
iris_gam_b <-update(iris_gam_a, . ~ . - s(Sepal.Width))
summary(iris_gam_b)

AICc(iris_gam_b,  iris_glm_final)

#compare visually using AUC
#calculate AUROC (AUC)
require(ROCR)
iris_glm_final_predict<-prediction(fitted.values(iris_glm_final), iris$virginica)
iris_glm_final_performance<-performance(iris_glm_predict,"tpr","fpr")
#to see auc
plot(iris_glm_performance, main = "glm AUC")

#compare to gam
iris_gam_b_predict<-prediction(fitted.values(iris_gam_b), iris$virginica)
iris_gam_b_performance<-performance(iris_gam_b_predict,"tpr","fpr")
#to see auc
plot(iris_gam_b_performance, main = "gam AUC")

#cross validation
require(boot)
#K is the number of groups to put data into. default is "leave-one"out" design
iris_glm_final_cv<-cv.glm(iris,  iris_glm_final)
str(iris_glm_final_cv)
#delta is the prediction error and the adjusted rate - use adjusted to minimize
#impact of sampling or outliers









