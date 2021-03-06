setClass("DEXSeqDataSet",
    contains = "DESeqDataSet",
        representation = representation( modelFrameBM = "data.frame") )

DEXSeqDataSet <- function( countData, sampleData, design= ~ sample + exon + condition:exon , featureID, groupID, featureRanges=NULL, transcripts=NULL, alternativeCountData=NULL)
{
    ### Checking inputs ###
    if( !(is( countData, "matrix" ) | is( countData, "data.frame" )) )
      stop( "Unexpected input: the parameter 'countData' must be either a matrix or a data.frame", 
            call.=FALSE )
    countData <- as.matrix( countData )
    if( !( is( featureID, "character" ) | is( featureID, "factor" ) ) )
      stop( "Unexpected input: the parameter 'featureID' must be either a character or a factor", 
            call.=FALSE )
    if( !( is( groupID, "character" ) | is( groupID, "factor" ) ) )
      stop( "Unexpected input: the parameter 'groupID' must be either a character or a factor", 
            call.=FALSE )
    if( !is( sampleData, "data.frame" ) )
      stop( "Unexpected input: the parameter 'sampleData' must be a data.frame", 
            call.=FALSE )
    rowNumbers <- nrow( countData )
    if( length(groupID) != rowNumbers )
      stop( "Unexpected length of 'groupID' parameter, it must be the same as the number of rows of countData", 
            call.=FALSE )
    if( length(featureID) != rowNumbers )
      stop( "Unexpected length of 'featureID' parameter, it must be the same as the number of rows of countData", 
            call.=FALSE )
    if( nrow(sampleData) != ncol(countData) )
      stop( "Unexpected number of rows of the 'sampleData' parameter, it must be the same as the number of columns of countData", 
            call.=FALSE )
    
    modelFrame <- cbind(
        sample = rownames(sampleData), sampleData )
    modelFrame <- rbind( cbind(modelFrame, exon = "this"),
                        cbind(modelFrame, exon = "others"))
    rownames(modelFrame) <- NULL
    colData <- DataFrame( modelFrame )
    
    if( !"exon" %in% all.vars( design ) )
        stop("The design formula does not specify an interaction contrast with the variable 'exon'", 
             call.=FALSE )

    allVars <- all.vars(design)
    if( any(!allVars %in% colnames( colData )) ){
        notPresent <- allVars[!allVars %in% colnames( colData ) ]
        notPresent <- paste(notPresent, collapse=",")
        stop(sprintf("The variables '%s', present in the design formula must be columns of 'sampleData'", 
                     notPresent ),
             call.=FALSE )
    }

    if( any( grepl(" |:", groupID ) | grepl(" |:", featureID) ) ) {
        warning("empty spaces or ':' characters were found either in your groupIDs or in your featureIDs, these will be removed from the identifiers")
        groupID <- gsub(" |:", "", groupID)
        featureID <- gsub(" |:", "", featureID)
    }

    rownames( countData ) <- paste( groupID, featureID, sep=":" )
    forCycle <- split( seq_len(nrow( countData )), as.character( groupID ) )

    if( is.null(alternativeCountData) ){
        others <- lapply( forCycle, function(i){
        sct <- countData[i, , drop = FALSE]
        rs <- t( vapply( seq_len(nrow(sct)), function(r) colSums(sct[-r, , drop = FALSE]), numeric(ncol(countData) ) ) )
        rownames(rs) <- rownames(sct)
        rs })
        others <- do.call(rbind, others)
    }else{
        stopifnot( identical(dim(countData), dim(alternativeCountData)) )
        stopifnot( identical( colnames(countData), colnames(alternativeCountData)))
        others <- alternativeCountData
        rownames( others ) <- paste( groupID, featureID, sep=":" )

    }
    
    stopifnot( all( rownames(countData) %in% rownames(others) ) )
    others <- others[rownames(countData),]
    nCountData <- cbind( countData, others )
    colnames(nCountData) <- NULL

    if( !is.null(featureRanges) ){
        stopifnot(is(featureRanges, "GRanges") ||
                  is(featureRanges, "GRangesList"))
        se <- SummarizedExperiment( nCountData, colData=colData, rowRanges=featureRanges )
    }else{
        se <- SummarizedExperiment( nCountData, colData=colData )
    }

    names(assays(se))[1] = "counts"
    mcols( se )$featureID <- featureID
    mcols( se )$groupID <- groupID
    mcols( se )$exonBaseMean <- rowMeans( countData )
    mcols( se )$exonBaseVar <- rowVars( countData )

    if( !is.null(transcripts) ){
        mcols(se)$transcripts <- transcripts
    }

    rownames(se) <- paste( groupID, featureID, sep=":")
    rse <- as( se, "RangedSummarizedExperiment" )
    mcols(rse) <- mcols(se)

    dds <- DESeqDataSet( rse, design, ignoreRank=TRUE )

    modelFrame <- makeBigModelFrame(dds)

    dxd <- new( "DEXSeqDataSet", dds, modelFrameBM=modelFrame )
    return(dxd)
}

makeBigModelFrame <- function(object){
    groupID <- mcols(object)$groupID
    featureID <- mcols(object)$featureID
    sampleData <- as.data.frame(colData(object)[colData(object)$exon == "this",])
    numExonsPerGene <- table(groupID)
    maxGene <- names(which.max(numExonsPerGene))
    rows <- mcols(object)$groupID %in%  maxGene
    numExons <- sum( rows )
    exonCol <-
        rep(factor(featureID[rows]), nrow(sampleData))
    modelFrame <- data.frame(
        sample=rep( sampleData$sample, each=numExons),
        exon = exonCol )
    varNames <- colnames(sampleData)[!colnames(sampleData) %in% c("sample", "exon")]
    for( i in varNames ){
        modelFrame[[i]] <- rep( sampleData[[i]], each=numExons )
    }
    modelFrame$dispersion <- NA
    if( is.null(object$sizeFactor )){
        modelFrame$sizeFactor <- NA
    }
    modelFrame$count <- NA
    modelFrame
}

setValidity( "DEXSeqDataSet", function( object ) {
    stopifnot(
        c("sample", "exon", "dispersion", "sizeFactor", "count")
        %in% colnames( object@modelFrameBM ) )
    stopifnot( all(object@modelFrameBM$sample %in% colData(object)$sample))
    stopifnot( all( c("sample", "exon") %in% colnames(colData(object)) ) )
    TRUE
} )

setClass("DEXSeqResults",
         contains = "DFrame",
         representation = representation( modelFrameBM = "data.frame", sampleData="DataFrame", dispersionFunction = "function") )


setValidity( "DEXSeqResults", function( object ){
    stopifnot( "sample" %in% colnames( object@sampleData ) )
    stopifnot( colnames(object$countData) == as.character(object@sampleData$sample) )
    TRUE
})

###########################
#### ACCESSOR FUNCTIONS####
###########################


featureCounts <- function( object, normalized=FALSE ){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    validObject(object)
    res <- counts(object, normalized=normalized)[,colData(object)$exon == "this"]
    colnames( res ) <- sampleAnnotation(object)$sample
    res
}

featureIDs <- function(object){
    if( is( object, "DEXSeqDataSet") ){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
        if (!.hasSlot(object, "rowRanges"))
            object <- updateObject(object)
        validObject(object)
        mcols(object)$featureID
    }else if( is(object, "DEXSeqResults") ){
        object$featureID
    }
}

`featureIDs<-` <- function( object, value ) {
     stopifnot( is( object, "DEXSeqDataSet" ) )
     # Temporary hack for backward compatibility with "old" DEXSeqDataSet
     # objects. Remove once all serialized DEXSeqDataSet objects around have
     # been updated.
     if (!.hasSlot(object, "rowRanges"))
         object <- updateObject(object)
     mcols(object)$featureID <- value
     rownames(object) <- paste( mcols(object)$groupID, mcols(object)$featureID, sep=":" )
     validObject(object)
     object
}

exonIDs <- function(object){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    validObject(object)
    featureIDs(object)
}

`exonIDs<-` <- function( object, value ) {
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    object <- `featureIDs<-`( object, value )
    object
}

groupIDs <- function( object ){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    validObject( object )
    mcols( object )$groupID
}

`groupIDs<-` <- function( object, value ) {
     stopifnot( is( object, "DEXSeqDataSet" ) )
     # Temporary hack for backward compatibility with "old" DEXSeqDataSet
     # objects. Remove once all serialized DEXSeqDataSet objects around have
     # been updated.
     if (!.hasSlot(object, "rowRanges"))
         object <- updateObject(object)
     mcols( object )$groupID <- value
     rownames(object) <- paste( mcols(object)$groupID, mcols(object)$featureID, sep=":" )
     validObject( object )
     object
}

geneIDs <- function( object ){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    validObject( object )
    groupIDs( object )
}

`geneIDs<-` <- function( object, value ) {
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
    # been updated.
    if (!.hasSlot(object, "rowRanges"))
        object <- updateObject(object)
    object <- `groupIDs<-`(object, value)
    object
}


sampleAnnotation <- function( object ){
    # Temporary hack for backward compatibility with "old" DEXSeqDataSet
    # objects. Remove once all serialized DEXSeqDataSet objects around have
                                        # been updated.
    if( is( object, "DEXSeqDataSet")){
        if (!.hasSlot(object, "rowRanges"))
            object <- updateObject(object)
        validObject( object )
        colData( object )[colData( object )$exon == "this",!colnames(colData( object )) %in% "exon"]
    }else if( is(object, "DEXSeqResults") ){
        object@sampleData
    }
}

#################
###FROM HTSEQ####
#################


DEXSeqDataSetFromHTSeq <- function( countfiles, sampleData, design= ~ sample + exon + condition:exon, flattenedfile=NULL )
{
    if( !all( sapply(countfiles, class) == 'character' ) ){
        stop("The countfiles parameter must be a character vector")
    }
    lf <- lapply( countfiles, function(x)
        read.table( x, header=FALSE,stringsAsFactors=FALSE ) )
    if( !all( sapply( lf[-1], function(x) all( x$V1 == lf[1]$V1 ) ) ) )
        stop( "Count files have differing gene ID column." )
    dcounts <- sapply( lf, `[[`, "V2" )
    rownames(dcounts) <- lf[[1]][,1]
    dcounts <- dcounts[ substr(rownames(dcounts),1,1)!="_", ]
    rownames(dcounts) <- sub(":", ":E", rownames(dcounts))
    colnames(dcounts) <- countfiles
    splitted <- strsplit(rownames(dcounts), ":")
    exons <- sapply(splitted, "[[", 2)
    genesrle <- sapply( splitted, "[[", 1)
    if(!is.null(flattenedfile)){
        aggregates<-read.delim(flattenedfile, stringsAsFactors=FALSE, header=FALSE)
        colnames(aggregates)<-c("chr", "source", "class", "start", "end", "ex", "strand", "ex2", "attr")
        aggregates$strand <- gsub( "\\.", "*", aggregates$strand )
        aggregates<-aggregates[which(aggregates$class =="exonic_part"),]
        aggregates$attr <- gsub("\"|=|;", "", aggregates$attr)
        aggregates$gene_id <- sub(".*gene_id\\s(\\S+).*", "\\1", aggregates$attr)
        transcripts <- gsub(".*transcripts\\s(\\S+).*", "\\1", aggregates$attr)
        transcripts <- strsplit(transcripts, "\\+")
        exonids <- gsub(".*exonic_part_number\\s(\\S+).*", "\\1", aggregates$attr)
        exoninfo<-GRanges(
            as.character(aggregates$chr),
            IRanges(start=aggregates$start, end=aggregates$end),
            strand=aggregates$strand)
        names( exoninfo ) <- paste( aggregates$gene_id, exonids, sep=":E" )
        names(transcripts) <- rownames(exoninfo)
        if (!all( rownames(dcounts) %in% names(exoninfo) )){
            stop("Count files do not correspond to the flattened annotation file")
        }
        matching <- match(rownames(dcounts), names(exoninfo))
        stopifnot( all( names( exoninfo[matching] ) == rownames(dcounts) ) )
        stopifnot( all( names( transcripts[matching] ) == rownames(dcounts) ) )

        dxd <- DEXSeqDataSet( dcounts, sampleData, design, exons, genesrle,
                             exoninfo[matching], transcripts[matching] )
        return(dxd)
    }else{
        dxd <- DEXSeqDataSet( dcounts, sampleData, design, exons, genesrle)
        return(dxd)
    }
}

DEXSeqDataSetFromSE <- function( SE, design= ~ sample + exon + condition:exon ){
    if( !all( c("gene_id", "tx_name") %in% colnames( mcols( SE  ) ) ) ){
      stop("make sure your SummarizedExperiment object contain the columns gene_id and tx_name")
    }
    SE <- SE[order(mcols(SE)$gene_id),]
    groupID <- as.character( mcols(SE)$gene_id )
    ln <- table( groupID )
    mcols(SE)$exonic_part <- unlist( lapply( ln, function(x){1:x}) )
    stopifnot( all( rep(names(ln), ln) == groupID ) )
    featureID <- sprintf("E%3.3d",  mcols(SE)$exonic_part )
    transcripts <- as.list( mcols(SE)$tx_name )
    sampleData <- as.data.frame( colData(SE) )
    design <- design
    mcols(SE) <- NULL
    featureRanges <- rowRanges(SE)
    countData <- assay(SE)
    dxd <- DEXSeqDataSet( countData,
        sampleData,
        design,
        featureID,
        groupID,
        featureRanges=featureRanges,
        transcripts=transcripts )
    dxd
}
