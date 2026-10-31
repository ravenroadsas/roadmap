# Entry point for Posit Connect (rsconnect::deployApp()) and local runs.
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
run_app()
