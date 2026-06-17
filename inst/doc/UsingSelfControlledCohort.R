## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE
)

## ----setup--------------------------------------------------------------------
library(SelfControlledCohort)
library(Eunomia)
library(DatabaseConnector)
library(dplyr)

# Create a temporary SQLite database with Eunomia data
connectionDetails <- getEunomiaConnectionDetails()
connection <- connect(connectionDetails)

# We will use the 'main' schema for this example
cdmDatabaseSchema <- "main"

## ----basic_run----------------------------------------------------------------
# Define a temporary folder for results
outputFolder <- tempfile("scc_output")
dir.create(outputFolder)

# Run the analysis
runSelfControlledCohort(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  exposureTable = "drug_era",
  outcomeTable = "condition_era",
  resultExportPath = outputFolder,
  databaseId = 1,
  analysisId = 1
)

## ----read_results-------------------------------------------------------------
results <- read.csv(file.path(outputFolder, "scc_result.csv"))

# Display the top 5 associations by Relative Risk
results %>%
  filter(analysis_id == 1) %>%
  arrange(desc(rr)) %>%
  head(5) %>%
  select(target_cohort_id, outcome_cohort_id, rr, lb_95, ub_95, p_value) %>%
  knitr::kable(digits = 3)

## ----create_cohorts-----------------------------------------------------------
# Create standard cohorts in the 'cohort' table:
# 1 = Celecoxib
# 2 = Diclofenac
# 3 = GI Bleed
# 4 = NSAIDs
createCohorts(connectionDetails)

## ----custom_cohort_run--------------------------------------------------------
runSelfControlledCohort(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  exposureTable = "cohort",
  outcomeTable = "cohort",
  exposureIds = c(1, 2, 4), # Celecoxib, Diclofenac, NSAIDs
  outcomeIds = c(3), # GI Bleed
  databaseId = 1,
  analysisId = 2, # Unique ID for this run
  resultExportPath = outputFolder
)

## ----view_custom_results------------------------------------------------------
results <- read.csv(file.path(outputFolder, "scc_result.csv"))

results %>%
  filter(analysis_id == 2) %>%
  select(target_cohort_id, outcome_cohort_id, rr, p_value) %>%
  knitr::kable(digits = 3)

## ----view_diagnostic_thresholds-----------------------------------------------
thresholds <- getDefaultDiagnosticThresholds()
str(thresholds)

## ----view_diagnostics---------------------------------------------------------
diagnostics <- read.csv(file.path(outputFolder, "scc_diagnostics_summary.csv"))

# Show the diagnostic results for analysis 2
diagnostics %>%
  filter(analysis_id == 2) %>%
  select(target_cohort_id, outcome_cohort_id, diagnostic_name, diagnostic_value, pass) %>%
  head(10) %>%
  knitr::kable()

## ----calibration_run----------------------------------------------------------
# Define negative controls (formatted as list of vectors: c(exposureId, outcomeId))
negativeControls <- list(
  c(1, 3), # Celecoxib - GI Bleed (Demo only!)
  c(2, 3) # Diclofenac - GI Bleed (Demo only!)
)

runSelfControlledCohort(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  exposureTable = "cohort",
  outcomeTable = "cohort",
  exposureIds = c(4), # Target: NSAIDs
  outcomeIds = c(3), # Outcome: GI Bleed
  analysisId = 4, # Unique ID for this calibration run
  negativeControlPairs = negativeControls, # <--- Supply negative controls
  resultExportPath = outputFolder,
  databaseId = 1
)

## ----view_calibration---------------------------------------------------------
results <- read.csv(file.path(outputFolder, "scc_result.csv"))

results %>%
  filter(analysis_id == 4, target_cohort_id == 4) %>%
  select(target_cohort_id, rr, calibrated_rr, p_value, calibrated_p_value) %>%
  knitr::kable(digits = 3)

## ----setup_analyses-----------------------------------------------------------
# Analysis 1: Standard risk windows (1-30 days exposed vs pre-exposure)
sccArgs1 <- createRunSelfControlledCohortArgs(
  riskWindowStartExposed = 1,
  riskWindowEndExposed = 30,
  addLengthOfExposureExposed = FALSE,
  riskWindowStartUnexposed = -30,
  riskWindowEndUnexposed = -1,
  addLengthOfExposureUnexposed = FALSE
)
analysis1 <- createSccAnalysis(
  analysisId = 101,
  description = "Standard 30-day windows",
  runSelfControlledCohortArgs = sccArgs1
)

# Analysis 2: Longer exposure risk window (1-90 days exposed)
sccArgs2 <- createRunSelfControlledCohortArgs(
  riskWindowStartExposed = 1,
  riskWindowEndExposed = 90,
  addLengthOfExposureExposed = FALSE,
  riskWindowStartUnexposed = -90,
  riskWindowEndUnexposed = -1,
  addLengthOfExposureUnexposed = FALSE
)
analysis2 <- createSccAnalysis(
  analysisId = 102,
  description = "Extended 90-day windows",
  runSelfControlledCohortArgs = sccArgs2
)

## ----setup_hypotheses---------------------------------------------------------
# Create hypotheses (treating IDs 1 and 2 as negative controls)
eo1 <- createExposureOutcome(exposureId = 4, outcomeId = 3) # Target (NSAIDs - GiBleed)
eo2 <- createExposureOutcome(exposureId = 1, outcomeId = 3, trueEffectSize = 1) # Control 1
eo3 <- createExposureOutcome(exposureId = 2, outcomeId = 3, trueEffectSize = 1) # Control 2

## ----run_multiple_analyses----------------------------------------------------
multiResultsFolder <- tempfile("scc_multi")

runSccAnalyses(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  exposureTable = "cohort",
  outcomeTable = "cohort",
  resultsFolder = multiResultsFolder,
  sccAnalysisList = list(analysis1, analysis2),
  exposureOutcomeList = list(eo1, eo2, eo3),
  databaseId = 1,
  computeThreads = 1,
  analysisThreads = 1 # Serial execution for Eunomia SQLite
)

## ----results_db_creation------------------------------------------------------
resultsDbFile <- tempfile("scc_results_db", fileext = ".sqlite")
resultsConnectionDetails <- createConnectionDetails(dbms = "sqlite", server = resultsDbFile)

## ----create_model-------------------------------------------------------------
createResultsDataModel(
  connectionDetails = resultsConnectionDetails,
  databaseSchema = "main"
)

## ----query_results_db---------------------------------------------------------
resultsConn <- connect(resultsConnectionDetails)

# Query the scc_result table for our calibrated run (Analysis 4)
resultsDb <- querySql(resultsConn, "SELECT * FROM main.scc_result WHERE analysis_id = 4")

# Show the results from the database
resultsDb %>%
  select(target_cohort_id, outcome_cohort_id, rr, calibrated_rr) %>%
  knitr::kable(digits = 3)

disconnect(resultsConn)

## ----cleanup, include=FALSE---------------------------------------------------
# Clean up
on.exit(disconnect(connection))
unlink(outputFolder, recursive = TRUE)
unlink(multiResultsFolder, recursive = TRUE)
unlink(resultsDbFile)

