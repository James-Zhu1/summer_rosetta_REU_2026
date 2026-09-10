#!/bin/bash

# Check if an input file was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_pdb_file>"
    exit 1
fi

INPUT_FILE="$1"
TEMP_FILE="temp_fixed.pdb"

# Initialize the starting chain
CHAIN="A"

# Read the file line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Check if the line starts with ATOM or HETATM
    if [[ "$line" =~ ^ATOM  ]] || [[ "$line" =~ ^HETATM ]]; then
        # Extract the parts before and after column 22 (the chain ID slot)
        # PDB column 22 is index 21 (0-based)
        before="${line:0:21}"
        after="${line:22}"
        
        # Reconstruct the line with the current active chain ID
        echo "${before}${CHAIN}${after}" >> "$TEMP_FILE"
        
    # Check if we hit the first TER record while still on chain A
    elif [[ "$line" =~ ^TER ]] && [ "$CHAIN" == "A" ]; then
        echo "$line" >> "$TEMP_FILE"
        CHAIN="B"  # Switch the chain to B for all subsequent lines
        
    else
        # Keep all other lines (TITLE, REMARK, CONECT, etc.) exactly as they are
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$INPUT_FILE"

# Overwrite the original file with the modified text
mv "$TEMP_FILE" "complex_chains_added.pdb"

echo "Successfully updated chain IDs in $INPUT_FILE!"

