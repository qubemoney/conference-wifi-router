#!/bin/sh

echo "Beginning Router Configuration..."

# Set constants
PRIVATE_KEY_PATH="/root/.ssh/id_rsa"
SSH_DIR="/root/.ssh"
JUMP_BOX_URL="wifi.qubemoney.com"
JUMP_BOX_PORT=443
TUNNEL_PORT_FILE="/etc/qube_tunnel_port"
JUMP_BOX_USER="ubuntu"
# Ensure OpenSSH is installed
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

# Configure SSH keys
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "Generating SSH key..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -C "Qube Conference Router"
    chmod 600 "$PRIVATE_KEY_PATH"
    echo "SSH key generated."
    echo "Public key:"
    cat "${PRIVATE_KEY_PATH}.pub"
    echo "Please provide the above public key to Marc to add to $JUMP_BOX_URL."
    while true; do
        echo -n "Has the key been added to $JUMP_BOX_URL? (yes to continue): "
        read RESPONSE
        if [ "$RESPONSE" = "yes" ]; then
            break
        fi
    done
else
    echo "SSH key already exists at $PRIVATE_KEY_PATH."
fi

# Fetch and apply SSH daemon configuration
echo "Fetching and applying SSH daemon configuration..."
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/sshd_config -o "/etc/ssh/sshd_config"
if [ $? -ne 0 ]; then
    echo "Error fetching sshd_config. Exiting."
    exit 1
fi

# Restart SSH service
/etc/init.d/sshd restart
/etc/init.d/sshd enable

# Add jump box host key to known_hosts
echo "Testing connection to $JUMP_BOX_URL..."
ssh-keyscan -p $JUMP_BOX_PORT $JUMP_BOX_URL >> /root/.ssh/known_hosts

# Prompt user for tunnel port if not already saved
if [ ! -f "$TUNNEL_PORT_FILE" ]; then
    while [ -z "$TUNNEL_PORT" ]; do
        echo -n "Enter the tunnel port number for the reverse SSH connection (example: 2222): "
        read TUNNEL_PORT
    done
    echo "$TUNNEL_PORT" > "$TUNNEL_PORT_FILE"
else
    TUNNEL_PORT=$(cat "$TUNNEL_PORT_FILE")
    echo "Tunnel port loaded from file: $TUNNEL_PORT"
fi

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
/etc/init.d/qube_tunnel enable
/etc/init.d/qube_tunnel start

# Update firewall rules
echo "Updating firewall rules..."
FIREWALL_SCRIPT_LOCATION="/usr/bin/qube_update_firewall.sh"
curl -s https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/qube_update_firewall.sh -o "$FIREWALL_SCRIPT_LOCATION"
chmod +x "$FIREWALL_SCRIPT_LOCATION"
/usr/bin/qube_update_firewall.sh

# Test the reverse SSH tunnel
echo "Testing reverse SSH tunnel..."
while true; do
    ssh -p $JUMP_BOX_PORT -o ConnectTimeout=5 $JUMP_BOX_USER@$JUMP_BOX_URL "echo Tunnel test successful"
    if [ $? -eq 0 ]; then
        echo "Reverse SSH tunnel established successfully."
        break
    else
        echo "Reverse SSH tunnel failed. Retrying in 3 seconds..."
        sleep 3
    fi
done

echo "Setup complete."
