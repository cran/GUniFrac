\name{GUniFrac}
\alias{GUniFrac}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Generalized UniFrac distances for comparing microbial communities.
}
\description{
A generalized version of commonly used UniFrac distances. It is defined as:
\deqn{d^{(\alpha)} = \frac{\sum_{i=1}^m b_i (p^A_{i} + p^B_{i})^\alpha 
\left\vert \frac{ p^A_{i} - p^B_{i} }{p^A_{i} + p^B_{i}} \right\vert } { 
 \sum_{i=1}^m b_i (p^A_{i} + p^B_{i})^\alpha},}{d^{(\alpha)} = 
 [\sum_{i=1}^m b_i (p^A_{i} + p^B_{i})^\alpha 
|p^A_{i} - p^B_{i}|/(p^A_{i} + p^B_{i})]/ [ 
 \sum_{i=1}^m b_i (p^A_{i} + p^B_{i})^\alpha],}
 
where \eqn{m}{m} is the number of branches, \eqn{b_i}{b_i} is the length of 
\eqn{i}{i}th branch, \eqn{p^A_{i}, p^B_{i}}{p^A_{i}, p^B_{i}} are the branch
proportion for community A and B. 

Generalized UniFrac distance contains an extra parameter \eqn{\alpha}{\alpha} 
controlling the weight on abundant lineages so the distance is not dominated 
by highly abundant lineages. \eqn{\alpha=0.5}{\alpha=0.5} ("d_0.5") is overall very robust. 

The unweighted ("d_1") and weighted UniFrac ("d_UW") are also implemented.  
}

\usage{
GUniFrac(otu.tab, tree, size.factor = NULL, alpha = c(0, 0.5, 1), verbose = TRUE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{otu.tab}{
%%     ~~Describe \code{otu.tab} here~~
a matrix, the OTU count table, row - n sample, column - q OTU
}
  \item{tree}{
%%     ~~Describe \code{tree} here~~
a rooted phylogenetic tree of R class \dQuote{phylo}
}

  \item{size.factor}{
   a numeric vector of the normalizing factors to divide the counts. The length
   is the number of samples. This provides the flexibility to normalize data using the 
   preferred normalization method (e.g. GMPR normalizing factor). If not supplied, the total sum will be used. 
}
  \item{alpha}{
%%     ~~Describe \code{alpha} here~~
a numeric vector, parameters controlling the weight on abundant lineages
}

  \item{verbose}{
%%     ~~Describe \code{alpha} here~~
logical value, whether to print out the messages
}
}

\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
Return a list containing
		\item{unifracs}{a three dimensional array containing all the UniFrac
		distance matrices}
}
\references{
%% ~put references to the literature/web site here ~
Chen, J., Bittinger, K., Charlson, E.S., Hoffmann, C., Lewis, J., Wu, G.D., Collman, R.G., Bushman, F.D. and Li, H. (2012). Associating microbiome composition with 
environmental covariates using generalized UniFrac distances. 28(16): 2106–2113.
}
\author{
%%  ~~who you are~~
Jun Chen <chen.jun2@mayo.edu>
}

\note{
%%  ~~further notes~~
The function only accepts rooted tree. To root a tree, you may consider using \code{midpoint} from the package \code{phangorn}.
}


%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
\code{\link{Rarefy}}, \code{\link{PermanovaG}}
}
\examples{
\dontrun{
data(throat.otu.tab)
data(throat.tree)
data(throat.meta)

groups <- throat.meta$SmokingStatus

# Rarefaction
otu.tab.rff <- Rarefy(throat.otu.tab)$otu.tab.rff

# Calculate the UniFracs
unifracs <- GUniFrac(otu.tab.rff, throat.tree, alpha=c(0, 0.5, 1))$unifracs

dw <- unifracs[, , "d_1"]		# Weighted UniFrac
du <- unifracs[, , "d_UW"]		# Unweighted UniFrac	
d0 <- unifracs[, , "d_0"]     	# GUniFrac with alpha 0  
d5 <- unifracs[, , "d_0.5"]   	# GUniFrac with alpha 0.5 

# Permanova - Distance based multivariate analysis of variance
adonis3(as.dist(d5) ~ groups)
}

}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ distance }
\keyword{ UniFrac }
\keyword{ ecology }% __ONLY ONE__ keyword per line
