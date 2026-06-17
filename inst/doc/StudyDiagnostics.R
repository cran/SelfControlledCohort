## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE
)

## ----thresholds---------------------------------------------------------------
library(SelfControlledCohort)
str(getDefaultDiagnosticThresholds())

## ----eval=FALSE---------------------------------------------------------------
# # Well-powered study
# computeMdrrForRateRatio(
#   exposedPersonTime = 50000,
#   unexposedPersonTime = 150000,
#   exposedEvents = 40,
#   unexposedEvents = 90
# )
# 
# # Underpowered study (SRL1 solver returns NA if power cannot be met)
# computeMdrrForRateRatio(
#   exposedPersonTime = 500,
#   unexposedPersonTime = 1500,
#   exposedEvents = 3,
#   unexposedEvents = 7
# )

## ----eval=FALSE---------------------------------------------------------------
# # Compute EASE from negative control estimates
# negatives <- data.frame(
#   rr = c(1.2, 0.8, 1.0, 1.1, 0.95),
#   seLogRr = c(0.2, 0.1, 0.3, 0.15, 0.25)
# )
# computeEase(negatives)

## ----eval=FALSE---------------------------------------------------------------
# thresholds <- getDefaultDiagnosticThresholds()
# thresholds$mdrrMaxAcceptable <- 15.0       # Allow higher MDRR
# thresholds$maxPreExposureProportion <- 0.10  # Allow up to 10% pre-exposure
# 
# runSelfControlledCohort(
#   ...,
#   runDiagnostics = TRUE,
#   diagnosticThresholds = thresholds
# )

## ----eval=FALSE---------------------------------------------------------------
# diagnostics <- read.csv("results/scc_diagnostics_summary.csv")
# 
# # Which target-outcome pairs had failures?
# failures <- diagnostics[diagnostics$pass == 0 &
#   !(diagnostics$diagnostic_name %in% c("UNBLIND", "UNBLIND_FOR_CALIBRATION")), ]
# print(failures)

