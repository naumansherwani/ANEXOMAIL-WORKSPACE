#!/usr/bin/env bash
# Q1b-3 audit (READ-ONLY, changes nothing): is the ClamAV gate really closed, and is inbound TLS post-quantum?
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-audit.sh)
# A) clamd limits that decide whether a "clean" verdict can be trusted (AlertEncrypted / AlertExceedsMax default NO = password-protected archives and zip-bombs pass as clean)
# B) the EICAR test string straight to clamd (INSTREAM, nothing is stored, no mail) -> must answer FOUND
# C) Postfix + OpenSSL versions and a local STARTTLS handshake offering X25519MLKEM768 (needs OpenSSL >= 3.5 and Postfix >= 3.10)
set -uo pipefail
echo "== A) clamd settings (clamd is shared with awam: we only READ it)"
CF="$(ls /etc/clamav/clamd.conf /etc/clamd.d/scan.conf 2>/dev/null | head -1)"; echo "  file: ${CF:-not found}"
for k in AlertEncrypted AlertEncryptedArchive AlertEncryptedDoc AlertExceedsMax StreamMaxLength MaxScanSize MaxFileSize MaxRecursion ScanMail ScanArchive MaxFiles; do v="$( [ -n "$CF" ] && grep -E "^$k[[:space:]]" "$CF" | tail -1)"; printf '  %-22s %s\n' "$k" "${v:-(not set = built-in default)}"; done
echo "== B) EICAR through clamd INSTREAM (standard antivirus test string, harmless)"
E1='X5O!P%@AP[4\PZX54(P^)7CC)7}$'; E2='EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'; EICAR="$E1$E2"
python3 - "$EICAR" <<'PY' 2>&1 | sed 's/^/  /'
import socket,struct,sys
d=sys.argv[1].encode()
s=socket.create_connection(("127.0.0.1",3310),5); s.sendall(b"zINSTREAM\0"+struct.pack(">I",len(d))+d+struct.pack(">I",0)); print("clamd says:", s.recv(200).rstrip(b"\0").decode())
PY
echo "== C) inbound TLS"
echo "  postfix: $(postconf -h mail_version 2>/dev/null)   openssl: $(openssl version 2>/dev/null)"
for k in smtpd_tls_security_level smtpd_tls_protocols smtpd_tls_mandatory_protocols tls_eecdh_auto_curves tls_config_file tls_config_name; do printf '  %-30s %s\n' "$k" "$(postconf -h "$k" 2>/dev/null)"; done
echo "  local STARTTLS handshake offering X25519MLKEM768 (no mail is sent):"
timeout 8 openssl s_client -connect 127.0.0.1:25 -starttls smtp -groups X25519MLKEM768 </dev/null 2>&1 | grep -E "Protocol|Negotiated TLS1.3 group|Server Temp Key|Cipher is|error|alert" | head -6 | sed 's/^/    /'
echo "== READ: B must say FOUND. A: AlertEncrypted/AlertExceedsMax 'no' = the founder intake guards encrypted ZIP/PDF/Office itself (fmail_in.rs opaque_attachment); encrypted 7z/RAR stays a gap until clamd AlertEncrypted yes (his haan, awam shares clamd)."
