# Roadmap Editor: companion app to build and edit the roadmap workbook.
# Run locally:      shiny::runApp("editor_app.R")   (or source this file)
# Posit Connect:    deploy this repository a second time with app.R and set
#                   the content's environment variable ROADMAP_APP=editor
#                   (see README, "Editor").
# The editor imports and exports workbooks; it never writes the workbook
# the roadmap app reads (ROADMAP_INPUT_XLSX).
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
run_editor()
