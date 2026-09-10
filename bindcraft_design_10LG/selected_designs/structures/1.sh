#!/bin/bash

input_file="0.15_80_10_pH6.5_clean_protein.result.pdb"
output_file="output.pdb"

awk '
BEGIN { 
    # Start with the default value "A"
    current_val = "A" 
}
{
    # Switch the value to "B" permanently when the line equals "TER"
    if ($0 == "TER") {
        current_val = "B"
    }
    
    # Print 11 original columns + 1 new column = 12 total columns
    print $1, $2, $3, $4, current_val, $5, $6, $7, $8, $9, $10, $11
}' "$input_file" > "$output_file"

