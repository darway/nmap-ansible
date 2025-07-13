#!/bin/bash

RESULTS_FILE="netmap_results.txt"

# Function to display the menu
display_menu() {
    clear
    echo "----------------------------------------"
    echo "          Nmap Network Scanner          "
    echo "----------------------------------------"
    echo "1. Discover all devices on local network"
    echo "2. Scan a specific IP address (Quick Scan)"
    echo "3. Scan a specific IP address (Full Port Scan)"
    echo "4. Scan a specific IP address (OS and Service Detection)"
    echo "5. Ping Scan of a Subnet"
    echo "6. Exit"
    echo "7. View Previous Scan Results"
    echo "8. Setup passwordless SSH access to discovered devices"
    echo "----------------------------------------"
    echo -n "Enter your choice: "
}

# Function to get local network IP range
get_local_ip_range() {
    local_ip=$(hostname -I | awk '{print $1}')
    if [[ -z "$local_ip" ]]; then
        echo "Could not determine local IP address. Please ensure you have an active network connection."
        return 1
    fi
    network_prefix=$(echo "$local_ip" | awk -F'.' '{print $1"."$2"."$3}')
    echo "${network_prefix}.0/24"
    return 0
}

# Function to save results
save_result() {
    echo "----- $(date) -----" >> "$RESULTS_FILE"
    echo "$1" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Main loop
while true; do
    display_menu
    read choice

    case $choice in
        1)
            echo ""
            echo "Discovering all devices on the local network..."
            echo "(This might require sudo and can take a moment)"
            IP_RANGE=$(get_local_ip_range)
            if [[ $? -eq 0 ]]; then
                result=$(sudo nmap -sn "$IP_RANGE")
                echo "$result"
                save_result "Discover all devices on local network:\n$result"

                # Extract live IPs from nmap output
                echo ""
                echo "Extracting live IPs for Ansible..."
                live_ips=$(echo "$result" | grep "Nmap scan report for" | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
                if [[ -z "$live_ips" ]]; then
                    echo "No live IPs found for Ansible."
                else
                    # Create a temporary Ansible inventory
                    INVENTORY_FILE="ansible_hosts.txt"
                    echo "$live_ips" > "$INVENTORY_FILE"
                    echo "Running Ansible ping on discovered devices..."
                    ansible all -i "$INVENTORY_FILE," -m ping
                    echo ""
                    echo "Gathering Ansible facts (setup module)..."
                    ansible all -i "$INVENTORY_FILE," -m setup --tree ansible_facts/
                    echo "Ansible facts saved in ansible_facts/ directory."
                    rm "$INVENTORY_FILE"
                fi
            else
                echo "Unable to proceed without a local IP range."
            fi
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        2)
            echo ""
            read -p "Enter the IP address to scan (e.g., 192.168.1.1): " target_ip
            echo "Performing quick scan on $target_ip..."
            result=$(sudo nmap -F "$target_ip")
            echo "$result"
            save_result "Quick scan on $target_ip:\n$result"
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        3)
            echo ""
            read -p "Enter the IP address to scan (e.g., 192.168.1.1): " target_ip
            echo "Performing full port scan on $target_ip..."
            result=$(sudo nmap -p- "$target_ip")
            echo "$result"
            save_result "Full port scan on $target_ip:\n$result"
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        4)
            echo ""
            read -p "Enter the IP address to scan (e.g., 192.168.1.1): " target_ip
            echo "Performing OS and service detection on $target_ip..."
            result=$(sudo nmap -A "$target_ip")
            echo "$result"
            save_result "OS and service detection on $target_ip:\n$result"
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        5)
            echo ""
            read -p "Enter the subnet to ping scan (e.g., 192.168.1.0/24): " subnet_range
            echo "Performing ping scan on $subnet_range..."
            result=$(sudo nmap -sn "$subnet_range")
            echo "$result"
            save_result "Ping scan on $subnet_range:\n$result"
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        6)
            echo "Exiting Nmap Network Scanner. Goodbye!"
            exit 0
            ;;
        7)
            echo ""
            echo "----- Previous Scan Results -----"
            if [[ -f "$RESULTS_FILE" ]]; then
                less "$RESULTS_FILE"
            else
                echo "No previous scan results found."
            fi
            echo "Press Enter to continue..."
            read
            ;;
         8)
            echo ""
            echo "Setting up passwordless SSH access to discovered devices..."
            IP_RANGE=$(get_local_ip_range)
            if [[ $? -eq 0 ]]; then
                result=$(sudo nmap -sn "$IP_RANGE")
                live_ips=$(echo "$result" | grep "Nmap scan report for" | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
                if [[ -z "$live_ips" ]]; then
                    echo "No live IPs found."
                else
                    read -p "Enter SSH username for target devices: " ssh_user
                    for ip in $live_ips; do
                        echo "Copying SSH key to $ip..."
                        ssh-copy-id "$ssh_user@$ip"
                    done
                    echo "Passwordless SSH setup attempted for all discovered devices."
                fi
            else
                echo "Unable to proceed without a local IP range."
            fi
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 7."
            echo "Press Enter to continue..."
            read
            ;;
    esac
done