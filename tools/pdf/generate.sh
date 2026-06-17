#!/usr/bin/env bash
# Build the resume PDF(s) from the site's Zola markdown — single source of truth.
#
# Runs from the project root (so it can read content/resume/index*.md and write
# directly to static/). Outputs:
#   en            → static/sam-ariafar.pdf
#   en --dark     → static/sam-ariafar.pdf   (dark mode, same path)
#   <l>           → static/sam-ariafar.<l>.pdf
#   <l> --dark    → static/sam-ariafar.<l>.pdf
set -euo pipefail

BASE="tools/pdf"
DEFAULT_LANG="en"
DARK=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dark) DARK=true ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

HEADER="$BASE/head.tex"
TEMPLATE="$BASE/template.tex"

mkdir -p static

shopt -s nullglob
for file in content/resume/index*.md; do
	stem=$(basename "$file" .md)
	if [[ "$stem" == "index" ]]; then
		lang="$DEFAULT_LANG"
		locale_suffix=""
	else
		lang="${stem#index.}"
		locale_suffix=".${lang}"
	fi

	output="static/sam-ariafar${locale_suffix}.pdf"

	# ------------------------------------------------------------------
	# Assemble LaTeX header (preamble)
	# ------------------------------------------------------------------
	awk '1;NR==1{print ""}' <<-EOF > "$HEADER"
		\RequirePackage{hyperref}
		\RequirePackage{titlesec}
		\PassOptionsToPackage{svgnames}{xcolor}
		\usepackage{color}
		\usepackage{fontspec}
		\usepackage{pgfmath}
		\usepackage{soul}
		\usepackage[most]{tcolorbox}
		%
		\newcommand{\fontSizeLineHeight}[1]{
			\pgfmathsetmacro{\lineHeight}{#1 * 1.5}
			\fontsize{#1}{\lineHeight}\selectfont
		}
		\newcommand{\qrCodeName}{qr-code-dark}
		\newcommand{\darkSuffix}{}
		\newcommand{\qrActionColor}{white}
	EOF

	[[ -f "$BASE/templates/fonts.${lang}.tex" ]] && fonts="fonts.${lang}" || fonts="fonts"

	awk 'FNR==1{print ""};1' \
		"$BASE/templates/${fonts}.tex" \
		"$BASE/templates/styles.tex" \
		"$BASE/templates/profile.tex" >> "$HEADER"

	# Dark-mode overrides — appended after templates so they take precedence
	if [[ "$DARK" == "true" ]]; then
		cat >> "$HEADER" <<-DARKEOF
			\renewcommand{\qrCodeName}{qr-code-light}
			\renewcommand{\darkSuffix}{_dark}
			\renewcommand{\qrActionColor}{black}
			\usepackage[pagecolor=black]{pagecolor}
			\pagecolor{black}
			\color{white}
			\definecolor{inlinecode}{HTML}{333333}
			\definecolor{linequote}{HTML}{1A1A1A}
			\definecolor{backquote}{HTML}{1A1A1A}
		DARKEOF
	fi

	# ------------------------------------------------------------------
	# Assemble pandoc template
	# ------------------------------------------------------------------
	awk '1;END{print ""}' <<-EOF > "$TEMPLATE"
		\$if(fullName)$\newcommand{\fullName}{\$fullName$}\$endif$
		\$if(jobTitle)$\newcommand{\jobTitle}{\$jobTitle$}\$endif$
		\$if(residenceCountry)$\newcommand{\residenceCountry}{\$residenceCountry$}\$endif$
		\$if(birthDate)$\newcommand{\birthDate}{\$birthDate$}\$endif$
		\$if(emailAddress)$\newcommand{\emailAddress}{\$emailAddress$}\$endif$
		\$if(phoneNumber)$\newcommand{\phoneNumber}{\$phoneNumber$}\$endif$
		\$if(qr)$
			\newcommand{\qrActionName}{\$qr.action.name$}
			\newcommand{\qrActionSize}{\$qr.action.size$}
			\newcommand{\qrLink}{\$qr.link$}
		\$endif$
	EOF
	pandoc -D latex >> "$TEMPLATE"
	sed -i 's/^\\maketitle/%&/g' "$TEMPLATE"

	python3 "$BASE/preprocess.py" < "$file" | pandoc \
		--output "$output" \
		--pdf-engine xelatex \
		--from markdown-raw_tex \
		--filter "$BASE/filters/formatter.py" \
		--metadata-file "$BASE/metadata/profile.${lang}.yaml" \
		--template "$TEMPLATE" \
		--include-in-header "$HEADER" \
		--variable geometry:"a4paper,margin=2cm"

	echo "→ $output"
done

rm -f "$HEADER" "$TEMPLATE"
