#!/bin/bash

# directories
INPUT_DIR="blogposts"
OUTPUT_DIR="w"       
INDEX_FILE="$OUTPUT_DIR/index.html"
TEMPLATE_FILE="$INPUT_DIR/template.html" 

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
	echo "Error: Missing template.html file."
	exit 1
fi

TEMP_INDEX=$(mktemp)

for md_file in "$INPUT_DIR"/*.md; do
    [[ -f "$md_file" ]] || continue 

    filename=$(basename -- "$md_file")
    slug="${filename%.*}" # Remove extension
    html_file="$OUTPUT_DIR/$slug.html"

    # Extract YAML metadata using awk
    metadata=$(awk '/^---$/ {f=!f; next} f' "$md_file")
    title=$(echo "$metadata" | awk -F': ' '/^title:/ {print $2}')
    date=$(echo "$metadata" | awk -F': ' '/^date:/ {print $2}')
    author=$(echo "$metadata" | awk -F': ' '/^author:/ {print $2}')

    # If no title is found, use the slug as a fallback
    title=${title:-$slug}
    date=${date:-"1970-01-01"}  # Default to earliest date if missing
    author=${author:-"Unknown"}

    # Convert Markdown to HTML, skipping YAML header
    content=$(sed '1,/^---$/d' "$md_file" | pandoc -f markdown -t html)

    # Generate the full HTML page
    awk -v title="$title" -v content="$content" '
    /<h1>writing<\/h1>/ { print "<h1>" title "</h1>"; print content; next }
    { print }
    ' "$TEMPLATE_FILE" > "$html_file"

    echo "Generated: $html_file"

    # Append to temporary index file for sorting later
    echo "$date|<li><a href=\"$slug.html\">$title</a> - $date by $author</li>" >> "$TEMP_INDEX"
done

# Generate updated index.html with sorted posts
{
    echo "<!DOCTYPE html>"
    echo "<html lang=\"en\">"
    echo "<head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"><link rel="stylesheet" href="../styles-nonpro.css"><title>Writing</title></head>"
    echo "<body>"
    echo "<div class="navbar">"
	echo "	<a href="../index.html">home</a>"
	echo "	<a href="../now/index.html">now</a>"
	echo "	<a href="../w/index.html">writing</a>"
	echo "	<a href="../r/index.html">read</a>"
	echo "	<a href="../m/index.html">math</a>"
	echo "	<a href="../p/index.html">projects</a>"
	echo "</div>"
    echo "<h1>writing</h1>"
    echo "<p>all opinions here are entirely my own and not endorsed by any employer, educational institution, or otherwise"
    echo "<ul>"

    # Sort entries by date in descending order
    sort -r "$TEMP_INDEX" | cut -d'|' -f2

    echo "</ul>"
    echo "</body>"
    echo "</html>"
} > "$INDEX_FILE"

rm "$TEMP_INDEX"  # Clean up

echo "Index updated: $INDEX_FILE"
