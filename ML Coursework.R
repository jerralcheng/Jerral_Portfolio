#R code to import and prepare the EWCS dataset
ewcs=read.table("EWCS_2016.csv",sep=",",header=TRUE)
ewcs[,][ewcs[, ,] == -999] <- NA
kk=complete.cases(ewcs)
ewcs=ewcs[kk,]

##PART 1 - Principal Component Analysis and Hierarchical Clustering##
names(ewcs)
ewcs_pca <- prcomp(ewcs, scale.=T)

#Plotting scree plot and biplot
ewcs_pca.var <- ewcs_pca$sdev^2 #Calculate how much variation in the original data each PC accounts for
ewcs_pca.var.percent <- round(ewcs_pca.var/sum(ewcs_pca.var)*100, 1) #Calculate the percentages for each variation

#Scree plot
barplot(ewcs_pca.var.percent, main = "Scree Plot", xlab="Principal Component", ylab = "Percent Variation")

#Biplot
biplot(ewcs_pca, scale = 0, xlab = paste("PC1 - ", ewcs_pca.var.percent[1], "%", sep = ""), ylab = paste("PC2 - ", ewcs_pca.var.percent[2], "%", sep = ""))
summary(ewcs_pca) #From the summary, we can see that PC1 and PC2 captured about 52% of the variance. 
ewcs_pca$rotation

#Q90b, Q90c, Q90f are relatively more important in PC2 than in PC1
#PCA concludes that Q90b, Q90c, Q90f are important differentiators

#Hierarchical Clustering
ewcs_scaled <- scale(ewcs)

#Average linkage
hc_avg = hclust(dist(ewcs_scaled), method = "average")
plot(hc_avg , main = "Average Linkage", xlab = "", sub = "", cex = .9)
sum(cutree(hc_avg , 2) == 2) #29
#Average linkage fails to provide sufficient sample size for one cluster.

#Complete linkage
hc_complete = hclust(dist(ewcs_scaled), method = "complete")
plot(hc_complete , main = "Complete Linkage", xlab = "", sub = "", cex = .9)
sum(cutree(hc_complete, 2) == 2)  ## 6427 cases of second cluster
sum(cutree(hc_complete, 4) == 2) ## 6386 cases of second cluster
sum(cutree(hc_complete, 6) == 2) ## 3738 cases of second cluster
#Even by increasing the number of clusters, cluster 2 remains with the highest number of observations.


##PART 2 - Regression##

#Import dataset
school1 <- read.table("student-mat.csv",sep = ";",header = TRUE, stringsAsFactors = T)
school2 <- read.table("student-por.csv",sep = ";",header = TRUE, stringsAsFactors = T)
school_combined <- rbind(school1, school2)

#Change all character variables to factor format
school_combined$Medu <- factor(school_combined$Medu)
school_combined$Fedu <- factor(school_combined$Fedu)
school_combined$traveltime <- factor(school_combined$traveltime)
school_combined$studytime <- factor(school_combined$studytime)
school_combined$famrel <- factor(school_combined$famrel)
school_combined$goout <- factor(school_combined$goout)
school_combined$Dalc <- factor(school_combined$Dalc)
school_combined$Walc <- factor(school_combined$Walc)
school_combined$health <- factor(school_combined$health)

school_combined$failures <- ifelse(school_combined$failures >= 1, "n" , 4)
school_combined$failures <- factor(school_combined$failures)

summary(school_combined)

#Remove G1 and G2 from dataset
schools_G3 <- subset(school_combined, select = -c(G1,G2))

##Model 1 - Linear Regression

#Linear Regression Model
LR_model <- lm(G3 ~ ., data = school_combined)
summary(LR_model) #Many dummy variables were generated along with many insignificant predictor variables

#Backward Elimination
LR_model2 <- lm(G3 ~ ., data = schools_G3)
bw_model <- step(LR_model2)
summary(bw_model)

#Plotting the diagnostic plots
par(mfrow = c(2,2))
plot(bw_model)
par(mfrow = c(1,1))

#VIF
library(car)
vif(bw_model) #GVIF predictor variables are all within 1, hence multicollinearity does not exist

RMSE_main <- round(sqrt(mean(residuals(bw_model)^2)),2)
RMSE_main #3.3 

#Train-test split, 70% train, 30% test
library(caTools)
set.seed(1) 
sample <-  sample.split(Y = schools_G3$G3, SplitRatio = 0.70)
train <-  subset(schools_G3, sample == T)
test  <- subset(schools_G3, sample == F)

train_model <- lm(G3 ~ address + famsize + Mjob + Fjob + internet + studytime +
                    failures + schoolsup + paid + higher + romantic + freetime +
                    goout + health, data = train)
summary(train_model)

#RMSE of linear regression model using the train set
RMSE_LR_train <- sqrt(mean(residuals(train_model)^2))
RMSE_LR_train #3.32

#Prediction of the training model using the test set 
predicted_LR_test<- predict(train_model, newdata = test)
test_error <- test$G3 - predicted_LR_test

#RMSE of linear regression model using the test set
RMSE_LR_test <- sqrt(mean(test_error^2))
RMSE_LR_test #3.40

##Model 2: Linear Regression with Lasso Regression

#Create a matrix of x variable with train set
library(glmnet)
x_train <-  model.matrix(G3 ~ ., train)[, -1]
#y variable for train set
y_train = train$G3

#Creating Lasso regression with regularisation to prevent overfitting
grid <-  10^seq(10,-2,length=100)
lasso <-  glmnet(x_train, y_train, alpha = 1, lambda = grid)

#Prediction of the linear model using the train set 
predicted_lasso_train <- predict(lasso, x_train, response = "raw")

#RMSE of linear regression model using the train set
RMSE_lasso_train <- sqrt(mean((predicted_lasso_train - y_train)^2))
RMSE_lasso_train #3.79

#Creating a matrix of x variable with test set
x_test <-  model.matrix(G3 ~ ., test)[, -1]
#y variable for training dataset
y_test <-  test$G3

#Prediction of the linear model using the test set 
predicted_lasso_test <- predict(lasso, x_test, response = "raw")

#RMSE of linear regression model with the test set
RMSE_lasso_test <- sqrt(mean((predicted_lasso_test - y_test)^2))
RMSE_lasso_test #3.78

##Model 3: Linear Regression with Ridge Regression

#Creating a matrix of x variable with train set
x_train <-  model.matrix(G3 ~ ., train)[, -1]
#y variable for training dataset
y_train <-  train$G3

#Creating Ridge regression with regularisation to prevent overfitting
ridge <-  glmnet(x_train, y_train, alpha = 0,lambda = grid)

#Prediction of the linear model using the train set 
predicted_ridge_train <- predict(ridge, x_train, response = "raw")

#RMSE of linear regression model with the train set
RMSE_ridge_train <- sqrt(mean((predicted_ridge_train - y_train)^2))
RMSE_ridge_train #3.71

#Creating a matrix of x variable with test set
x_test <-  model.matrix(G3 ~ ., test)[, -1]
#Y variable for training dataset
y_test <-  test$G3

#Prediction of the linear model using the test set 
predicted_ridge_test <- predict(ridge, x_test, response = "raw")

#RMSE of linear regression model with the test set
RMSE_ridge_test <- sqrt(mean((predicted_ridge_test - y_test)^2))
RMSE_ridge_test #3.73


##PART 3 - Classification##
library(rpart)
library(rpart.plot) 
library(tidyverse)

#Import dataset
client_data <- read.csv("bank.csv", sep = ";", stringsAsFactors = T)
client_data <- select(client_data, -duration) #Remove duration column 
summary(client_data) #4000 no, 521 yes

#CART
set.seed(2)
#Set cp = 0 to guarantee no pruning in order to grow tree to max
m1 <- rpart(y ~ . , data = client_data, method = "class", control = rpart.control(cp = 0))

#Plot Maximal Tree 
rpart.plot(m1, nn = T , main = "Maximal Tree in m1")

#Results of CART as decision rules
print(m1)

#Print CP results (critical cp values)
printcp(m1, digits = 3)

#Plot CV error vs cp values
plotcp(m1)

#Finding the minimum cp value in m1
cp.min <- m1$cptable[which.min(m1$cptable[, "xerror"]), "CP"]
cp1 <- 0.006718 #minimum CV error, coincidentally the simplest tree within 1SE

#Prune the 2nd optimal tree as m2
m2 <- prune(m1, cp = cp1)
print(m2)
printcp(m2, digits = 3)

rpart.plot(m2, nn= T, main = "Pruned Tree with cp = 0.006718")

#Test CART model using m2 predictions
testcase1 <- data.frame(age = c(34), job = c("management"), marital = c("single"), 
                        education = c("secondary"), default = c("no"), 
                        balance = c(1002), housing = c("no"), loan = c("yes"), 
                        contact = c("cellular"), day = c(11), month = c("oct"),
                        campaign = c(2), pdays = c(100),
                        previous = c(0), poutcome = c("success"))

predict.cart <- predict(m2, newdata = testcase1, type = "class")
results <- data.frame(testcase1, predict.cart)

