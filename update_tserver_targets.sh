#!/bin/bash

# This script can update your Prometheus *_targets.json file with all the running TServer addresses.
# example:
# update_tserver_targets.sh \
# --master-addrs localhost:8764,localhost:8766,localhost:8768 \
# --json-path ~/git/prometheus_scripts/tserver_targets.json

MASTER_ADDRS=$1
JSON_PATH=$2
DEFAULT_PORT="8075"

function usage() {
cat << EOF
Usage:
update_tserver_targets.sh [flags]
-h, --help              Print help
-m, --master-addrs      Comma separated list of master host:port addresses
-j, --json-path         Prometheus target json file path
-p, --webserver-port    Kudu webserver port (default: 8075)
EOF
}

while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage
      exit 1
      ;;
    -m|--master-addrs)
      MASTER_ADDRS=$2
      shift 2
      ;;
    -j|--json-path)
      JSON_PATH=$2
      shift 2
      ;;
    -p|--webserver-port)
      DEFAULT_PORT=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      usage
      exit 1
      ;;
    *) # positional arguments
      echo "Error: Unsupported argument $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z $MASTER_ADDRS ]]; then
    echo "Must supply master addresses"
    usage
    exit 1
fi
if [[ -z $JSON_PATH ]]; then
    echo "Must supply output json file path"
    usage
    exit 1
fi

# Run the kudu tserver list command and extract the addresses
host_names=$(kudu tserver list $MASTER_ADDRS -format=pretty -columns=rpc-addresses | awk 'NR>2 {print $1}' | cut -d: -f1)

json='[
\t{
\t\t"labels": {
\t\t\t"job": "kudu",
\t\t\t"group": "tservers"
\t\t},
\t\t"targets": [
'

# Loop through each address and add it to the JSON structure
while IFS= read -r host_names; do
    json+="\t\t\t\"$host_names:$DEFAULT_PORT\",\n"
done <<< "$host_names"

# Remove the trailing comma from the last entry
json="${json%,*}"

# Close the JSON structure
json+='
\t\t]
\t}
]'

# Print the final JSON
echo -e "$json" > $JSON_PATH
echo "Targets have been written to $JSON_PATH"