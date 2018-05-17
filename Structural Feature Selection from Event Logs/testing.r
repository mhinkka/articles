########################################################################################
# R test framework sources used to perform the tests required by paper: "Structural Feature Selection for Event Logs" 
# by Markku Hinkka, Teemu Lehto, Keijo Heljanko and Alexander Jung
# 2.7.2017

########################################################################################
# Configuration

fileLocation <- "D:\\dev\\aalto\\papers\\structural-influence-analysis\\"
logFileLocation <- "C:\\Users\\User\\Dropbox\\Aalto\\testing\\testruns\\"
#logFileLocation <- "C:\\Users\\marhink\\Dropbox\\Aalto\\testing\\testruns\\"
# Initialize random seed so that the results are repeatable.
seed <- 1234

########################################################################################
# Load required libraries
require(caret)
require(caretEnsemble)
require(pROC)
require(caTools)
require(psych)
require(plyr)
require(cluster)
require(data.table)
require(kernlab)
require(fastICA)
require(bnlearn)
require(glmnet)
require(randomForest)
require(infotheo)
require(mRMRe)
require(e1071)
require(flexclust)


########################################################################################
# Function definitions
writeLogMessage <- function(writeLogMessage) {
  print(paste(Sys.time(), paste(writeLogMessage, collapse=",")))
}

loadDataset <- function(datasetName, caseAttributesName, resultColumnName, outcomeName, separator) {
  outcomeName <<- outcomeName
  resultColumnName <<- resultColumnName
  trainData <- read.csv(paste(fileLocation, datasetName, ".csv", sep = ""), sep=separator, dec=".", stringsAsFactors=FALSE)
  trainData <- trainData[order(trainData[,1]),] # Order data by first column
  traindf <- data.frame(trainData)
  predictorNames <<- names(traindf)[names(traindf) != resultColumnName & names(traindf) != outcomeName & names(traindf) != "Id"]
  outcome <- ifelse(traindf[,resultColumnName]==1, "yes", "no")
  traindf <- cbind(outcome, traindf)
  names(traindf)[1] <- outcomeName
  traindf <- data.frame(lapply(traindf, as.factor))
  traindf <<- traindf

  if (caseAttributesName != "") {
    caseAttributeData <<- read.csv(paste(fileLocation, caseAttributesName, ".csv", sep = ""), sep=separator, dec=".", stringsAsFactors=FALSE)
  } else {
    caseAttributeData <<- NULL
  }
  writeLogMessage(paste("Number of columns in the training dataset: ", ncol(traindf), sep=""))
}

initializeClassificationControl <- function(df, resamples) {
  return(trainControl(
    method="boot",
    number=resamples,
    savePredictions="final",
    classProbs=TRUE,
    index=createResample(df[,outcomeName], resamples),
    summaryFunction=twoClassSummary
  ))
}

convertToFactors <- function(df) {
  return(data.frame(lapply(df, factor)))
}

convertToNumeric <- function(df) {
  for (col in names(df)) set(df, j=col, value=as.numeric(df[[col]]))
  return(df)
}

getPrunedTraindfNone <- function(df, initialK, outcomeCol) {
  result <- NULL
  result$alldf <- df
  return(result)
}

getPrunedTraindfPCA <- function(df, initialK, outcomeCol) {
  result <- NULL
  if (initialK >= ncol(df)) {
    result$alldf <- df
    return(result)
  }
  df <- df[, sapply(df, nlevels) > 1]
  df <- convertToNumeric(df)
  df <- addNoise(df)
  result$pca <- preProcess(df, method=c("center", "scale", "pca"), pcaComp=initialK)
  result$alldf <- data.frame(predict(result$pca, df))
  result$featureExtractor <- function(df2) {
    for (col in names(df2)) set(df2, j=col, value=as.numeric(df2[[col]]))
    missingCols <- setdiff(names(result$pca$mean), names(df2))
    for (col in missingCols) {
      df2[col] = rep(0, nrow(df2))
    }
    return(predict(result$pca, df2))
  }
  return(result)
}

getPrunedTraindfICA <- function(df, initialK, outcomeCol) {
  result <- NULL
  if (initialK >= ncol(df)) {
    result$alldf <- df
    return(result)
  }
  for (col in names(df)) set(df, j=col, value=as.numeric(df[[col]]))
  df <- addNoise(df)
  result$ica <- preProcess(df, method=c("center", "scale", "ica"), n.comp=initialK)
  result$alldf <- data.frame(predict(result$ica, df))
  result$featureExtractor <- function(df2) {
    for (col in names(df2)) set(df2, j=col, value=as.numeric(df2[[col]]))
    missingCols <- setdiff(names(result$ica$mean), names(df2))
    for (col in missingCols) {
      df2[col] = rep(0, nrow(df2))
    }
    return(predict(result$ica, df2))
  }
  return(result)
}

getPrunedTraindfClusterEx <- function(df, initialK, outcomeCol, removeDuplicates) {
  result <- NULL
  if (initialK >= ncol(df)) {
    result$alldf <- df
    return(result)
  }
    
  getUniqueFeatures <- function(df, threshold) {
    res <- NULL
    findFeatureClustering <- function(df, threshold) {
      featuredf <- t(data.frame(lapply(df, function(x) as.numeric(as.character(x)))))
      k <- initialK
      repeat {
        kresult <- kmeans(featuredf, k)
        clusterPercentage <- (kresult$betweenss / kresult$totss) * 100
        writeLogMessage(paste("Cluster size #", k, " percentage:", clusterPercentage))
        if (clusterPercentage >= threshold) {
          res$clusterPercentage <<- clusterPercentage
          res$clusterCount <<- k
          return(kresult)
        }
        k <- k + 1
      }
    }
    
    clusters <- findFeatureClustering(df, threshold)
    
    # Initialize clustering maps
    clusters$maps <- new.env()
    for (i in 1:length(clusters$cluster)) {
      c <- clusters$cluster[i]
      varName <- paste("C", as.numeric(c), sep="")
      
      if (!exists(varName, envir=clusters$maps)) {
        evalStr <- paste(varName, " <- data.frame(clusters$center[", as.numeric(c),",])", sep="")
        eval(parse(text=evalStr), envir=clusters$maps)
      }
      evalStr <- paste(varName, " <- cbind.data.frame(", varName,", ", names(c), "=df$", names(c), ")", sep="")
      eval(parse(text=evalStr), envir=clusters$maps)
    }

    # Calculate closest features to cluster centers
    clusterCenterFeatureIndexes <- NULL    
    for (i in 1:initialK) {
      evalStr <- paste("C", i, sep="")
      cmp <- eval(parse(text=evalStr), envir=clusters$maps)
      d <- data.frame(as.matrix(dist(t(cmp))))
      d <- d[order(d[,1]), ]
      id <- which(names(df) == rownames(d)[2])
      clusterCenterFeatureIndexes <- c(clusterCenterFeatureIndexes, id)
    }
    res$clusters <- clusters

    res$clusters$clusterCenterFeatureIndexes <- clusterCenterFeatureIndexes
    res$clusters$clusterCenterFeatures <- names(df)[clusterCenterFeatureIndexes]
    res$clusters$clusterCenterFeatureNames <- colnames(df[, clusterCenterFeatureIndexes])
    return(res)
  }

  if (removeDuplicates) {
    df <- df[!duplicated(lapply(df, summary))]
    nc <- ncol(df)
    writeLogMessage(paste("Predictors with duplicates removed:", nc))
  }

  if (initialK >= ncol(df)) {
    result$alldf <- df
    writeLogMessage(paste("Target number of predictors reached before clustering: ", ncol(result$alldf), sep=""))
    return(result)
  }

  result <- getUniqueFeatures(df, 0)
  result$alldf <- df[, result$clusters$clusterCenterFeatureNames]

  writeLogMessage(paste("Predictor names after cluster (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfClusterWithOutliers <- function(df, initialK, outcomeCol) {
  result <- NULL
  if (initialK >= ncol(df)) {
    result$alldf <- df
    return(result)
  }
    
  getUniqueFeatures <- function(df, threshold) {
    featuredf <- t(data.frame(lapply(df, function(x) as.numeric(as.character(x)))))
    findFeatureClustering <- function(df, threshold) {
      k <- initialK
      repeat {
        kresult <- kmeans(featuredf, k)
        clusterPercentage <- (kresult$betweenss / kresult$totss) * 100
        writeLogMessage(paste("Cluster size #", k, " percentage:", clusterPercentage))
        if (clusterPercentage >= threshold) {
          result$clusterPercentage <<- clusterPercentage
          result$clusterCount <<- k
          return(kresult)
        }
        k <- k + 1
      }
    }
    
    clusters <- findFeatureClustering(df, threshold)
    
    # Initialize clustering maps
    clusters$maps <- new.env()
    for (i in 1:length(clusters$cluster)) {
      c <- clusters$cluster[i]
      varName <- paste("C", as.numeric(c), sep="")
      
      if (!exists(varName, envir=clusters$maps)) {
        evalStr <- paste(varName, " <- data.frame(clusters$center[", as.numeric(c),",])", sep="")
        eval(parse(text=evalStr), envir=clusters$maps)
      }
      evalStr <- paste(varName, " <- cbind.data.frame(", varName,", ", names(c), "=df$", names(c), ")", sep="")
      eval(parse(text=evalStr), envir=clusters$maps)
    }

    # Calculate closest features to cluster centers
    clusterCenterFeatureIndexes <- NULL    
    for (i in 1:(as.integer(0.8 * initialK))) {
      evalStr <- paste("C", i, sep="")
      cmp <- eval(parse(text=evalStr), envir=clusters$maps)
      d <- data.frame(as.matrix(dist(t(cmp))))
      d <- d[order(d[,1]), ]
      id <- which(names(df) == rownames(d)[2])
      clusterCenterFeatureIndexes <- c(clusterCenterFeatureIndexes, id)
    }
    
    centers <- clusters$centers[clusters$cluster, ] # "centers" is a data frame of 3 centers but the length of iris dataset so we can canlculate distance difference easily.
    distances <- sqrt(rowSums((featuredf - centers)^2))

    nOutliers <- initialK - length(clusterCenterFeatureIndexes)
    writeLogMessage(paste("Selecting ", nOutliers, " outliers", sep=""))
    outliers <- order(distances, decreasing=T)
    clusterCenterFeatureIndexes <- unique(c(clusterCenterFeatureIndexes, outliers))[1:initialK]

    result$clusters <<- clusters

    result$clusters$clusterCenterFeatureIndexes <<- clusterCenterFeatureIndexes
    result$clusters$clusterCenterFeatures <<- names(df)[clusterCenterFeatureIndexes]
    return(colnames(df[, clusterCenterFeatureIndexes]))
  }

  if (initialK >= ncol(df)) {
    result$alldf <- df
    writeLogMessage(paste("Target number of predictors reached before clustering: ", ncol(result$alldf), sep=""))
    return(result)
  }

  prunedPredictorNames <- getUniqueFeatures(df, 0)
  
  result$alldf <- df[, prunedPredictorNames]

  writeLogMessage(paste("Predictor names after cluster (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfCluster <- function(df, initialK, outcomeCol) {
  getPrunedTraindfClusterEx(df, initialK, outcomeCol, TRUE)
}

getPrunedTraindfClusterDuplicates <- function(df, initialK, outcomeCol) {
  getPrunedTraindfClusterEx(df, initialK, outcomeCol, FALSE)
}

getPrunedTraindfClusterPCA <- function(df, initialK, outcomeCol) {
  n <- (ncol(df) - initialK)
  result1 <- getPrunedTraindfCluster(df, ncol(df) - (n / 2))
  result <- getPrunedTraindfPCA(result1$alldf, initialK)
  result$step1 <- result1
  return(result)
}

getPrunedTraindfClusterICA <- function(df, initialK, outcomeCol) {
  n <- (ncol(df) - initialK)
  result1 <- getPrunedTraindfCluster(df, ncol(df) - (n / 2))
  result <- getPrunedTraindfICA(result1$alldf, initialK)
  result$step1 <- result1
  return(result)
}

addNoise <- function(mtx)
{
  noise <- matrix(runif(prod(dim(mtx)), min = -0.0000001, max = 0.0000001), nrow = dim(mtx)[1])
  return(noise + mtx)
}

getPrunedTraindfImportance <- function(df, initialK, outcomeCol) {
  result <- NULL
  # prepare training scheme
  # train the model
  predictorCols <- df
  for (col in names(predictorCols)) set(predictorCols, j=col, value=ifelse(predictorCols[[col]]==1, 1, 0))
  model <- randomForest(predictorCols, as.factor(outcomeCol))
  # estimate variable importance
  result$importance <- varImp(model, scale=FALSE)
  i <- cbind.data.frame(rownames(result$importance), result$importance)
  prunedPredictorNames <- (i[order(-i$Overall),][1:initialK,])[,1]
  writeLogMessage("Predictor names after importance:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfImportanceGBM <- function(df, initialK, outcomeCol) {
  result <- NULL
  # prepare training scheme
  # train the model
  predictorCols <- df
  for (col in names(predictorCols)) set(predictorCols, j=col, value=ifelse(predictorCols[[col]]==1, 1, 0))

  tc <- trainControl(
    method="boot",
    number=3,
    savePredictions="final",
    classProbs=TRUE,
    index=createResample(outcomeCol, 1),
    summaryFunction=twoClassSummary
  )

  model <- train(
    predictorCols, 
    ifelse(outcomeCol==1, 'yes', 'no'), 
    method="gbm", 
    
    metric="ROC", 
    trControl=tc)

  # estimate variable importance
  result$importance <- varImp(model, scale=FALSE)
  # summarize importance

  i <- cbind.data.frame(rownames(result$importance$importance), result$importance$importance)
  prunedPredictorNames <- (i[order(-i$Overall),][1:initialK,])[,1]
  writeLogMessage("Predictor names after importance:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfImportanceCaret <- function(df, initialK, outcomeCol) {
  result <- NULL
  # prepare training scheme
  # train the model
  predictorCols <- df
  for (col in names(predictorCols)) set(predictorCols, j=col, value=ifelse(predictorCols[[col]]==1, 1, 0))
  control <- trainControl(method="repeatedcv", number=1, repeats=1)
  model <- train(predictorCols, outcomeCol, method="rf", importance = TRUE)
  # estimate variable importance
  result$importance <- varImp(model, scale=FALSE)
  i <- data.frame(result$importance$importance)
  prunedPredictorNames <- rownames(i[order(-i$X0),][1:initialK,])
  writeLogMessage("Predictor names after importance (caret):")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getRFEControl <- function(funcs) {
  # define the control using a random forest selection function
  return(rfeControl(functions=funcs, method="cv", repeats=1, number=3, returnResamp="final", verbose = FALSE))
}

getTrainControlForRF <- function() {
  return(trainControl(classProbs = TRUE, summaryFunction = twoClassSummary))
}

getPrunedTraindfRecursive <- function(df, initialK, outcomeCol) {
  result <- NULL
  outcomedf <- cbind.data.frame(Selected=outcomeCol, SelectedC=ifelse(outcomeCol==1, "yes", "no"))
  
  # define the control using a random forest selection function
  # run the RFE algorithm
  predictorCols <- df
  result$rfe <- rfe(predictorCols, outcomedf[, "SelectedC"], 
    sizes=c(initialK), 
    rfeControl=getRFEControl(rfFuncs),
    trControl=getTrainControlForRF())
  
  prunedPredictorNames <- result$rfe$optVariables[1:min(length(result$rfe$optVariables), initialK)]

  writeLogMessage(paste("Features in the descending order of importance: ", paste(prunedPredictorNames, sep=",", collapse = ',')))
  writeLogMessage("Predictor names after recursion:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfRecursive2Sizes <- function(df, initialK, outcomeCol) {
  result <- NULL
  outcomedf <- cbind.data.frame(Selected=outcomeCol, SelectedC=ifelse(outcomeCol==1, "yes", "no"))
  
  n <- (ncol(df) - initialK)
  mid <- max(initialK * 4, ncol(df) - (3 * n / 4))

  # define the control using a random forest selection function
  # run the RFE algorithm
  predictorCols <- df
  result$rfe <- rfe(predictorCols, outcomedf[, "SelectedC"], 
    sizes=c(mid, initialK), 
    rfeControl=getRFEControl(rfFuncs),
    trControl=getTrainControlForRF())
  
  prunedPredictorNames <- result$rfe$optVariables[1:min(length(result$rfe$optVariables), initialK)]

  writeLogMessage(paste("Features in the descending order of importance: ", paste(prunedPredictorNames, sep=",", collapse = ',')))
  writeLogMessage("Predictor names after recursion:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfRecursive4Sizes <- function(df, initialK, outcomeCol) {
  result <- NULL
  outcomedf <- cbind.data.frame(Selected=outcomeCol, SelectedC=ifelse(outcomeCol==1, "yes", "no"))
  
  n <- (ncol(df) - initialK)

  writeLogMessage("Using sizes:")
  s <- c(as.integer(ncol(df) - (0.25 * n)), as.integer(ncol(df) - (0.5 * n)), as.integer(ncol(df) - (0.75 * n)), initialK)
  writeLogMessage(s)

  # define the control using a random forest selection function
  # run the RFE algorithm
  predictorCols <- df
  result$rfe <- rfe(predictorCols, outcomedf[, "SelectedC"], 
    sizes=s, 
    rfeControl=getRFEControl(rfFuncs),
    trControl=getTrainControlForRF())
  
  prunedPredictorNames <- result$rfe$optVariables[1:min(length(result$rfe$optVariables), initialK)]

  writeLogMessage(paste("Features in the descending order of importance: ", paste(prunedPredictorNames, sep=",", collapse = ',')))
  writeLogMessage("Predictor names after recursion:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfRecursiveSVM <- function(df, initialK, outcomeCol) {
  result <- NULL
  outcomedf <- cbind.data.frame(Selected=outcomeCol, SelectedC=ifelse(outcomeCol==1, "yes", "no"))
  
  predictorCols <- convertToNumeric(df)
  # run the RFE algorithm
  result$rfe <- rfe(predictorCols, outcomedf[, "SelectedC"], 
    sizes=c(initialK),
    rfeControl=getRFEControl(caretFuncs),
    method="svmRadial",
    metric = "Accuracy",
    trControl = getTrainControlForRF())
                             
 
  prunedPredictorNames <- result$rfe$optVariables[1:min(length(result$rfe$optVariables), initialK)]

  writeLogMessage(paste("Features in the descending order of importance: ", paste(prunedPredictorNames, sep=",", collapse = ',')))
  writeLogMessage("Predictor names after recursion:")
  writeLogMessage(prunedPredictorNames)
  result$alldf <- df[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfBlanket <- function(df, initialK, outcomeCol) {
  result <- NULL
  predictorCols <- df[, sapply(df, nlevels) > 1]
  predictorCols <- convertToFactors(cbind.data.frame(predictorCols, Selected=outcomeCol))
  
  result$model <- hc(predictorCols, score="aic")
  result$mb <- mb(result$model, "Selected")
  prunedPredictorNames <- result$mb[1:min(length(result$mb), initialK)]
  writeLogMessage("Predictor names after applying Markov blanket:")
  writeLogMessage(paste(prunedPredictorNames, collapse=","))
  result$alldf <- predictorCols[, prunedPredictorNames]
  return(result)
}

getPrunedTraindfBlanketPCA <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfBlanket(df, initialK, outcomeCol)
  if (initialK < ncol(result$alldf)) {
    result1 <- result;
    result <- getPrunedTraindfPCA(df[, result1$mb], initialK, outcomeCol)
    result$blanket <- result1
  }
  return(result)
}

getPrunedTraindfBlanketICA <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfBlanket(df, initialK, outcomeCol)
  if (initialK < ncol(result$alldf)) {
    result1 <- result;
    result <- getPrunedTraindfICA(df[, result1$mb], initialK, outcomeCol)
    result$blanket <- result1
  }
  return(result)
}

getPrunedTraindfBlanketImpPCA <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfBlanket(df, 1000000, outcomeCol);
  if (initialK < length(result$mb)) {
    result1 <- result
    result2 <- getPrunedTraindfImportance(result$alldf, initialK, outcomeCol)
    result <- getPrunedTraindfPCA(result2$alldf, initialK, outcomeCol)
    result$blanket <- result1
    result$importance <- result2
  }
  return(result)
}

getPrunedTraindfLASSO <- function(df, initialK, outcomeCol) {
  getPredictorNames <- function() {
    predictorCols <- df
    for (col in names(predictorCols)) set(predictorCols, j=col, value=ifelse(predictorCols[[col]]==1, 1, 0))
    predictorCols <- addNoise(predictorCols)
    oc <- ifelse(outcomeCol==1, 1, 0)
    '%ni%'<-Negate('%in%')
    result$glmnet <<- cv.glmnet(x=as.matrix(predictorCols),y=oc,type.measure='mse',nfolds=5,alpha=.5)
    c <- coef(result$glmnet,s='lambda.min')
    inds <- which(c!=0)
    v <- row.names(c)[inds]
    v <- head(v[v != '(Intercept)'], initialK)
    return(v)
  }

  predictorNames <- NULL
  bestPredictorNames <- c()
  result <- NULL
  i <- 1
  repeat {
    predictorNames <- getPredictorNames()
    if (length(predictorNames) >= initialK)
      break;
    writeLogMessage(paste("Got ", length(predictorNames), " predictors from LASSO (trying to get:", initialK, "). Retrying...", sep=""))
    if (length(predictorNames) > length(bestPredictorNames))
      bestPredictorNames <- predictorNames
    if (i > 10) {
      predictorNames <- bestPredictorNames
      break;
    }
    i <- i + 1
  }
  result$alldf <- df[, predictorNames]
  writeLogMessage(paste("Predictor names after LASSO (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfLASSORepeated <- function(df, initialK, outcomeCol) {
  return(getPrunedTraindfLASSORepeatedEx(df, initialK, outcomeCol, "lambda.min"))
}

getPrunedTraindfLASSORepeated1se <- function(df, initialK, outcomeCol) {
  return(getPrunedTraindfLASSORepeatedEx(df, initialK, outcomeCol, "lambda.1se"))
}

getUniqueOrderedPredictors <- function(predictorNamesFunc, messageSuffix = "") {
  predictorNamesTable <- data.frame(predictorName=character(), count=numeric(), stringsAsFactors=FALSE)
  i <- 1
  repeat {
    # Get next set of predictors and add all the predictors in that into the beginning of the
    # list of predictors
    newPredictorNames <- predictorNamesFunc(i)
    if (is.null(newPredictorNames)) {
      break;
    }
    for (pn in newPredictorNames) {
      ind <- which(predictorNamesTable[,1] == pn)
      if (length(ind) > 0) {
        predictorNamesTable[ind[1], 2] <- as.numeric(predictorNamesTable[ind, 2]) + 1
      }
      else {
        predictorNamesTable[nrow(predictorNamesTable) + 1,] <- c(pn, as.numeric(1))
      }
    }
    writeLogMessage(paste("Got ", nrow(predictorNamesTable), " unique predictors in ", i, " iterations", messageSuffix, ".", sep=""))
    i <- i + 1
  }

  return(predictorNamesTable[order(-as.numeric(predictorNamesTable[,2])), ]$predictorName)
}

getPrunedTraindfLASSORepeatedEx <- function(df, initialK, outcomeCol, coefAlgorithm) {
  getPredictorNames <- function(index) {
    if (index > 10) {
      return(NULL)
    }
    predictorCols <- df
    for (col in names(predictorCols)) set(predictorCols, j=col, value=ifelse(predictorCols[[col]]==1, 1, 0))
    predictorCols <- addNoise(predictorCols)
    oc <- ifelse(outcomeCol==1, 1, 0)
    '%ni%'<-Negate('%in%')
    result$glmnet <<- cv.glmnet(x=as.matrix(predictorCols),y=oc)
    c <- coef(result$glmnet,s=coefAlgorithm)
    inds <- which(c!=0)
    v <- row.names(c)[inds]
    v <- head(v[v != '(Intercept)'], initialK)
    return(v)
  }
  result <- NULL
  predictorNames <- getUniqueOrderedPredictors(getPredictorNames, paste(" using LASSO (trying to get: ", initialK, ")", sep=""))
  predictorNames <- predictorNames[1:min(length(predictorNames), initialK)]
  result$alldf <- df[, predictorNames[1:min(initialK, length(predictorNames))]]
  writeLogMessage(paste("Predictor names after ", 10, " iterations of LASSO (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfLASSOImportance <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfLASSO(df, 1000000, outcomeCol);
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    importanceSampleSize <- 100
    result <- getPrunedTraindfImportance(result$alldf[1:importanceSampleSize,], initialK, outcomeCol[1:importanceSampleSize])
    result$alldf <- result1$alldf[,names(result$alldf)]
    result$LASSO <- result1
  }
  return(result)
}

getPrunedTraindfLASSOPCA <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfLASSO(df, 1000000, outcomeCol);
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    result$alldf <- convertToFactors(result$alldf)
    result <- getPrunedTraindfPCA(result$alldf, initialK, outcomeCol)
    result$LASSO <- result1
  }
  return(result)
}

getPrunedTraindfLASSOCluster <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfLASSO(df, 1000000, outcomeCol);
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    result <- getPrunedTraindfCluster(result$alldf, initialK)
    result$LASSO <- result1
  }
  return(result)
}

getPrunedTraindfClusterImportance <- function(df, initialK, outcomeCol) {
  n <- (ncol(df) - initialK)
  result <- getPrunedTraindfCluster(df, max(initialK * 4, ncol(df) - (3 * n / 4)))
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    importanceSampleSize <- min(nrow(df), 1000)
    result <- getPrunedTraindfImportance(result$alldf[1:importanceSampleSize,], initialK, outcomeCol[1:importanceSampleSize])
    result$alldf <- result1$alldf[,names(result$alldf)]
    result$cluster <- result1
  }
  return(result)
}

getPrunedTraindfInfluence <- function(df, initialK, outcomeCol) {
  result <- NULL
  if (initialK < ncol(df)) {
    n_totalSel <- table(outcomeCol)[2]
    p_totalSel <- n_totalSel / nrow(df)
    contributions <- rep(0, ncol(df))
    i <- 1
    for (col in names(df)) {
      df_all <- data.frame(col = df[col], outcome = outcomeCol)
      df_sel <- df_all[which(df_all$outcome != 0),]
      n_feat <- length(which(df_all[col] != 0))
      n_sel <- length(which(df_sel[col] != 0))
      p_sel <- n_sel / n_feat
      diff <- abs(p_sel - p_totalSel)
      contributions[i] <- diff * n_feat
      i <- i + 1
    }
    tmpdf <- data.frame(col = names(df), contribution = abs(contributions))
    tmpdf <- tmpdf[order(-tmpdf$contribution),]
    featureNames <- tmpdf[1:initialK,1]
    writeLogMessage("Predictor names after influence:")
    writeLogMessage(featureNames)
    result$alldf <- df[,featureNames]
    return(result)
  }
  else {
    result$alldf <- df
    return(result)
  }
}

getPrunedTraindfClusterInfluence <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfCluster(df, initialK * 2, outcomeCol)
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    result <- getPrunedTraindfInfluence(result$alldf, initialK, outcomeCol)
    result$cluster <- result1
  }
  return(result)
}

getPrunedTraindfFisher <- function(df, initialK, outcomeCol) {
# http://ink.library.smu.edu.sg/cgi/viewcontent.cgi?article=1458&context=sis_research
#   A feature will
#   have a very large Fisher score if it has very similar values
#   within the same class and very different values across different
#   classes. In this case, this feature is very discriminative to
#   differentiate instances from different classes
  result <- NULL
  if (initialK < ncol(df)) {
    mu <- mean(as.numeric(outcomeCol) - 1)
    scores <- rep(0, ncol(df))
    i <- 1
    for (col in names(df)) {
      df_all <- data.frame(col = convertToNumeric(df[col]) - 1, outcome = outcomeCol)
      df_sel <- df_all[which(df_all$outcome != 0),]
      df_notSel <- df_all[which(df_all$outcome == 0),]
#      df_feat <- df_all[which(df_all[col] != 0),]
#      df_notFeat <- df_sel[which(df_sel[col] != 0),]
      n_sel <- nrow(df_sel)
      n_notSel <- nrow(df_all) - n_sel
      col_sel <- df_sel[col]
      col_notSel <- df_notSel[col]
      mu_sel <- sapply(col_sel, mean, na.rm = TRUE)
      sigma_sel <- sapply(col_sel, sd, na.rm = TRUE)
      mu_notSel <- sapply(col_notSel, mean, na.rm = TRUE)
      sigma_notSel <- sapply(col_notSel, sd, na.rm = TRUE)
      a = n_sel * (mu_sel - mu) * (mu_sel - mu) + n_notSel * (mu_notSel - mu) * (mu_notSel - mu)
      b = n_sel * sigma_sel + n_notSel * sigma_notSel
      if (b == 0) {
        score = 0
      }
      else {
        score = a / b
      }
      scores[i] = score
      i <- i + 1
    }
    tmpdf <- data.frame(col = names(df), score = scores)
    tmpdf <- tmpdf[order(-tmpdf$score),]
    featureNames <- tmpdf[1:initialK,1]
    writeLogMessage("Predictor names after Fisher scoring:")
    writeLogMessage(featureNames)
    result$alldf <- df[,featureNames]
    return(result)
  }
  else {
    result$alldf <- df
    return(result)
  }
}

getPrunedTraindfClusterFisher <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfCluster(df, initialK * 2, outcomeCol)
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    result <- getPrunedTraindfInfluence(result$alldf, initialK, outcomeCol)
    result$cluster <- result1
  }
  return(result)
}

getPrunedTraindfClusterAllInfluence <- function(df, initialK, outcomeCol) {
  n <- (ncol(df) - initialK)
#  result <- getPrunedTraindfClusterDuplicates(df, initialK * 1.5)
  result <- getPrunedTraindfClusterDuplicates(df, initialK + 2)
  if (initialK < ncol(result$alldf)) {
    contributions <- rep(0, ncol(result$alldf))
    names(contributions) <- colnames(result$alldf)
    featureToClusterCenterFeatureMap <- rep(0, ncol(df))
    names(featureToClusterCenterFeatureMap) <- colnames(df)
    for (col in names(df)) {
      clusterId <- result$clusters$cluster[col]
      featureToClusterCenterFeatureMap[col] <- result$clusters$clusterCenterFeatures[clusterId]
    }
    
    nTotalNotSel <- table(outcomeCol)[1]
    nTotalSel <- table(outcomeCol)[2]
    pTotalSel <- nTotalSel / nrow(df)
    i <- 1
    for (col in names(df)) {
      coldf <- data.frame(col = df[col], outcome = outcomeCol)
      seldf <- coldf[which(coldf$outcome != 0),]
      featseldf <- which(seldf[col] != 0)
      nSel <- length(featseldf)
      if (length(featseldf) != 0) {
        pSel <- nSel / length(which(coldf[col] != 0))
        diff <- pSel - pTotalSel
        contributions[featureToClusterCenterFeatureMap[col]] <- contributions[featureToClusterCenterFeatureMap[col]] + (diff * nTotalSel)
      }
      i <- i + 1
    }
    tmpdf <- data.frame(col = names(result$alldf), contribution = contributions)
    tmpdf <- tmpdf[order(-tmpdf$contribution),]
    featureNames <- tmpdf[1:initialK,1]
    writeLogMessage("Predictor names after influence:")
    writeLogMessage(featureNames)
    result$cluster <- result
    result$alldf <- result$alldf[,featureNames]
  }
  return(result)
}

genericKcca <- function(df, initialK, outcomeCol, family, control) {
  result <- NULL
  if (initialK >= ncol(df)) {
    result$alldf <- df
    return(result)
  }
  
  getUniqueFeatures <- function(df, threshold) {
    res <- NULL
    findFeatureClustering <- function(df, threshold) {
      featuredf <- t(data.frame(lapply(df, function(x) as.numeric(as.character(x)))))

      if (is.null(control)) {
        kresult <- kcca(featuredf, initialK, family=family)
      }
      else {
        kresult <- kcca(featuredf, initialK, family=family, control=control)
      }
      res$clusterCount <<- initialK
      return(kresult)
    }
    
    res$clusters <- findFeatureClustering(df, threshold)
    clusters <- res$clusters
    
    # Initialize clustering maps
    res$maps <- new.env()
    for (i in 1:length(clusters@cluster)) {
      c <- clusters@cluster[i]
      varName <- paste("C", as.numeric(c), sep="")
      
      if (!exists(varName, envir=res$maps)) {
        evalStr <- paste(varName, " <- data.frame(clusters@centers[", as.numeric(c),",])", sep="")
        eval(parse(text=evalStr), envir=res$maps)
      }
      evalStr <- paste(varName, " <- cbind.data.frame(", varName,", ", names(c), "=df$", names(c), ")", sep="")
      eval(parse(text=evalStr), envir=res$maps)
    }
    
    # Calculate closest features to cluster centers
    clusterCenterFeatureIndexes <- NULL    
    for (i in 1:initialK) {
      evalStr <- paste("C", i, sep="")
      cmp <- eval(parse(text=evalStr), envir=res$maps)
      d <- data.frame(as.matrix(dist(t(cmp))))
      d <- d[order(d[,1]), ]
      id <- which(names(df) == rownames(d)[2])
      clusterCenterFeatureIndexes <- c(clusterCenterFeatureIndexes, id)
    }
    res$clusters <- clusters
    
    res$clusterCenterFeatureIndexes <- clusterCenterFeatureIndexes
    res$clusterCenterFeatures <- names(df)[clusterCenterFeatureIndexes]
    res$clusterCenterFeatureNames <- colnames(df[, clusterCenterFeatureIndexes])
    return(res)
  }
  
  if (initialK >= ncol(df)) {
    result$alldf <- df
    writeLogMessage(paste("Target number of predictors reached before clustering: ", ncol(result$alldf), sep=""))
    return(result)
  }
  
  result <- getUniqueFeatures(df, 0)
  result$alldf <- df[, result$clusterCenterFeatureNames]
  
  writeLogMessage(paste("Predictor names after cluster (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfClusterKccaKMeans <- function (df, initialK, outcomeCol) {
  return(genericKcca(df, initialK, outcomeCol, kccaFamily("kmeans"), list(initcent="kmeanspp")))
}

getPrunedTraindfClusterKccaKMedians <- function (df, initialK, outcomeCol) {
  return(genericKcca(df, initialK, outcomeCol, kccaFamily("kmedians"), list(initcent="kmeanspp")))
}

getPrunedTraindfClusterKccaJaccard <- function (df, initialK, outcomeCol) {
  return(genericKcca(df, initialK, outcomeCol, kccaFamily("jaccard"), list(initcent="kmeanspp")))
}

getPrunedTraindfClusterKccaKMeansWeightedDistance <- function (df, initialK, outcomeCol) {
  contributions <- rep(0, ncol(df))
  names(contributions) <- colnames(df)
  
  nTotalNotSel <- table(outcomeCol)[1]
  nTotalSel <- table(outcomeCol)[2]
  pTotalSel <- nTotalSel / nrow(df)
  i <- 1
  for (col in names(df)) {
    coldf <- data.frame(col = df[col], outcome = outcomeCol)
    seldf <- coldf[which(coldf$outcome != 0),]
    featseldf <- which(seldf[col] != 0)
    nSel <- length(featseldf)
    if (length(featseldf) != 0) {
      pSel <- nSel / length(which(coldf[col] != 0))
      diff <- pSel - pTotalSel
      contributions[col] <- contributions[col] + (diff * nTotalSel)
    }
    i <- i + 1
  }

  for (col in names(df)) {
    coldf <- data.frame(col = df[col], outcome = outcomeCol)
    seldf <- coldf[which(coldf$outcome != 0),]
    featseldf <- which(seldf[col] != 0)
    nSel <- length(featseldf)
    if (length(featseldf) != 0) {
      pSel <- nSel / length(which(coldf[col] != 0))
      diff <- pSel - pTotalSel
      contributions[col] <- contributions[col] + (diff * nTotalSel)
    }
    i <- i + 1
  }
  
  w <- rep(0, ncol(df))
  maxContribution <- max(contributions, na.rm=TRUE)
  for (i in 1:length(contributions)) {
    w[i] <- abs(contributions[i] / maxContribution)
  }
  
  family <- kccaFamily(dist=function (x, centers) 
  {
    if (ncol(x) != ncol(centers)) 
      stop(sQuote("x"), " and ", sQuote("centers"), " must have the same number of columns")
    z <- matrix(0, nrow = nrow(x), ncol = nrow(centers))
    for (k in 1:nrow(centers)) {
      z[, k] <- sqrt(colSums((w*(t(x) - centers[k, ]))^2))
    }
    z
  })
  return(genericKcca(df, initialK, outcomeCol, family, list(initcent="kmeanspp")))
}

getPrunedTraindfClusterImportanceGBM <- function(df, initialK, outcomeCol) {
  n <- (ncol(df) - initialK)
  result <- getPrunedTraindfCluster(df, max(initialK * 4, ncol(df) - (3 * n / 4)))
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    importanceSampleSize <- min(nrow(df), 1000)
    result <- getPrunedTraindfImportanceGBM(result$alldf[1:importanceSampleSize,], initialK, outcomeCol[1:importanceSampleSize])
    result$alldf <- result1$alldf[,names(result$alldf)]
    result$cluster <- result1
  }
  return(result)
}

getPrunedTraindfRandom <- function(df, initialK, outcomeCol) {
  result <- NULL
  result$alldf <- df[, sample(names(df), initialK)]
  writeLogMessage(paste("Predictor names after random (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfMRMR <- function(df, initialK, outcomeCol, solutionCount) {
  result <- NULL
  datadf <- convertToNumeric(cbind.data.frame(outcomeCol, df))
  dd <- mRMR.data(data = datadf)
  result$mRMR <- mRMR.ensemble(data = dd, target_indices = c(1), solution_count = solutionCount, feature_count = initialK)

  getPredictorNames <- function(index) {
    filters <- attr(result$mRMR, "filters")[[1]]
    if (index > ncol(filters)) {
      return(NULL)
    }
    return(names(df)[filters[,index]])
  }
  predictorNames <- getUniqueOrderedPredictors(getPredictorNames)
  predictorNames <- predictorNames[1:min(length(predictorNames), initialK)]
  predictorNames <- predictorNames[!is.na(predictorNames)]
  
  result$alldf <- df[, predictorNames]
  writeLogMessage(paste("Predictor names after minimum-redundancy maximum-relevancy (", ncol(result$alldf), "):", sep=""))
  writeLogMessage(names(result$alldf))
  return(result)
}

getPrunedTraindfMRMRClassic <- function(df, initialK, outcomeCol) {
  return(getPrunedTraindfMRMR(df, initialK, outcomeCol, 1))
}

getPrunedTraindfMRMREnsemble5 <- function(df, initialK, outcomeCol) {
  return(getPrunedTraindfMRMR(df, initialK, outcomeCol, 5))
}

getPrunedTraindfClusterMRMR <- function(df, initialK, outcomeCol) {
  result <- getPrunedTraindfCluster(df, initialK * 2, outcomeCol)
  if (initialK < ncol(result$alldf)) {
    result1 <- result
    result <- getPrunedTraindfMRMREnsemble5(result$alldf, initialK, outcomeCol)
    result$cluster <- result1
  }
  return(result)
}

removeColumnsHavingOneLevel <- function (df) {
  nc <- ncol(df)

  writeLogMessage(paste("Number of predictors before naming constant valued columns:", nc))
  
  df <- df[, sapply(df, nlevels) > 1]

  if (nc > ncol(df)) {
    writeLogMessage(paste((nc - ncol(df)), " predictors having constant value removed in training set", sep=""))
  }
  return(df)
}

initializePrunedFeatures <- function(traindf, selectionFunc, initialK, outcomeFeature, filteredFeatures, dummyFunc) {
  result <- NULL
  prunedTraindf <- traindf
  if (filteredFeatures != "") {
    prunedTraindf$Selected <- traindf[, outcomeFeature]
    prunedTraindf <- prunedTraindf[, !names(traindf) %in% grep(filteredFeatures, names(traindf), perl=TRUE, value=TRUE)]
  }

  prunedTraindf <- prunedTraindf[, !names(prunedTraindf) %in% grep("X_0|X0", names(prunedTraindf), perl=TRUE, value=TRUE)]

  fixedCols <- prunedTraindf[, 1:4]
  predictorCols <- prunedTraindf[, 5:ncol(prunedTraindf)]

  removeColumnsHavingOneLevel(predictorCols)

  result$featureNamesBeforeSelection <- colnames(predictorCols)
  result$dummyFunc <- dummyFunc
  if (!is.null(dummyFunc)) {
    writeLogMessage("Dummifying training set.")
    predictorCols <- dummyFunc(predictorCols)
  }

  predictorCols <- convertToFactors(predictorCols)

  d1 <<- predictorCols
  d2 <<- initialK
  d3 <<- prunedTraindf$Selected
  if (initialK < ncol(predictorCols)) {
    pruneResult <- selectionFunc(predictorCols, initialK, prunedTraindf$Selected)
  }
  else {
    writeLogMessage(paste("Feature selection was not required due to the desired number of selected features being greater than the number of actual features."))
    pruneResult <- NULL
    pruneResult$alldf <- predictorCols
  }

  result$featureNames <- sort(colnames(pruneResult$alldf))
  result$pruneResult <- predictorCols

  writeLogMessage(paste("Pruned number of predictors:", ncol(pruneResult$alldf)))
  result$traindf <- cbind(fixedCols, pruneResult$alldf)

  result$predictorNames <- result$featureNames[result$featureNames != "Selected"]
  result$outcomeName <- "Result"
  outcome <- ifelse(result$traindf[,"Selected"]!=0, "yes", "no")
  result$traindf[result$outcomeName] <- outcome

  result$trainControl <- initializeClassificationControl(result$traindf, 5)
  writeLogMessage(paste("Predictors and outcome initialized"))
  return(result)
}

initializeSamples <- function(df) {
  result <- NULL
  s <- sample(nrow(df), 0.75 * nrow(df))
  result$traindf <- df[s,]
  result$testdf <- df[-s,]
  result$alldf <- df
  return(result)
}

preprocessTestData <- function(trainingResult, testdf) {
  writeLogMessage("Pre-processing test data started.")
  testPredictorCols <- testdf[, trainingResult$featureSelection$featureNamesBeforeSelection]
  testPredictorCols <- data.frame(as.matrix(testPredictorCols))

  nc <- ncol(testPredictorCols)
  testPredictorCols <- testPredictorCols[, sapply(testPredictorCols, nlevels) > 1]

  if (nc > ncol(testPredictorCols)) {
    writeLogMessage(paste((nc - ncol(testPredictorCols)), " predictors with 1 levels removed in test set", sep=""))
  }
  predictorCols <- trainingResult$featureSelection$traindf[, (5:(ncol(trainingResult$featureSelection$traindf) - 1))]
  if (!is.null(trainingResult$featureSelection$dummyFunc)) {
    writeLogMessage("Dummifying.")
    testPredictorCols <- trainingResult$featureSelection$dummyFunc(testPredictorCols)
  }
  missingCols <- setdiff(names(predictorCols), names(testPredictorCols))
  for (col in missingCols) {
    testPredictorCols[col] = 0
  }
  testPredictorCols <- convertToFactors(testPredictorCols)
  testdf <- cbind(testdf[, 1:5], testPredictorCols)
  outcome <- ifelse(testdf[,"Selected"]!=0, "yes", "no")
  testdf[trainingResult$featureSelection$outcomeName] <- outcome
  writeLogMessage("Pre-processing test data finished.")
  return(testdf)
}

calculateMutualInformation <- function (df, predictors) {
  originaldf <- df
  
  extractPredictorsFunc <- function (df, predictors) {
    return (df[,predictors])
  }
  
  newdf <- try(extractPredictorsFunc(originaldf, predictors))
  if (inherits(newdf, "try-error")) {
    res <- 0
  } else {
    res <- condinformation(originaldf, newdf, method="emp")
  }
  return(res)
}

calculateMutualInformationWithFeature <- function (df, featureCol, predictors) {
  extractPredictorsFunc <- function (df, predictors) {
    return (df[,predictors])
  }
  
  newdf <- try(extractPredictorsFunc(df, predictors))
  if (inherits(newdf, "try-error")) {
    res <- 0
  } else {
    res <- condinformation(featureCol, newdf, method="emp")
  }
  return(res)
}

testClassificationModel <- function(trainingResult, testdfIn) {
  result <- NULL
  td0 <<- trainingResult
  td1 <<- testdfIn
  testdf <- preprocessTestData(trainingResult, testdfIn)
  predictorNames <- trainingResult$featureSelection$predictorNames
  outcomeName <- trainingResult$featureSelection$outcomeName
  traindf <- trainingResult$featureSelection$traindf
  if (!is.null(trainingResult$featureSelection$pruneResult$featureExtractor)) {
    td1 <<- testdf
    td2 <<- trainingResult
    testdfNew <- cbind.data.frame(testdf[,1:5], trainingResult$featureSelection$pruneResult$featureExtractor(testdf[,5:ncol(testdf)-1]))
    testdfNew[,outcomeName] = testdf[,outcomeName]
    testdf <- testdfNew
  }
  predTest <- predict(trainingResult$model, testdf[,predictorNames])
  predTrain <- predict(trainingResult$model, traindf[,predictorNames])
  result$correctTestP <- sum(predTest==testdf[,outcomeName])/nrow(testdf)
  result$correctTrainP <- sum(predTrain==traindf[,outcomeName])/nrow(traindf)
  result$testPredictions <- cbind.data.frame(predTest, testdf[,outcomeName])
  result$trainPredictions <- cbind.data.frame(predTrain, traindf[,outcomeName])
  writeLogMessage(paste(trainingResult$model$method, ": Correct in training set %:", 100 * result$correctTrainP, ", correct in test set %:", 100 * result$correctTestP))
  result$testcm <- confusionMatrix(data=predTest, ref=testdf[,outcomeName])
  result$traincm <- confusionMatrix(data=predTrain, ref=traindf[,outcomeName])

  alldf <- trainingResult$alldf
  predictorsdf <- alldf[,6:ncol(alldf)]
  result$mutualInformation <- calculateMutualInformation(predictorsdf, predictorNames)
  result$mutualInformationWithOutcome <- calculateMutualInformationWithFeature(predictorsdf, alldf$Selected, predictorNames)
#  result$mutualInformation <- NULL
#  result$mutualInformationWithOutcome <- NULL
  writeLogMessage(paste("Mutual information factors: all: ", result$mutualInformation, " outcome: ", result$mutualInformationWithOutcome, sep=""))

  return(result)
}

performTest <- function(df, selectionFunc, initialK, outcomeFeature, filteredFeatures, dummyFunc, seedValue) {
  set.seed(seedValue)
  result <- initializeSamples(df)
  featureSelectionFunc <- function() {
    result$featureSelection <<- initializePrunedFeatures(result$traindf, selectionFunc, initialK, outcomeFeature, filteredFeatures, dummyFunc)
  }
  result$featureSelectionDurations <- system.time(featureSelectionFunc())

  modelBuildingFunc <- function() {
    result$model <<- train(
      result$featureSelection$traindf[,result$featureSelection$predictorNames], 
      result$featureSelection$traindf[,result$featureSelection$outcomeName], 
      method="gbm", 
      metric="ROC", 
      trControl=result$featureSelection$trainControl)
  }
  set.seed(seedValue)
  result$modelBuildingDurations <- system.time(modelBuildingFunc())

  set.seed(seedValue)
  testFunc <- function() {
    result$testResult <<- testClassificationModel(result, result$testdf)
  }
  result$testDurations <- system.time(testFunc())
  return(result)
}

report <- function(res, includePredictors = FALSE) {
  cols <- c(
    "Phenomenon",
    "DataSetSize",
    "TestName",
    "Repeat #",
    "StartTime",
    "Algorithm", 
    "DummyFunc",
    "PredictorSets",
    "NumPredictors", 
    "CorrectPTest", 
    "CorrectPTrain", 
    "ProcTime",
    "ModelBuildTime",
    "TestProcTime",
    "MutualInformation",
    "MutualInformationOutcome",
    "# CM TP",
    "# CM TN",
    "# CM FP",
    "# CM FN",
    "Predictors")
  result <- data.frame(matrix(vector(), 0, length(cols),
                dimnames=list(c(), cols)),
                stringsAsFactors=F)
  for (i in 1:length(res$runs)) {
    r <- res$runs[[i]]
    if (is.null(r$error)) {
      result[nrow(result)+1,] <- c(
        r$phenomenon,
        r$dataSetSize,
        r$testName,
        r$rpt, 
        as.character(r$startTime),
        r$featureSelection$algorithm, 
        r$featureSelection$dummyVariableCreationFunction,
        r$featureSelection$initialPredictorSets,
        length(r$featureSelection$featureNames), 
        r$testResult$correctTestP,
        r$testResult$correctTrainP,
        r$featureSelectionDurations[3],
        r$modelBuildingDurations[3],
        r$testDurations[3],
        r$testResult$mutualInformation,
        r$testResult$mutualInformationWithOutcome,
        r$testResult$testcm$table[2,2],
        r$testResult$testcm$table[1,1],
        r$testResult$testcm$table[2,1],
        r$testResult$testcm$table[1,2],
        paste(r$featureSelection$featureNames, sep=",", collapse = ',')
      )
    }
    else {
      result[nrow(result)+1,] <- c(
        r$phenomenon,
        r$dataSetSize,
        r$testName,
        r$rpt, 
        as.character(r$startTime),
        r$featureSelection$algorithm, 
        r$featureSelection$dummyVariableCreationFunction, 
        r$featureSelection$initialPredictorSets,
        "<error>", 
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>",
        "<error>"
      )
    }
  }
  if (!includePredictors)
    result <- subset(result, select = -c(Predictors) )
  return(result)
}

resetResultRegistry <- function() {
  rr <<- NULL
  rr$runs <<- list()
}

selectFeatureSets <- function(featureSets, df) {
  allFeatures <- names(df)[6:ncol(df)]
  writeLogMessage(paste("Selecting predictor sets: ", featureSets, " out of ", length(allFeatures), " predictors", sep=""))
  resultFeatures <- names(df)[1:5]
  sets <- strsplit(featureSets, ",")[[1]]
  for (i in 1:length(sets)) {
    set <- sets[i]
    if (set == "task") {
      resultFeatures <- append(resultFeatures, grep("^X[0-9]+$", allFeatures, perl=TRUE, value=TRUE))
    }
    else if (set == "2gram") {
      resultFeatures <- append(resultFeatures, grep("^X[1-9][0-9]*_[1-9][0-9]*$", allFeatures, perl=TRUE, value=TRUE))
    }
    else if (set == "startend") {
      resultFeatures <- append(resultFeatures, grep("^X((0_[0-9]+|([0-9]+_0)))$", allFeatures, perl=TRUE, value=TRUE))
    }
    else if (set == "order") {
      resultFeatures <- append(resultFeatures, grep("^X[1-9][0-9]*\\.[1-9][0-9]*$", allFeatures, perl=TRUE, value=TRUE))
    }
  }
  result <- df[,resultFeatures]
  writeLogMessage(paste("Selected total of ", length(resultFeatures), " predictors", sep=""))
  return(result)
}

performTestSuite <- function(testName, paramdf, sampleSizes, numVars, selectionFuncNames, outcomeFeature, filteredFeatures, dummyFuncs, featureSetsToTest, numRepeats = 1, phenomenon = NULL, seedOffset = 0) {
  if (is.null(testName))
    testName <- "test"
  if (is.null(seedOffset))
    seedOffset <- 0
  filePrefix <- paste(logFileLocation, testName, "-", as.Date(Sys.time()), "-", format(Sys.time(), "%H%M%S"), sep="")
  logFile <- paste(filePrefix, ".csv", sep="")
  logMessageFile <- paste(filePrefix, ".txt", sep="")
  writeLogMessage(paste("Redirecting output to: ", logMessageFile, sep=""))
  sink(logMessageFile, split="TRUE")
  
  if (is.null(phenomenon)) {
    phenomenon <- "duration>7d"
  } else {
    tmp <- cbind.data.frame(Name=caseAttributeData$Name, Selected2=ifelse(caseAttributeData[,(which(colnames(caseAttributeData)==phenomenon[1]))]==phenomenon[2], 1, 0))
    tmp <- merge(paramdf, tmp, by="Name")
    paramdf$Selected <- tmp$Selected2
    paramdf$SelectedC <- ifelse(paramdf$Selected==1, "yes", "no")
    phenomenon <- paste(phenomenon[1], "=", phenomenon[2], sep="")
  }

  writeLogMessage(paste("Starting test set for outcome feature: ", outcomeFeature, " rows in full test data: ", nrow(paramdf), " filtered features: ", filteredFeatures, " phenomenon: ", phenomenon, sep=""))
  result <- NULL
  result$runs <- list()
  id <- 1
  
  if (is.null(dummyFuncs)) {
    dummyFuncs = c(NULL)
  }
  if (is.null(featureSetsToTest)) {
    featureSetsToTest = c("task,startend,2gram,order")
  }
  reportdf <- data.frame()
  totalIterationCount <- numRepeats * length(sampleSizes) * length(numVars) * length(selectionFuncNames) * length(dummyFuncs) * length(featureSetsToTest)
  for (r in 1:numRepeats) {
    for (s in 1:length(sampleSizes)) {
      df <- paramdf[1:(sampleSizes[s]),]
      writeLogMessage(paste("Starting tests for test data having ", nrow(df), " rows.", sep=""))
      for (v in numVars) {
        for (i in 1:length(selectionFuncNames)) {
          for (d in 1:length(dummyFuncs)) {
            for (f in 1:length(featureSetsToTest)) {
              result$runs <- list() # reset list to avoid excessive memory use

              featureSets <- featureSetsToTest[f]
              dummyFuncName <- dummyFuncs[d]
              if (is.null(dummyFuncName) || dummyFuncName == "") {
                dummyFunc <- NULL
                dummyFuncName <- "<none>"
              }
              else
                dummyFunc <- eval(parse(text=dummyFuncName))
              sFuncName <- selectionFuncNames[i]
              sFunc <- eval(parse(text=sFuncName))
              writeLogMessage(paste("Starting test #", id, "/", totalIterationCount ," using ", v, " features, selection function: ", sFuncName, ", dummy function: ", dummyFuncName, ", feature sets: ", featureSets, sep=""))
              res <- NULL
              startTime <- Sys.time()
              tdf <- selectFeatureSets(featureSets, df)
              
              testFunc <- function() {
                res <<- performTest(tdf, sFunc, v, outcomeFeature, filteredFeatures, dummyFunc, seed + r + seedOffset)
              }
              dur <- try(system.time(testFunc()))
              res$id <- id
              res$rpt <- r + seedOffset
              res$startTime <- startTime
              res$phenomenon <- phenomenon
              res$dataSetSize <- nrow(df)
              res$testName <- testName
              res$featureSelection$algorithm <- sFuncName
              res$featureSelection$dummyVariableCreationFunction <- dummyFuncName
              res$featureSelection$initialPredictorSets <- featureSets
              if (inherits(dur, "try-error")) {
                res$error <- dur
                res$stacktrace <- traceback()
              }
              else {
                res$durations <- dur
              }
              result$runs[[1]] <- res
              writeLogMessage(paste("Test finished for function ", sFuncName, ": elapsed=", dur[3], "", sep=""))
              dbg <<- result
              reportdf <- rbind.data.frame(reportdf, report(result, TRUE))

              write.csv(reportdf, logFile)
              id <- id + 1
            }
          }
        }
      }
    }
  }
  sink()
  return(result);
}

performTestSuiteIncludingDefaultPhenomenon <- function(testName, paramdf, sampleSizes, numVars, selectionFuncNames, outcomeFeature, filteredFeatures, dummyFuncs, featureSetsToTest, numRepeats = 1, phenomenon = NULL, seedOffset = 0) {
  if (!is.null(phenomenon)) {
    performTestSuite(testName, paramdf, sampleSizes, numVars, selectionFuncNames, outcomeFeature,
      filteredFeatures, dummyFuncs, featureSetsToTest, numRepeats, NULL, seedOffset)
  }
  performTestSuite(testName, paramdf, sampleSizes, numVars, selectionFuncNames, outcomeFeature,
    filteredFeatures, dummyFuncs, featureSetsToTest, numRepeats, phenomenon, seedOffset)
}

dummify <- function (df, createFeaturesForMoreThanNLevels = 0) {
  writeLogMessage(paste("Number of features before dummification: ", ncol(df), sep=""))
  predictorCols <- df
  trsf <- data.frame(predict(dummyVars(" ~ .", data = predictorCols, fullRank = T), newdata = predictorCols))
  writeLogMessage(paste("Number of features with dummies: ", ncol(trsf), sep=""))
  t <- convertToFactors(trsf)
  trsf <- trsf[, sapply(t, nlevels) > 1] # using trsf instead of t causes "incorrect number of dimensions"
  result <- convertToFactors(trsf)
  writeLogMessage(paste("Number of features after dummy creation: ", ncol(result), sep=""))
  if (createFeaturesForMoreThanNLevels != 0) {
    colsWithManyLevels <- names(predictorCols[, sapply(predictorCols, function(col) length(unique(col))) >= createFeaturesForMoreThanNLevels])
    for (col in 1:length(colsWithManyLevels)) {
      result <- (cbind.data.frame(result, ifelse(predictorCols[colsWithManyLevels[col]]!=0, 1, 0)))
    }
    writeLogMessage(paste("Number of features after adding multi level indicator cols: ", ncol(result), sep=""))
  }
  return(result);
}

dummyAddSeparateFeatureForMoreThanOneLevel <- function (df) {
  originalCols <- df
  predictorCols <- convertToNumeric(originalCols)
  writeLogMessage(paste("Number of predictors before adding indicators for 1, 2 and >2 visits:", ncol(originalCols)))
  colsWithManyRevisits <- names(predictorCols[, sapply(predictorCols, function(col) sum(ifelse(col == 1, 1, 0)) >= 1)])
  if (length(colsWithManyRevisits) > 0) {
    for (col in 1:length(colsWithManyRevisits)) {
      predictorCols <- (cbind.data.frame(predictorCols, ifelse(predictorCols[colsWithManyRevisits[col]]==1, 1, 0)))
      names(predictorCols)[ncol(predictorCols)] <- paste(colsWithManyRevisits[col],".1", sep="")
    }
    writeLogMessage(paste("Indicators added for features with exactly one visits: ", length(colsWithManyRevisits), sep=""))
  }

  colsWithManyRevisits <- names(predictorCols[, sapply(predictorCols, function(col) sum(ifelse(col == 2, 1, 0)) >= 1)])
  if (length(colsWithManyRevisits) > 0) {
    for (col in 1:length(colsWithManyRevisits)) {
      predictorCols <- (cbind.data.frame(predictorCols, ifelse(predictorCols[colsWithManyRevisits[col]]==2, 1, 0)))
      names(predictorCols)[ncol(predictorCols)] <- paste(colsWithManyRevisits[col],".2", sep="")
    }
    writeLogMessage(paste("Indicators added for features with exactly two visits: ", length(colsWithManyRevisits), sep=""))
  }

  colsWithManyRevisits <- names(predictorCols[, sapply(predictorCols, function(col) max(col) >= 3)])
  if (length(colsWithManyRevisits) > 0) {
    for (col in 1:length(colsWithManyRevisits)) {
      predictorCols <- (cbind.data.frame(predictorCols, ifelse(predictorCols[colsWithManyRevisits[col]]>=3, 1, 0)))
      names(predictorCols)[ncol(predictorCols)] <- paste(colsWithManyRevisits[col],".N", sep="")
    }
    writeLogMessage(paste("Indicators added for features with more than three visits: ", length(colsWithManyRevisits), sep=""))
  }
  
  predictorCols <- predictorCols[,!(names(predictorCols) %in% names(originalCols))]
  predictorCols <- convertToFactors(predictorCols)
  predictorCols <- removeColumnsHavingOneLevel(predictorCols)
  writeLogMessage(paste("Number of predictors after adding indicators for 1, 2 and >2 visits:", ncol(predictorCols)))
  return(predictorCols);
}

dummyOnly <- function(df) {
  dummify(df)
}

dummyAndCreateMultiLevelFeatures <- function(df) {
  dummify(df, 1)
}

resetResultRegistry()


########################################################################################
# Initialize test data
#loadDataset("rabobank-all-structural-features", "rabobank-case-attributes", "Selected", "SelectedC", ";")
#loadDataset("hospital-all-features", "", "Selected", "SelectedC", ",")
#loadDataset("BPIC13_incidents-all-features", "", "Selected", "SelectedC", ";")
#loadDataset("BPIC17_morethan5weeks-all-features", "", "Selected", "SelectedC", ";")
#loadDataset("BPIC12_morethan2weeks-all-features", "", "Selected", "SelectedC", ";")



########################################################################################
# Example for running actual tests

loadDataset("rabobank-all-structural-features", "rabobank-case-attributes", "Selected", "SelectedC", ";")
r <- performTestSuiteIncludingDefaultPhenomenon(
  "bpic14",
  traindf, 
  c(40000),
  c(10,30),
  c(
    "getPrunedTraindfCluster",
    "getPrunedTraindfClusterMRMR",
    "getPrunedTraindfClusterFisher",
    "getPrunedTraindfFisher",
    "getPrunedTraindfMRMREnsemble5"
  ),
  "Selected",
  "",
  c(""),
  c("task", "task,startend", "task,startend,2gram", "task,startend,order", "task,startend,2gram,order", "task,2gram", "task,2gram,order", "task,order", "2gram", "order", "2gram,order"),
  1
,  c("Category", "request for information")
)

loadDataset("BPIC12_morethan2weeks-all-features", "", "Selected", "SelectedC", ";")
r <- performTestSuite(
  "bpic12",
  traindf, 
  c(13087),
  c(10,30),
  c(
    "getPrunedTraindfCluster",
    "getPrunedTraindfClusterMRMR",
    "getPrunedTraindfClusterFisher",
    "getPrunedTraindfFisher",
    "getPrunedTraindfMRMREnsemble5"
  ),
  "Selected",
  "",
  c(""),
  c("task", "task,startend", "task,startend,2gram", "task,startend,order", "task,startend,2gram,order", "task,2gram", "task,2gram,order", "task,order", "2gram", "order", "2gram,order"),
  1
)
