#!/bin/sh

CONTENT_DIR="post-content"
OUTPUT_DIR="w"
SITE_TITLE="deglebe"

mkdir -p "$OUTPUT_DIR"

escape_html() {
	echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

extract_date() {
	local file="$1"
	local date_str=""

	if head -n 10 "$file" | grep -q '^---$'; then
		date_str=$(awk '/^---$/{p=1; next} p==1 && /^date:/{print $2; exit}' "$file" 2> /dev/null)
	fi

	if [ -z "$date_str" ]; then
		date_str=$(sed -n '3p' "$file" 2> /dev/null)
	fi

	if [ -z "$date_str" ] || ! echo "$date_str" | grep -qE '\*?[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\*?'; then
		date_str=$(head -n 10 "$file" | grep -E '\*?[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\*?' | head -n 1)
	fi

	echo "$date_str"
}

# convert date to sortable format (YYYY/MM/DD)
date_to_sortable() {
	local date_str="$1"
	local clean_date month day year

	clean_date=$(echo "$date_str" | sed 's/\*//g; s/^[[:space:]]*//; s/[[:space:]]*$//')

	if echo "$clean_date" | grep -qE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'; then
		day=$(echo "$clean_date" | cut -d'/' -f1)
		month=$(echo "$clean_date" | cut -d'/' -f2)
		year=$(echo "$clean_date" | cut -d'/' -f3)

		day=$(printf "%02d" "$day" 2> /dev/null || echo "$day")
		month=$(printf "%02d" "$month" 2> /dev/null || echo "$month")

		echo "$year/$month/$day"
	else
		echo "9999/99/99"
	fi
}

# extract first 200 words from markdown for preview
extract_preview() {
	local file="$1"

	awk '
    BEGIN { in_code = 0; word_count = 0; preview = ""; skip_next = 0 }

    /^```/ { in_code = !in_code; next }
    in_code { next }
    /^# / { next }  # Skip title
    /^\*[0-9]+\/[0-9]+\/[0-9]+\*$/ { next }  # Skip date line
    /^\[\^[^]]*\]:/ { next }  # Skip footnote definitions
    /^$/ {
        if (word_count > 0 && preview != "") preview = preview " "
        next
    }

    {
        # Remove markdown formatting for preview
        gsub(/\[([^\]]+)\]\([^)]+\)/, "\\1")  # Links
        gsub(/\[\^[^\]]+\]/, "")              # Footnotes
        gsub(/\*\*([^*]+)\*\*/, "\\1")        # Bold
        gsub(/\*([^*]+)\*/, "\\1")            # Italic
        gsub(/`[^`]+`/, "")                   # Code
        gsub(/!\[([^\]]*)\]\([^)]+\)/, "\\1") # Images
        gsub(/~~([^~]+)~~/, "\\1")            # Strikethrough

        # Split into words
        n = split($0, words, /[[:space:]]+/)
        for (i = 1; i <= n && word_count < 200; i++) {
            word = words[i]
            # Clean up word (remove punctuation at edges but keep internal)
            gsub(/^[[:punct:]]+|[[:punct:]]+$/, "", word)
            if (word != "" && length(word) > 0) {
                if (preview != "" && word_count > 0) preview = preview " "
                preview = preview word
                word_count++
            }
        }

        if (word_count >= 200) exit
    }

    END {
        if (preview != "") {
            print preview
        }
    }
    ' "$file"
}

process_markdown() {
	local input_file="$1"
	local temp_file="/tmp/md_temp_$$"
	local footnote_raw="/tmp/footnotes_raw_$$"

	grep "^\[\^[^]]*\]:" "$input_file" > "$footnote_raw" 2> /dev/null || true
	grep -v "^\[\^[^]]*\]:" "$input_file" > "$temp_file"

	awk '
    BEGIN {
        in_code = in_paragraph = in_list = in_olist = in_blockquote = 0
        list_type = ""
        olist_counter = 0
    }

    function close_blocks() {
        if (in_paragraph) { print "</p>"; in_paragraph = 0 }
        if (in_list) { print "</ul>"; in_list = 0; list_type = "" }
        if (in_olist) { print "</ol>"; in_olist = 0; olist_counter = 0 }
        if (in_blockquote) { print "</blockquote>"; in_blockquote = 0 }
    }

    function escape_html_special(text) {
        gsub(/&/, "\\&amp;", text)
        gsub(/</, "\\&lt;", text)
        gsub(/>/, "\\&gt;", text)
        return text
    }

    function format_inline(line, in_code_block) {
        if (in_code_block) {
            return escape_html_special(line)
        }

        gsub(/\\\*/, "\x01ASTERISK\x01", line)
        gsub(/\\`/, "\x01BACKTICK\x01", line)
        gsub(/\\\[/, "\x01LBRACKET\x01", line)
        gsub(/\\\]/, "\x01RBRACKET\x01", line)
        gsub(/\\\(/, "\x01LPAREN\x01", line)
        gsub(/\\\)/, "\x01RPAREN\x01", line)
        gsub(/\\_/, "\x01UNDERSCORE\x01", line)

        while (match(line, /\*\*([^*]+)\*\*/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 2, len - 4)
            line = substr(line, 1, start - 1) "<strong>" content "</strong>" substr(line, start + len)
        }

        while (match(line, /__([^_]+)__/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 2, len - 4)
            line = substr(line, 1, start - 1) "<strong>" content "</strong>" substr(line, start + len)
        }

        while (match(line, /\*([^*]+)\*/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 1, len - 2)
            line = substr(line, 1, start - 1) "<em>" content "</em>" substr(line, start + len)
        }

        while (match(line, /_([^_]+)_/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 1, len - 2)
            line = substr(line, 1, start - 1) "<em>" content "</em>" substr(line, start + len)
        }

        while (match(line, /~~([^~]+)~~/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 2, len - 4)
            line = substr(line, 1, start - 1) "<del>" content "</del>" substr(line, start + len)
        }

        while (match(line, /`([^`]+)`/)) {
            start = RSTART; len = RLENGTH; content = substr(line, start + 1, len - 2)
            line = substr(line, 1, start - 1) "<code>" escape_html_special(content) "</code>" substr(line, start + len)
        }

        while (match(line, /!\[([^\]]*)\]\(([^)]+)\)/)) {
            start = RSTART; len = RLENGTH
            matched_text = substr(line, start, len)
            bracket_end = index(matched_text, "](")
            alt_text = substr(matched_text, 3, bracket_end - 3)
            img_url = substr(matched_text, bracket_end + 2, len - bracket_end - 2)
            line = substr(line, 1, start - 1) "<img src=\"" img_url "\" alt=\"" alt_text "\" />" substr(line, start + len)
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

        gsub(/\x01ASTERISK\x01/, "*", line)
        gsub(/\x01BACKTICK\x01/, "`", line)
        gsub(/\x01LBRACKET\x01/, "[", line)
        gsub(/\x01RBRACKET\x01/, "]", line)
        gsub(/\x01LPAREN\x01/, "(", line)
        gsub(/\x01RPAREN\x01/, ")", line)
        gsub(/\x01UNDERSCORE\x01/, "_", line)

        return line
    }

    /^```/ {
        close_blocks()
        if (in_code == 0) {
            lang = substr($0, 4)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", lang)
            print (lang != "") ? "<pre><code class=\"language-" lang "\">" : "<pre><code>"
            in_code = 1
        } else {
            print "</code></pre>"
            in_code = 0
        }
        next
    }

    in_code == 1 {
        print escape_html_special($0)
        next
    }

    /^#{1,6} / {
        close_blocks()
        level = length($1)
        content = substr($0, level + 2)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", content)
        content = format_inline(content, 0)
        print "<h" level ">" content "</h" level ">"
        next
    }

    /^[-*_]{3,}$/ {
        close_blocks()
        print "<hr />"
        next
    }

    /^> / {
        if (!in_blockquote) {
            close_blocks()
            print "<blockquote>"
            in_blockquote = 1
        }
        content = format_inline(substr($0, 3))
        print "<p>" content "</p>"
        next
    }

    /^[-*+] / {
        if (in_paragraph) { print "</p>"; in_paragraph = 0 }
        if (in_olist) { print "</ol>"; in_olist = 0; olist_counter = 0 }
        if (!in_list) { print "<ul>"; in_list = 1; list_type = "ul" }
        content = format_inline(substr($0, 3))
        print "<li>" content "</li>"
        next
    }

    /^[0-9]+\. / {
        if (in_paragraph) { print "</p>"; in_paragraph = 0 }
        if (in_list) { print "</ul>"; in_list = 0; list_type = "" }
        if (!in_olist) { print "<ol>"; in_olist = 1; olist_counter = 0 }
        match($0, /^[0-9]+\. /)
        content = format_inline(substr($0, RLENGTH + 1))
        print "<li>" content "</li>"
        next
    }

    /^$/ {
        close_blocks()
        next
    }

    {
        if (in_list) { print "</ul>"; in_list = 0; list_type = "" }
        if (in_olist) { print "</ol>"; in_olist = 0; olist_counter = 0 }
        if (in_blockquote) { print "</blockquote>"; in_blockquote = 0 }
        if (!in_paragraph) {
            printf "<p>"
            in_paragraph = 1
        } else {
            printf " "
        }
        printf "%s", format_inline($0, 0)
    }

    END { close_blocks() }
    ' "$temp_file"

	[ -s "$footnote_raw" ] && {
		echo '<div class="footnotes"><h3>footnotes</h3><ul class="blank-list">'
		awk '
        function format_inline_footnote(content) {
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
                gsub(/&/, "\\&amp;", text)
                gsub(/</, "\\&lt;", text)
                gsub(/>/, "\\&gt;", text)
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
            return content
        }

        /^\[\^[^]]*\]: / {
            sub(/^\[\^/, "")
            id_end = index($0, "]: ")
            if (id_end > 0) {
                id = substr($0, 1, id_end - 1)
                content = substr($0, id_end + 3)
                content = format_inline_footnote(content)
                print "<li id=\"fn-" id "\"><a href=\"#fnref-" id "\">" id "</a>: " content "</li>"
            }
        }
        ' "$footnote_raw"
		echo '</ul></div>'
	}

	rm -f "$temp_file" "$footnote_raw"
}

[ ! -d "$CONTENT_DIR" ] && {
	echo "error: content directory $CONTENT_DIR does not exist" >&2
	exit 1
}

echo "building post directory..."

temp_posts="/tmp/posts_$$"
post_count=0
processed_count=0

for md_file in "$CONTENT_DIR"/*.md; do
	[ ! -f "$md_file" ] && continue

	filename=$(basename "$md_file" .md)

	title=$(awk '/^# / {print substr($0, 3); exit}' "$md_file" 2> /dev/null)
	[ -z "$title" ] && title="$filename"

	date_line=$(extract_date "$md_file")
	display_date=""
	sortable_date=$(date_to_sortable "$date_line")

	if [ "$sortable_date" != "9999/99/99" ]; then
		display_date=$(echo "$date_line" | sed 's/\*//g; s/^[[:space:]]*//; s/[[:space:]]*$//')
	fi

	echo "  processing: $filename.md -> $OUTPUT_DIR/$filename.html"

	{
		cat << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>$(escape_html "$SITE_TITLE") | $(escape_html "$title")</title>
    <link rel="stylesheet" href="../style.css" />
    <script src="../theme.js"></script>
  </head>
  <body>
    <header>
      <h1>$SITE_TITLE</h1>
      <div class="theme-switcher">
        <a href="#" id="theme-dark">dark</a>
        <a href="#" id="theme-light">light</a>
      </div>
      <nav>
        <a href="../index.html">home</a>
        <a href="../play.html">play</a>
        <a href="../misc.html">misc</a>
        <a href="../about.html">about</a>
      </nav>
    </header>
    <main>
EOF
		process_markdown "$md_file"
		cat << EOF
    </main>
    <footer></footer>
  </body>
</html>
EOF
	} > "$OUTPUT_DIR/$filename.html"

	preview=$(extract_preview "$md_file")
	echo "$sortable_date|$filename|$title|$display_date|$preview" >> "$temp_posts"
	post_count=$((post_count + 1))
	processed_count=$((processed_count + 1))
done

if [ $post_count -gt 0 ]; then
	echo "updating index.html with $post_count posts..."

	sorted_posts=$(sort -t'|' -k1,1r "$temp_posts" 2> /dev/null || sort -t'|' -k1,1 "$temp_posts" | tac)

	post_previews=""
	echo "$sorted_posts" | while IFS='|' read -r sortable_date filename title display_date preview; do
		escaped_title=$(escape_html "$title")
		escaped_filename=$(escape_html "$filename")
		escaped_preview=$(escape_html "$preview")
		if [ -n "$display_date" ]; then
			escaped_date=$(escape_html "$display_date")
			post_previews="${post_previews}      <article>
        <h2><a href=\"$OUTPUT_DIR/$escaped_filename.html\">$escaped_title</a></h2>
        <p class=\"post-date\"><em>$escaped_date</em></p>
        <p class=\"post-preview\">$escaped_preview...</p>
        <p><a href=\"$OUTPUT_DIR/$escaped_filename.html\">read more</a></p>
      </article>
"
		else
			post_previews="${post_previews}      <article>
        <h2><a href=\"$OUTPUT_DIR/$escaped_filename.html\">$escaped_title</a></h2>
        <p class=\"post-preview\">$escaped_preview...</p>
        <p><a href=\"$OUTPUT_DIR/$escaped_filename.html\">read more</a></p>
      </article>
"
		fi
		echo "$post_previews" > "/tmp/post_previews_$$"
	done

	post_previews=$(cat "/tmp/post_previews_$$" 2> /dev/null || echo "")

	cat > index.html << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>deglebe</title>
    <link rel="stylesheet" href="style.css" />
    <script src="theme.js"></script>
  </head>
  <body>
    <header>
      <h1>deglebe</h1>
      <div class="theme-switcher">
        <a href="#" id="theme-dark">dark</a>
        <a href="#" id="theme-light">light</a>
      </div>
      <nav>
        <a class="active" href="">home</a>
        <a href="play.html">play</a>
        <a href="misc.html">misc</a>
        <a href="about.html">about</a>
      </nav>
    </header>
    <main>
$(printf "$post_previews")    </main>
    <footer></footer>
  </body>
</html>
EOF

	rm -f "$temp_posts" "/tmp/post_previews_$$"

	echo "build complete! processed $processed_count posts."
else
	echo "warning: no markdown files found in $CONTENT_DIR"
fi
