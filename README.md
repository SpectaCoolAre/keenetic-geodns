# keenetic-geodns

[![GitHub Release](https://img.shields.io/github/release/SpectaCoolAre/keenetic-geodns?style=flat&color=green)](https://github.com/SpectaCoolAre/keenetic-geodns/releases)
[![License](https://img.shields.io/github/license/SpectaCoolAre/keenetic-geodns.svg?style=flat&color=orange)](LICENSE)

Пакет для обхода геоблока через DNS на маршрутизаторах Keenetic/Netcraze с Entware.

Сервисы с геоблоком (Gemini, ChatGPT, Claude, Spotify, игры Supercell и сотни других
из списка) получают адреса прокси от DNS-серверов обхода (bezmezhau, malw, zapret.moe и
другие), всё остальное — обычный DNS провайдера или честный DoH. Устройствам в сети
ничего настраивать не нужно.

Выбор серверов — тот же, что в умном DNS модуля [nfqws2-android-ext](https://github.com/SpectaCoolAre/nfqws2-android-ext),
тем же кодом: роутер и телефон выбирают одинаково, и у всех устройств дома один адрес
выхода для каждого сервиса.

> [!IMPORTANT]
> Данный материал подготовлен в научно-технических целях.
> Использование предоставленных материалов в целях отличных от ознакомления может являться нарушением действующего законодательства.
> Автор не несет ответственности за неправомерное использование данного материала.

### Что это?

- `dnsmasq` на роутере отправляет домены из списка геоблока к серверам обхода через `https-dns-proxy` (DoH).
- Каждые 4 часа серверы проверяются по всему списку, каждые полчаса — основные сервисы и по факту
  (настоящий ли сертификат сайта по адресу прокси, не отвечает ли сайт «unusual traffic»).
- Группа сайтов (Google, OpenAI, Anthropic, xAI, игры Supercell) всегда идёт целиком через один сервер, который
  обходит её домены, — у сервиса один адрес выхода. Выбранный сервер держится, пока не подвёл
  две проверки подряд.
- Всё остальное — через DoH (`dns.google` по умолчанию), чтобы провайдер не подменял ответы.

### Подготовка Keenetic/Netcraze

Прочитайте инструкцию полностью, прежде чем что-то делать. geodns становится **единственным DNS
в домашней сети**: любой другой DNS на роутере или устройствах либо отнимет у него порт 53, либо
пойдёт в обход него — и геоблок останется.

#### Где выполнять команды

- **CLI роутера** — команды KeeneticOS (`opkg dns-override`, `system configuration save`):
  веб-интерфейс `http://192.168.1.1/a` или `telnet 192.168.1.1` (логин и пароль администратора роутера).
- **Entware** — команды `opkg install`, `geodns …`: `ssh root@192.168.1.1 -p 222` (пароль по
  умолчанию `keenetic`) или в telnet после входа — `exec sh`.

#### 1. Entware

Установите Entware [на встроенную память](https://help.keenetic.com/hc/ru/articles/360021888880)
или [на USB-накопитель](https://help.keenetic.com/hc/ru/articles/360021214160). Во встроенной
памяти места мало — ставьте пакет своей архитектуры (шаг 2 установки), не универсальный.

#### 2. DNS-настройки роутера — вычистить

В веб-интерфейсе роутера:

- **Интернет-фильтры** (Сетевые правила → Интернет-фильтры / Интернет-безопасность): выключите все
  фильтры — NextDNS, AdGuard DNS, SkyDNS, Яндекс DNS, Cloudflare и другие.
- **Настройка DNS** (там же): удалите все добавленные серверы DNS-over-TLS и DNS-over-HTTPS и
  статические DNS-серверы; выключите **публичные DNS-резолверы** (public DNS resolvers). geodns берёт
  DNS провайдера из списка DNS роутера: с публичными резолверами или своими серверами в нём он
  примет за «DNS провайдера» не тот сервер.
- **Интернет → ваше подключение → IP и DNS**: DNS — от провайдера (автоматически), без «Игнорировать
  DNS провайдера» и без своих адресов. Если провайдер DNS не выдаёт или подменяет ответы — впишите
  нужный в `PROVIDER_DNS` в `/opt/etc/geodns/geodns.conf` после установки.
- **Домашняя сеть → DHCP**: поле «DNS-сервер» для клиентов — пустое (клиенты получают адрес самого
  роутера). Свой адрес там (например, 8.8.8.8) уводит устройства мимо geodns.

#### 3. Другие DNS в Entware — убрать

Порт 53 должен быть свободен для dnsmasq. Если в Entware стоят AdGuard Home, stubby,
dnscrypt-proxy, unbound, другая сборка dnsmasq или прежний geodns — остановите и удалите их.
Что сейчас слушает порт 53:
```bash
netstat -lnup | grep ':53 '
```
До установки там может быть только `ndnproxy` (встроенный DNS Keenetic) — это нормально.

Если geodns раньше ставился вручную (архивом), удалите его файлы (настройки сохранятся в
`/opt/etc/geodns.manual`):
```bash
/opt/etc/init.d/S55geodns stop
rm -f /opt/bin/geodns /opt/bin/nfqws2-helper /opt/etc/init.d/S55geodns
mv /opt/etc/geodns /opt/etc/geodns.manual
rm -rf /opt/var/lib/geodns
sed -i '/geodns/d' /opt/etc/dnsmasq.conf
```
Без последней команды dnsmasq не запустится (его конфиг ссылается на файлы в `/opt/etc/geodns`).

#### 4. Устройства

На телефонах и компьютерах выключите собственный DNS, иначе они ходят мимо роутера:
- Android: Настройки → Сеть → **Частный DNS** → «Выкл» или «Автоматически»;
- браузеры: **Безопасный DNS** / DNS через HTTPS (Chrome, Edge, Яндекс Браузер, Firefox) — выключить;
- VPN и приложения-«DNS-чейнджеры» (1.1.1.1, Intra, AdGuard) — выключить в домашней сети.

---

### Установка на Keenetic/Netcraze и другие системы с Entware

1. Установите необходимые зависимости
   ```bash
   opkg update
   opkg install ca-certificates wget-ssl
   opkg remove wget-nossl
   ```

2. Установите opkg-репозиторий под архитектуру роутера (определится сама по opkg.conf)
   ```bash
   mkdir -p /opt/etc/opkg
   A=$(grep -oE 'mipsel|mips|aarch64|armv7' /opt/etc/opkg.conf | head -n 1)
   echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/${A:-all}" > /opt/etc/opkg/keenetic-geodns.conf
   echo "репозиторий: ${A:-all}"
   ```
   Пакет своей архитектуры — ≈2,5 МБ. Если архитектура не определилась (`all`), ставится
   универсальный пакет: помощник под все архитектуры, ≈9 МБ во время установки — во встроенной
   памяти роутера может не хватить места.

   <details>
     <summary>Или выберите репозиторий вручную</summary>

     - `mips-3.4` <sub><sup>Keenetic Giga SE (KN-2410), Ultra SE (KN-2510), DSL (KN-2010), Launcher DSL (KN-2012), Duo (KN-2110), Skipper DSL (KN-2112), Hopper DSL (KN-3610); Zyxel Keenetic DSL, LTE, VOX</sup></sub>
       ```bash
       mkdir -p /opt/etc/opkg
       echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/mips" > /opt/etc/opkg/keenetic-geodns.conf
       ```

     - `mipsel-3.4` <sub><sup>Keenetic 4G (KN-1212), Omni (KN-1410), Extra (KN-1710/1711/1713), Giga (KN-1010/1011), Ultra (KN-1810), Viva (KN-1910/1912/1913), Hero 4G (KN-2310/2311), Giant (KN-2610), Skipper 4G (KN-2910), Hopper (KN-3810); Zyxel Keenetic II / III, Extra, Extra II, Giga II / III, Omni, Omni II, Viva, Ultra, Ultra II</sup></sub>
       ```bash
       mkdir -p /opt/etc/opkg
       echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/mipsel" > /opt/etc/opkg/keenetic-geodns.conf
       ```

     - `aarch64-3.10` <sub><sup>Keenetic Peak (KN-2710), Ultra (KN-1811), Hopper (KN-3811), Hopper SE (KN-3812), Giga (KN-1012)</sup></sub>
       ```bash
       mkdir -p /opt/etc/opkg
       echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/aarch64" > /opt/etc/opkg/keenetic-geodns.conf
       ```
     - `armv7-3.2` <sub><sup>роутеры и устройства с Entware armv7</sup></sub>
       ```bash
       mkdir -p /opt/etc/opkg
       echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/armv7" > /opt/etc/opkg/keenetic-geodns.conf
       ```

     - `all` — универсальный (≈9 МБ при установке)
       ```bash
       mkdir -p /opt/etc/opkg
       echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/all" > /opt/etc/opkg/keenetic-geodns.conf
       ```
   </details>

3. Установите пакет
   ```bash
   opkg update
   opkg install keenetic-geodns
   ```

4. Отдайте порт 53 dnsmasq — в **CLI роутера**:
   ```
   opkg dns-override
   system configuration save
   ```
   Без этого порт 53 остаётся у встроенного DNS Keenetic: dnsmasq не запустится (`geodns status` —
   «dnsmasq: НЕ ЗАПУЩЕН», в журнале — «порт 53 занят»). Затем в Entware:
   ```bash
   /opt/etc/init.d/S55geodns restart
   ```

5. Через минуту-две проверьте
   ```bash
   netstat -lnup | grep ':53 '      # на порту 53 — dnsmasq
   geodns status                    # dnsmasq: работает; серверы обхода выбраны
   nslookup ya.ru 192.168.1.1       # обычный сайт отвечает
   geodns test claude.ai            # сайт из списка идёт к серверу обхода
   ```

#### Если в статусе «запасной DNS»

`geodns status` пишет «запасной DNS 77.88.8.8 — DNS провайдера нет…», когда у самого Keenetic нет
ни одного DNS-сервера (в CLI роутера `show ip name-server` отвечает «server list is empty»).
Включите получение DNS от провайдера в настройках подключения или впишите нужный DNS в
`PROVIDER_DNS` в `/opt/etc/geodns/geodns.conf` и перезапустите: `/opt/etc/init.d/S55geodns restart`.

#### Сервер на паузе

Если прокси сервера обхода из вашей сети не открывается (провайдер заблокировал его адрес), geodns
ставит сервер на паузу — сайты его групп уходят на другие серверы — и сам перепроверяет его через
30 минут, час и дальше раз в 2 часа. В `geodns status` такой сервер виден как «на паузе».

#### Если пропал интернет

DNS в сети отвечает только dnsmasq. Если он не запущен, а `opkg dns-override` включён, порт 53
не слушает никто, и сайты не открываются (ping по IP при этом работает). Смотрите:
```bash
geodns status
tail -n 20 /opt/var/log/geodns.log
```
Быстро вернуть DNS встроенному DNS Keenetic — в CLI роутера:
```
no opkg dns-override
system configuration save
```
и перезагрузите роутер.

##### Обновление

```bash
opkg update
opkg upgrade keenetic-geodns
```

##### Удаление

Сначала верните DNS встроенному DNS Keenetic — в CLI роутера:
```
no opkg dns-override
system configuration save
```
Затем в Entware:
```bash
opkg remove --autoremove keenetic-geodns
sed -i '/geodns/d' /opt/etc/dnsmasq.conf
rm -rf /opt/var/lib/geodns /opt/var/run/geodns
```
и перезагрузите роутер. В обратном порядке на время удаления в сети пропадёт DNS: dnsmasq уже
удалён, а порт 53 ещё не вернулся Keenetic.

##### Информация об установленной версии

```bash
opkg info keenetic-geodns
```

---

### Команды

```bash
geodns status          # что работает, какие серверы выбраны, последние записи журнала
geodns scan            # полная проверка серверов сейчас
geodns check           # частая проверка основных сервисов сейчас
geodns routes          # куда идёт каждый домен (в том же виде, что в модуле)
geodns test claude.ai  # куда идёт домен, ответ роутера и провайдера
geodns update          # скачать свежий список геоблока (itdoginfo)
geodns log             # журнал
```

### Настройки

Конфиг — `/opt/etc/geodns/geodns.conf`, после правки: `/opt/etc/init.d/S55geodns restart`.

- `servers.list` — серверы обхода;
- `groups.list` — группы сайтов, у которых один сервер на все домены;
- `prefer.list` — предпочтительные серверы групп;
- `off.list` — серверы, отключённые вручную (по одному в строке);
- `own.list` — свои домены в дополнение к списку геоблока.

`servers.list`, `groups.list`, `prefer.list` и `geo-*.awk` — копии из модуля nfqws2-android-ext;
при обновлении пакета заменяются.

> [!NOTE]
> Журнал — `/opt/var/log/geodns.log`. Итоги проверок — `/opt/var/lib/geodns`.
