#
#
#	This script has not been maintained in ages; I'm committing it to get it off
#	my machine, but it is not presently usable.  BCH 4/14/2025
#
#


# plot
cpu_data <- NULL
mem_data <- NULL
out_data <- NULL
tests_included <- NULL

for (test in tests)
{
	# exclude tests that fix the mutrun count, not representative
	if ((test == "010.1 downscaled Gravel 1MR") || (test == "011.1 full Gravel 1MR") || (test == "015.1 genetic structure 1MR ***") || (test == "016.1 intensive neutral 32MR"))
		next
	
	# exclude nucleotide tests that don't include vectorized addNewDrawnMutation()
	if ((test == "097 modeling nucleotides") || (test == "098 modeling nucleotides 1000"))
		next
	
	results <- run_test(test, versions, replicates=4)
	cpu <- results$cpu
	mem <- results$peak
	out <- results$output
	
	cpu_data <- rbind(cpu_data, cpu)
	mem_data <- rbind(mem_data, mem)
	out_data <- rbind(out_data, out)
	tests_included <- c(tests_included, test)
}

names <- as.character(results$version)
names[8] <- "nonWF 1"
names[9] <- "nonWF 2"
names[10] <- "objpools"
names[11] <- "poolinline"
names[12] <- "genomeptrs"
names[13] <- "cutfs"
names[14] <- "propaccel"
names[15] <- "plotopts"
names[16] <- "moreopts"

colnames(cpu_data) <- names
colnames(mem_data) <- names
colnames(out_data) <- names

rownames(cpu_data) <- NULL
rownames(mem_data) <- NULL
rownames(out_data) <- NULL

cpu_data <- cpu_data[, c(1:7,16)]
mem_data <- mem_data[, c(1:7,16)]
out_data <- out_data[, c(1:7,16)]

names <- c("SLiM 2.0", "SLiM 2.1", "SLiM 2.2", "SLiM 2.3", "SLiM 2.4", "SLiM 2.5", "SLiM 2.6", "SLiM 3.0")

quartz(width=10, height=5)
par(mar=c(3.1, 3.1, 2, 2), tcl=-0.3, mgp=c(1.9, 0.4, 0), family="serif")
plot(x=1:8, y=seq(1, 22, length.out=8), cex.axis=0.8, cex.lab=1.0, type="n", xlab="SLiM version", ylab="Speedup factor (log scale)", xaxt="n", yaxt="n", log="y")
axis(side=1, at=1:8, labels=names, cex.axis=0.8)
axis(side=2, at=c(1,2,4,8,16), labels=c("1", "2", "4", "8", "16"), cex.axis=0.8)

totals <- numeric(8)
counts <- integer(8)

for (iter in 1:2)
{
	for (row in 2:NROW(cpu_data))
	{
		times <- cpu_data[row,]
		outs <- out_data[row,]
		
		indices <- 1:8
		time.na <- is.na(times)
		out.na <- is.na(outs)
		
		# exclude points with an NA time or out
		ok <- (!time.na & !out.na)
		indices <- indices[ok]
		times <- times[ok]
		outs <- outs[ok]
		
		# exclude SLiM 2.4 when it messed up
		slim24_index <- which(indices==5)
		if (length(slim24_index) > 0)
			if (outs[slim24_index] == "0")
			{
				ok <- (indices != 5)
				indices <- indices[ok]
				times <- times[ok]
				outs <- outs[ok]
			}
		
		# rescale
		max_time <- max(times)
		speedups <- max_time / times	# speed-ups
		times <- times / max_time
		
		# plot
		still_slow <- (times[length(times)] > 0.7)
		
		if ((still_slow && (iter == 1)) || (!still_slow && (iter == 2)))
			next
		
		if (still_slow)
			cat(paste0("still slow: ", tests_included[row], "\n"))
		
		lines(indices, speedups, col=(if (still_slow) "black" else "#CCCCCC"))
		totals[indices] <- totals[indices] + speedups
		counts[indices] <- counts[indices] + 1
	}
}

lines(1:8, (totals / counts), col="red", lwd=3)
box()

(totals / counts)
(totals / counts)[1] / (totals / counts)[8]


