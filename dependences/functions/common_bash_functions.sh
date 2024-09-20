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

# Function to compress all .nii files in a folder recursively
compress_nii() {
    local folder=$1

    # Find all .nii files recursively and compress them using gzip
    find "$folder" -type f -name "*.nii" | while read nii_file; do
        if [[ ! -f "${nii_file}.gz" ]]; then
            echo "Compressing $nii_file"
            gzip "$nii_file"
        else
            echo "$nii_file.gz already exists, skipping compression."
        fi
    done
}

# Function to decompress all .nii.gz files in a folder recursively
decompress_nii_gz() {
    local folder=$1

    # Find all .nii.gz files recursively and decompress them using gunzip
    find "$folder" -type f -name "*.nii.gz" | while read gz_file; do
        if [[ -f "$gz_file" ]]; then
            echo "Decompressing $gz_file"
            gunzip "$gz_file"
        else
            echo "$gz_file not found or already decompressed, skipping."
        fi
    done
}

