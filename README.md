**README.md**

---

# Gateway Brute-Force Selector

This project provides a **Bash-based algorithm** that tests multiple candidate gateway IPs on a network and automatically configures the fastest working one in **NetworkManager**.

It was designed for environments where multiple gateways exist but not all provide working internet or DNS, and performance varies significantly between them.

---

## Features

1. Iterates through a list of candidate gateway IPs.
2. For each gateway:

   * Replaces the default route with the candidate.
   * Pings the gateway to confirm responsiveness.
   * Verifies internet connectivity with an external IP.
   * Checks DNS resolution (via `google.com`).
   * Runs a **speed test** using `speedtest-cli`.
3. Tracks the **fastest working gateway** (highest download Mbps).
4. Automatically applies the selected gateway to a NetworkManager connection.

---

## Requirements

* **Linux system** with:

  * `bash`
  * `iproute2` (`ip` command)
  * `ping`
  * `nmcli` (NetworkManager)
  * `bc` (for numeric comparisons)
  * `speedtest-cli` ([install via pip or package manager](https://github.com/sivel/speedtest-cli))

### Installation

On Fedora / RHEL:

```bash
sudo dnf install speedtest-cli bc iproute NetworkManager
```

On Debian / Ubuntu:

```bash
sudo apt install speedtest-cli bc iproute2 network-manager
```

Or install speedtest-cli via pip:

```bash
pip install speedtest-cli
```

---

## Usage

1. Clone or copy the script to your machine.
2. Edit the following variables in the script if needed:

   * `CANDIDATES`: list of candidate gateway IPs to test.
   * `CONN_NAME`: the NetworkManager connection profile to modify.
   * `DEV`: the network interface name (e.g., `enp5s0`).
3. Run the script with:

```bash
sudo ./brute-gateway.sh
```

---

## Example Output

```text
🔎 Testing candidate gateways...
➡️  172.16.8.1 ... ✅ works (3.22 ms, 48.6 Mbps download)
➡️  172.16.8.6 ... ⚠️  responds (0.938 ms) but no internet
➡️  172.16.8.72 ... ✅ works (1.06 ms, 12.3 Mbps download)
➡️  172.16.11.82 ... ✅ works (0.563 ms, 95.7 Mbps download)

🎯 Best working gateway: 172.16.11.82 (0.563 ms, 95.7 Mbps)
🔧 Applying to NetworkManager...
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/5)
```

---

## Algorithm Logic

1. Loop over candidate gateways.
2. For each gateway:

   * `ping gateway` → if no reply, skip.
   * `ping external IP` → confirm internet.
   * `ping google.com` → confirm DNS.
   * `speedtest-cli` → record download speed.
3. Select the gateway with **highest download speed**.
4. Apply gateway via:

   ```bash
   nmcli connection modify "$CONN_NAME" ipv4.gateway "$BEST_GATEWAY" ipv4.method manual
   nmcli connection up "$CONN_NAME"
   ```

---

## Notes

* Speed tests can take **10–15 seconds per candidate**. If many gateways are tested, total runtime may be long.
* For faster testing, replace `speedtest-cli` with a simple file download benchmark using `curl` or `wget`.
* This script requires **sudo/root privileges** since it modifies routing and NetworkManager settings.

---

**License:** MIT

---

**Recommendation:**
Would you like me to also prepare a **lighter variant of this README** (short, step-by-step usage only) for quick reference, alongside this full one?
