#!/usr/bin/Rscript
library(reshape2)
library(ggplot2)
library(gridExtra)

# Plots the stretch vs. unsched bytes from text data files generated by PlotDigeter.py script
stretchVsUnsched <- read.table("stretchVsUnsched.txt", na.strings = "NA",
        col.names=c('LoadFactor', 'WorkLoad', 'MsgSizeRange', 'SizeCntPercent', 'BytesPercent', 'UnschedBytes', 'MeanStretch', 'MedianStretch', 'TailStretch'),
        header=TRUE, row.names=NULL)
tailStretchVsUnsched <- subset(stretchVsUnsched, !is.na(TailStretch), select=c('LoadFactor', 'WorkLoad', 'MsgSizeRange', 'UnschedBytes', 'TailStretch'))
nCols = length(unique(stretchVsUnsched$WorkLoad))
pdf("TailStretchVsUnsched.pdf", width=60, height=40)
homa_plot <- ggplot(tailStretchVsUnsched, aes(x=MsgSizeRange, y=TailStretch, group=2))+
    geom_line(aes(color=LoadFactor, size = 10, alpha = 0.8)) +
    theme(text = element_text(size=60, face="bold"), axis.text.x = element_text(angle=75, vjust=0.5),
    	strip.text.x = element_text(size = 50), strip.text.y = element_text(size = 50)) + 
    scale_x_continuous() +
    scale_y_continuous() +
    aes(ymin=1, xmin=0)
print(homa_plot)
dev.off()



