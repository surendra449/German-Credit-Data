#loading the libraries
library("Metrics")
library("ROCR")
library("caret")
library("ggplot2")
library("e1071")
library("randomForest")
library("xgboost")
library("Matrix")
library("readr")
library("parallel")

setwd('local_path')
# German Credit Data
german_credit <- read.csv('local_path/german_credit.csv')

str(german_credit)

#converting the numerical values to factors
german_credit$Creditability <- as.factor(german_credit$Creditability)
german_credit$AccountBalance <- as.factor(german_credit$AccountBalance)	
german_credit$Payment_Status_of_Previous_Credit <- as.factor(german_credit$Payment_Status_of_Previous_Credit)
german_credit$Purpose <- as.factor(german_credit$Purpose)
german_credit$Value_Stocks <- as.factor(german_credit$Value_Stocks)
german_credit$Length_of_current_employment<- as.factor(german_credit$Length_of_current_employment)
german_credit$Instalment_percent<- as.factor(german_credit$Instalment_percent)
german_credit$Sex_Marital_Status<- as.factor(german_credit$Sex_Marital_Status)
german_credit$Guarantors<- as.factor(german_credit$Guarantors)
german_credit$Duration_in_Current_address<- as.factor(german_credit$Duration_in_Current_address)
german_credit$Most_valuable_available_asset<- as.factor(german_credit$Most_valuable_available_asset)
german_credit$Concurrent_Credits<- as.factor(german_credit$Concurrent_Credits)
german_credit$Type_of_apartment<- as.factor(german_credit$Type_of_apartment)
german_credit$No_of_Credits_at_this_Bank<- as.factor(german_credit$No_of_Credits_at_this_Bank)
german_credit$Occupation<- as.factor(german_credit$Occupation)
german_credit$No_of_dependents<- as.factor(german_credit$No_of_dependents)
german_credit$Telephone<- as.factor(german_credit$Telephone)
german_credit$Foreign_Worker<- as.factor(german_credit$Foreign_Worker)


#checking for levels in the target variable
table(german_credit$Creditability)

#Since the target class is highly unbalanced, we should balance the dataset
german_credit1<-german_credit[german_credit$Creditability==1,]
german_credit1<-german_credit1[sample(nrow(german_credit1), 300), ]
german_credit0<-german_credit[german_credit$Creditability==0,]
german_credit<-rbind(german_credit0,german_credit1)

#randomizing the dataset
german_credit<-german_credit[sample(nrow(german_credit), nrow(german_credit)), ]

#checking for levels in the target variable. Now the data is balanced
table(german_credit$Creditability)

#checking for missing values
missing<-function(x){
    return (sum(is.na(x)))
}
apply(german_credit,2,missing)
#no missing values in the dataset


#Base Model - Logistic regression
set.seed(1)
#splitting the dataset into train and test
index <- sample(1:nrow(german_credit), size = 0.9*nrow(german_credit))
train <- german_credit[index,]
test <- german_credit[-index,]

#building generalised linear model
LogModel <- glm(Creditability ~ ., family=binomial, data = train)
#predicting the model on test
LogModel_pred <- predict(LogModel, test)
pred_class <- ifelse(LogModel_pred>=0.5, 1,0)
#computing the accuracy
table(pred_class,test$Creditability)
print(paste("Accuracy usind validation method is: ", 1-sum(pred_class!=test$Creditability)/nrow(test)))

#plotting auc curve
pred<-prediction(LogModel_pred,test$Creditability)
pref<-performance(pred, measure = "tpr", x.measure = "fpr")
auc <- performance(pred, measure = "auc")
auc <- auc@y.values[[1]]
roc.data <- data.frame(fpr=unlist(pref@x.values), tpr=unlist(pref@y.values), model="GLM")
ggplot(roc.data, aes(x=fpr, ymin=0, ymax=tpr)) + geom_ribbon(alpha=0.2) +
geom_line(aes(y=tpr)) + ggtitle(paste0("ROC Curve w/ AUC=", auc))

#since everytime we run the above code, we get different accuracy, hence to avoid this problem, we use k-fold cross validation technique

k=10
n=floor(nrow(german_credit)/k)
log_accuracy<-c()
#using 10-fold cross validation
for (i in 1:k){
    s1 = ((i-1)*n+1)
    s2 = (i*n)
    subset = s1:s2
    log_train<- german_credit[-subset,]
    log_test<- german_credit[subset,]
    log_fit<-glm(Creditability ~ ., family=binomial, data = log_train)
    log_pred <- predict(log_fit, log_test)
    log_pred_class <- ifelse(log_pred>0.5, 1, 0)
    print(paste("Logistic Accuracy: ",1-sum(log_test$Creditability!=log_pred_class)/nrow(log_test)))
    log_accuracy[i]<- 1- (sum(log_test$Creditability!=log_pred_class)/nrow(log_test))
}
#taking the mean of all the 10 model to estimate the accuracy of the model
print(paste("The accuracy of the logistic Model is: ",mean(log_accuracy)))
#The base model gives an accuracy of 68.5%


#RandomForest - Tuning the parameters using Cross-validation technique

ntree = c(600,700,800,900,1000)
mtry = c(11,12,13)
nodesize = c(4,5,6)
k=10
n=floor(nrow(german_credit)/k)
rf_accuracy_poss=c()
rf_accuracy_all=data.frame("No_of_Trees" = integer(0),"No_of_features"=integer(0),
"Nodesize" = integer(0), "Accuracy"= numeric(0))
#using 10-fold cross validation
for (t in ntree){
    for (m in mtry){
        for (n in nodesize){
            for (i in 1:k){
                s1 = ((i-1)*n+1)
                s2 = (i*n)
                subset = s1:s2
                rf_train<- german_credit[-subset,]
                rf_test<- german_credit[subset,]
                rf_fit<-randomForest(x=rf_train[,-c(1)], y = rf_train[,c(1)],
                ntree = t, mtry = m, nodesize = n)
                rf_pred <- predict(rf_fit, rf_test, type = "prob")[,2]
                rf_pred_class <- ifelse(rf_pred>0.5, 1, 0)
                rf_accuracy_poss[i]<- 1 - sum(rf_test$Creditability!=rf_pred_class)/nrow(rf_test)
            }
            print(paste("number of trees: ",t,"number of features: ", m, "nodesize :", n,
            "Cross-Validation mean Accuracy",mean(rf_accuracy_poss)))
            rf_accuracy_all<- rbind(rf_accuracy_all, data.frame(t,m,n,mean(rf_accuracy_poss)))
        }
    }
}

print("The best parameters and the accuracies are :")
rf_accuracy_all[rf_accuracy_all$mean.rf_accuracy_poss. == max(rf_accuracy_all$mean.rf_accuracy_poss.),]

#Building the model using the best parameters
k=10
n=floor(nrow(german_credit)/k)
rf_accuracy<-c()
for (i in 1:k){
    s1 = ((i-1)*n+1)
    s2 = (i*n)
    subset = s1:s2
    rf_train<- german_credit[-subset,]
    rf_test<- german_credit[subset,]
    rf_fit<-randomForest(x=rf_train[,-c(1)], y = rf_train[,c(1)],
    ntree = 1000,mtry = 12,nodesize = 6)
    rf_pred <- predict(rf_fit, rf_test, type = "prob")[,2]
    rf_pred_class <- ifelse(rf_pred>0.5, 1, 0)
    print(paste("RF Accuracy: ",1 - sum(rf_test$Creditability!=rf_pred_class)/nrow(rf_test)))
    rf_accuracy[i]<- 1- (sum(rf_test$Creditability!=rf_pred_class)/nrow(rf_test))
}

print(paste("The accuracy of the Random Forest is: ", mean(rf_accuracy)))
# The final accuracy from Random Forest is 73.16%


#XGBoost- Tuning the parameters and finding the accuracy of the model

cv.nfold <- 10
n=floor(nrow(german_credit)/cv.nfold)
#passing different sets of parameters using expand.grid
params<-expand.grid(nround = c(100),#200,#300
eta=c(0.3),#0.1,0.2
gamma= c(1),#2,3
max_depth=c(6),#7,8
min_child_weight = c(1),#2,3
subsample = c(1),
colsample_bytree = c(0.8),
num_parallel_tree = c(500))

p=data.frame("nround" = integer(0),"max_depth"=integer(0),
"eta"=integer(0), "gamma"=integer(0), "min_child_weight"=integer(0),
"subsample"=integer(0),"colsample_bytree"=integer(0),
"num_parallel_tree"= integer(0),"Accuracy"= numeric(0))

#tuning the parameters and picking the best from them
for (k in 1:nrow(params)) {
    xgb_accuracy=c()
    for (i in 1:cv.nfold){
        s1 = ((i-1)*n+1)
        s2 = (i*n)
        subset = s1:s2
        german_credit_sm <- sparse.model.matrix(Creditability ~ .-1, data = german_credit)
        x_train<- german_credit_sm[-subset,]
        x_test<- german_credit_sm[subset,]
        y_train<-german_credit[-subset,c(1)]
        y_train<-as.integer(y_train)-1
        y_test<-german_credit[subset,c(1)]
        y_test<-as.integer(y_test)-1
        dxgb_train <- xgb.DMatrix(data = x_train, label = y_train)
        prm <- params[k,]
        n_proc <- detectCores()
        md <- xgb.train(data = dxgb_train, nthread = n_proc,
        objective = "binary:logistic", nround = prm$nround,
        max_depth = prm$max_depth, eta = prm$eta, gamma = prm$gamma,
        min_child_weight = prm$min_child_weight, subsample = prm$subsample,
        colsample_bytree = prm$colsample_bytree,
        eval_metric = "error",
        early_stop_round = 100, printEveryN = 100,
        num_parallel_tree = prm$num_parallel_tree)
        phat = predict(md, newdata = x_test)
        phat_class<-ifelse(phat>0.5,1,0)
        xgb_accuracy[i]<-1-(sum(y_test!=phat_class)/length(y_test))
        print(xgb_accuracy[i])
    }
    p<-rbind(p,data.frame(prm$nround, prm$max_depth, prm$eta, prm$gamma, prm$min_child_weight,
    prm$subsample, prm$colsample_bytree,mean(xgb_accuracy)))
    print (p)
}

#The accuracy of the XGBoost is 71% on an average.
