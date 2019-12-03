#!/usr/bin/Rscript
library(reshape2)
library(ggplot2)
library(grid)
library(gridExtra)
library(plyr)

# Plots the stretch vs. unsched bytes from text data files generated by
# PlotDigeter.py script
stretch <- read.table("stretchVsUnschedBytes.txt",
    na.strings = "NA",
    col.names=c('TransportType', 'LoadFactor', 'WorkLoad', 'MsgSizeRange',
    'SizeCntPercent', 'BytesPercent', 'UnschedBytes', 'MeanStretch',
    'MedianStretch', 'TailStretch'), header=TRUE)
stretch$UnschedBytes <- factor(stretch$UnschedBytes)

allW <- c('W1', 'W2', 'W3', 'W4', 'W5')
allWorkloads <- c('FACEBOOK_KEY_VALUE', 'GOOGLE_SEARCH_RPC',
    'FABRICATED_HEAVY_MIDDLE', 'GOOGLE_ALL_RPC','FACEBOOK_HADOOP_ALL')
workloads <- allWorkloads[match(unique(stretch$WorkLoad), allWorkloads)]
levels(stretch$WorkLoad) <- allW[match(levels(stretch$WorkLoad), allWorkloads)]
stretch$WorkLoad <- as.character(stretch$WorkLoad)
stretch <- stretch[with(stretch, order(TransportType, WorkLoad)),]
stretch$WorkLoad <- as.factor(stretch$WorkLoad)
Ws <- levels(stretch$WorkLoad)

stretch$LoadFactor <- factor(stretch$LoadFactor)
stretch$TransportType <- factor(stretch$TransportType)
meanStretch <- subset(stretch,
    !is.na(MeanStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'WorkLoad', 'MsgSizeRange',
    'SizeCntPercent', 'BytesPercent', 'UnschedBytes', 'MeanStretch'))

meanStretch <- ddply(meanStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes), transform,
    SizeCumPercent = round(cumsum(SizeCntPercent), 2), 
    BytesCumPercent = round(cumsum(BytesPercent), 2))

meanStretch$MsgSizeRange <- as.numeric(as.character(
    meanStretch$MsgSizeRange))

medianStretch <- subset(stretch,
    !is.na(MedianStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'WorkLoad', 'MsgSizeRange',
    'SizeCntPercent', 'BytesPercent', 'UnschedBytes', 'MedianStretch'))

medianStretch <- ddply(medianStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes), transform,
    SizeCumPercent = round(cumsum(SizeCntPercent), 2),
    BytesCumPercent = round(cumsum(BytesPercent), 2))

medianStretch$MsgSizeRange <- as.numeric(
    as.character(medianStretch$MsgSizeRange))

tailStretch <- subset(stretch,
    !is.na(TailStretch) & !(MsgSizeRange %in% c('Huge', 'OverAllSizes')),
    select=c('TransportType', 'LoadFactor', 'WorkLoad', 'MsgSizeRange',
    'SizeCntPercent', 'BytesPercent', 'UnschedBytes', 'TailStretch'))

tailStretch <- ddply(tailStretch,
    .(TransportType, LoadFactor, WorkLoad, UnschedBytes), transform,
    SizeCumPercent = round(cumsum(SizeCntPercent), 2),
    BytesCumPercent = round(cumsum(BytesPercent), 2))

tailStretch$MsgSizeRange <- as.numeric(
    as.character(tailStretch$MsgSizeRange))

textSize <- 55 
titleSize <- 55 
yLimit <- 15
for (rho in unique(tailStretch$LoadFactor)) {
    i <- 0
    tailStretchPlot = list()
    for (workload in Ws) {
        # Use CDF as the x axis
        tmp <- subset(tailStretch, WorkLoad==workload & LoadFactor==rho,
            select=c('LoadFactor', 'WorkLoad', 'MsgSizeRange', 'SizeCntPercent',
            'SizeCumPercent', 'TransportType', 'TailStretch', 'UnschedBytes'))
        if (nrow(tmp) == 0) {
            next
        }

        i <- i+1
        plotTitle = sprintf("Workload: %s                                 ",
            workload)

        yLab = 'TailStretch (Log Scale)\n'
        xLab <- 'Message Sizes (Bytes)'

        # You might ask why I'm using "x=SizeCumPercent-SizeCntPercent/200" in
        # the plot? The reason is that ggplot geom_bar is so dumb and I was
        # not able to shift the bars to the write while setting the width of
        # each bar to be equal to it's size probability. So I ended up manaully
        # shift the bars to the the left for half of the probability and
        # setting the width equal to the probability
        tailStretchPlot[[i]] <- ggplot() +
            geom_step(data=tmp, aes(x=SizeCumPercent-SizeCntPercent/2,
            y=TailStretch, width=SizeCntPercent, colour=UnschedBytes), size=4)

        plotTitle <- paste(append(unlist(strsplit(plotTitle, split='')), '\n',
            as.integer(nchar(plotTitle)/2)), sep='', collapse='')

        xIntervals <- findInterval(c(0)+seq(2,102,10),
            tmp[tmp$UnschedBytes=='9328',]$SizeCumPercent)

        tailStretchPlot[[i]] <- tailStretchPlot[[i]] +
            theme(text = element_text(size=1.5*textSize),
                axis.text = element_text(size=1.3*textSize),
                axis.text.x = element_text(angle=75, vjust=0.5),
                strip.text = element_text(size = textSize),
                plot.title = element_text(size = 1.2*titleSize,
                color='darkblue'), plot.margin=unit(c(2,2,2.5,2.2),"cm"),
                legend.position = c(0.1, 0.85),
                legend.text = element_text(size=1.5*textSize)) +
            guides(colour = guide_legend(override.aes = list(size=textSize/4)))+
            scale_x_continuous(limits = c(0,101),
                breaks = tmp[xIntervals,]$SizeCumPercent,
                labels=tmp[xIntervals,]$MsgSizeRange, expand = c(0, 0)) +
            scale_y_log10(breaks=c(1,2,3,4,5,10,15)) +
            coord_cartesian(ylim=c(1, yLimit)) +
            labs(title = plotTitle, y = yLab, x = xLab)

    }
    pdf(sprintf("plots/changeUnschedBytes/TailStretchVsUnschedBytes_rho%s.pdf",
        rho), width=40, height=20*length(unique(tailStretch$WorkLoad)))
    args.list <- c(tailStretchPlot, list(ncol=1))
    do.call(grid.arrange, args.list)
    dev.off()
}


yLimit <- 5
for (rho in unique(medianStretch$LoadFactor)) {
    i <- 0
    medianStretchPlot = list()
    for (workload in Ws) {
        # Use CDF as the x axis
        tmp <- subset(medianStretch, WorkLoad==workload & LoadFactor==rho,
            select=c('LoadFactor', 'WorkLoad', 'MsgSizeRange', 'SizeCntPercent',
            'SizeCumPercent', 'TransportType', 'MedianStretch', 'UnschedBytes'))
        if (nrow(tmp) == 0) {
            next
        }
        i <- i+1
        plotTitle =
            sprintf("Workload: %s                                 ", workload)

        yLab = 'MedianStretch (Log Scale)\n'
        xLab <- 'Message Sizes (Bytes)'

        # You might ask why I'm using "x=SizeCumPercent-SizeCntPercent/200" in
        # the plot? The reason is that ggplot geom_bar is so dumb and I was not
        # able to shift the bars to the write while setting the width of each
        # bar to be equal to it's size probability. So I ended up manaully shift
        # the bars to the the left for half of the probability and setting the
        # width equal to the probability
        medianStretchPlot[[i]] <- ggplot() + geom_step(data=tmp,
            aes(x=SizeCumPercent-SizeCntPercent/2, y=MedianStretch,
            width=SizeCntPercent, colour=UnschedBytes),
            size=4)

        plotTitle <- paste(append(unlist(strsplit(plotTitle, split='')), '\n',
            as.integer(nchar(plotTitle)/2)), sep='', collapse='')
        
        xIntervals <- findInterval(c(0)+seq(2,102,10),
            tmp[tmp$UnschedBytes=='9328',]$SizeCumPercent)

        medianStretchPlot[[i]] <- medianStretchPlot[[i]] +
            theme(text = element_text(size=1.5*textSize),
                axis.text = element_text(size=1.3*textSize),
                axis.text.x = element_text(angle=75, vjust=0.5),
                strip.text = element_text(size = textSize),
                plot.title = element_text(size = 1.2*titleSize,
                color='darkblue'), plot.margin=unit(c(2,2,2.5,2.2),"cm"),
                legend.position = c(0.1, 0.85),
                legend.text = element_text(size=1.5*textSize)) +
            guides(colour = guide_legend(override.aes = list(size=textSize/4)))+
            scale_x_continuous(limits = c(0,101),
                breaks = tmp[xIntervals,]$SizeCumPercent,
                labels=tmp[xIntervals,]$MsgSizeRange, expand = c(0, 0)) +
            scale_y_log10(breaks=c(1,2,3,4,5,10,15)) +
            coord_cartesian(ylim=c(1, yLimit)) +
            labs(title = plotTitle, y = yLab, x = xLab)

    }
    pdf(sprintf("plots/changeUnschedBytes/MedianStretchVsUnschedBytes_rho%s.pdf",
        rho), width=40, height=20*length(unique(medianStretch$WorkLoad)))
    args.list <- c(medianStretchPlot, list(ncol=1))
    do.call(grid.arrange, args.list)
    dev.off()
}

for (rho in unique(meanStretch$LoadFactor)) {
    i <- 0
    meanStretchPlot = list()
    for (workload in Ws) {
        # Use CDF as the x axis
        tmp <- subset(meanStretch, WorkLoad==workload & LoadFactor==rho,
            select=c('LoadFactor', 'WorkLoad', 'MsgSizeRange', 'SizeCntPercent',
            'SizeCumPercent', 'TransportType', 'MeanStretch', 'UnschedBytes'))

        if (nrow(tmp) == 0) {
            next
        }
        i <- i+1
        plotTitle =
            sprintf("Workload: %s                                 ", workload)

        yLab = 'MeanStretch (Log Scale)\n'
        xLab <- 'Message Sizes (Bytes)'

        # You might ask why I'm using "x=SizeCumPercent-SizeCntPercent/200" in
        # the plot? The reason is that ggplot geom_bar is so dumb and I was not
        # able to shift the bars to the write while setting the width of each
        # bar to be equal to it's size probability. So I ended up manaully shift
        # the bars to the the left for half of the probability and setting the
        # width equal to the probability
        meanStretchPlot[[i]] <- ggplot() + geom_step(data=tmp,
            aes(x=SizeCumPercent-SizeCntPercent/2, y=MeanStretch,
            width=SizeCntPercent, colour=UnschedBytes), size=4)

        plotTitle <- paste(append(unlist(strsplit(plotTitle, split='')), '\n',
            as.integer(nchar(plotTitle)/2)), sep='', collapse='')

        xIntervals <- findInterval(c(0)+seq(2,102,10),
            tmp[tmp$UnschedBytes=='9328',]$SizeCumPercent)

        meanStretchPlot[[i]] <- meanStretchPlot[[i]] +
            theme(text = element_text(size=1.5*textSize),
                axis.text = element_text(size=1.3*textSize),
                axis.text.x = element_text(angle=75, vjust=0.5),
                strip.text = element_text(size=textSize),
                plot.title = element_text(size=1.2*titleSize, color='darkblue'),
                plot.margin=unit(c(2,2,2.5,2.2),"cm"),
                legend.position = c(0.1, 0.85),
                legend.text = element_text(size=1.5*textSize)) +
            guides(colour = guide_legend(override.aes = list(size=textSize/4)))+
            scale_x_continuous(limits = c(0,101),
                breaks = tmp[xIntervals,]$SizeCumPercent,
                labels=tmp[xIntervals,]$MsgSizeRange, expand = c(0, 0)) +
            scale_y_log10(breaks=c(1,2,3,4,5,10,15)) +
            coord_cartesian(ylim=c(1, yLimit)) +
            labs(title = plotTitle, y = yLab, x = xLab)
    }
    pdf(sprintf("plots/changeUnschedBytes/MeanStretchVsUnschedBytes_rho%s.pdf",
        rho), width=40, height=20*length(unique(meanStretch$WorkLoad)))
    args.list <- c(meanStretchPlot, list(ncol=1))
    do.call(grid.arrange, args.list)
    dev.off()
}
