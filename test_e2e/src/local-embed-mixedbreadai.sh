#!/usr/bin/env bash

set -e

# Set the paths and directories
SRC_PATH=$(dirname "$(realpath "$0")")
SCRIPT_DIR=$(dirname "$SRC_PATH")
cd "$SCRIPT_DIR"/.. || exit 1
OUTPUT_FOLDER_NAME=embed-mixedbreadai
OUTPUT_ROOT=${OUTPUT_ROOT:-$SCRIPT_DIR}
OUTPUT_DIR=$OUTPUT_ROOT/structured-output/$OUTPUT_FOLDER_NAME
WORK_DIR=$OUTPUT_ROOT/workdir/$OUTPUT_FOLDER_NAME
max_processes=${MAX_PROCESSES:=$(python3 -c "import os; print(os.cpu_count())")}
MXBAI_API_KEY=${MXBAI_API_KEY:-$MXBAI_API_KEY}

# Include the cleanup script and define the cleanup function
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/cleanup.sh
function cleanup() {
  cleanup_dir "$OUTPUT_DIR"
  cleanup_dir "$WORK_DIR"
}
trap cleanup EXIT

if [ -z "$MXBAI_API_KEY" ]; then
  echo "Skipping Mixedbread AI ingest test because the MXBAI_API_KEY env var is not set."
  exit 8
fi

# Define the run script
RUN_SCRIPT=${RUN_SCRIPT:-./unstructured_ingest/main.py}
# Run the ingestion script with the specified parameters
PYTHONPATH=${PYTHONPATH:-.} "$RUN_SCRIPT" \
  local \
  --api-key "$UNS_PAID_API_KEY" \
  --partition-by-api \
  --partition-endpoint "https://api.unstructuredapp.io" \
  --num-processes "$max_processes" \
  --metadata-exclude coordinates,filename,file_directory,metadata.data_source.record_locator.path,metadata.data_source.date_created,metadata.data_source.date_modified,metadata.data_source.date_processed,metadata.last_modified,metadata.detection_class_prob,metadata.parent_id,metadata.category_depth \
  --output-dir "$OUTPUT_DIR" \
  --verbose \
  --reprocess \
  --input-path example-docs/book-war-and-peace-1p.txt \
  --work-dir "$WORK_DIR" \
  --embedding-provider "mixedbread-ai" \
  --embedding-api-key "$MXBAI_API_KEY" \
  --embedding-model-name "mixedbread-ai/mxbai-embed-large-v1"

set +e

# Check the differences with the expected output
"$SCRIPT_DIR"/check-diff-expected-output.py --output-folder-name $OUTPUT_FOLDER_NAME