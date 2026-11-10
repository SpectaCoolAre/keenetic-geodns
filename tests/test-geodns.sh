#!/bin/sh
# Тест geodns без роутера: Entware — в песочнице (GEODNS_ROOT), helper,
# nslookup, https-dns-proxy — заглушки. Данные — настоящая проверка
# телефона модулем nfqws2-android-ext (МТС, 09.11), в которой Gemini
# получал геоблок: выбор должен совпасть с модулем (Google — bezmezhau,
# Anthropic — wlrus).
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/.." && pwd)
SB=$(mktemp -d); MOCK="$SB/mock"; RT="$SB/router"; G="$RT/opt/etc/geodns"
mkdir -p "$MOCK" "$G" "$RT/opt/bin"
PATH="$MOCK:$PATH"; export PATH
cp "$REPO"/etc/geodns/* "$G/"
printf 'PROVIDER_DNS="10.0.0.1"\nDEFAULT_DOH=""\n' > "$G/geodns.conf"
printf '#!/bin/sh\necho "Name: x"; echo "Address 1: 1.2.3.4"\n' > "$MOCK/nslookup"
for c in https-dns-proxy killall netstat; do printf '#!/bin/sh\nexit 0\n' > "$MOCK/$c"; done
printf '#!/bin/sh\nexit 1\n' > "$MOCK/pidof"
FIX="$HERE/fixtures/geoscan-mts-0911.tsv"
H="$RT/opt/bin/geodns-helper"
helper_ok() { printf '#!/bin/sh\n[ "$1" = -h ] && { echo "  -geoscan string" >&2; exit 2; }\ngrep -v "^#" "%s"\n' "$FIX" > "$H"; chmod 755 "$H"; }
chmod 755 "$MOCK"/*
geodns() { GEODNS_ROOT="$RT" sh "$REPO/bin/geodns" "$@"; }
L="$RT/opt/var/log/geodns.log"; C="$G/dnsmasq-geo.conf"; PORTS="$RT/opt/var/run/geodns/ports"; S="$RT/opt/var/lib/geodns"
pass=0; fail=0
ok() { if [ "$1" = 0 ]; then pass=$((pass + 1)); echo "   ok   $2"; else fail=$((fail + 1)); echo "   FAIL $2"; fi; }
has() { case "$1" in *"$2"*) ok 0 "$3" ;; *) ok 1 "$3 -- [$2] not found" ;; esac; }
port() { awk -v h="$1" '$1 == h { print $2 }' "$PORTS"; }

echo "== no check yet or every server failed"
printf '#!/bin/sh\n[ "$1" = -h ] && { echo "  -geoscan string" >&2; exit 2; }\nprintf "dns.example\\tfail\\t0\\t0\\t740\\t0\\t-\\tDoH: x509: certificate signed by unknown authority\\n"\necho "boom" >&2\n' > "$H"; chmod 755 "$H"
geodns scan > /dev/null 2>&1
has "$(cat "$L")" "dns.example: DoH: x509: certificate signed by unknown authority" "the log says why no server answered"
has "$(cat "$L")" "geodns-helper: boom" "and what the helper said"
geodns build
has "$(grep '/claude.ai/' "$C")" "127.0.0.1#5053" "without a check the list goes to the fallback server, not to the provider"
has "$(cat "$PORTS")" "dns.bezmezhau.com 5053" "the fallback server gets the pool port"
has "$(geodns status 2>/dev/null)" "запасной" "and the status says it is the fallback"
rm -f "$RT/opt/var/run/geodns/scan.failed"
printf '(\n' > "$H"
geodns scan > /dev/null 2>&1
has "$(cat "$L")" "не запускается на этом роутере" "a helper built for another CPU is named in the log"
rm -f "$RT/opt/var/run/geodns/scan.failed"

echo "== full check: the module's scanner and server choice"
helper_ok
geodns scan > /dev/null 2>&1
[ -s "$S/scan.tsv" ]; ok $? "the check result is kept"
has "$(head -n 1 "$S/scan.tsv")" " v=4" "in the module's format and version"
has "$(grep '/gemini.google.com/' "$C")" "#$(port dns.bezmezhau.com)" "09.11: Gemini goes to the server bypassing the whole group"
has "$(grep '/geminiweb-pa.clients.google.com/' "$C")" "#$(port dns.bezmezhau.com)" "with all of its domains"
has "$(grep '/claude.ai/' "$C")" "#$(port dns.wlrus.cfd)" "Claude — the server of its group"
has "$(cat "$S/groups.pin")" "@google dns.bezmezhau.com" "group servers are pinned"
has "$(geodns routes)" "gemini.google.com	dns.bezmezhau.com" "geodns routes prints routes as the module does"
n=$(grep -c . "$C"); [ "$n" -gt 500 ]; ok $? "the whole list is routed ($n domains)"

rm -rf "$SB"
echo "----------------------------------------"
if [ "$fail" = 0 ]; then echo "PASS  $pass checks"; else echo "FAIL  $fail of $((pass + fail)) checks failed"; exit 1; fi
