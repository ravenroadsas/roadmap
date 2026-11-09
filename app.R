# Entry point for Posit Connect (rsconnect::deployApp()) and local runs.
# ROADMAP_APP=editor serves the Roadmap Editor from the same bundle;
# locally, editor_app.R launches the editor directly.
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
if (identical(Sys.getenv("ROADMAP_APP"), "editor")) run_editor() else run_app()
