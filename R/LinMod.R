


Conf <- function(x, ...) UseMethod("Conf")


Conf.table <- function(x, pos = NULL, ...) {

  CollapseConfTab <- function(x, pos = NULL, ...) {

    if(nrow(x) > 2) {
      names(attr(x, "dimnames")) <- c("pred", "obs")
      x <- CollapseTable(x, obs=c("neg", pos)[(rownames(x)==pos)+1],
                         pred=c("neg", pos)[(rownames(x)==pos)+1])
    }

    # order confusion table so
    # that the positive class is the first and the others keep their position
    ord <- c(pos, rownames(x)[-grep(pos, rownames(x))])
    # the columnnames must be the same as the rownames
    x <- as.table(x[ord, ord])
    return(x)
  }

  p <- (d <- dim(x))[1L]
  if(!is.numeric(x) || length(d) != 2L || p != d[2L]) {    # allow nxn!  || p != 2L)
    stop("'x' is not a nxn numeric matrix.")
    # print(x)
    # invisible()
  }

  # observed in columns, predictions in rows
  if(!identical(rownames(x), colnames(x)))
    stop("rownames(x) and colnames(x) must be identical")

  if(is.null(pos)) pos <- rownames(x)[1]
  if(nrow(x)!=2) {
    # ignore pos for nxn tables, pos makes only sense for sensitivity
    # and that is not defined for n-dim tables
    pos <- NULL

  } else {
    # order 2x2-confusion table so
    # that the positive class is the first and the others keep their position
    ord <- c(pos, rownames(x)[-grep(pos, rownames(x))])
    # the columnnames must be the same as the rownames
    x <- as.table(x[ord, ord])
  }

  # overall statistics first
  res <- list(
    table   = x,
    pos     = pos,
    diag    = sum(diag(x)),
    n       = sum(x)
  )
  res <- c(res,
           acc     = BinomCI(x=res$diag, n=res$n),
           sapply(binom.test(x=res$diag, n=res$n,
                             p=max(apply(x, 2, sum) / res$n),
                             alternative = "greater")[c("null.value", "p.value")], unname),
           kappa   = CohenKappa(x),
           mcnemar = mcnemar.test(x)$p.value
  )
  names(res) <- c("table","pos","diag","n","acc","acc.lci","acc.uci",
                  "nri","acc.pval","kappa","mcnemar.pval")

  # byclass
  lst <- list()
  for(i in 1L:nrow(x)){

    z <- CollapseConfTab(x=x, pos=rownames(x)[i])
    A <- z[1, 1]; B <- z[1, 2]; C <- z[2, 1]; D <- z[2, 2]

    lst[[i]] <- rbind(
      sens    = A / (A + C),                 # sensitivity
      spec    = D / (B + D),                 # specificity
      ppv     = A / (A + B),                 # positive predicted value
      npv     = D / (C + D),                 # negative predicted value
      prev    = (A + C) / (A + B + C + D),   # prevalence
      detrate = A / (A + B + C + D),         # detection rate
      detprev = (A + B) / (A + B + C + D),   # detection prevalence
      bacc    = mean(c(A / (A + C), D / (B + D)) ),  # balanced accuracy
      fval    = Hmean(c(A / (A + B), A / (A + C)), conf.level = NA) # guetemass wollschlaeger s. 150
    )
  }

  res <- c(res, byclass=list(do.call(cbind, lst)))
  colnames(res[["byclass"]]) <- rownames(x)

  if(nrow(x)==2) res[["byclass"]] <- res[["byclass"]][, res[["pos"]], drop=FALSE]

  class(res) <- "Conf"

  return(res)

}


Conf.default <-  function(x, ref, pos = NULL, na.rm = TRUE, ...) {
  if(na.rm) {
    idx <- complete.cases(data.frame(x, ref))
    x <- x[idx]
    ref <- ref[idx]
  }
  clvl <- CombLevels(x, ref)

  Conf.table(table(pred=factor(x, levels=clvl), obs=factor(ref, levels=clvl)), pos = pos, ...)
}

Conf.matrix <- function(x, pos = NULL, ...) {
  Conf.table(as.table(x), pos=pos, ...)
}


# the confusion interface for rpart
Conf.rpart <- function(x, ...){
  # y <- attr(x, "ylevels")
  Conf(x=attr(x,"ylevels")[x$frame$yval[x$where]],
       ref=attr(x,"ylevels")[x$y], ...)
}

Conf.multinom <- function(x, ...){
  if(is.null(x$model)) stop("x does not contain model. Run multinom with argument model=TRUE!")
  resp <- model.extract(x$model, "response")

  # attention: this will not handle correctly responses defined as dummy codes
  # adapt for that!!  ************************************************************
  # resp <- x$response[,1]

  pred <- predict(x, type="class")
  Conf(x=pred, resp, ... )
}


Conf.glm <- function(x, cutoff = 0.5, ...){
  resp <- model.extract(x$model, "response")
  if(is.factor(resp)){
    pred <- levels(resp)[(predict(x, type="response") > cutoff)+1]
  } else {
    pred <- levels(factor(resp))[(predict(x, type="response") > cutoff)+1]
  }
  Conf(x=pred, ref=resp, ... )
}


Conf.randomForest <- function(x, ...){
  Conf(x=x$predicted, ref=x$y, ... )
}


Conf.svm <- function(x, ...){

# old:  Conf(x=predict(x), ref=model.extract(model.frame(x), "response"), ... )
  Conf(x=predict(x, type="class"), ref=model.response(model.frame(x)), ... )
}


Conf.lda <- function(x, ...){

  # extract response from the model

  Conf(x=predict(x)$class,
       ref=model.extract(model.frame(x), "response") , ... )
}

Conf.qda <- function(x, ...){
  Conf(x=predict(x)$class,
       ref=model.extract(model.frame(x), "response") , ... )
}



Conf.regr <- function(x, ...){
  NextMethod()
  # Conf(x=Predict(x, type="class"), reference=x$response[,], ... )
}



plot.Conf <- function(x, main="Confusion Matrix", ...){
  mosaicplot(t(x$table), shade=TRUE, main=main, col=c("red", "green"), ...)
}


print.Conf <- function(x, digits = max(3, getOption("digits") - 3), ...) {
  cat("\nConfusion Matrix and Statistics\n\n")

  names(attr(x$table, "dimnames")) <- c("Prediction","Reference")
  print(x$table, ...)

  if(nrow(x$table)!=2) cat("\nOverall Statistics\n")

  txt <- gettextf("
               Accuracy : %s
                 95%s CI : (%s, %s)
    No Information Rate : %s
    P-Value [Acc > NIR] : %s

                  Kappa : %s
 Mcnemar's Test P-Value : %s\n\n",
                  Format(x$acc, digits=digits), "%",
                  Format(x$acc.lci, digits=digits), Format(x$acc.uci, digits=digits),
                  Format(x$nri, digits=digits), Format(x$acc.pval, fmt="p", na.form="NA"),
                  Format(x$kappa, digits=digits), Format(x$mcnemar.pval, fmt="p", na.form="NA")
                  )
  cat(txt)

  rownames(x$byclass) <- c("Sensitivity", "Specificity", "Pos Pred Value", "Neg Pred Value", "Prevalence",
                           "Detection Rate", "Detection Prevalence", "Balanced Accuracy","F-val Accuracy")

  if(nrow(x$table)==2){
    cat(
      paste(StrPad(paste(rownames(x$byclass), ":"), width=25, adj = "right"),
            Format(x$byclass, digits=digits))
      , sep="\n")

    txt <- gettextf("\n       'Positive' Class : %s\n\n", x$pos)
    cat(txt)

  } else {

    cat("\nStatistics by Class:\n\n")
    print(Format(x$byclass, digits = digits, na.form="NA"), quote = FALSE)
    cat("\n")

  }

}



Sens <- function(x, ...) Conf(x, ...)[["byclass"]]["sens",]

Spec <- function(x, ...) Conf(x, ...)[["byclass"]]["spec",]




PseudoR2 <- function(x, which = NULL) {

  # this function will not work with weights, neither with cbind lhs!!
  # http://stats.stackexchange.com/questions/183699/how-to-calculate-pseudo-r2-when-using-logistic-regression-on-aggregated-data-fil

  # test: https://stats.idre.ucla.edu/other/mult-pkg/faq/general/faq-what-are-pseudo-r-squareds/
  # library(haven)
  # hsb2 <- as.data.frame(read_dta("https://stats.idre.ucla.edu/stat/stata/notes/hsb2.dta"))
  # hsb2$honcomp <- hsb2$write >= 60
  # r.logit <- glm(honcomp ~ female + read + science, hsb2, family="binomial")
  # PseudoR2(r.logit, "a")



  # http://digitalcommons.wayne.edu/cgi/viewcontent.cgi?article=2150&context=jmasm
  # Walker, Smith (2016) JMASM36: Nine Pseudo R^2 Indices for Binary Logistic Regression Models (SPSS)
  # fuer logit Korrektur https://langer.soziologie.uni-halle.de/pdf/papers/rc33langer.pdf

  # check with pscl::pR2(x); rcompanion::nagelkerke(x)


  if (!(inherits(x, what="glm") || inherits(x, what="polr")
        || inherits(x, what = "multinom") || inherits(x, what = "vglm")))
    return(NA)


  if (!(inherits(x, what="vglm")) && !is.null(x$call$summ) && !identical(x$call$summ, 0))
    stop("can NOT get Loglik when 'summ' argument is not zero")

  L.full <- logLik(x)
  D.full <- -2 * L.full # deviance(x)

  if(inherits(x, what="multinom"))
    L.base <- logLik(update(x, ~1, trace=FALSE))
  else
    L.base <- logLik(update(x, ~1))

  D.base <- -2 * L.base # deviance(update(x, ~1))
  G2 <- -2 * (L.base - L.full)

  # n <- if(length(weights(x)))
  #   sum(weights(x))
  # else
  n <- attr(L.full, "nobs")   # alternative: n <- dim(x$residuals)[1]


  if(inherits(x, "multinom"))
    edf <- x$edf
  else if(inherits(x, "vglm")){
    edf <- x@rank
    n <- nobs(x)  # logLik does not return nobs for vglm
  } else
    edf <- x$rank

  # McFadden
  McFadden <- 1 - (L.full/L.base)
  # adjusted to penalize for the number of predictors (k) in the model
  McFaddenAdj <- 1 - ((L.full - edf)/L.base)

  # Nagelkerke / CraggUhler
  Nagelkerke <- (1 - exp((D.full - D.base)/n))/(1 - exp(-D.base/n))

  # CoxSnell / Maximum Likelihood R2
  CoxSnell <- 1 - exp(-G2/n)

  res <- c(McFadden=McFadden, McFaddenAdj=McFaddenAdj,
           CoxSnell=CoxSnell, Nagelkerke=Nagelkerke, AldrichNelson=NA,
           VeallZimmermann=NA,
           Effron=NA, McKelveyZavoina=NA, Tjur=NA,
           AIC=AIC(x), BIC=BIC(x), logLik=L.full, logLik0=L.base, G2=G2)


  if(inherits(x, what="glm") || inherits(x, what="vglm") ) {

    if(inherits(x, what="vglm")){
      fam <- x@family@vfamily
      link <- if(all(x@extra$link == "logit")){
                  "logit"
                } else if(all(x@extra$link == "probit")){
                  "probit"
                } else {
                  NA
                }
      y <- x@y

    } else {
      fam <- x$family$family
      link <- x$family$link
      y <- x$y
    }


    s2 <- switch(link, probit = 1, logit = pi^2/3, NA)

    # Aldrich/Nelson
    res["AldrichNelson"] <- G2 / (G2 + n * s2)

    # Veall/Zimmermann
    res["VeallZimmermann"] <- res["AldrichNelson"] * (2*L.base - n * s2)/(2*L.base)


    # McKelveyZavoina
    y.hat <- predict(x)
    sse <- sum((y.hat - mean(y.hat))^2)
    res["McKelveyZavoina"] <- sse/(n * s2 + sse)

    # EffronR2
    y.hat.resp <- predict(x, type="response")
    res["Effron"] <- (1 - (sum((y - y.hat.resp)^2)) /
                        (sum((y - mean(y))^2)))

    # Tjur's D
    # compare with binomTools::Rsq.glm()
    if(identical(fam, "binomial"))
      res["Tjur"] <- unname(diff(tapply(y.hat.resp, y, mean, na.rm=TRUE)))

  }


  if(is.null(which))
    which <- "McFadden"
  else
    which <- match.arg(which, c("McFadden","AldrichNelson","VeallZimmermann","McFaddenAdj", "CoxSnell", "Nagelkerke",
                                "Effron", "McKelveyZavoina", "Tjur","AIC", "BIC", "logLik", "logLik0","G2","all"),
                       several.ok = TRUE)

  if(any(which=="all"))
    return(res)
  else
    return(res[which])

}




BrierScore <- function(...){
  UseMethod("BrierScore")
}


BrierScore.default <- function(resp, pred, scaled = FALSE, ...){

  res <- mean(resp * (1-pred)^2 + (1-resp) * pred^2)

  if(scaled){
    mean_y <- mean(resp)

    Bmax <- mean_y * (1-mean_y)^2 + (1-mean_y) * mean_y^2
    res <- 1 - res/Bmax
  }

  return(res)

}


BrierScore.glm <- function(x, scaled = FALSE, ...){
  BrierScore.default(resp=x$y, pred=predict(x, type="response"), scaled = scaled)
}


BrierScore.mult <- function(x, scaled=FALSE, ...){

  # https://en.wikipedia.org/wiki/Brier_score

  ref <- model.response(model.frame(x))
  res <- mean(apply((Dummy(ref, method = "full") - predict(x, type="prob"))^2, 1, sum))

  # check for reference, this is not correct!!
  # if(scaled){
  #   mean_y <- mean(x)
  #
  #   Bmax <- mean_y * (1-mean_y)^2 + (1-mean_y) * mean_y^2
  #   res <- 1 - res/Bmax
  # }

  return(res)

}


# Cstat <- function(x){
#
#   y <- as.numeric(factor(model.response(x$model)))
#
#   probs <- predict(x, type = "response")
#   d.comb <- expand.grid(pos = probs[y == 2L],
#                         neg = probs[y == 1L])
#
#   mean(d.comb$pos > d.comb$neg)
#
# }


Cstat <- function (x, ...)
  UseMethod("Cstat")


Cstat.glm <- function(x, ...) {
  Cstat.default(predict(x, type = "response"), model.response(x$model))
}


Cstat.default <- function(x, resp, ...) {

  # the response ("class")
  y <- as.numeric(factor(resp))

  prob <- x # predicted probs
  d.comb <- expand.grid(pos = prob[y == 2L],
                        neg = prob[y == 1L])

  mean(d.comb$pos > d.comb$neg)

}



MAE <- function(x, ...) UseMethod("MAE")

MAE.lm <- function(x, ...)
  # regr will escalate to lm, so no need for another interface here
  MAE(predict(x), model.response(x$model), na.rm=FALSE)

MAE.default <- function (x, ref, na.rm=FALSE, ...) {
  # mean will bark, if there are NAs, so no need to do here anyhing further
  # (the difference will report NAs anyway)
  mean(abs(ref-x), na.rm=na.rm)
}

MSE <- function(x, ...) UseMethod("MSE")

MSE.lm <- function(x, ...)
  # regr will escalate to lm, so no need for another interface here
  MSE(predict(x), model.response(x$model), na.rm=FALSE)

MSE.default <- function (x, ref, na.rm=FALSE, ...) {
  mean((ref-x)^2, na.rm=na.rm)
}

RMSE <- function(x, ...) UseMethod("RMSE")

RMSE.lm <- function(x, ...)
  # regr will escalate to lm, so no need for another interface here
  RMSE(predict(x), model.response(x$model), na.rm=FALSE)


RMSE.default <- function (x, ref, na.rm=FALSE, ...) {
  sqrt(MSE(x, ref, na.rm))
}


MAPE <- function(x, ...) UseMethod("MAPE")

MAPE.lm <- function(x, ...)
  # regr will escalate to lm, so no need for another interface here
  MAPE(predict(x), model.response(x$model), na.rm=FALSE)

MAPE.default <- function (x, ref, na.rm=FALSE, ...) {
  # mean will bark, if there are NAs, so no need to do here anyhing further
  # (the difference will report NAs anyway)
  mean(abs((ref-x)/ref), na.rm=na.rm)
}


SMAPE <- function(x, ...) UseMethod("SMAPE")

SMAPE.lm <- function(x, ...)
  # regr will escalate to lm, so no need for another interface here
  SMAPE(predict(x), model.response(x$model), na.rm=FALSE)

SMAPE.default <- function (x, ref, na.rm=FALSE, ...) {

  mean( 2 * abs(ref-x) / (abs(x) + abs(ref)) )
}

# Chen and Yang (2004), in an unpublished working paper, defined the sMAPE as
# \[\text{sMAPE} = \text{mean}(2|y_t - \hat{y}_t|/(|y_t| + |\hat{y}_t|)).\]
# They still called it a measure of "percentage error" even though they dropped the multiplier 100.
# At least they got the range correct, stating that this measure has a maximum value of two when
# either y_t or \hat{y}_t is zero, but is undefined when both are zero.
# The range of this version of sMAPE is (0,2). Perhaps this is the definition that Makridakis and
# Armstrong intended all along, although neither has ever managed to include it correctly
# in one of their papers or books.
# source: http://robjhyndman.com/hyndsight/smape/



NMSE <- function(x, ref, train.y){
  sse <- sum((ref-x)^2)
  sse/sum((ref-mean(train.y))^2)
}

NMAE <- function(x, ref, train.y){
  sae <- sum(abs(ref-x))
  sae/sum(abs(ref-mean(train.y)))
}



VIF <- function(mod, ...) {

  # original from car: Henric Nilsson and John Fox

  if (any(is.na(coef(mod))))
    stop ("there are aliased coefficients in the model")

  v <- vcov(mod)
  assign <- attr(model.matrix(mod), "assign")
  if (names(coefficients(mod)[1]) == "(Intercept)") {
    v <- v[-1, -1]
    assign <- assign[-1]
  }
  else warning("No intercept: vifs may not be sensible.")

  terms <- labels(terms(mod))
  n.terms <- length(terms)

  if (n.terms < 2) stop("model contains fewer than 2 terms")

  R <- cov2cor(v)

  detR <- det(R)
  result <- matrix(0, n.terms, 3)
  rownames(result) <- terms
  colnames(result) <- c("GVIF", "Df", "GVIF^(1/(2*Df))")

  for (term in 1:n.terms) {
    subs <- which(assign == term)
    result[term, 1] <- det(as.matrix(R[subs, subs])) *
      det(as.matrix(R[-subs, -subs])) / detR
    result[term, 2] <- length(subs)
  }

  if (all(result[, 2] == 1)) result <- result[, 1]
  else result[, 3] <- result[, 1]^(1/(2 * result[, 2]))
  result
}

# ????
# this will presumably not be found without a S3method declaration, but John doesn't declare it either
model.matrix.gls <- function(object, ...){
  model.matrix(formula(object), data=eval(object$call$data))
}





ModSummary <- function(x, ...){
  UseMethod("ModSummary")
}


ModSummary.lm <- function(x, conf.level=0.95, ...){


  smrx <- summary(x)

  #coefx <- cbind(smrx$coefficients, confint(x, level=conf.level), stbeta=c(NA, StdCoeff(x)))
  coefx <- data.frame(rownames(smrx$coefficients), smrx$coefficients, confint(x, level=conf.level),
                      stringsAsFactors = FALSE)
  colnames(coefx) <- c("name","est","se","stat","p","lci","uci")

  fit <- x$fitted.values
  y <- model.response(x$model)

  statsx <- c(with(smrx, c(
    sigma         = sigma,
    r.squared     = r.squared,
    adj.r.squared = adj.r.squared,
    F             = F,
    numdf         = fstatistic[[2]],
    dendf         = fstatistic[[3]],
    p             = pf(F, fstatistic[[2]], fstatistic[[3]], lower.tail=FALSE),
    N             = sum(df[1:2])
  )),
  logLik        = logLik(x),
  deviance      = deviance(x),
  AIC           = AIC(x),
  BIC           = BIC(x),
  MAE           = MAE(x=fit, ref = y),
  MAPE          = MAPE(x=fit, ref = y),
  MSE           = MSE(x=fit, ref = y),
  RMSE          = RMSE(x=fit, ref = y)
  )

  list(coef=coefx, ncoef=length(x$coefficients), statsx=statsx, contrasts=x$contrasts, xlevels=x$xlevels, call=x$call)

}




ModSummary.glm <- function(x, conf.level=0.95, ...){

  sumry <- summary(x)

  # coefx <- cbind(summod$coefficients, confint(x, level=conf.level), stbeta=c(NA, StdCoeff(x)))
  ci <- confint(x, level=conf.level)
  if(nrow(sumry$coefficients)==1)
    ci <- t(ci)
  coefx <- data.frame(row.names(sumry$coefficients), sumry$coefficients, ci,
                      stringsAsFactors = FALSE)
  colnames(coefx) <- c("name", "est","se","stat","p","lci","uci")

  pred <- x$fitted.values
  y <- model.response(x$model)


  N <- if(length(weights(x))) {
    sum(weights(x), na.rm=TRUE)
  } else {
    sum(sumry$df[1:2])
  }

  phi <- sumry$dispersion
  degf <- sumry$df.null - sumry$df.residual

  # if(degf > 0){
  LR <- sumry$null.deviance - sumry$deviance
  p <- pchisq(LR, degf, lower.tail=FALSE)
  L0.pwr <- exp(-sumry$null.deviance / N)


  if(x$family$family == "binomial"){

    statsx <- PseudoR2(x, which = "all")
    statsy <- .assocs_condis(pred, model.response(x$model))

    statsx <- c(statsx,
             "Kendall Tau-a" = unname(statsy["taua"]),
             "Somers Delta" = unname(statsy["somers_r"]),
             "Gamma" = unname(statsy["gamma"]),
             "Brier" = BrierScore(x), "C"= Cstat(x)
    )
  } else {

    statsx <- PseudoR2(x, which =c("McFadden","McFaddenAdj","Nagelkerke","CoxSnell",
                                "AIC","BIC","logLik",
                                "logLik0", "G2"))

    statsx <- c(statsx[],
             "MAE" = MAE(pred, model.response(x$model)),
             "MAPE" = MAPE(pred, model.response(x$model)),
             "MSE" = MSE(pred, model.response(x$model)),
             "RMSE" = RMSE(pred, model.response(x$model))

    )
  }

  # L0.pwr        = exp(-summod$null.deviance / N),
  # logLik        = logLik(x),
  # deviance      = deviance(x),


  list(coef=coefx, ncoef=length(x$coefficients), statsx=statsx, contrasts=x$contrasts, xlevels=x$xlevels, call=x$call)

}


TMod <- function(..., FUN = NULL){


  # prepare function to put together coefficients and stats
  if(is.null(FUN))
    FUN <- function(est, se, tval, pval, lci, uci){
      gettextf("%s %s",
               Format(est, fmt=Fmt("num")),
               Format(pval, fmt="*"))
    }


  to.frame <- function(x){
    res <- data.frame(names(x), x)
    colnames(res) <- c("name", "val")
    res
  }


  modname <- unlist(lapply(match.call(expand.dots=FALSE)$..., as.character))

  lmod <- list(...)
  lst <- lapply(lmod, ModSummary)

  modname[names(lst) != ""] <- names(lst)[names(lst) != ""]

  lcoef <- lapply(lst, "[[", "coef")
  lstatsx <- lapply(lst, "[[", "statsx")


  # merge coefficients of all models
  m <- lcoef[[1]][, c("name", "est")]
  m$est <- apply(lcoef[[1]][,-1], 1, function(x) FUN(x["est"], x["se"], x["stat"], x["p"], x["lci"], x["uci"]))
  colnames(m) <- c("name", modname[1])

  if(length(lcoef)>1) {
    for(i in 2L:length(lcoef)){
      m2 <- lcoef[[i]][, c("name", "est")]
      m2$est <- apply(lcoef[[i]][,-1], 1, function(x) FUN(x["est"], x["se"], x["stat"], x["p"], x["lci"], x["uci"]))
      m <- merge(x=m, y=m2, by.x="name", by.y="name", all.x=TRUE, all.y=TRUE)
      colnames(m)[i+1] <- modname[i]
    }
  }
  colnames(m)[1] <- "coef"

  # merge statistics of all models
  mm <- to.frame(lstatsx[[1]])
  colnames(mm) <- c("name", modname[1])
  if(length(lstatsx) > 1){
    for(i in 2L:length(lstatsx)){
      mm <- merge(x=mm, y=to.frame(lstatsx[[i]]), by.x="name", by.y="name", all.x=TRUE, all.y=TRUE)
      colnames(mm)[i+1] <- modname[i]
    }
  }
  colnames(mm)[1] <- "stat"

  row.names(mm) <- mm$stat
  mm <- mm[match(c("r.squared", "adj.r.squared","sigma","logLik","logLik0","G2","deviance",
             "AIC","BIC","numdf","dendf","N","F","p","MAE","MAPE","MSE","RMSE","McFadden",
             "McFaddenAdj","Nagelkerke","CoxSnell","Kendall Tau-a","Somers Delta","Gamma","Brier","C"),
             rownames(mm))
           , ]
  mm <- mm[!is.na(mm$stat), ]

  row.names(mm) <- NULL

  return(structure(list(m, mm), class="TMod"))


}


print.TMod <- function(x, ...){

  x[[1]][, -1] <- Format(x[[1]][, -1], digits=3, na.form = "-")
  x[[2]][, -1] <- Format(x[[2]][, -1], digits=3, na.form = "-")

  m <- rbind(x[[1]],  setNames(c("---", rep("", ncol(x[[1]]) -1)), colnames(x[[1]])),
             setNames(x[[2]], colnames(x[[1]])))

  m[, -1] <- apply(m[, -1, drop=FALSE], 2, StrAlign, sep=".")
  row.names(m) <- NULL
  print(m, ...)

}


ToWrd.TMod <- function(x, font=NULL, para=NULL, main=NULL, align=NULL,
                       autofit=TRUE, ..., wrd=DescToolsOptions("lastWord")) {
  m <- FixToTable(capture.output(x))
  if(is.null(align))
    align <- "l"
  wt <- ToWrd.matrix(x=m, font=font, para=para, main=main, align=align, autofit=autofit, ..., wrd=wrd)

  # insert decimal tabs
# Selection.ParagraphFormat.TabStops(CentimetersToPoints(1.14)).Position = CentimetersToPoints(1.14)
# Selection.TypeText Text:=vbTab

}







.partialsd <- function(x, sd, vif, n, p = length(x) - 1) {
    sd * sqrt(1 / vif) * sqrt((n - 1)/(n - p))
}


PartialSD <- function(x) {

  mm <- model.matrix(x)
  .partialsd(coef(x), apply(mm, 2L, sd), VIF(x), nobs(x),
             sum(attr(mm, "assign") != 0))

}

`coeffs` <-
  function (model) UseMethod("coeffs")

`coeffs.multinom` <-
  function (model) {
    cf <- coef(model)
    if (!is.vector(cf)) {
      cf <- t(as.matrix(cf))
      cfnames <- expand.grid(dimnames(cf), stringsAsFactors = FALSE)
      cfnames <- sprintf("%s(%s)", cfnames[,2L], cfnames[,1L])
      structure(as.vector(cf), names = cfnames)
    } else cf
  }

`coeffs.survreg` <-
  function (model) {
    rval <- coef(model)
    if (nrow(vcov(model)) > length(rval)) { # scale was estimated
      lgsc <- log(model$scale)
      names(lgsc) <- if(is.null(names(lgsc)))
        "Log(scale)" else
          paste0("Log(scale):", names(lgsc))
      rval <- c(rval, lgsc)
    }
    rval
  }

`coeffs.default` <-
  function(model) coef(model)


`coefTable` <-
  function (model, ...) UseMethod("coefTable")

.makeCoefTable <-
  function(x, se, df = NA_real_, coefNames = names(x)) {
    if(n <- length(x)) {
      xdefined <- !is.na(x)
      ndef <- sum(xdefined)
      if(ndef < n) {
        if(length(se) == ndef) {
          y <- rep(NA_real_, n); y[xdefined] <- se; se <- y
        }
        if(length(df) == ndef) {
          y <- rep(NA_real_, n); y[xdefined] <- df; df <- y
        }
      }
    }
    if(n && n != length(se)) stop("length(x) is not equal to length(se)")
    ret <- matrix(NA_real_, ncol = 3L, nrow = length(x),
                  dimnames = list(coefNames, c("Estimate", "Std. Error", "df")))
    if(n) ret[, ] <- cbind(x, se, rep(if(is.null(df)) NA_real_ else df,
                                      length.out = n), deparse.level = 0L)
    class(ret) <- c("coefTable", "matrix")
    ret
  }

`coefTable.default` <-
  function(model, ...) {
    dfs <- tryCatch(df.residual(model), error = function(e) NA_real_)
    cf <- summary(model, ...)$coefficients
    .makeCoefTable(cf[, 1L], cf[, 2L], dfs, coefNames = rownames(cf))
  }

`coefTable.lm` <-
  function(model, ...)
    .makeCoefTable(coef(model), sqrt(diag(vcov(model, ...))), model$df.residual)


`coefTable.survreg` <-
  function(model, ...) {
    .makeCoefTable(
      coeffs(model),
      sqrt(diag(vcov(model, ...))),
      NA
    )
  }

`coefTable.coxph` <-
  function(model, ...) {
    .makeCoefTable(coef(model), if(all(is.na(model$var)))
      rep(NA_real_, length(coef(model))) else sqrt(diag(model$var)),
      model$df.residual)
  }

`coefTable.multinom` <-
  function (model, ...) {
    .makeCoefTable(coeffs(model), sqrt(diag(vcov(model, ...))))
  }

`coefTable.zeroinfl` <-
  function(model, ...)
    .makeCoefTable(coef(model), sqrt(diag(vcov(model, ...))))

`coefTable.hurdle` <-
  function(model, ...) {
    cts <- summary(model)$coefficients
    ct <- do.call("rbind", unname(cts))
    cfnames <- paste0(rep(names(cts), vapply(cts, nrow, 1L)), "_", rownames(ct))
    .makeCoefTable(ct[, 1L], ct[, 2L], coefNames = cfnames)
    #.makeCoefTable(coef(model), sqrt(diag(vcov(model, ...))))
  }




StdCoef <- function(x, partial.sd = FALSE, ...) {

  coefmat <- coefTable(x, ...)

  mm <- model.matrix(x)

  if(partial.sd) {
    bx <- .partialsd(coefmat[, 1L], apply(mm, 2L, sd),
                     VIF(x), nobs(x), sum(attr(mm, "assign") != 0))
  } else {
    response.sd <- sd(model.response(model.frame(x)))
    bx <- apply(mm, 2L, sd) / response.sd
  }
  coefmat[, 1L:2L] <- coefmat[, 1L:2L] * bx
  colnames(coefmat)[1L:2L] <- c("Estimate*", "Std. Error*")
  return (coefmat)

}





