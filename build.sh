#!/usr/bin/env bash

# Default values
ENV_FILE_PATH=""
BUILD_NAME="ensembl-rest"
ENV_FILE_PROVIDED=0

# Parse named parameters
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -e|--env-file)
      ENV_FILE_PATH="$2"
      ENV_FILE_PROVIDED=1
      shift # past argument
      shift # past value
      ;;
    -n|--build-name)
      BUILD_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      shift # past argument
      ;;
  esac
done

# Check if --env-file argument was provided
if [[ $ENV_FILE_PROVIDED -eq 0 ]]; then
  echo "Error: --env-file argument not provided."
  exit 1
fi

if [ ! -f "$ENV_FILE_PATH" ]; then
  echo "provide a file containing the following variables:"
  echo "For example to connect to ensembl servers:"
  echo "DB_HOST=ensembldb.ensembl.org"
  echo "DB_PORT=3306"
  echo "DB_USER=anonymous"
  echo "DB_PASSWORD="
  echo "DB_VERSION=109"
  echo "VERSION=109"
  echo "ASSEMBLY=GRCh38"
  echo "MAX_REQUESTS_PER_SECOND=15"
  exit 1
fi


# Function to load the .env file without exporting the variables
load_env() {
  while IFS= read -r line; do
    if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
      local var_name=$(echo "$line" | cut -d= -f1)
      local var_value=$(echo "$line" | cut -d= -f2-)
      declare -g "$var_name=$var_value"
      build_args="$build_args --build-arg $var_name=$var_value"
    fi
  done < "$1"
}

# Load the .env file
load_env "$ENV_FILE_PATH"

# Function to check if the environment variables are set
check_var() {
  local skip_check_if_empty="$3"
  if [ ! -n "$1" ] && [ "$skip_check_if_empty" != "skip" ]; then
    echo "Error: $2 variable not set."
    exit 1
  fi
}

# Call the function to check for missing environment variables
check_var "$DB_HOST" "DB_HOST"
check_var "$DB_PORT" "DB_PORT"
check_var "$DB_USER" "DB_USER"
check_var "$DB_PASSWORD" "DB_PASSWORD" "skip"
check_var "$DB_VERSION" "DB_VERSION"
check_var "$VERSION" "VERSION"
check_var "$ASSEMBLY" "ASSEMBLY"


# Build the Docker image using the --build-arg flag to pass the value of the environment variable
echo "docker build $build_args -t $BUILD_NAME ."
docker build $build_args -t $BUILD_NAME .
