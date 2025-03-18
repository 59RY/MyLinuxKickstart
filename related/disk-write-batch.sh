#!/bin/bash

# This script copies disk data in 512KiB blocks while reducing AWS EBS snapshot costs.
# Zero-filled blocks are skipped to minimize storage usage.

# Prompt user for input device, output device, and number of blocks to copy
read -p "Enter the source device or raw disk image (e.g., /dev/nvme1n1): " input_device
read -p "Enter the destination device (e.g., /dev/nvme2n1): " output_device
read -p "Enter the number of blocks to copy (unit: 512KiB): " NUM_BLOCKS

echo -e "\nSource: ${input_device}"
echo "Destination: ${output_device}"
echo "Number of blocks to copy: ${NUM_BLOCKS}"
read -p "Press any key to proceed, or Ctrl + C to cancel..."

# Create temporary files
BLOCK_TEMP=$(mktemp)
ZERO_TEMP=$(mktemp)

# Generate a 512KiB zero block
dd if=/dev/zero of="$ZERO_TEMP" bs=512K count=1 status=none

# Initialize block write counter
written_blocks=0

# Process the specified number of blocks
for ((i=0; i<NUM_BLOCKS; i++)); do
	echo "Processing block $i..."
	
	# Read 1 block (512KiB) from the input device
	dd if="$input_device" of="$BLOCK_TEMP" bs=512K count=1 skip=$i status=none

	# Check if the block is entirely zero
	if cmp -s "$BLOCK_TEMP" "$ZERO_TEMP"; then
		echo "Block $i is all zeros. Skipping..."
	else
		echo "Writing block $i to ${output_device}..."
		dd if="$BLOCK_TEMP" of="$output_device" bs=512K count=1 seek=$i conv=notrunc status=none
		written_blocks=$((written_blocks+1))
	fi
done

# Remove temporary files
rm "$BLOCK_TEMP" "$ZERO_TEMP"

# Calculate total written size (1 block = 512KiB = 0.5MiB)
total_mib=$(awk "BEGIN {printf \"%.1f\", $written_blocks/2}")

echo "Disk copy process completed."
echo "Total blocks written: ${written_blocks}"
echo "Total data written: ${total_mib} MiB"
