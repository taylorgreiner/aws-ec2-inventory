#!/bin/bash

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Function to get instance type specifications
get_instance_specs() {
    local instance_type=$1
    aws ec2 describe-instance-types \
        --instance-types "$instance_type" \
        --query 'InstanceTypes[0].{vCPU:VCpuInfo.DefaultVCpus,MemoryMiB:MemoryInfo.SizeInMiB}' \
        --output json
}

# Function to convert MiB to GiB
convert_mib_to_gib() {
    local mib=$1
    echo "scale=1; $mib/1024" | bc
}

# Function to get volume information for an instance
get_volume_info() {
    local instance_id=$1
    aws ec2 describe-volumes \
        --filters "Name=attachment.instance-id,Values=$instance_id" \
        --query 'Volumes[].Size' \
        --output json
}

# Create output file and write header
output_file="ec2_inventory_$(date +%Y%m%d_%H%M%S).csv"
echo "Instance ID,Instance Type,vCPUs,Memory (GiB),Disk Count,Total Storage (GB)" > "$output_file"

# Get list of running instances
instances=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType]' \
    --output json)

echo "$instances" | jq -r '.[] | @sh' | while read -r instance_info; do
    # Extract instance ID and type
    eval "instance_array=($instance_info)"
    instance_id="${instance_array[0]}"
    instance_type="${instance_array[1]}"
    
    # Get instance specifications
    specs=$(get_instance_specs "$instance_type")
    vcpus=$(echo "$specs" | jq -r '.vCPU')
    memory_mib=$(echo "$specs" | jq -r '.MemoryMiB')
    memory_gib=$(convert_mib_to_gib "$memory_mib")
    
    # Get volume information
    volumes=$(get_volume_info "$instance_id")
    disk_count=$(echo "$volumes" | jq '. | length')
    total_storage=$(echo "$volumes" | jq 'add')
    
    # Write to CSV
    echo "$instance_id,$instance_type,$vcpus,$memory_gib,$disk_count,$total_storage" >> "$output_file"
done

echo "Output written to $output_file"
