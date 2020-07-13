#
#	run_slim_tests.R
#
#	Run a suite of standard tests of SLiM across different versions and compare results
#
#	Created by Ben Haller on 5/3/17.
#	Copyright (c) 2017 Philipp Messer.  All rights reserved.
#	A product of the Messer Lab, http://messerlab.org/slim/
#

# What are all the SLiM versions that are available?
versions_path <- path.expand("~/Desktop/SLiM-Tests/")
versions <- list.files(versions_path, "slim[2-3].*", include.dirs=T)
versions


# Notes for old versions (some of which are not in this repository...)

# The slim2.3 versions left in are the ones that show known and understood transitions in outcome, before and after: 1 to 2 and 10 to 11;
# apart from discontinuities at those points, slim 2.4 and 2.3+ are supposed to behave the same as 2.3, so the discontinuity seen in test 038 is indeed a bug

# sub-versions post-2.3 are no longer of interest, but show two specific deliberate breaks in backward compatibility of output for some models

# the discontinuity from slim2.6+11_uniform_fitness_opt to slim2.6+12_recomb_overhaul is well-understood
# and is due to the switch to the new recombination-rate paradigm and the new gene conversion code

# the discontinuity from slim2.6+14_before_1e15_chr to slim2.6+15_after_1e15chr is well-understood and
# is due to the switch to using the MT64 RNG for all coin flips, and for chromosome position draws during
# crossover, changing the RNG sequence

# the discontinuity from slim2.6+15_after_1e15chr to slim2.6+16_new_rbinom_rdunif is well-understood, due
# to switching to using the MT64 RNG in some cases for the rdunif() and rbinom() functions

# there are several discontinuities from slim3.3-04_current-4-15 to slim3.3-05_current-5-4, all
# well-understood, due to (a) changing mmJukesCantor() from mu to alpha, (b) fixing a bug in nonWF .trees
# save/load, (c) fixing a bug that led to incorrect mutationCounts()/mutationFrequencies() results in
# nonWF models, and (d) the intential non-backward-compatible change to initializeGeneConversion()


# Select a subset of versions for testing; unless you're interested in historical comparisons,
# the last four versions generally suffices to establish discontinuities
versions <- versions[(length(versions) - 4) : length(versions)]
versions


# Note that putting "TSXC" in a version name will cause the -TSXC flag to be passed to slim,
# which will test tree-sequence recording and mutation recording with runtime crosschecks.
# Of course this flag is only recognized in relatively recent SLiM versions.

# To test with a DEBUG build, or any other special build, just make the build and put it in a folder
# that matches the grep pattern "slim[2-3].*".  Note that the versions are processed alphabetically,
# so if you want your special build to run last, ensure it is alphabetically last.


# Run a given test across the specified versions
actually_run_test <- function(test_name, test_versions, replicates=1, force_run=FALSE)
{
	testfile <- paste0(tests_path, test_name, ".slim")
	
	if (!file.exists(testfile))
		return
	
	script <- readLines(testfile)
	
	for (rep in 1:replicates)
	{
		for (version in test_versions)
		{
			if (!file.exists(testfile))
				break
			
			versionfolder <- paste0(versions_path, version, "/")
			
			old_wd <- getwd()
			setwd(versionfolder)
			
			slim_flags <- c("-m", "-t")
			
			if (grepl("TSXC", version, fixed=TRUE))
				slim_flags <- c(slim_flags, "-TSXC")
			
			supports_long_output <- !(version %in% c("slim2.0", "slim2.0.1", "slim2.0.2", "slim2.0.3", "slim2.0.4", "slim2.1", "slim2.1.1", "slim2.2", "slim2.2.1", "slim2.3", "slim2.3+_01_mutbackcompat", "slim2.3+_02_nobackwardcompat", "slim2.3+_03_mutindex_initial"))
			
			if (supports_long_output)
				slim_flags <- c("-l", slim_flags)
			
			# run the test script with replicates as requested
			outfile <- paste0(versionfolder, "TEST ", test_name, " REP ", rep, " out.txt")
			errfile <- paste0(versionfolder, "TEST ", test_name, " REP ", rep, " err.txt")
			if (force_run || !file.exists(outfile))
				system2("./slim", args=c(slim_flags, "-s", rep, shQuote(testfile)), stdout=outfile, stderr=errfile)
			
			setwd(old_wd)
		}
	}
}

# this does all the test-harness stuff around calls to actually_run_test()
run_test <- function(test_name, test_versions, replicates=1, force_run=FALSE, print_scripts=FALSE)
{
	testfile <- paste0(tests_path, test_name, ".slim")
	results <- NULL
	results.numeric <- NULL
	
	if (!file.exists(testfile))
	{
		cat("Test file does not exist.\n")
		return(NULL)
	}
	
	# do the runs of the test script
	actually_run_test(test_name, test_versions, replicates=replicates, force_run=force_run)
	
	if (!file.exists(testfile))
	{
		cat("Test file does not exist.\n")
		return(NULL)
	}
	
	# print the test script
	cat("\n---------------------------------------------------------------------------\n\n")
	cat("Test file: ", paste0(test_name, ".slim"), " (", replicates, " replicate", ifelse(replicates==1, "", "s"), ")\n\n", sep="")
	script <- readLines(testfile)
	if (print_scripts)
	{
		cat(script, sep="\n")
		cat("\n");
	}
	
	# find the output grep pattern in the script
	output_grep_pattern <- gsub("^.*\\.slim : (.*)$", "\\1", script[1])
	if ((length(output_grep_pattern) == 0) || (nchar(output_grep_pattern) == 0))
		stop(paste0("Output grep pattern not found in line:\n", script[1]))
	
	last_cpu <- NULL
	last_wall <- NULL
	
	for (version in test_versions)
	{
		versionfolder <- paste0(versions_path, version, "/")
		
		old_wd <- getwd()
		setwd(versionfolder)
		
		# run the test script with replicates as requested
		cpu_usages <- NULL
		wall_usages <- NULL
		initial_mems <- NULL
		peak_mems <- NULL
		patterns <- NULL
		mutruns <- NULL
		
		for (rep in 1:replicates)
		{
			if (!file.exists(testfile))
				break
			
			outfile <- paste0(versionfolder, "TEST ", test_name, " REP ", rep, " out.txt")
			errfile <- paste0(versionfolder, "TEST ", test_name, " REP ", rep, " err.txt")
			
			# if the error file exists, extract key info from it
			if (file.exists(errfile))
			{
				if (file.size(errfile) == 0)
				{
					file.remove(errfile)
				}
				else
				{
					errlines <- readLines(errfile)
					
					if ((length(grep("^ERROR ", errlines)) > 0) || (length(grep("^Error on script line ", errlines)) > 0))
					{
						cpu_usages <- c(cpu_usages, NA)
						wall_usages <- c(wall_usages, NA)
						initial_mems <- c(initial_mems, NA)
						peak_mems <- c(peak_mems, NA)
					}
					else
					{
						cpu_usage <- grep(" CPU time used: ", errlines, value=T)
						cpu_usage <- gsub("^.* used: (.*)$", "\\1", cpu_usage)
						cpu_usages <- c(cpu_usages, as.numeric(cpu_usage))
						
						wall_usage <- grep(" Wall time used: ", errlines, value=T)
						wall_usage <- gsub("^.* used: (.*)$", "\\1", wall_usage)
						wall_usages <- c(wall_usages, as.numeric(wall_usage))
						
						initial_mem <- grep(" Initial memory usage: ", errlines, value=T)
						initial_mem <- gsub("^.* usage: (.*) bytes .*$", "\\1", initial_mem)
						initial_mems <- c(initial_mems, as.numeric(initial_mem))
						
						peak_mem <- grep(" Peak memory usage: ", errlines, value=T)
						peak_mem <- gsub("^.* usage: (.*) bytes .*$", "\\1", peak_mem)
						peak_mems <- c(peak_mems, as.numeric(peak_mem))
					}
				}
			}
			
			# if the output file exists, search for the grep pattern and extract it
			if (file.exists(outfile))
			{
				if (file.size(outfile) == 0)
				{
					file.remove(outfile)
				}
				else
				{
					outlines <- readLines(outfile)
					
					pattern <- grep(output_grep_pattern, outlines, value=T)
					if (length(pattern) > 0)
						pattern <- gsub(output_grep_pattern, "\\1", pattern)
					else
						pattern <- NA
					patterns <- c(patterns, pattern)
					
					mutrun_find <- grep("^// Override mutation run count: (.*)$", outlines, value=T)
					if (length(mutrun_find) > 0)
					{
						mutrun <- gsub("^// Override mutation run count: (.*)$", "\\1", mutrun_find)
					}
					else
					{
						mutrun_find <- grep("^//    mutrun_count_ = (.*)$", outlines, value=T)
						if (length(mutrun_find) > 0)
							mutrun <- gsub("^//    mutrun_count_ = (.*)$", "\\1", mutrun_find)
						else
						{
							mutrun_find <- grep("^// Mutation run modal count: ([0-9]+) .*$", outlines, value=T)
							if (length(mutrun_find) > 0)
								mutrun <- gsub("^// Mutation run modal count: ([0-9]+) .*$", "\\1", mutrun_find)
							else
							{
								mutrun_find <- grep("^// Override mutation run count = ([0-9]+),.*$", outlines, value=T)
								if (length(mutrun_find) > 0)
								{
									mutrun <- gsub("^// Override mutation run count = ([0-9]+),.*$", "\\1", mutrun_find)
								}
								else
									mutrun <- NA
							}
						}
					}
					mutruns <- c(mutruns, as.numeric(mutrun))
				}
			}
		}
		
		# save off timing data so we can do a t-test at the end
		next_to_last_cpu <- last_cpu
		last_cpu <- cpu_usages
		next_to_last_wall <- last_wall
		last_wall <- wall_usages
		
		# CPU usage that is NULL, or all NA, indicates that the run failed, so use NA for everything
		if (is.null(cpu_usages) || all(is.na(cpu_usages)))
		{
			cpu_line <- paste0("  NA")
			wall_line <- paste0("  NA")
			initial_mem_line <- paste0("  NA")
			peak_mem_line <- paste0("  NA")
			pattern_line <- paste0("  NA")
			mutrun_line <- paste0("  NA")
			
			cpu_usages <- NA
			wall_usages <- NA
			initial_mems <- NA
			peak_mems <- NA
			mutruns <- NA
			first_output <- NA
		}
		else
		{
			cpu_usages <- mean(cpu_usages)
			wall_usages <- if (length(wall_usages) == 0) NA else mean(wall_usages)
			initial_mems <- mean(initial_mems)
			peak_mems <- mean(peak_mems)
			mutruns <- if (any(is.na(mutruns))) NA else mean(mutruns)
			
			cpu_line <- format(cpu_usages, digits=3, scientific=F)
			cpu_line <- paste0("  ", cpu_line, " secs")
			
			wall_line <- format(wall_usages, digits=3, scientific=F)
			wall_line <- paste0("  ", wall_line, " secs")
			
			initial_mem_line <- format(initial_mems / (1024*1024), digits=3, nsmall=2, scientific=F)
			initial_mem_line <- paste0("  ", initial_mem_line, " MB")
			
			peak_mem_line <- format(peak_mems / (1024*1024), digits=3, nsmall=2, scientific=F)
			peak_mem_line <- paste0("  ", peak_mem_line, " MB")
			
			# pattern_line <- paste(" ", paste0(" \"", patterns, "\""), sep="", collapse="")	# all output
			if (is.null(patterns[1]) || is.na(patterns[1]))
			{
				pattern_line <- paste0("  NA")
				first_output <- NA
			}
			else
			{
				pattern_line <- paste0("  \"", patterns[1], "\"")									# first output
				first_output <- patterns[1]
			}
			
			mutrun_line <- paste0("  ", mutruns)
		}
		
		setwd(old_wd)
		
		results <- rbind(results, data.frame(version=version, cpu=cpu_line, wall=wall_line, initial=initial_mem_line, peak=peak_mem_line, mutruns= mutrun_line, output=pattern_line))
		results.numeric <- rbind(results.numeric, data.frame(version=version, cpu=cpu_usages, wall=wall_usages, initial=initial_mems, peak=peak_mems, mutruns=mutruns, output=first_output, stringsAsFactors=F))
	}
	
	print(results);
	
	# print something if results have changed, to make it easier to find those
	output_col <- results$output
	if (length(output_col) > 2)
	{
		out1 <- output_col[length(output_col) - 1]
		out2 <- output_col[length(output_col)]
		if (!identical(out1, out2))
			cat("************** CHANGED *************\n")
	}
	
	# do a t-test to see if times changed significantly
	# it turns out significant differences are found that are nevertheless tiny, so this needs to look at effect size also
	# if (is.null(next_to_last_cpu) || is.null(last_cpu) || all(is.na(next_to_last_cpu)) || all(is.na(last_cpu)))
		# cat("************** CAN'T COMPARE TIMES *************\n")
	# else if (t.test(next_to_last_cpu, last_cpu, conf.level=0.99)$p.value < 0.01)
	# {
		# cat("************** TIMES DIFFER SIGNIFICANTLY *************\n")
		# print(next_to_last_cpu)
		# print(last_cpu)
		# print(t.test(next_to_last_cpu, last_cpu, conf.level=0.99))
	# }
	
	cat("\n");
	
	invisible(results.numeric);
}


# Run all tests that have not already been run; to re-run tests, run the clean code below first
tests_path <- path.expand("~/Desktop/SLiM-Tests/test scripts/")
tests <- list.files(tests_path, "*.slim")
tests <- gsub("^(.*)\\.slim$", "\\1", tests)	# strip off .slim extensions
tests

if (F)
{
	# Various ways to invoke run_test(); I generally run all this stuff from inside the R GUI app,
	# so if you want to run it from the command line, modify this script to do what you want...
	
	for (test in tests)
		run_test(test, versions, replicates=1)
	
	for (test in tests)
		run_test(test, versions, replicates=10)
	
	for (test in tests)
		run_test(test, versions, replicates=10, print_scripts=FALSE)
	
	run_test(tests[1], versions, replicates=1)
	
	run_test(tests[21], versions, replicates=10)
	
	run_test(tests[98], versions[12:15], replicates=10)
	
	for (test in tests[c(15,19,20,35,36,38:41,84:86,96:101)])
		run_test(test, versions[18:20], replicates=1)
}


# DO NOT RUN BY DEFAULT: Clean all test output files
if (F)
{
	for (dir in versions)
	{
		cat("Cleaning ", dir, "...", sep="");
		
		output_files <- list.files(paste0(versions_path, dir), "^TEST .*\\.txt", full.names=TRUE)
		for (file in output_files)
			file.remove(file)
			
		cat(" ", length(output_files), " output file(s) removed.\n", sep="")
	}
}

# DO NOT RUN BY DEFAULT: Clean a specific test (as specified with the grep pattern below)
if (F)
{
	for (dir in versions)
	{
		cat("Cleaning ", dir, "...", sep="");
		
		output_files <- list.files(paste0(versions_path, dir), "^TEST 153 .*\\.txt", full.names=TRUE)
		for (file in output_files)
			file.remove(file)
			
		cat(" ", length(output_files), " output file(s) removed.\n", sep="")
	}
}



















