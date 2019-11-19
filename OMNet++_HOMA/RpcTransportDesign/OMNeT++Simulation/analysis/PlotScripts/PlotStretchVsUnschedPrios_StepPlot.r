#!/usr/bin/Rscript
library(reshape2)
library(ggplot2)
library(grid)
library(gridExtra)
library(plyr)

# Plots the stretch vs. unsched bytes from text data files generated by
# PlotDigeter.py script
stretch <- read.table("stretchVsUnschedPrios.txt",
    na.strings = "NA",
    col.names=c('TransportType', 'LoadFactor', 'PrioLevels', 'SchedPrios',
    'WorkLoad', 'MsgSizeRange', 'SizeCntPercent', 'BytesPercent',
    'UnschedBytes', 'MeanStretch', 'MedianStretch', 'TailStretch'),
    header=TRUE)
stretch$UnschedPrios <- stretch$PrioLevels - stretch$SchedPrios
stretch$TransportType <- factor(stretch$TransportType)

allW <- c('W1', 'W2', 'W3', 'W4', 'W5')
allWorkloads <- c('FACEBOOK_KEY_VALUE', 'GOOGLE_SEARCH_RPC',
    'FABRICATED_HEAVY_MIDDLE', 'GOOGLE_ALL_RPC','FACEBOOK_HADOOP_ALL')
workloads <- allWorkloads[match(unique(stretch$WorkLoad), allWorkloads)]
levels(stretch$WorkLoad) <- allW[match(levels(stretch$WorkLoad), allWorkloads)]
stretch$WorkLoad <- as.character(stretch$WorkLoad)
stretch <- stretch[with(stretch, order(TransportType, WorkLoad, PrioLevels)),]
stretch$WorkLoad <- as.factor(stretch$WorkLoad)
Ws <- levels(stretch$WorkLoad)

meanStretch <- subset(stretch,
    !is.na(MeanStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'PrioLevels', 'SchedPrios',
    'WorkLoad', 'MsgSizeRange', 'SizeCntPercent', 'BytesPercent',
    'UnschedBytes', 'MeanStretch', 'UnschedPrios'))

meanStretch <- ddply(meanStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes, SchedPrios,
    PrioLevels), transform, SizeCumPercent = round(cumsum(SizeCntPercent), 2),
    BytesCumPercent = round(cumsum(BytesPercent), 2))

meanStretch$MsgSizeRange <- as.numeric(as.character(
    meanStretch$MsgSizeRange))

medianStretch <- subset(stretch,
    !is.na(MedianStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'PrioLevels', 'SchedPrios',
    'WorkLoad', 'MsgSizeRange', 'SizeCntPercent', 'BytesPercent',
    'UnschedBytes', 'MedianStretch', 'UnschedPrios'))

medianStretch <- ddply(medianStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes, SchedPrios,
    PrioLevels), transform, SizeCumPercent = round(cumsum(SizeCntPercent), 2),
    BytesCumPercent = round(cumsum(BytesPercent), 2))

medianStretch$MsgSizeRange <- as.numeric(
    as.character(medianStretch$MsgSizeRange))

tailStretch <- subset(stretch,
    !is.na(TailStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'PrioLevels', 'SchedPrios',
    'WorkLoad', 'MsgSizeRange', 'SizeCntPercent', 'BytesPercent',
    'UnschedBytes', 'TailStretch', 'UnschedPrios'))

tailStretch <- ddply(tailStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes, SchedPrios,
    PrioLevels), transform, SizeCumPercent = round(cumsum(SizeCntPercent), 2),
    BytesCumPercent = round(cumsum(BytesPercent), 2))

tailStretch$MsgSizeRange <- as.numeric(as.character(tailStretch$MsgSizeRange))

textSize <- 55 
titleSize <- 55 
yLimit <- 15
rhos = c(0.8)
#rhos = unique(tailStretch$LoadFactor)

for (rho in rhos) {
    i <- 0
    tailStretchPlot = list()
    for (workload in Ws) {
        # Use CDF as the x axis
        tmp <- subset(tailStretch, WorkLoad==workload & LoadFactor==rho,
            select=c('MsgSizeRange', 'SizeCntPercent', 'UnschedPrios',
            'SizeCumPercent', 'TailStretch'))
        tmp$UnschedPrios <- factor(tmp$UnschedPrios)
        if (nrow(tmp) == 0) {
            next
            print("skiped workload")
        }

        i <- i+1
        plotTitle = sprintf("Workload: %s", workload)

        yLab = 'TailStretch (Log Scale)\n'
        xLab <- 'Message Sizes (Cumulative Sizes %)'

        tailStretchPlot[[i]] <- ggplot() + geom_step(data=tmp,
            aes(x=SizeCumPercent-SizeCntPercent/2, y=TailStretch,
            width=SizeCntPercent, colour=UnschedPrios), size=3)

        xIntervals <- findInterval(c(0)+seq(2,102,10),
            tmp[tmp$UnschedPrios==unique(tmp$UnschedPrios)[1],]$SizeCumPercent)

        tailStretchPlot[[i]] <- tailStretchPlot[[i]] +
            theme(text = element_text(size=1.5*textSize),
                axis.text = element_text(size=1.3*textSize),
                axis.text.x = element_text(angle=75, vjust=0.5),
                strip.text = element_text(size = textSize),
                plot.title = element_text(size = 1.2*titleSize,
                    color='darkblue'),
                plot.margin=unit(c(2,2,2.5,2.2),"cm"),
                legend.position = c(0.1, 0.85),
                legend.text = element_text(size=1.5*textSize)) +
            guides(colour = guide_legend(
                override.aes = list(size=textSize/4)))+
            scale_x_continuous(limits = c(0,101),
                breaks = tmp[xIntervals,]$SizeCumPercent,
                labels=tmp[xIntervals,]$MsgSizeRange, expand = c(0, 0)) +
            scale_y_log10(breaks=c(1,2,3,4,5,10,15)) +
            coord_cartesian(ylim=c(1, yLimit)) +
            labs(title = plotTitle, y = yLab, x = xLab)
    }

    pdf(sprintf(paste("plots/unschedPrios/",
        "TailStretchVsUnschedPrios_rho%s_SizePct.pdf", sep=''), rho),
        width=30*length(prioLevels),
        height=20*length(Ws))
    args.list <- c(tailStretchPlot, list(ncol=length(prioLevels)))
    do.call(grid.arrange, args.list)
    dev.off()
}

for (rho in rhos) {
    i <- 0
    tailStretchPlot = list()
    for (workload in Ws) {
        # Use CDF as the x axis
        tmp <- subset(tailStretch, WorkLoad==workload & LoadFactor==rho,
            select=c('MsgSizeRange', 'BytesPercent', 'UnschedPrios',
            'BytesCumPercent', 'TailStretch'))
        tmp$UnschedPrios <- factor(tmp$UnschedPrios)
        if (nrow(tmp) == 0) {
            next
            print("skiped workload")
        }

        i <- i+1
        plotTitle = sprintf("Workload: %s", workload)

        yLab = 'TailStretch (Log Scale)\n'
        xLab <- 'Message Sizes (Cumulative Sizes %)'

        tailStretchPlot[[i]] <- ggplot() + geom_step(data=tmp,
            aes(x=BytesCumPercent-BytesPercent/2, y=TailStretch,
            width=BytesPercent, colour=UnschedPrios), size=3)

        xIntervals <- findInterval(c(0)+seq(2,102,10),
            tmp[tmp$UnschedPrios==unique(tmp$UnschedPrios)[1],]$BytesCumPercent)

        tailStretchPlot[[i]] <- tailStretchPlot[[i]] +
            theme(text = element_text(size=1.5*textSize),
                axis.text = element_text(size=1.3*textSize),
                axis.text.x = element_text(angle=75, vjust=0.5),
                strip.text = element_text(size = textSize),
                plot.title = element_text(size = 1.2*titleSize,
                    color='darkblue'),
                plot.margin=unit(c(2,2,2.5,2.2),"cm"),
                legend.position = c(0.1, 0.85),
                legend.text = element_text(size=1.5*textSize)) +
            guides(colour = guide_legend(
                override.aes = list(size=textSize/4)))+
            scale_x_continuous(limits = c(0,101),
                breaks = tmp[xIntervals,]$BytesCumPercent,
                labels=tmp[xIntervals,]$MsgSizeRange, expand = c(0, 0)) +
            scale_y_log10(breaks=c(1,2,3,4,5,10,15)) +
            coord_cartesian(ylim=c(1, yLimit)) +
            labs(title = plotTitle, y = yLab, x = xLab)
    }

    pdf(sprintf(paste("plots/unschedPrios/",
        "TailStretchVsUnschedPrios_rho%s_BytesPct.pdf", sep=''), rho),
        width=30*length(prioLevels),
        height=20*length(Ws))
    args.list <- c(tailStretchPlot, list(ncol=length(prioLevels)))
    do.call(grid.arrange, args.list)
    dev.off()
}
