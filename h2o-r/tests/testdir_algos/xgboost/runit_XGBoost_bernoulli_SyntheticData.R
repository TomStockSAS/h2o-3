setwd(normalizePath(dirname(R.utils::commandArgs(asValues=TRUE)$"f")))
source("../../../scripts/h2o-r-test-setup.R")
#   This test is to check bernoulli xgboost implementation, 
#   It creates a synthetic dataset, runs xgboost grid in H2O and R and compares aucs




test.XGBoost.bernoulli.SyntheticData <- function() {

    #   Generate dataset
    # http://www.stat.missouri.edu/~speckman/stat461/boost.R
    set.seed(3719)

    n <- 2000
    #  Generate variables V1, ... V10
    X <- matrix(rnorm(10*n), n, 10)
    #  y = +1 if sum_i x_{ij}^2 > chisq median on 10 df
    y <- rep(-1, n)
    y[apply(X*X, 1, sum) > qchisq(.5, 10)] <- 1

    #  Assign names to the columns of X:
    dimnames(X)[[2]] <- c("V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10")

    #  Convert to data.frame
    train.data <- as.data.frame(X)
    #  Add y
    train.data$y <- y

    #  Now repeat for 10000 test data
    n <- 10000
    X <- matrix(rnorm(10*n), n, 10)
    y <- rep(-1, n)
    y[apply(X*X, 1, sum) > qchisq(.5, 10)] <- 1
    dimnames(X)[[2]] <- c("V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10")
    test.data <- as.data.frame(X)
    test.data$y <- y

    #  Need to put training and test data together for xgboost below and convert
    #  to 0-1 data

    train.data2 <- train.data
    train.data2$y[train.data2$y < 0] <- 0
    test.data2 <- test.data
    test.data2$y[test.data2$y < 0] <- 0
    all.data2 <- rbind(train.data2, test.data2)

    #  Parse data to H2O
    print("Parse data to H2O")
    system.time(alldata <- as.h2o(all.data2, destination_frame = "alldata"))
    system.time(test <- as.h2o(test.data2, destination_frame = "test"))

    str(alldata)

    myX <- c("V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10")
    myY <- "y"
    test[,myY] <- as.factor(test[,myY])
    alldata[,myY] <- as.factor(alldata[,myY])

    #  Run H2O-XGBoost grid job
    print("H2O XGBoost grid search")
    grid_space <- list()
    grid_space$ntrees <- c(5)
    grid_space$min_rows <- c(2)
    grid_space$max_depth <- c(1,2,3)
    grid_space$learn_rate <- c(1,.1)
# No nbins in XGBoost!    grid_space$nbins <- c(20)
    grid_space$distribution <- "bernoulli"
    system.time(tru.xgboost <- h2o.grid("xgboost", x = myX, y = myY, training_frame = alldata, hyper_params = grid_space))

    num_models <- length(tru.xgboost@model_ids)
    print(paste("Number of xgboost models created:", num_models,sep ='') )
    expect_equal(num_models,6)
    print("XGBoost models summary")
    print(tru.xgboost)
    
}
doTest("XGBoost Grid Test: Synthetic dataset with Bernoulli distribution H2O vs R", test.XGBoost.bernoulli.SyntheticData)
