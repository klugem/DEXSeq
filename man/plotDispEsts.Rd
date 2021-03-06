\docType{methods}
\name{plotDispEsts}
\alias{plotDispEsts}
\alias{plotDispEsts,DEXSeqDataSet-method}
\title{Plot dispersion estimates}
\usage{
\S4method{plotDispEsts}{DEXSeqDataSet}(object, ymin,
  genecol = "black", fitcol = "red", finalcol = "dodgerblue",
  legend=TRUE, xlab, ylab, log = "xy", cex = 0.45, ...)
}
\arguments{
  \item{object}{a DESeqDataSet}

  \item{ymin}{the lower bound for points on the plot,
  points beyond this are drawn as triangles at ymin}

  \item{genecol}{the color for gene-wise dispersion
  estimates}

  \item{fitcol}{the color of the fitted estimates}

  \item{finalcol}{the color of the final estimates used for
  testing}

  \item{legend}{logical, whether to draw a legend}

  \item{xlab}{xlab}

  \item{ylab}{ylab}

  \item{log}{log}

  \item{cex}{cex}

  \item{...}{further arguments to \code{plot}}
}
\description{
A simple helper function that plots the per-gene dispersion
estimates together with the fitted mean-dispersion
relationship. Internally, it is a wrapper for the 
pltoDispEsts method from DESeq2.
}

