#!/bin/sh

CONTENT_DIR="post-content"
OUTPUT_DIR="w"
SITE_TITLE="deglebe"

mkdir -p "$OUTPUT_DIR"

process_markdown() {
    local input_file="$1"
    local temp_file="/tmp/md_temp_$$"
    local footnote_raw="/tmp/footnotes_raw_$$"

    grep "^\[\^[^]]*\]:" "$input_file" > "$footnote_raw"
    grep -v "^\[\^[^]]*\]:" "$input_file" > "$temp_file"

    awk '
    BEGIN { in_code = in_paragraph = in_list = 0 }
    
    function close_blocks() {
        if (in_paragraph) { print "</p>"; in_paragraph = 0 }
        if (in_list) { print "</ul>"; in_list = 0 }
    }
    
    function format_inline(line) {
        while (match(line, /\*\*([^*]+)\*\*/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 2, len - 4)
            line = substr(line, 1, start - 1) "<strong>" content "</strong>" substr(line, start + len)
        }
        while (match(line, /\*([^*]+)\*/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 1, len - 2)
            line = substr(line, 1, start - 1) "<em>" content "</em>" substr(line, start + len)
        }
        while (match(line, /`([^`]+)`/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 1, len - 2)
            line = substr(line, 1, start - 1) "<code>" content "</code>" substr(line, start + len)
        }
        while (match(line, /\[([^\]]+)\]\(([^)]+)\)/)) {
            start = RSTART; len = RLENGTH
            matched_text = substr(line, start, len)
            bracket_end = index(matched_text, "](")
            link_text = substr(matched_text, 2, bracket_end - 2)
            link_url = substr(matched_text, bracket_end + 2, len - bracket_end - 2)
            line = substr(line, 1, start - 1) "<a href=\"" link_url "\">" link_text "</a>" substr(line, start + len)
        }
        while (match(line, /\[\^([^\]]+)\]/)) {
            start = RSTART; len = RLENGTH; ref = substr(line, start + 2, len - 3)
            line = substr(line, 1, start - 1) "<sup><a href=\"#fn-" ref "\" id=\"fnref-" ref "\">" ref "</a></sup>" substr(line, start + len)
        }
        return line
    }
    
    /^```/ {
        close_blocks()
        if (in_code == 0) {
            lang = substr($0, 4)
            print (lang != "") ? "<pre><code class=\"language-" lang "\">" : "<pre><code>"
            in_code = 1
        } else {
            print "</code></pre>"; in_code = 0
        }
        next
    }
    
    in_code == 1 { gsub(/&/, "\\&amp;"); gsub(/</, "\\&lt;"); gsub(/>/, "\\&gt;"); print; next }
    
    /^#{1,3} / {
        close_blocks()
        level = length($1); content = substr($0, level + 2)
        print "<h" level ">" content "</h" level ">"
        next
    }
    
    /^- / {
        if (in_paragraph) { print "</p>"; in_paragraph = 0 }
        if (!in_list) { print "<ul>"; in_list = 1 }
        content = format_inline(substr($0, 3))
        print "<li>" content "</li>"
        next
    }
    
    /^$/ { close_blocks(); next }
    
    {
        if (in_list) { print "</ul>"; in_list = 0 }
        if (!in_paragraph) { printf "<p>"; in_paragraph = 1 } else { printf " " }
        printf "%s", format_inline($0)
    }
    
    END { close_blocks() }
    ' "$temp_file"

    [ -s "$footnote_raw" ] && {
        echo '<div class="footnotes"><h3>footnotes</h3><ul class="blank-list">'
        awk '/^\[\^[^]]*\]: / {
            sub(/^\[\^/, ""); id_end = index($0, "]: ")
            if (id_end > 0) {
                id = substr($0, 1, id_end - 1); content = substr($0, id_end + 3)
                while (match(content, /\*\*([^*]+)\*\*/)) {
                    start = RSTART; len = RLENGTH; text = substr(content, start + 2, len - 4)
                    content = substr(content, 1, start - 1) "<strong>" text "</strong>" substr(content, start + len)
                }
                while (match(content, /\*([^*]+)\*/)) {
                    start = RSTART; len = RLENGTH; text = substr(content, start + 1, len - 2)
                    content = substr(content, 1, start - 1) "<em>" text "</em>" substr(content, start + len)
                }
                while (match(content, /`([^`]+)`/)) {
                    start = RSTART; len = RLENGTH; text = substr(content, start + 1, len - 2)
                    content = substr(content, 1, start - 1) "<code>" text "</code>" substr(content, start + len)
                }
                while (match(content, /\[([^\]]+)\]\(([^)]+)\)/)) {
                    start = RSTART; len = RLENGTH
                    matched_text = substr(content, start, len)
                    bracket_end = index(matched_text, "](")
                    link_text = substr(matched_text, 2, bracket_end - 2)
                    link_url = substr(matched_text, bracket_end + 2, len - bracket_end - 2)
                    content = substr(content, 1, start - 1) "<a href=\"" link_url "\">" link_text "</a>" substr(content, start + len)
                }
                print "<li id=\"fn-" id "\"><a href=\"#fnref-" id "\">" id "</a>: " content "</li>"
            }
        }' "$footnote_raw"
        echo '</ul></div>'
    }

    rm -f "$temp_file" "$footnote_raw"
}

date_to_sortable() {
    local date_str="$1"
    if echo "$date_str" | grep -q '^\*[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]\*$'; then
        clean_date=$(echo "$date_str" | sed 's/\*//g')
        month=$(echo "$clean_date" | cut -d'/' -f1)
        day=$(echo "$clean_date" | cut -d'/' -f2)
        year=$(echo "$clean_date" | cut -d'/' -f3)
        echo "$year/$month/$day"
    else
        echo "9999/99/99"
    fi
}

[ ! -d "$CONTENT_DIR" ] && {
    echo "content directory $CONTENT_DIR does not exist"
    exit 1
}

echo "building post directory"

temp_posts="/tmp/posts_$$"
post_count=0

for md_file in "$CONTENT_DIR"/*.md; do
    [ ! -f "$md_file" ] && continue
    filename=$(basename "$md_file" .md)
    title=$(sed -n 's/^# //p' "$md_file" | head -n 1)
    [ -z "$title" ] && title="$filename"

    date_line=$(sed -n '3p' "$md_file")
    display_date=""
    sortable_date=$(date_to_sortable "$date_line")

    if [ "$sortable_date" != "9999/99/99" ]; then
        display_date=$(echo "$date_line" | sed 's/\*//g')
    fi

    echo "processing $md_file -> $OUTPUT_DIR/$filename.html"

    {
        cat << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>$SITE_TITLE | $title</title>
    <link rel="stylesheet" href="../style.css" />
  </head>
  <body>
    <header>
      <h1>$SITE_TITLE</h1>
      <nav>
        <a href="../index.html">home</a>
        <a href="../now.html">now</a>
        <a class="active" href="../posts.html">posts</a>
        <a href="../about.html">about</a>
	<a href="../reads.html">reads</a>
      </nav>
    </header>
    <main>
EOF
        process_markdown "$md_file"
        echo "    </main>
    <footer></footer>
  </body>
</html>"
    } > "$OUTPUT_DIR/$filename.html"

    echo "$sortable_date|$filename|$title|$display_date" >> "$temp_posts"
    post_count=$((post_count + 1))
done

[ $post_count -gt 0 ] && {
    echo "updating posts.html with $post_count posts"

    sorted_posts=$(sort -t'|' -k1,1 "$temp_posts" | tac)

    post_list=""
    echo "$sorted_posts" | while IFS='|' read -r sortable_date filename title display_date; do
        if [ -n "$display_date" ]; then
            post_list="$post_list<li><a href=\"$OUTPUT_DIR/$filename.html\">$title</a> <em>$display_date</em></li>\n"
        else
            post_list="$post_list<li><a href=\"$OUTPUT_DIR/$filename.html\">$title</a></li>\n"
        fi
        echo "$post_list" > "/tmp/post_list_$$"
    done

    post_list=$(cat "/tmp/post_list_$$" 2> /dev/null || echo "")

    cat > posts.html << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>deglebe | posts</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <header>
      <h1>deglebe</h1>
      <nav>
        <a href="index.html">home</a>
        <a href="now.html">now</a>
        <a class="active" href="">posts</a>
        <a href="about.html">about</a>
	<a href="reads.html">reads</a>
      </nav>
    </header>
    <main>
      <ul class="blank-list">
$(printf "$post_list")      </ul>
    </main>
    <footer></footer>
  </body>
</html>
EOF

    rm -f "$temp_posts" "/tmp/post_list_$$"

} || echo "no markdown files found in $CONTENT_DIR"

echo "build complete!"
