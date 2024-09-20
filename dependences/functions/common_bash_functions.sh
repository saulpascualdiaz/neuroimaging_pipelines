# ANSI color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color


# Functions
run_command() {
    echo -e "${BLUE}command:${NC} $*"
    "$@"
}

# Check if a file exists and return true or false
function file_exists() {
    local file=$1
    if [ -f "$file" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}