
perm.fdr.adj <- function (F0, Fp) {
	ord <- order(F0, decreasing = T)
	F0 <- F0[ord]
	perm.no <- ncol(Fp)
	Fp <- as.vector(Fp)
	Fp <- Fp[!is.na(Fp)]
	Fp <- sort(c(Fp, F0), decreasing = F)
	n <- length(Fp)
	m <- length(F0)
	FPN <- (n + 1) - match(F0, Fp) - 1:m
	p.adj.fdr <- FPN / perm.no / (1:m)
	
	# Impute 0s - pseudo-ct 0.5
	p.adj.fdr[p.adj.fdr == 0] <- 0.5 / perm.no / which(p.adj.fdr == 0)
	
	p.adj.fdr <- pmin(1, rev(cummin(rev(p.adj.fdr))))[order(ord)]

	return(p.adj.fdr)
}

perm.fwer.adj <- function (F0, Fp) {
	ord <- order(F0, decreasing = T)
	m <- length(F0)
	F0 <- F0[ord]
	Fp <- Fp[ord, , drop=FALSE]
	col.max <- Fp[m, ]
	p.adj.fwer <- sapply(m:1, function(i) {
				x <- F0[i]
				y <- Fp[i, ]
				col.max <<- ifelse(y > col.max, y, col.max)
				# Impute 0s
				mean(c(1, col.max >= x))
			})
	p.adj.fwer <- rev(p.adj.fwer)
	
	p.adj.fwer <- pmin(1, rev(cummin(rev(p.adj.fwer))))[order(ord)]
	return(p.adj.fwer)
}

na.pad <- function (vec, ind) {
	vec0 <- numeric(length(ind))
	vec0[!ind] <- vec
	vec0[ind] <- NA
	return(vec0)
}

find.ref.z1 <- function(otu.tab, M,  ref.pct = 0.50, feature.dat.type, p.max = 500) {
  
  # p.max to reduce the computation time
	p <- nrow(otu.tab)
	n <- ncol(otu.tab)
	
	if (p > p.max) {
	  ord <- order(rowSums(otu.tab), decreasing = TRUE)
	  otu.tab <- otu.tab[ord[1 : p.max], ]
	  p <- p.max
	} else {
	  ord <- 1 : p
	}

	if (feature.dat.type == 'count') {
		otu.tab <- otu.tab + 1
	}
	
	if (feature.dat.type == 'proportion') {
		otu.tab <- t(apply(otu.tab, 1, function (x) {
							x[x == 0] <- min(x[x != 0]) / 2
							return(x)
						}))
	}
	
	otu.tab <- t(otu.tab)
	res <- matrix(NA, p, p)
	
	XXI <- solve(t(M) %*% M)
	dof <- n - ncol(M)
	XXIM <- XXI %*% t(M)
	
	for (i in 1 : (p - 1)) {
		
		Y <- (as.matrix(log((otu.tab[, i]) / (otu.tab[, (i + 1) : p]))))

		est <- XXIM %*% Y
		resid <- Y - M %*% est
		sigma <- sqrt(colSums(resid^2) / dof)
		
		res[i, (i + 1) : p] <- res[(i + 1) : p, i] <- sigma
	}
	ref.ind <- order(rowMedians(res, na.rm = TRUE))[1 : round(ref.pct * p)]
	return(ord[ref.ind])
}

bbmix.fit.MM <- function (ct, dep,  nIter = 10, winsor.qt = 1.0) {
	
	if (mean(ct == 0) >= 0.95 | sum(ct != 0) < 5) {
		stop('The number of nonzero is too small to fit the model! Consider removing it from testing or please do not enable posterior sampling!\n')
	}
	
	# Initialization
	prop0 <- ct / dep
	qt <- quantile(prop0, winsor.qt)
	prop0[prop0 >= qt] <- qt
	
	var1 <- var(prop0) / 2
	mean1 <- mean(prop0) / 2
	
	var2 <- var(prop0) / 2
	mean2 <- 3 * mean(prop0) / 2
	
	pi <- 0.5
	
	for (i in 1 : nIter) {
		
		
		shape1.1 <- ((1 - mean1) / var1 - 1 / mean1) * mean1 ^ 2
		shape1.2 <- shape1.1 * (1 / mean1 - 1)
		
		shape2.1 <- ((1 - mean2) / var2 - 1 / mean2) * mean2 ^ 2
		shape2.2 <- shape2.1 * (1 / mean2 - 1)
		
		m1 <- shape1.1 / (shape1.1 + shape1.2)
		s1 <- shape1.1 + shape1.2
		
		m2 <- shape2.1 / (shape2.1 + shape2.2)
		s2 <- shape2.1 + shape2.2
		
		f1 <- dbetabinom(ct, dep, m1, s1)
		f2 <- dbetabinom(ct, dep, m2, s2)
		
		q1 <-  pi * f1 /  (pi * f1 + (1 - pi) * f2)
		q2 <-  1 - q1
		
		pi <- mean(q1)
		
		# Rough estimation
		mean1 <- sum(prop0 * q1) / sum(q1)
		var1 <- sum((prop0 - mean1)^2 * q1) / sum(q1)
		
		mean2 <- sum(prop0 * q2) / sum(q2)
		var2 <- sum((prop0 - mean2)^2 * q2) / sum(q2)
	}
	
	return(list(shape1.1 = shape1.1, shape1.2 = shape1.2, shape2.1 = shape2.1, shape2.2 = shape2.2, pi = pi, q1 = q1))
	
}

#' @title Permutation-based differential abundance analysis
#' @param meta.dat a data frame containing the sample information
#' @param feature.dat a matrix of counts, row - features (OTUs, genes, etc) , column - samples.
#' @param feature.dat.type  the type of the feature data. It could be "count", "proportion" or "other". For "proportion" data type, posterior sampling will not be performed,
#' but the reference-based ratio approach will still be used to address compositional effects. For "other" data type, neither posterior sampling or reference-base ratio approach
#' will be used.
#' @param grp.name the name for variable of interest. It could be numeric or categorical; should be in "meta.dat".
#' @param adj.name  the name for the variable(s) to be adjusted. They could be numeric or categorical; should be in "meta.dat."
#' @param prev.filter the prevalence cutoff, under which the features will  be filtered. 
#' @param mean.abund.filter the mean relative abundance cutoff, under which the features will  be filtered. 
#' @param max.abund.filter the max relative abundance cutoff, under which the features will  be filtered. 
#' @param min.prop  proportions less than this value will be replaced with this value. Only relevant when log transformation is used. The default is 0. 
#' @param is.winsor a logical value indicating whether winsorization should be performed to replace outliers. The default is TRUE.
#' @param winsor.end a character indicating whether the outliers at the top, bottom or both will be winsorized.
#' @param outlier.pct the percentage of expected outliers. These outliers will be winsorized.
#' @param is.post.sample a logical value indicating whether to perform posterior sampling of the underlying proportions. Only relevant when the feature data are counts.
#' @param post.sample.no the number of posterior samples if posterior sampling is used.
#' @param link.func  a list of transformation functions for the feautre data.
#' @param perm.no the number of permutations; If the raw p values are of the major interest, set "perm.no" to at least 999.
#' @param strata  a factor indicating the permutation strata; permutation will be confined to each stratum.
#' @param stats.combine.func function to combine the F-statistic for the omnibus test.
#' @param ref.pct percentage of reference taxa.
#' @param stage.no the number of stages if multiple-stage normalization is used.
#' @param excl.pct the maximum percentage of significant features in the reference set that can be removed. Only relevant when multiple-stage normalization is used.
#' @param p.max the maximum number of most abundant features to be considered in reference selection; only relevant for large data sets 
#' @param is.fwer a logical value indicating whether the family-wise error rate control (West-Young) will be performed.
#' @param verbose a logical value indicating whether the trace information should be printed out.
#' @param return.feature.dat a logical value indicating whether the wisorized, filtered "feature.dat" matrix should be returned.
#' @return A list with the elements
#' \item{call}{the call}
#' \item{feature.dat}{the wisorized, filtered "feature.dat" matrix}
#' \item{meta.dat}{"meta.dat" used}
#' \item{grp.name}{"grp.name" used}
#' \item{filter.ind}{a vector of logical values indicating which features are filtered}
#' \item{R2}{a matrix of percent explained variance (number of features by number of transformation functions)}
#' \item{F0}{a matrix of observed F-statistics (number of features by number of functions)}
#' \item{RSS}{a matrix of residual sum squares (number of features by number of functions)}
#' \item{df.model, df.residual}{degrees of freedom for the model and residual space}
#' \item{p.raw}{the raw p-values based on permutations (not accurate if "perm.no" is small)}
#' \item{p.adj.fdr}{permutation-based FDR-adjusted p-values}
#' \item{p.adj.fwer}{permutation-based FWER-adjusted (West-Young) p-values}
#' @import stats
#' @import nlme
#' @import matrixStats
#' @import vegan
#' @import ape
#' @import statmod
#' @importFrom rmutil dbetabinom
#' @rdname ZicoSeq
#' @export

ZicoSeq <- function (
		meta.dat, feature.dat, grp.name, adj.name = NULL, feature.dat.type = c('count', 'proportion', 'other'),
		prev.filter = 0, mean.abund.filter = 0, max.abund.filter = 0, min.prop = 0,
		is.winsor = TRUE, outlier.pct = 0.03, winsor.end = c('top', 'bottom', 'both'),
		is.post.sample = TRUE,  post.sample.no = 25,
		link.func = list(function (x) sign(x) * (abs(x))^0.5), stats.combine.func = max,
		perm.no = 99,  strata = NULL, 
		ref.pct = 0.50, stage.no = 6, excl.pct = 0.20, p.max = 500,
		is.fwer = FALSE, verbose = TRUE, return.feature.dat = TRUE) {
	
	this.call <- match.call()
	feature.dat.type <- match.arg(feature.dat.type)
	winsor.end <- match.arg(winsor.end)
	
	if (!is.null(strata)) {
	  if (length(strata) == 1 & is.character(strata)) {
	    strata <- factor(meta.dat[, strata])
	  } else {
	    strata <- factor(strata)
	  }
	  if (length(strata) != nrow(meta.dat)) {
	    stop("'strata' parameter is not correct. Dimension does not match!\n")
	  }
	}
	
	if(is.null(rownames(feature.dat)[1])) {
		rownames(feature.dat) <- paste0("S", 1 : nrow(feature.dat))
	}
	
	sds <- rowSds(feature.dat)
	if (sum(sds == 0) != 0) {
		stop(paste('Feature ',  paste(which(sds == 0), collapse = ','), 
						'have identical values (e.g. all 0s)! Please remove them!\n'))
	}
	

	if (perm.no < 99) {
		warning('To obtain stable results, number of permutations should be at least 99!\n')
	}
	
	if (feature.dat.type == 'count') {
		if (sum(feature.dat < 0 | (feature.dat < 1 & feature.dat > 0)) != 0) {
			stop('It seems the feature data are not counts. Please check!\n')
		}
	}
	
	if (feature.dat.type == 'proportion') {
		if (sum(feature.dat < 0 | feature.dat > 1) != 0) {
			stop('It seems the feature data are not proportions. Please check!\n')
		}
	}
	
	if (feature.dat.type %in% c('proportion', 'other') & is.post.sample == TRUE) {
		cat('For proportion and other data types,  posterior sampling will not be performed!\n')
		is.post.sample <- FALSE
	}
	
	if (feature.dat.type == 'other') {
		stage.no <- 1
	}
	if (feature.dat.type == 'count' & nrow(meta.dat) <= 40) {
		cat('For sample size less than 40, posterior sampling will not be used!\n')
		is.post.sample <- FALSE
	}
	
	if (feature.dat.type == 'count' & is.post.sample == FALSE){
		if (min(coef(summary(lm(sqrt(colSums(feature.dat)) ~  meta.dat[, grp.name])))[-1, 'Pr(>|t|)']) < 0.05) {
			warning('The sequencing depth is correlated with the variable of interest!
							Rarefaction is needed to control for false positves!\n')
			
		}
	}

	###############################################################################
	# Filter to remove very rare taxa
	if (feature.dat.type %in% c('count', 'proportion')) {

		temp <- t(t(feature.dat) / colSums(feature.dat))

		filter.ind <- rowMeans(temp != 0) >= prev.filter & rowMeans(temp) >= mean.abund.filter & rowMaxs(temp) >= max.abund.filter
		names(filter.ind) <- rownames(feature.dat)
		if (verbose)  cat(sum(!filter.ind), ' features are filtered!\n')
		filter.features <- rownames(feature.dat)[!filter.ind]
		feature.dat <- feature.dat[filter.ind, ]
	} else {
		filter.ind <- rep(TRUE, ncol(feature.dat))
		filter.features <- NULL
	}
	
	# After filtering, some samples could have all zeros, will need to remove them.
	if (feature.dat.type %in% c('count', 'proportion')) {

	  ind <- colSums(feature.dat) != 0
	  
	  if (sum(!ind) != 0) {
	    warning(sum(!ind), ' samples have all zeros after filtering! They will be removed! \n')
	    feature.dat <- feature.dat[, ind, drop = FALSE]
	    meta.dat <- meta.dat[ind, ]
	    if (!is.null(strata)) {
	      strata <- strata[ind]
	    }
	  }

	}

	  
	if (feature.dat.type == 'proportion') {
		# Renormalization
		feature.dat <- t(t(feature.dat) / colSums(feature.dat))
	}
	
	sample.no <- ncol(feature.dat)
	otu.no <- nrow(feature.dat)
	row.names <- rownames(feature.dat)
	depth <- colSums(feature.dat)
	
	if (verbose) cat('The data has ', sample.no, ' samples and ', otu.no, ' features will be tested!\n' )

	if (feature.dat.type %in% c('count', 'proportion') & sum(rowSums(feature.dat != 0) <= 2) != 0) {
		warning('Some features have less than 3 nonzero values! 
               They have virtually no statistical power. Please consider removing them in the analysis!\n')
	}
	
	###############################################################################
	# Winsorization to reduce the influence of outliers
	
	if (is.winsor == TRUE) {
		depth <- colSums(feature.dat)
		
		cat("On average, ", round(length(depth) * outlier.pct), 
		                          " outlier counts will be replaced for each feature!\n") 

		feature.dat <- apply(feature.dat, 1, function (x) {

					if (feature.dat.type == 'count') {
						x <- x / depth
					}
					
					if (winsor.end == 'top') {
						qt <- quantile(x, 1 - outlier.pct)
						x[x >= qt] <- qt
					}
					
					if (winsor.end == 'bottom') {
						qt <- quantile(x, outlier.pct)
						x[x <= qt] <- qt
					}
					
					if (winsor.end == 'both') {
						qt1 <- quantile(x, 1 - outlier.pct / 2)
						qt2 <- quantile(x, outlier.pct / 2)
						x[x >= qt1] <- qt1
						x[x <= qt2] <- qt2
					}
					
					if (feature.dat.type == 'count') {
						return(round(x * depth))
					} else {
						return(x)
					}				
				})
		feature.dat <- t(feature.dat)
		sds <- rowSds(feature.dat)
		if (sum(sds == 0) != 0) {
			stop(paste('After winsorization, feature ',  paste(which(sds == 0), 
			             collapse = ','),  'have identical values! Did you set the "outlier.pct" too high or some features are extremely sparse?\n'))
		}
		
	}
	
	if (feature.dat.type == 'proportion') {
		# Renormalization
		feature.dat <- t(t(feature.dat) / colSums(feature.dat))
	}
	
	###############################################################################
	# Generate samples from posterior distribution (stacking it)
	if (is.post.sample == TRUE) {
		
		if (verbose) cat('Fitting beta mixture ...\n')
		feature.dat.p <- apply(feature.dat, 1, function (x) {
					err1 <- try(res <- bbmix.fit.MM(x, depth), silent = TRUE)
					
					# Handle error
					if (!inherits(err1, 'try-error')) {
						prop1.1 <- rbeta(sample.no * post.sample.no, shape1 = x + res$shape1.1, shape2 = res$shape1.2 + depth - x)
						prop1.2 <- rbeta(sample.no * post.sample.no, shape1 = x + res$shape2.1, shape2 = res$shape2.2 + depth - x)
						prop <- ifelse(runif(sample.no * post.sample.no) <= res$q1, prop1.1, prop1.2)
					} else {
						prop <- x / depth
						v <- var(prop)
						m <- mean(prop)
						
						a1 <- ((1 - m) / v - 1 / m) * m ^ 2
						a2 <- a1 * (1 / m - 1)
						
						if (is.na(a1) | a1 < 0) {
							# uniform prior
							prop <- rbeta(sample.no * post.sample.no, shape1 = x + 1, shape2 = otu.no + depth - x)
						} else {
							# beta prior
							prop <- rbeta(sample.no * post.sample.no, shape1 = x + a1, shape2 = a2 + depth - x)
						}
					}
					return(prop)
				})
		
		feature.dat.p <- t(feature.dat.p)
		feature.dat.p.list <- list()
		st <- 1
		end <- sample.no
		for (i in 1 : post.sample.no) {
			feature.dat.p.list[[i]] <- feature.dat.p[, st : end]
			# Normalization
			#    feature.dat.p.list[[i]] <- t(t(feature.dat.p[, st : end]) / colSums(feature.dat.p[, st : end]))
			st <- st + sample.no
			end <- end + sample.no
		}
	} else {
		feature.dat.p.list <- list()
		if (feature.dat.type == 'count') {
			feature.dat.p.list[[1]] <- t(t(feature.dat) / depth)
		} else{
			feature.dat.p.list[[1]] <- feature.dat
		}
		
		post.sample.no <- 1
	}
	
	# Replace zeros or extremely small values for log calculation
	if (feature.dat.type %in% c('count', 'proportion')) {
		for (i in 1 : post.sample.no) {
			temp <- feature.dat.p.list[[i]]
			temp[temp <= min.prop] <- min.prop
			feature.dat.p.list[[i]] <- temp
		}
	}
	#return(feature.dat.p.list)
	###############################################################################
	# Covariate space (including intercept)

	
	if (is.null(adj.name)) {
		M0 <- model.matrix(~ 1, meta.dat)
	} else {
		data0 <- meta.dat[, c(adj.name), drop = FALSE]
		if (sum(is.na(data0)) != 0) {
		  stop("Please remove or impute NAs in the variables to be adjusted!\n")
		}
		M0 <- model.matrix( ~ ., data0)
	}
	
	data1 <- meta.dat[, c(grp.name), drop = FALSE]
	
	if(sum(is.na(data1)) != 0) {
	  stop("Please remove or impute NAs in the variable of interest!\n")
	}
	
	M1 <-  model.matrix( ~ ., data1)[, -1, drop = FALSE]  # No intercept
	
	M01 <- cbind(M0, M1)
	
	# QR decompostion
	qrX0 <- qr(M0, tol = 1e-07)
	Q0 <- qr.Q(qrX0)
	Q0 <- Q0[, 1:qrX0$rank, drop = FALSE]
	H0 <- (Q0 %*% t(Q0))
	
	qrX1 <- qr(M1, tol = 1e-07)
	Q1 <- qr.Q(qrX1)
	Q1 <- Q1[, 1:qrX1$rank, drop = FALSE]
	
	qrX01 <- qr(M01, tol = 1e-07)
	Q01 <- qr.Q(qrX01)
	Q01 <- Q01[, 1:qrX01$rank, drop = FALSE]
	
	R0 <- as.matrix(resid(lm(Q1 ~ Q0 - 1)))
	
	pX0 <- ncol(Q0)
	pX1 <- ncol(Q1)
	pX01 <- ncol(Q01)
	
	df.model <- pX01 - pX0
	df.residual <- sample.no - pX01
	
	func.no <- length(link.func)
	
	###############################################################################
	if (feature.dat.type %in% c('count', 'proportion')) {
		if (verbose)  cat('Finding the references ...\n')
		ref.ind <- find.ref.z1(feature.dat, M0, ref.pct = ref.pct, feature.dat.type = feature.dat.type, p.max = p.max)
		size.factor <- colSums(feature.dat[ref.ind, ])
	} else {
		ref.ind <- NULL
	}
	###############################################################################
	# Perform multiple stage normalization
	if (verbose) cat('Permutation testing ...\n')
	# norm.ind <- NULL
	
	for (i in 1 : stage.no) {
		# Reference proportion
		
		if (feature.dat.type == 'other') {
			divisor <- 1
		} else {
			divisor <- size.factor / depth
			divisor[divisor == 0] <- 0.5 * min(divisor[divisor != 0])
		}
		
		# Create the giant Y matrix
		Y <- matrix(NA, sample.no, func.no * otu.no * post.sample.no)
		
		# Change order - func.no * otu.no
		for (k in 1 : post.sample.no) {
			for (j in 1 : func.no) {
				func <- link.func[[j]]
				feature.dat.p <- feature.dat.p.list[[k]]
				
				Y[, (k - 1) * func.no * otu.no + func.no * (0 : (otu.no - 1)) + j] <-
						func(t(feature.dat.p) / divisor)  # No scaling first
				
			}
		}
		
		Y <- t(Y)
		TSS <- rowSums(Y^2)
		MSS01 <- rowSums((Y %*% Q01)^2)
		MSS0 <- rowSums((Y %*% Q0)^2)
		
		MSS <- (MSS01 - MSS0)
		RSS <- (TSS - MSS01)
		
		
		getPermuteMatrix <- getFromNamespace("getPermuteMatrix", "vegan")
		perm.ind <- getPermuteMatrix(perm.no, sample.no, strata = strata)
		perm.no <- nrow(perm.ind)
		
		MRSSp <- sapply(1 : perm.no, function(ii) {
					if (verbose) {
						if (ii %% 10 == 0) cat('.')
					}
					
					Rp <- R0[perm.ind[ii, ], , drop = FALSE]
					# Project to the reisdual space
					Rp <- Rp - H0 %*% Rp
					
					qrRp <- qr(Rp, tol = 1e-07)
					Q1p <- qr.Q(qrRp)
					Q1p <- Q1p[, 1:qrRp$rank, drop = FALSE]
					
					MSS01p <- MSS0 + rowSums((Y %*% Q1p)^2)
					
					MSSp <- (MSS01p - MSS0)
					RSSp <- (TSS - MSS01p)
					
					c(MSSp, RSSp)
					
				})
		
		unit <- func.no * otu.no * post.sample.no
		MSSp <- MRSSp[1 : unit, ]
		RSSp <- MRSSp[(unit + 1) : (2 * unit), ]
		
		# EB is based on the aggregated RSS
		RSS.m <- array(RSS, c(func.no, otu.no,  post.sample.no))
		RSS.m <- t(apply(RSS.m, c(1, 2), mean))  # otu.no by func.no
		
		F0.m <- array((MSS / df.model) / (RSS / df.residual), c(func.no, otu.no,  post.sample.no))
		F0.m <-  t(apply(F0.m, c(1, 2), mean))  # otu.no by func.no
		
		R2.m <- array(MSS / TSS, c(func.no, otu.no, post.sample.no))
		R2.m <- t(apply(R2.m, c(1, 2), mean))  # otu.no by func.no
		
		F0 <- (MSS / df.model)  /  (RSS  / df.residual)
		Fp <- (MSSp / df.model)  /  (RSSp  / df.residual)
		
		# Expectation of F0 and Fp
		F0 <- array(F0, c(func.no, otu.no, post.sample.no))
		Fp <- array(Fp, c(func.no, otu.no, post.sample.no, perm.no))
		
		F0 <- apply(F0, c(1, 2), mean)    # func.no * otu.no
		Fp <- apply(Fp, c(1, 2, 4), mean) # func.no * otu.no * perm.no
		
		###############################################################################
		# Omnibus test by taking maximum
		F0 <- apply(F0, 2, stats.combine.func)
		Fp <- apply(Fp, c(2, 3), stats.combine.func)  # otu.no by perm.no
		
		if (verbose) cat('\n')
		
		if (mean(is.na(F0)) >= 0.1) {
			warning('More than 10% observed F stats have NA! Please check! \n')
		}
		
		if (mean(is.na(Fp)) >= 0.1) {
			warning('More than 10% permuted F stats have NA! Please check! \n')
		}
		
		na.ind <- is.na(F0)
		F0 <- F0[!na.ind]
		Fp <- Fp[!na.ind, ]
		
		which.nan.ind <- which(!na.ind)
		###############################################################################
		p.raw <- rowMeans(cbind(Fp, F0) >= F0)
		
		if (i == stage.no) {
			break
		} else {
			if (mean(p.raw <= 0.05) >= excl.pct) {
				ind <- order(p.raw)[1 : round(length(p.raw) * excl.pct)]
			} else {
				ind <- which(p.raw <= 0.05)
			}
			size.factor <- colSums(feature.dat[setdiff(ref.ind, which.nan.ind[ind]), ])
			# norm.ind <- cbind(norm.ind, !(1:nrow(feature.dat) %in% setdiff(ref.ind, which.nan.ind[ind])))
		}
	}
	
	
	
	p.adj.fdr <- perm.fdr.adj(F0, Fp)
	p.raw <- na.pad(p.raw, na.ind)
	p.adj.fdr <- na.pad(p.adj.fdr, na.ind)
	names(p.raw) <- names(p.adj.fdr) <- rownames(R2.m) <- rownames(RSS.m) <- rownames(F0.m) <- row.names
	colnames(R2.m) <- colnames(F0.m) <- colnames(RSS.m) <- paste0('Func', 1 : func.no)
	
	if (is.fwer) {
		p.adj.fwer <- perm.fwer.adj(F0, Fp)
		p.adj.fwer <- na.pad(p.adj.fwer, na.ind)
		names(p.adj.fwer)  <- row.names
	} else {
		p.adj.fwer <- NULL
	}
	
	# Finally, get the direction of change under specific transformations
    if (length(ref.ind) != 0) {
    divisor <- colSums(feature.dat[ref.ind, ])
    divisor[divisor == 0] <- 1
		temp.dat <- t(t(feature.dat) / divisor)
	} else {
		temp.dat <- feature.dat
	}
	
	coef.list <- NULL
	for (j in 1 : func.no) {
		func <- link.func[[j]]
		coef.list[[j]] <- solve(t(M01) %*% M01) %*% t(M01) %*% t(func(temp.dat))

	}

    
	if (!return.feature.dat) {
		feature.dat <- NULL
	}
	if (verbose) cat('Completed!\n')
	
	return(list(call = this.call, feature.dat = feature.dat, meta.dat = meta.dat, grp.name = grp.name,
	            filter.features = filter.features, ref.features = row.names[ref.ind],
					R2 = R2.m, F0 = F0.m, RSS = RSS.m, df.model = df.model, df.residual = df.residual, coef.list = coef.list,
					p.raw = p.raw, p.adj.fdr = p.adj.fdr,  p.adj.fwer = p.adj.fwer))
	
}



#' Plot ZicoSeq results
#' The function plots the association strength and direction based on the output from \code{ZicoSeq}.
#' @param ZicoSeq.obj return from function \code{ZicoSeq}.
#' @param pvalue.type character; It could be 'p.adj.fdr','p.raw' or 'p.adj.fwer'.
#' @param cutoff a real value between 0 and 1; cutoff for pvalue.type.
#' @param text.size text size for the plots.
#' @param out.dir character; the directory to save the figures, e.g., \code{getwd()}. Default is NULL. If NULL, figures will not be saved.
#' @param file.name character; the name of the file.
#' @param width the width of the graphics region in inches. See R function \code{ggsave}.
#' @param height the height of the graphics region in inches. See R function \code{ggsave}.
#' @return A \code{ggplot2} object.
#' @import ggplot2
#' @import dplyr
#' @import tibble
#' @importFrom ggpubr ggarrange
#' @rdname ZicoSeq.plot
#' @export
#' 


ZicoSeq.plot <- function(ZicoSeq.obj, pvalue.type = c('p.adj.fdr','p.raw','p.adj.fwer'), 
		cutoff = 0.1, text.size = 10, out.dir = NULL, file.name = 'ZicoSeq.plot.pdf',  width = 10, height = 6){
	
#  if(sum(ZicoSeq.obj[[pvalue.type]]<= cutoff) == 0){
#    cat(paste0('No taxa within ', pvalue.type, ' <= ',cutoff, '!'))
#  }
	
	grp.name <-  ZicoSeq.obj$grp.name
	meta.dat <- ZicoSeq.obj$meta.dat
	
	# cat('Significant(',pvalue.type,'<=',cutoff,') association strength between taxa and ',grp.name, ' is visualized!\n' )
	
	if(ZicoSeq.obj$call$feature.dat.type == 'proportion'){
		abundance <- ZicoSeq.obj$feature.dat
		prevalence <- apply(ZicoSeq.obj$feature.dat, 1, function(x) mean(x > 0))
	}
	
	if(ZicoSeq.obj$call$feature.dat.type == 'count'){
		abundance <- t(t(ZicoSeq.obj$feature.dat)/colSums(ZicoSeq.obj$feature.dat))
		prevalence <- apply(ZicoSeq.obj$feature.dat, 1, function(x) mean(x > 0))
	}
	
	if(ZicoSeq.obj$call$feature.dat.type == 'other'){
		abundance <- ZicoSeq.obj$feature.dat
		prevalence <- apply(abundance, 1, function(x) sd(x))
	}
	
	# relative abundance
	abundance <- apply(abundance, 1, function(x) mean(x))
	
	if(!(length(unique(meta.dat[,grp.name])) > 2 & !is.numeric(meta.dat[,grp.name]))) {
		coefs <- sapply(ZicoSeq.obj$coef.list, function(x) x[grep(grp.name,rownames(x)),])
		colnames(coefs) <- paste0('coef_Func',1:length(ZicoSeq.obj$coef.list))
	}  
	
	if (!is.numeric(meta.dat[,grp.name]) & length(unique(meta.dat[,grp.name])) == 2) {
		level2 <- rownames(ZicoSeq.obj$coef.list[[1]])[grep(paste0('^',grp.name),rownames(ZicoSeq.obj$coef.list[[1]]))]
		level2 <- gsub(grp.name, '', level2)
		base <- setdiff(unique(meta.dat[,grp.name]), level2)
	}
	
	# Break the ties
	ZicoSeq.obj$R2 <- ZicoSeq.obj$R2 + runif(length(ZicoSeq.obj$R2), 0, 1e-10)
	
	R2 <- rowMaxs(ZicoSeq.obj$R2)

	## pvalue = 0??? -log10(p)
	if(length(unique(meta.dat[,grp.name])) > 2 & !is.numeric(meta.dat[,grp.name])){
		plot.data <- data.frame(pvals = ZicoSeq.obj[[pvalue.type]], 
				prevalence = prevalence, abundance = abundance, 
				R2 = R2, 
				taxa = rownames(ZicoSeq.obj$R2))
		plot.data[plot.data$pvals > cutoff, 'taxa'] <- ''
		
		
	}else{

		signs <- t(sign(coefs))[t(ZicoSeq.obj$R2 == R2)]
		signs[signs == 0] <- 1
		
		plot.data <- data.frame(pvals = ZicoSeq.obj[[pvalue.type]], 
				prevalence = prevalence, abundance = abundance, 
				R2 = R2 * signs, 
				taxa = rownames(ZicoSeq.obj$R2))
		
		plot.data[plot.data$pvals > cutoff, 'taxa'] <- ''
		
		
	}
	
	if(is.numeric(meta.dat[,grp.name])) {
		title.name = paste0('Association between ', grp.name, ' and  taxa abundance')
	}
	
	if(!is.numeric(meta.dat[,grp.name]) & length(unique(meta.dat[,grp.name])) > 2){
		title.name = paste0('Association between ', grp.name, ' and  taxa abundance')
	}
	
	if(!is.numeric(meta.dat[,grp.name]) & length(unique(meta.dat[,grp.name])) == 2){
		title.name = paste0('Differential abundance between ', paste0(base, ' (reference) and ', level2))
	}
	
	pvals <- R2 <- taxa <- NULL
	plot.obj <-
			ggplot(plot.data, aes(x = R2, y = -log10(pvals))) +
			geom_point(aes(size = abundance, color = prevalence)) +
			geom_vline(aes(xintercept = 0), color = 'gray', linetype = 'dashed') +
			geom_hline(aes(yintercept = -log10(cutoff)), color = 'gray', linetype = 'dashed') +
			scale_colour_gradient2(low = "white", high = "#006D2C") +
			scale_y_continuous(limits = c(0, max(-log10(plot.data$pvals)) * 1.3)) +
			ggrepel::geom_text_repel(aes(label = taxa), max.overlaps = Inf, color = 'black') +
			labs(x = bquote(R^2), y = paste0('-log10(',pvalue.type,')'),
					color = ifelse(ZicoSeq.obj$call$feature.dat.type == 'other','Standard deviation','Prevalence'),
					size = ifelse(ZicoSeq.obj$call$feature.dat.type == 'other','Mean value','Mean abundance')) +
			theme_bw() +
			theme(axis.text = element_text(color = 'black', size = text.size),
					axis.title = element_text(color = 'black', size = text.size),
					legend.text = element_text(color = 'black', size = text.size),
					legend.title = element_text(color = 'black', size = text.size)) +
			ggtitle(title.name)
	
	
	
#	plots <- ggarrange(plotlist = plot.list, common.legend = T)
	
	if(!is.null(out.dir)) {
		print(plot.obj)
		ggsave(paste0(out.dir, file.name), width = width, height = height)
	}
	return(plot.obj)
}




