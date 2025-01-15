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

