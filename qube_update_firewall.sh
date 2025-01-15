#!/bin/sh

# Define the template and destination configuration files
TEMPLATE_FILE="/etc/config/firewall_template"
CONFIG_FILE="/etc/config/firewall_test"
TEMP_FILE="/tmp/firewall_resolved.conf"

# Function to resolve all IP addresses for a domain
resolve_ips() {
    domain=$1
    nslookup "$domain" 8.8.8.8 2>/dev/null | awk '/^Address [0-9]+:/ { print $3 }'
}

# Check if the template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE does not exist."
    exit 1
fi

# Define the list of domains to resolve
DOMAINS="qubemoney.com dashboard.qubemoney.com api.qubemoney.com fonts.googleapis.com cdn.jsdelivr.net rum.browser-intake-datadoghq.com plausible.io session-replay.browser-intake-datadoghq.com qube-production.s3.amazonaws.com www.googletagmanager.com www.google-analytics.com static.zdassets.com widget-mediator.zopim.com static.elfsight.com service-reviews-ultimate.elfsight.com qubemoneystg.wpenginepowered.com qubemoneyllc.ontralink.com qubemoneyhelp.zendesk.com qubemoney.wpenginepowered.com googleads.g.doubleclick.net connect.facebook.net cdn.funnelytics.io cdn.branch.io"

# Initialize the placeholder replacement content
FIREWALL_RULES=""

# Resolve IPs and generate firewall rules
for domain in $DOMAINS; do
    echo "Resolving IPs for $domain..."
    IPS=$(resolve_ips "$domain")
    if [ -z "$IPS" ]; then
        echo "Warning: No IPs resolved for $domain."
        continue
    fi
    for ip in $IPS; do
        echo "Adding rule for $ip..."
        FIREWALL_RULES="$FIREWALL_RULES
config rule
    option name 'Allow $domain ($ip)'
    option src 'lan'
    option dest 'wan'
    option dest_ip '$ip'
    option proto 'all'
    option target 'ACCEPT'"
    done
done

# Check if any rules were generated
if [ -z "$FIREWALL_RULES" ]; then
    echo "Error: No firewall rules generated. Exiting."
    exit 1
fi

# Escape problematic characters in rules
ESCAPED_RULES=$(printf '%s' "$FIREWALL_RULES" | sed 's/[\/&|]/\\&/g')

# Debugging: Output escaped rules
echo "Escaped rules for debugging:"
echo "$ESCAPED_RULES"

# Replace placeholder <Qube_Websites> in the template
if ! grep -q "<Qube_Websites>" "$TEMPLATE_FILE"; then
    echo "Error: Placeholder <Qube_Websites> not found in the template."
    exit 1
fi

echo "Updating $CONFIG_FILE with new rules..."
sed "s|<Qube_Websites>|$ESCAPED_RULES|g" "$TEMPLATE_FILE" > "$TEMP_FILE"

# Verify the output
if [ ! -s "$TEMP_FILE" ]; then
    echo "Error: Generated file $TEMP_FILE is empty. Check template or rules generation."
    exit 1
fi

# Move the updated file to the firewall config location
mv "$TEMP_FILE" "$CONFIG_FILE"

echo "Firewall configuration updated successfully in $CONFIG_FILE."
echo "Reloading the firewall to apply changes..."
/etc/init.d/firewall reload

echo "Done."
