# From Zero to DA in ~120s (Active Directory Lab Script)

**Chain:** LLMNR/NBNS ➜ NTLM Relay (LDAP) ➜ Kerberoast  
**Lab Env:** Windows Server 2022 (DC), Windows 10 client, Kali 2025 (VirtualBox NAT Network)

---

## 1. What this script does

- Starts **Responder** to capture NTLMv2 hashes  
- Uses **impacket-ntlmrelayx** to relay to LDAP and create a weak service account  
- Runs **GetUserSPNs.py** to request SPNs and dump TGS hashes  
- Cracks hashes with **hashcat** (rockyou + custom wordlist)

---

## 2. Before you run it (IMPORTANT)

Open `lab_attack.sh` and **change these values** at the top of the file:

```bash
DOMAIN="lab.local"          # Your AD domain
DC_IP="192.168.138.10"      # IP of your Domain Controller / LDAP target
