import requests
import pandas as pd
import matplotlib.pyplot as plt
from typing import List, Dict, Any, Tuple, Optional
from datetime import datetime
import time
import csv

def get_laureate_papers(author_name: str, prize_year: int) -> List[Dict[Any, Any]]:
    """
    Retrieve papers by a Nobel laureate published before receiving the prize.
    
    Args:
        author_name: The name of the laureate
        prize_year: The year they received the Nobel Prize
        
    Returns:
        A list of paper dictionaries containing metadata
    """
    base_url = "https://api.semanticscholar.org/graph/v1"
    
    # First get the author ID
    author_search_url = f"{base_url}/author/search"
    params = {"query": author_name, "limit": 1}
    headers = {}#{"x-api-key": "YOUR_API_KEY_HERE"}
    
    response = requests.get(author_search_url, params=params, headers=headers)
    response.raise_for_status()
    
    author_data = response.json()
    if not author_data["data"]:
        print(f"Author not found: {author_name}")
        return []
    
    # Write author data to a json file for debugging
    with open(f"{author_name}.json", "w") as f:
        import json
        json.dump(author_data, f, indent=2)
    
    author_id = author_data["data"][0]["authorId"]
    
    # Now get all papers by this author
    papers_url = f"{base_url}/author/{author_id}/papers"
    params = {
        "limit": 500,  # Increased limit to get more papers
        "fields": "title,year,citationCount,citations.year,citations"
    }
    
    response = requests.get(papers_url, params=params, headers=headers)
    response.raise_for_status()
    
    # Filter papers published before the prize year
    papers = response.json()["data"]
    pre_prize_papers = [p for p in papers if p.get("year") is not None and p.get("year") <= prize_year]
    
    return pre_prize_papers

def calculate_citation_count_at_year(paper: Dict[Any, Any], year: int) -> int:
    """
    Calculate how many citations a paper had received by a specific year.
    
    Args:
        paper: The paper data from the API
        year: The year to calculate citations up to
        
    Returns:
        The number of citations received by the specified year
    """
    if "citations" not in paper:
        return 0
    
    citations_by_year = [c for c in paper["citations"] 
                        if c.get("year") is not None and c.get("year") <= year]
    
    return len(citations_by_year)

def calculate_h_index(citation_counts: List[int]) -> int:
    """
    Calculate h-index from a list of citation counts.
    
    Args:
        citation_counts: List of citation counts for papers
        
    Returns:
        The calculated h-index
    """
    # Sort citation counts in descending order
    sorted_counts = sorted(citation_counts, reverse=True)
    
    h_index = 0
    for i, count in enumerate(sorted_counts, 1):
        if count >= i:
            h_index = i
        else:
            break
    
    return h_index

def process_laureate(name: str, prize_year: int) -> Tuple[int, List[Dict[Any, Any]]]:
    """
    Process a single Nobel laureate to calculate their h-index at prize time.
    
    Args:
        name: The laureate's name
        prize_year: The year they received the Nobel Prize
        
    Returns:
        The calculated h-index and the list of papers used
    """
    print(f"Processing {name}, Nobel Prize {prize_year}...")
    papers = get_laureate_papers(name, prize_year)
    
    if not papers:
        print(f"No papers found for {name}")
        return 0, []
    
    # Calculate citation count for each paper at prize year
    citation_counts = []
    for paper in papers:
        count = calculate_citation_count_at_year(paper, prize_year)
        paper["citations_at_prize"] = count  # Add this to the paper data
        citation_counts.append(count)
    
    h_index = calculate_h_index(citation_counts)
    print(f"{name}: h-index at prize time ({prize_year}): {h_index}")
    
    return h_index, papers

def main(input_file: str, output_file: str) -> None:
    """
    Process all laureates from an input CSV file.
    
    Args:
        input_file: Path to CSV with laureate names and prize years
        output_file: Path to output the results
    """
    results = []
    
    # Read the input file
    with open(input_file, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        laureates = [(row[0], int(row[1])) for row in reader]
    
    for name, year in laureates:
        h_index, papers = process_laureate(name, year)
        
        # Get paper details for the output
        paper_details = [{
            "title": p.get("title", "Unknown"),
            "year": p.get("year", "Unknown"),
            "citations_at_prize": p.get("citations_at_prize", 0)
        } for p in papers]
        
        results.append({
            "name": name,
            "prize_year": year,
            "h_index_at_prize": h_index,
            "paper_count": len(papers),
            "papers": paper_details
        })
        
        # Be nice to the API
        time.sleep(1)
    
    # Save the results
    df = pd.DataFrame([{
        "name": r["name"],
        "prize_year": r["prize_year"],
        "h_index_at_prize": r["h_index_at_prize"],
        "paper_count": r["paper_count"]
    } for r in results])
    
    df.to_csv(output_file, index=False)
    
    # Also save detailed results with paper info
    with open(output_file.replace('.csv', '_detailed.json'), 'w') as f:
        import json
        json.dump(results, f, indent=2)
    
    # Create visualization
    plt.figure(figsize=(12, 8))
    plt.scatter(df["prize_year"], df["h_index_at_prize"], s=100, alpha=0.7)
    
    for i, row in df.iterrows():
        plt.annotate(row["name"], 
                    (row["prize_year"], row["h_index_at_prize"]),
                    xytext=(5, 5),
                    textcoords="offset points")
    
    plt.title("H-index of Nobel Laureates at Time of Prize")
    plt.xlabel("Year of Nobel Prize")
    plt.ylabel("H-index")
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.savefig("nobel_laureates_h_index.png")
    plt.show()

if __name__ == "__main__":
    main("nobel_laureates.csv", "nobel_laureates_h_index.csv")

