#!/usr/bin/env Rscript

# Load required libraries
if (!require("scholar")) {
  install.packages("scholar")
  library(scholar)
}
library(dplyr)
library(readr)

#' Fetch papers from multiple Google Scholar profiles
#'
#' @param input_csv_path Character: Path to the input CSV file with scholar information
#' @param output_csv_path Character: Path where the output CSV will be saved
#' @param max_papers Integer: Maximum number of papers to fetch per author (default: 100)
#' @param use_cites Logical: Whether to sort results by citation count (default: TRUE)
#' @return DataFrame: Combined dataframe of all papers
fetch_scholar_papers <- function(input_csv_path = "scholars.csv", 
                              output_csv_path = "scholar_papers.csv",
                              max_papers = 100,
                              use_cites = TRUE) {
  
  # Read the scholars CSV file
  scholars <- read_csv(input_csv_path)
  
  # Check if required columns exist
  required_cols <- c("name", "id")
  missing_cols <- required_cols[!required_cols %in% names(scholars)]
  
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in input CSV:", 
              paste(missing_cols, collapse = ", ")))
  }
  
  # Initialize empty dataframe for results
  all_papers <- data.frame()
  
  # Process each scholar
  for (i in 1:nrow(scholars)) {
    scholar_id <- scholars$id[i]
    scholar_name <- scholars$name[i]
    
    cat(sprintf("\nFetching publications for %s (ID: %s)...\n", 
               scholar_name, scholar_id))
    
    # Fetch publications for this scholar
    tryCatch({
      # Get publications
      papers <- get_publications(scholar_id, pagesize = max_papers, sortby = "year")
      
      if (nrow(papers) > 0) {
        # Add scholar info to each paper
        papers$scholar_name <- scholar_name
        papers$scholar_id <- scholar_id
        
        # Combine with overall results
        all_papers <- bind_rows(all_papers, papers)
        
        cat(sprintf("  Found %d papers.\n", nrow(papers)))
      } else {
        cat("  No papers found.\n")
      }
    }, error = function(e) {
      cat(sprintf("  Error fetching publications: %s\n", e$message))
    })
    
    # Add a small delay to avoid hitting API limits
    Sys.sleep(1)
  }
  
  # Remove duplicates based on title
  if (nrow(all_papers) > 0) {
    unique_papers <- all_papers %>%
      distinct(title, .keep_all = TRUE)
    
    cat(sprintf("\nFound %d total papers (%d unique).\n", 
               nrow(all_papers), nrow(unique_papers)))
    
    # Write to CSV
    write_csv(unique_papers, output_csv_path)
    cat(sprintf("Results saved to %s\n", output_csv_path))
    
    return(unique_papers)
  } else {
    cat("No papers were found for any of the scholars.\n")
    return(data.frame())
  }
}

input_file <- "scholars.csv"
output_file <- "scholar_papers.csv"
max_papers <- 100

# Execute the main function
result <- fetch_scholar_papers(input_file, output_file, max_papers)

