
#################################################################
## Functions calculating evaluation metrics
#################################################################


# =====================================================================
# Function to calculate some standard regression evaluation statistics
# ---------------------------------------------------------------------
# L. Torgo (2009)
#
# Examples:
# s <- regressionMetrics(tr,ps,train.y=data[,'Y'])
# s <- regressionMetrics(tr,ps,metrics=c('mse','mae'))
#
regressionMetrics <- function(trues,preds,
                              metrics=NULL,
                              train.y=NULL)
{
    ## Checking preds
    if (!is.null(dim(preds))) stop("regressionMetrics:: expecting a vector as predictions.")

    ## Cheking the statistics
    knownMetrics <- c('mae','mse','rmse','mape','nmse','nmae','theil')
    if (is.null(metrics))  # user wants all available metrics
        metrics <- if (is.null(train.y)) setdiff(knownMetrics,c("nmse","nmae")) else knownMetrics
    
    if (any(c('nmse','nmad') %in% metrics) && is.null(train.y))
        stop('regressionMetrics:: train.y parameter not specified.',call.=FALSE)
    if (!all(metrics %in% knownMetrics))
        stop("regressionMetrics:: don't know how to calculate -> ",call.=FALSE,
             paste(metrics[which(!(metrics %in% knownMetrics))],collapse=','))

    ## copying with missing predictions
    if (length(preds) != length(trues)) {
        warning("regressionMetrics:: less predictions than test cases, filling with NAs.")
        t <- trues
        t[] <- NA
        t[names(preds)] <- preds
        preds <- t
    }
   
    N <- length(trues)
    sae <- sum(abs(trues-preds))
    sse <- sum((trues-preds)^2)
    r <- c(mae=sae/N,mse=sse/N,rmse=sqrt(sse/N),mape=sum(abs((trues-preds)/trues))/N)
    if (!is.null(train.y))
        r <- c(r,c(nmse=sse/sum((trues-mean(train.y))^2),
                   theil=sum((trues-preds)^2)/sum((c(train.y[length(train.y)],trues[-length(trues)])-preds)^2),
                   nmae=sae/sum(abs(trues-mean(train.y)))))
    return(r[metrics])
}

# =====================================================================
# Function to calculate some standard classification evaluation statistics
# ---------------------------------------------------------------------
# L. Torgo (2012)
#
# Examples:
# s <- classificationMetrics(tr,ps)
# s <- classificationMetrics(tr,ps,benMtrx=matrix(c(2,-13,-4,5),2,2))
#
classificationMetrics <- function(trues,preds,
                 metrics=NULL,
                 benMtrx=NULL,
                 allCls=unique(c(levels(as.factor(trues)),levels(as.factor(preds)))),
                 posClass=allCls[1],
                 beta=1
                 )

{
    ## Checking preds
    if (!is.null(dim(preds))) stop("classificationMetrics:: expecting a vector as predictions.")

    ## Cheking the statistics
    twoClsMetrics <- c('fpr','fnr','tpr','tnr','rec','sens','spec',
                       'prec','rpp','lift','F','ppv','fdr','npv','for','plr','nlr','dor')
    knownMetrics <- c(twoClsMetrics,c('acc','err','totU',
                      'microF','macroF',"macroRec","macroPrec"))

    if (is.null(metrics)) {
        metrics <- knownMetrics
        if (length(allCls) > 2) metrics <- setdiff(metrics,twoClsMetrics)
        if (is.null(benMtrx))   metrics <- setdiff(metrics,'totU')
    }

    if (any(twoClsMetrics %in% metrics) && length(allCls) > 2)
          stop("classificationMetrics:: some of the metrics are only available for two class problems.",call.=FALSE)
    if (any(c('totU') %in% metrics) && is.null(benMtrx))
      stop('classificationMetrics:: benMtrx parameter not specified.',call.=FALSE)
    if (!all(metrics %in% knownMetrics))
      stop("classificationMetrics:: don't know how to calculate -> ",call.=FALSE,
           paste(metrics[which(!(metrics %in% knownMetrics))],collapse=','))

    r <- rep(NA,length(knownMetrics))
    names(r) <- knownMetrics

    ## copying with missing predictions (only necessary for non-standard WFs)
    if (length(preds) != length(trues)) {
        warning("classificationMetrics:: less predictions than test cases, filling with NAs.")
        t <- trues
        t[] <- NA
        t[names(preds)] <- preds
        preds <- t
    }

    ## copying with eventually missing class labels
    preds <- factor(preds,levels=allCls)
    trues <- factor(trues,levels=allCls)
    
    N <- length(trues)
    cm <- as.matrix(table(preds,trues))

    a <- sum(diag(cm))/N
    r[c('acc','microF','err')] <- c(a,a,1-a)

    if (length(allCls) == 2) {
        negClass <- setdiff(allCls,posClass)
        r[c('tpr','rec','sens')] <- cm[posClass,posClass]/sum(cm[,posClass])
        r[c('spec','tnr')] <- cm[negClass,negClass]/sum(cm[,negClass])
        r['fpr'] <- cm[posClass,negClass]/sum(cm[,negClass])
        r['fnr'] <- cm[negClass,posClass]/sum(cm[,posClass])
        r[c('prec','ppv')] <- cm[posClass,posClass]/sum(cm[posClass,])
        
        r['npv'] <- cm[negClass,negClass]/sum(cm[negClass,])
        r['fdr'] <- cm[posClass,negClass]/sum(cm[posClass,])
        r['for'] <- cm[negClass,posClass]/sum(cm[negClass,])

        r['plr'] <- r['tpr']/r['fpr']
        r['nlr'] <- r['fnr']/r['tnr'] 
        r['dor'] <- r['plr']/r['nlr']

        r['rpp'] <- sum(cm[posClass,])/N
        r['lift'] <- r['rec']/sum(cm[posClass,])
        r['F'] <- (1+beta^2)*r['prec']*r['rec']/(beta^2*r['prec']+r['rec'])
    }

    if (any(c("macroF","macroRec","macroPrec") %in% metrics)) {
        F <- R <- P <- 0
        for(cl in allCls) {
            pr <- cm[cl,cl]/sum(cm[cl,])
            rc <- cm[cl,cl]/sum(cm[,cl])
            F <- F+(1+beta^2)*pr*rc/(beta^2*pr+rc)
            P <- P + pr
            R <- R + rc
        }
        r["macroF"] <- F/length(allCls)
        r["macroRec"] <- R/length(allCls)
        r["macroPrec"] <- P/length(allCls)
    }
    
    
    if (!is.null(benMtrx))
      if (!all(dim(cm)==dim(benMtrx)))
        stop("classificationMetrics:: dimensions of confusion and cost/benefit matrices do not match",call.=FALSE)
      else r['totU'] <- sum(cm*benMtrx)
    
    return(r[metrics])
}   






