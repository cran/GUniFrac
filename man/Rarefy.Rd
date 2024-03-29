\name{Rarefy}
\alias{Rarefy}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Rarefy a Count Table to Equal Sequencing Depth
}
\description{
GUniFrac is also sensitive to different sequencing depth. To compare
microbiomes on an equal basis, rarefaction might be used.
}
\usage{
Rarefy(otu.tab, depth = min(rowSums(otu.tab)))
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{otu.tab}{
OTU count table, row - n sample, column - q OTU
}
  \item{depth}{
required sequencing depth; If not specified, the lowest sequencing
depth is used.
}
}

\value{
 Return a list containing:
 \item{otu.tab.rff}{rarefied OTU table}
 \item{discard}{IDs of samples that does not reach the specified sequencing depth}
%% ...
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


%% ~Make other sections like Warning with \section{Warning }{....} ~

\examples{
data(throat.otu.tab)
# Rarefaction
otu.tab.rff <- Rarefy(throat.otu.tab, 1024)$otu.tab.rff
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ Normalization}
\keyword{ Microbiome}% __ONLY ONE__ keyword per line
