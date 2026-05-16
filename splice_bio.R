library(commonmark)

bio_path   <- "website-tutorials/bio.md"
index_path <- "website-tutorials/index.html"

bio_md   <- paste(readLines(bio_path, encoding = "UTF-8"), collapse = "\n")
bio_html <- trimws(markdown_html(bio_md))

# indent each line to match surrounding HTML
bio_html <- paste0(
  "          ",
  strsplit(bio_html, "\n")[[1]],
  collapse = "\n"
)

index  <- readLines(index_path, encoding = "UTF-8")
start  <- grep("<!-- BIO_START -->", index)
end    <- grep("<!-- BIO_END -->",   index)

if (length(start) != 1 || length(end) != 1)
  stop("Expected exactly one BIO_START and one BIO_END marker in index.html")

index <- c(
  index[seq_len(start)],
  bio_html,
  index[end:length(index)]
)

writeLines(index, index_path, useBytes = FALSE)
cat("bio.md spliced into index.html\n")
