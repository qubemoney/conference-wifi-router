#!/bin/sh
echo "Beginning Router Configuration..."
# Error handling
set -e


# Set constants
PRIVATE_KEY_PATH="/root/.ssh/id_rsa"
SSH_DIR="/root/.ssh"
JUMP_BOX_URL="wifi.qubemoney.com"
JUMP_BOX_PORT=443
TUNNEL_PORT_FILE="/etc/qube_tunnel_port"
JUMP_BOX_USER="ubuntu"
# Ensure OpenSSH is installed

enable_service_if_needed() {
    SERVICE_NAME=$1

    if /etc/init.d/"$SERVICE_NAME" enabled; then
        echo "Service $SERVICE_NAME is already enabled."
    else
        echo "Enabling service $SERVICE_NAME..."
        /etc/init.d/"$SERVICE_NAME" enable
        echo "Service $SERVICE_NAME has been enabled."
    fi
}

# Download and configure qube_tunnel init.d script
echo "Setting up qube_tunnel service..."
REBOOT_SERVICE="/etc/init.d/qube_reboot"
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/qube_reboot -o "$REBOOT_SERVICE"
chmod +x "$REBOOT_SERVICE"
enable_service_if_needed qube_reboot


echo "Checking for OpenSSH Server..."
if ! opkg list-installed | grep -q openssh-server; then
    echo "Installing OpenSSH Server..."
    opkg update
    opkg install openssh-server
else
    echo "OpenSSH Server is already installed."
fi

echo "Checking for OpenSSH Client..."
if ! opkg list-installed | grep -q openssh-client; then
    echo "Installing OpenSSH Client..."
    opkg update
    opkg install openssh-client
else
    echo "OpenSSH Client is already installed."
fi

echo "Checking for OpenSSH Client..."
if ! opkg list-installed | grep -q dnsmasq; then
    echo "Installing dnsmasq..."
    opkg update
    opkg install dnsmasq
else
    echo "dnsmasq is already installed."
fi

echo "Forcing proper SSH authorized_keys..."
cat <<'EOF' >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCbQWUwLV99v5MVG+sscBL7rcPf2DVG73nlQBPcRuZHtnyxdcdvb+ekEiKy65EiPcsIBF6h4BaUkMaxqpCXGZl+b0hdXLxO3OY8UAfBdGKTsdXUjwH1YXuAfRcX1CP7PXwEl7YxwiqaJw29hLdJBOL5XaonRd+UX/BmAPPRHELMAq55d89zruOAqr9HG9/62vyq52IzZRR5N50I3abouZ15prFFplq8+ZuKGFJJ4vl6eRhm7gcNN6w8uz0iv261yH/2z2lpha9PuQPCf9q+3NmRD/zDQGrLm14sR4vLvcMT10sD2CivIhSQhSk7dQVRE3qcmTWPY0najT4FlkMAUToB marcsmith@Marcs-MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDd6MG3K4ikMbXBQorJzKGaqFdqjGf7Rrx/GQjOlf0cFzbvI3Ku8XcFLtd06zSaLlER8HIuwxjkG2eD0GQ1j/IsTXBUOmZQRBQFNkIodh4NlphsXUPkGo+ML/cx+mbrrlxDtNNK4jjUS7CEZ3UNpJCF7BQ0VvklbKo+KDwx1PflBGQ9VUAppNnCEa2jBw9QVHqasfudi8H8gMtNYyb8R8C86LiOo8i9PcD/UGocg9FSnAhgiIgeRzVbIzt4C8pNaI6v+HS1UorwVGPeXALPt09+0mg8PkHzDUmjOOyCQfHlfl2wdX0uDl4QRJfBEjJS4n7wRwBHAvyNDPn6eLi5Umav wifi.qubemoney.com Jump Box Key
EOF

# Prompt user for tunnel port if not already saved
if [ ! -f "$TUNNEL_PORT_FILE" ]; then
    TUNNEL_PORT=""
    while ! echo "$TUNNEL_PORT" | grep -q '^[0-9]\+$'; do
        printf "Enter a valid numeric tunnel port number: "
        read TUNNEL_PORT < /dev/tty
    done
    TUNNEL_PORT=$(echo "$TUNNEL_PORT" | tr -cd '0-9')
    echo "$TUNNEL_PORT" > "$TUNNEL_PORT_FILE"
else
    TUNNEL_PORT=$(cat "$TUNNEL_PORT_FILE")
    # Sanitize and save after loading from the file
    TUNNEL_PORT=$(echo "$TUNNEL_PORT" | tr -cd '0-9')
    echo "Tunnel port loaded and sanitized from file: $TUNNEL_PORT"
    echo "$TUNNEL_PORT" > "$TUNNEL_PORT_FILE"
fi

# Configure SSH keys
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "Generating SSH key..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -C "Qube Conference Router Port: $TUNNEL_PORT" -N ""
    chmod 600 "$PRIVATE_KEY_PATH"
    echo "SSH key generated."
    echo "Public key:"
    cat "${PRIVATE_KEY_PATH}.pub"
    echo "Please provide the above public key to Marc to add to $JUMP_BOX_URL."

    while true; do
        echo -n "Has the key been added to $JUMP_BOX_URL? (type 'yes' to continue): "
        read RESPONSE < /dev/tty
        if [ "$RESPONSE" = "yes" ]; then
            echo "Continuing with the process..."
            break
        else
            echo "Waiting for the key to be added..."
        fi
    done
else
    echo "SSH key already exists at $PRIVATE_KEY_PATH."
fi

# Fetch and apply SSH daemon configuration
echo "Fetching and applying SSH daemon configuration..."
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/sshd_config -o "/etc/ssh/sshd_config"

# Restart SSH service
/etc/init.d/sshd restart
enable_service_if_needed sshd


# Download and configure ensure_qube_tunnel.sh
echo "Setting up ensure_qube_tunnel.sh..."
ENSURE_TUNNEL_SCRIPT="/usr/bin/ensure_qube_tunnel.sh"
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/ensure_qube_tunnel.sh -o "$ENSURE_TUNNEL_SCRIPT"
chmod +x "$ENSURE_TUNNEL_SCRIPT"

# Download and configure qube_tunnel init.d script
echo "Setting up qube_tunnel service..."
TUNNEL_SERVICE="/etc/init.d/qube_tunnel"
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/qube_tunnel -o "$TUNNEL_SERVICE"
chmod +x "$TUNNEL_SERVICE"
enable_service_if_needed qube_tunnel

# Test the reverse SSH tunnel
echo "Testing reverse SSH tunnel..."
while true; do
    ssh -p $JUMP_BOX_PORT -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $JUMP_BOX_USER@$JUMP_BOX_URL "echo Tunnel test successful"
    if [ $? -eq 0 ]; then
        echo "Reverse SSH tunnel established successfully."
        break
    else
        echo "Reverse SSH tunnel failed. Retrying in 3 seconds..."
        sleep 3
    fi
done


# Fetch and apply SSH daemon configuration
echo "Fetching and applying dnsmasq configuration..."
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/dnsmasq.conf -o "/etc/dnsmasq.conf"
/etc/init.d/dnsmasq restart
enable_service_if_needed dnsmasq


# Update firewall rules
echo "Updating firewall rules to force all DNS requests..."
FIREWALL_SCRIPT_LOCATION="/usr/bin/qube_update_firewall.sh"
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/qube_update_firewall.sh -o "$FIREWALL_SCRIPT_LOCATION"
chmod +x "$FIREWALL_SCRIPT_LOCATION"
echo "running..."
/usr/bin/qube_update_firewall.sh



# Confirm the rules
echo "Current iptables rules for $TARGET_IP:$TARGET_PORT:"
iptables -t nat -L PREROUTING -v -n | grep "$TARGET_IP:$TARGET_PORT"

echo "Setup complete."
