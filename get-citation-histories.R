#!/usr/bin/env Rscript

# Load required libraries
if (!require("scholar")) {
  install.packages("scholar")
  library(scholar)
}
library(dplyr)
library(readr)
library(jsonlite)

#' Fetch citation history for multiple Google Scholar profiles
#'
#' @param input_csv_path Character: Path to the input CSV file with scholar information
#' @param output_json_path Character: Path where the output JSON will be saved
#' @return List: Citation history data for all scholars
fetch_scholar_citations <- function(input_csv_path = "scholars.csv", 
                                  output_json_path = "scholar_citations.json") {
  
  # Read the scholars CSV file
  scholars <- read_csv(input_csv_path)
  
  # Check if required columns exist
  required_cols <- c("name", "id")
  missing_cols <- required_cols[!required_cols %in% names(scholars)]
  
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in input CSV:", 
              paste(missing_cols, collapse = ", ")))
  }
  
  # Initialize empty list for results
  all_citations <- list()
  
  # Process each scholar
  for (i in 1:nrow(scholars)) {
    scholar_id <- scholars$id[i]
    scholar_name <- scholars$name[i]
    
    cat(sprintf("\nFetching citation history for %s (ID: %s)...\n", 
               scholar_name, scholar_id))
    
    # Fetch citation history for this scholar
    tryCatch({
      # Get citation history
      citation_history <- get_citation_history(scholar_id)
      
      if (nrow(citation_history) > 0) {
        # Add scholar info
        scholar_data <- list(
          name = scholar_name,
          id = scholar_id,
          citations = citation_history
        )
        
        # Add additional scholar info if available
        if ("institution" %in% names(scholars)) {
          scholar_data$institution <- scholars$institution[i]
        }
        
        # Add to overall results
        all_citations[[length(all_citations) + 1]] <- scholar_data
        
        cat(sprintf("  Found citation data for %d years.\n", nrow(citation_history)))
      } else {
        cat("  No citation data found.\n")
      }
    }, error = function(e) {
      cat(sprintf("  Error fetching citation history: %s\n", e$message))
    })
    
    # Add a small delay to avoid hitting API limits
    Sys.sleep(1)
  }
  
  if (length(all_citations) > 0) {
    # Calculate some summary statistics
    total_scholars <- length(all_citations)
    total_years <- sum(sapply(all_citations, function(x) nrow(x$citations)))
    
    cat(sprintf("\nFound citation data for %d scholars across %d total years.\n", 
               total_scholars, total_years))
    
    # Add metadata
    result <- list(
      metadata = list(
        date_generated = as.character(Sys.time()),
        total_scholars = total_scholars,
        scholars_processed = sapply(all_citations, function(x) x$name)
      ),
      citation_data = all_citations
    )
    
    # Convert to JSON and write to file
    json_data <- toJSON(result, pretty = TRUE, auto_unbox = TRUE)
    write(json_data, output_json_path)
    
    cat(sprintf("Results saved to %s\n", output_json_path))
    
    return(result)
  } else {
    cat("No citation data was found for any of the scholars.\n")
    return(list())
  }
}

# Main execution if script is run directly
if (!interactive()) {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  # Set default values
  input_file <- "scholars.csv"
  output_file <- "scholar_citations.json"
  
  # Process command line arguments
  if (length(args) >= 1) input_file <- args[1]
  if (length(args) >= 2) output_file <- args[2]
  
  # Execute the main function
  result <- fetch_scholar_citations(input_file, output_file)
}

# Example usage:
result <- fetch_scholar_citations("scholars.csv", "scholar_citations.json")
# Note: The input CSV should have columns "name" and "id" for the scholars.