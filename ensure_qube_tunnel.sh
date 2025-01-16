#! /bin/sh
echo "Checking reverse SSH tunnel..."

PRIVATE_KEY_PATH="/root/.ssh/id_rsa"
JUMP_BOX="wifi.qubemoney.com"
JUMP_BOX_PORT=443
TUNNEL_PORT=$1
USER="ubuntu"
ROUTER_PORT=602
PIDFILE="/var/run/qube_tunnel.pid"
SSH_BASE="ssh -i $PRIVATE_KEY_PATH -o ConnectTimeout=5" #timeout after 5 seconds    
TUNNEL_PORT_FILE="/etc/qube_tunnel_port"

# Load TUNNEL_PORT from file
if [ ! -f "$TUNNEL_PORT_FILE" ]; then
    echo "Error: Tunnel port file not found. Falling back to a random port between 2228-2232."
    TUNNEL_PORT=$((RANDOM % 5 + 2228)) # Generate a random port between 2228 and 2232
    echo "$TUNNEL_PORT" > "$TUNNEL_PORT_FILE" # Save the generated port to the file
    echo "Generated and saved new tunnel port: $TUNNEL_PORT"
else
    TUNNEL_PORT=$(cat "$TUNNEL_PORT_FILE")
    if ! [[ "$TUNNEL_PORT" =~ ^[0-9]+$ ]] || [ "$TUNNEL_PORT" -lt 1 ] || [ "$TUNNEL_PORT" -gt 65535 ]; then
        echo "Error: Invalid port in tunnel port file. Falling back to a random port between 2228-2232."
        TUNNEL_PORT=$((RANDOM % 5 + 2228)) # Generate a random port between 2228 and 2232
        echo "$TUNNEL_PORT" > "$TUNNEL_PORT_FILE" # Save the generated port to the file
        echo "Generated and saved new tunnel port: $TUNNEL_PORT"
    fi
fi

echo "Using tunnel port: $TUNNEL_PORT"


SSH_OPTIONS=" -p $JUMP_BOX_PORT -N -R 0.0.0.0:$TUNNEL_PORT:localhost:$ROUTER_PORT $USER@$JUMP_BOX"

while true; do
    if ! $SSH_BASE -p "$JUMP_BOX_PORT" "$USER@$JUMP_BOX" \
        "$SSH_BASE -p $TUNNEL_PORT root@localhost \"echo ping\"" 2>/dev/null | grep -qx "ping"; then
        echo "Tunnel not active."
        if [ -f "$PIDFILE" ]; then
            echo "PID exists..."
            CURRENT_PID=$(cat "$PIDFILE")
            echo "Got PID..."
            if kill -0 "$CURRENT_PID" 2>/dev/null; then
                echo "Killing existing process with PID $CURRENT_PID..."
                kill "$CURRENT_PID"
                rm -f "$PIDFILE"
            else
                echo "Stale PID file found. Cleaning up..."
                rm -f "$PIDFILE"
            fi
        fi
        
        echo "Tunnel not active. Cleaning up..."
        $SSH_BASE -p "$JUMP_BOX_PORT" "$USER@$JUMP_BOX" \
            "sudo ss -tulnp | grep :$TUNNEL_PORT | sed -n 's/.*pid=\\([0-9]*\\),.*/\\1/p' | xargs -r sudo kill -9" 2>/dev/null
        
        echo "reconnecting..."
        echo "$SSH_BASE $SSH_OPTIONS"
        $SSH_BASE $SSH_OPTIONS &
        TUNNEL_PID=$!
        touch "$PIDFILE"
        echo "$TUNNEL_PID" > "$PIDFILE"
        echo "Reconnection attempt made with PID $TUNNEL_PID."
    else
        echo "Tunnel is active."
    fi
    sleep 10
done

