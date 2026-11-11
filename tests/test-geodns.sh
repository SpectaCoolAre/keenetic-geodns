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
# curl: прокси из curl.down «не открывается» (000), остальные отвечают 200
printf '#!/bin/sh\nip=""; w=""; for a; do [ "$p" = --resolve ] && ip="${a##*:}"; [ "$a" = -w ] && w=1; p="$a"; done\n[ -n "$w" ] || exit 7\nif [ -n "$ip" ] && grep -qx "$ip" "%s/curl.down" 2>/dev/null; then printf 000; exit 28; fi\nprintf 200\n' "$MOCK" > "$MOCK/curl"
FIX="$HERE/fixtures/geoscan-mts-0911.tsv"
H="$RT/opt/bin/geodns-helper"
# -ask <сервер> -samples <домен>: адрес из ask.<сервер>, если есть, иначе ничего
helper_ok() { printf '#!/bin/sh\n[ "$1" = -h ] && { echo "  -geoscan string" >&2; exit 2; }\nif [ "$1" = -ask ]; then [ -f "%s/ask.$2" ] && printf "%%s\\t%%s\\n" "$4" "$(cat "%s/ask.$2")"; exit 0; fi\ngrep -v "^#" "%s"\n' "$MOCK" "$MOCK" "$FIX" > "$H"; chmod 755 "$H"; }
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
has "$(cat "$PORTS")" "dns.zapret.moe 5053" "the fallback server gets the pool port"
has "$(geodns status 2>/dev/null)" "запасной" "and the status says it is the fallback"
rm -f "$RT/opt/var/run/geodns/scan.failed"
printf '(\n' > "$H"
geodns scan > /dev/null 2>&1
has "$(cat "$L")" "не запускается на этом роутере" "a helper built for another CPU is named in the log"
rm -f "$RT/opt/var/run/geodns/scan.failed"

echo "== the server list: «[Service]» lines are names, not servers"
printf '#!/bin/sh\n[ "$1" = -h ] && { echo "  -geoscan string" >&2; exit 2; }\necho "$@" > "%s"\n' "$MOCK/args" > "$H"; chmod 755 "$H"
geodns scan > /dev/null 2>&1
a=$(cat "$MOCK/args" 2>/dev/null)
has "$a" "sync.bezmezhau.com,dns.dagami.ru" "the check gets the addresses of the list"
case "$a" in *"["*) ok 1 "no «[service]» line is taken for a server" ;; *) ok 0 "no «[service]» line is taken for a server" ;; esac
has "$a" "dns.nullsproxy.com" "NullsProxy (Supercell) is checked"
rm -f "$RT/opt/var/run/geodns/scan.failed"

echo "== a server with its own DoH path"
printf '#!/bin/sh\necho "$@" >> "%s"\nexit 0\n' "$MOCK/hdp.args" > "$MOCK/https-dns-proxy"; chmod 755 "$MOCK/https-dns-proxy"
GEODNS_ROOT="$RT" sh -c '. "$1"; proxy_start api.example/sync 5099; proxy_start dns.example 5098' _ "$REPO/bin/geodns" > /dev/null 2>&1
has "$(cat "$MOCK/hdp.args" 2>/dev/null)" "-r https://api.example/sync " "https-dns-proxy gets the server's own path"
has "$(cat "$MOCK/hdp.args" 2>/dev/null)" "-r https://dns.example/dns-query " "and /dns-query for the rest"
printf '#!/bin/sh\nexit 0\n' > "$MOCK/https-dns-proxy"

echo "== after a package upgrade with a new server list the old check is not used"
mkdir -p "$S"; printf '#time=%s boot=x v=4\ndns.comss.one\tok\t50\t29\t722\t0\ttls\n' "$(date +%s)" > "$S/scan.tsv"
GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; scan_due "$SCAN" 14400' _ "$REPO/bin/geodns"; ok $? "a fresh check of other servers is due at once"
{ printf '#time=%s boot=x v=4\n' "$(date +%s)"; GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; servers' _ "$REPO/bin/geodns" | tr ',' '\n' | awk '{ print $1 "\tok\t50\t1\t722\t0\ttls" }'; } > "$S/scan.tsv.new"
sed -i "1s/v=4/v=$(sed -n 's/^SCAN_VER=\([0-9]*\).*/\1/p' "$REPO/bin/geodns")/" "$S/scan.tsv.new"; mv "$S/scan.tsv.new" "$S/scan.tsv"
GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; scan_due "$SCAN" 14400' _ "$REPO/bin/geodns"; [ $? = 1 ]; ok $? "a fresh check of the same servers is not"
rm -f "$S/scan.tsv"

echo "== dnsmasq cannot take port 53"
mkdir -p "$RT/opt/etc/init.d" "$RT/opt/sbin"
printf '#!/bin/sh\necho " Starting dnsmasq...              failed."\n' > "$RT/opt/etc/init.d/S56dnsmasq"
printf '#!/bin/sh\ncase "$*" in *--test*) echo "syntax check OK." ;; *) echo "dnsmasq: failed to create listening socket for port 53: Address in use" >&2; exit 2 ;; esac\n' > "$RT/opt/sbin/dnsmasq"
printf '#!/bin/sh\necho "udp        0      0 0.0.0.0:53              0.0.0.0:*                           537/ndnproxy"\n' > "$MOCK/netstat"
chmod 755 "$RT/opt/etc/init.d/S56dnsmasq" "$RT/opt/sbin/dnsmasq" "$MOCK/netstat"
GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; dnsmasq_restart' _ "$REPO/bin/geodns" >/dev/null 2>&1
has "$(tail -n 2 "$L")" "Address in use" "the log has dnsmasq's own reason, not just «failed»"
has "$(tail -n 2 "$L")" "537/ndnproxy" "and who holds port 53"
has "$(tail -n 2 "$L")" "opkg dns-override" "and what to do about it"
rm -f "$RT/opt/etc/init.d/S56dnsmasq" "$RT/opt/sbin/dnsmasq"; printf '#!/bin/sh\nexit 0\n' > "$MOCK/netstat"

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

echo "== a server whose proxy does not open here is paused"
gx() { GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; shift; "$@"' _ "$REPO/bin/geodns" "$@"; }
wl=$(awk -F'\t' '$1 == "+dns.wlrus.cfd" && $3 + 0 > m { m = $3 + 0; ip = $2 } END { print ip }' "$S/scan.tsv")
echo "$wl" > "$MOCK/curl.down"
gx proxy_check all > /dev/null 2>&1
has "$(cat "$S/down.list" 2>/dev/null)" "dns.wlrus.cfd	$wl" "11.11: wlrus, whose proxy no longer opens, is paused"
has "$(cat "$L")" "на паузе: dns.wlrus.cfd — его прокси $wl отсюда не открывается" "the log says so"
case "$(geodns routes | grep '^claude.ai	')" in *wlrus*) ok 1 "Claude leaves the paused server" ;; *) ok 0 "Claude leaves the paused server" ;; esac
has "$(geodns status 2>/dev/null)" "на паузе: dns.wlrus.cfd" "the status shows the pause"
gx proxy_check use > /dev/null 2>&1
has "$(cat "$S/down.list" 2>/dev/null)" "dns.wlrus.cfd" "before its time it is not checked again"
rm -f "$MOCK/curl.down"
awk -F'\t' 'BEGIN { OFS = "\t" } { $4 = 1; print }' "$S/down.list" > "$S/down.t" && mv "$S/down.t" "$S/down.list"
gx proxy_check use > /dev/null 2>&1
[ ! -s "$S/down.list" ]; ok $? "its time came, the proxy opens — the pause is over"
case "$(cat "$(gx off_eff)")" in *wlrus*) ok 1 "and the server can be chosen again (groups keep their server while it works: no jumping back)" ;; *) ok 0 "and the server can be chosen again (groups keep their server while it works: no jumping back)" ;; esac
cut -f1 "$S/scan.tsv" | awk '!/^[#=+!?]/ && NF { printf "%s\t1.1.1.1\t1\t9999999999\t1\n", $1 }' > "$S/down.list"
[ ! -s "$(gx off_eff)" ]; ok $? "all answering servers paused — the pause does not apply"
rm -f "$S/down.list"

echo "== the proxy checked is the one the server gives for that domain now"
echo 198.51.100.50 > "$MOCK/ask.dns.wlrus.cfd"; echo 198.51.100.50 > "$MOCK/curl.down"
gx proxy_check all > /dev/null 2>&1
has "$(cat "$S/down.list" 2>/dev/null)" "dns.wlrus.cfd	198.51.100.50" "the address asked from the server is probed, not its most frequent one"
rm -f "$MOCK/ask.dns.wlrus.cfd" "$MOCK/curl.down" "$S/down.list"
case "$(gx proxy_targets)" in *" gamea.clashofclans.com"*) ok 1 "game servers are never the probe domain (not HTTPS)" ;; *) ok 0 "game servers are never the probe domain (not HTTPS)" ;; esac

echo "== a frequent check right after the full one"
gx hot_due; [ $? = 1 ]; ok $? "right after the full check the frequent one is not due (it ran a minute later, when servers rate-limit DoH)"
before=$(geodns routes | grep '^claude.ai	')
{ printf '#time=%s boot=x v=4\n' "$(date +%s)"; awk -F'\t' '!/^[#=+!?]/ && NF > 2 { print $1 "\tfail\t0\t0\t10\t0\t-\tDoH: context deadline exceeded" }' "$S/scan.tsv"; } > "$S/scan.tsv.hot"
sed -i 's/^dns.semqka.xyz\tfail.*/dns.semqka.xyz\tok\t200\t5\t10\t0\thttps/' "$S/scan.tsv.hot"
eq_r=$(geodns routes | grep '^claude.ai	')
[ "$before" = "$eq_r" ]; ok $? "servers silent in a frequent check (DoH rate limits) are not dropped: routes do not collapse onto the one that answered"
rm -f "$S/scan.tsv.hot"
mkdir -p "$RT/opt/var/run/geodns/work.lock"; sleep 600 & hold=$!; echo "$hold" > "$RT/opt/var/run/geodns/work.lock/pid"
gx work_lock; [ $? = 1 ]; ok $? "the watchdog skips while a command works (one check or rebuild at a time)"
kill "$hold" 2>/dev/null; wait "$hold" 2>/dev/null
gx work_lock; ok $? "a lock of a finished process is taken over"
rm -rf "$RT/opt/var/run/geodns/work.lock"

echo "== busybox awk (the router's awk) saves the choice"
if command -v busybox >/dev/null 2>&1; then
  mkdir -p "$SB/bb"; ln -sf "$(command -v busybox)" "$SB/bb/awk"
  printf '@openai dns.example.gone\n' > "$S/groups.pin"
  PATH="$SB/bb:$PATH" GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; pin_save' _ "$REPO/bin/geodns" > /dev/null 2>&1
  ! grep -q 'dns.example.gone' "$S/groups.pin"; ok $? "a group server is saved over the old one (busybox awk dropped writes to a file it had read: the group stayed on a paused server)"
  printf 'x.example\tdns.semqka.xyz\t0.000\t9\n' > "$S/scan.tsv.rel"
  PATH="$SB/bb:$PATH" GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; rel_update "$SCAN"' _ "$REPO/bin/geodns" > /dev/null 2>&1
  [ "$(wc -l < "$S/scan.tsv.rel")" -gt 1 ]; ok $? "the reliability history is updated by busybox awk"
fi

echo "== the default DoH and the provider DNS"
GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; DEFAULT_DOH=dns.example; default_keep; default_keep' _ "$REPO/bin/geodns" > /dev/null 2>&1
[ ! -f "$RT/opt/var/run/geodns/default.down" ]; ok $? "two failed checks of the default DoH do not switch DNS (no dnsmasq restart every minute)"
GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; DEFAULT_DOH=dns.example; default_keep' _ "$REPO/bin/geodns" > /dev/null 2>&1
[ -f "$RT/opt/var/run/geodns/default.down" ]; ok $? "three in a row do"
rm -f "$RT/opt/var/run/geodns/default.down" "$RT/opt/var/run/geodns/default.streak"
has "$(GEODNS_ROOT="$RT" sh -c '. "$1" >/dev/null; PROVIDER_DNS=; provider_text' _ "$REPO/bin/geodns" 2>/dev/null)" "запасной DNS 77.88.8.8 — DNS провайдера нет" "no provider DNS anywhere: the status says it is a fallback, not the provider's"

rm -rf "$SB"
echo "----------------------------------------"
if [ "$fail" = 0 ]; then echo "PASS  $pass checks"; else echo "FAIL  $fail of $((pass + fail)) checks failed"; exit 1; fi
