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
- Группа сайтов (Google, OpenAI, Anthropic, xAI) всегда идёт целиком через один сервер, который
  обходит её домены, — у сервиса один адрес выхода. Выбранный сервер держится, пока не подвёл
  две проверки подряд.
- Всё остальное — через DoH (`dns.google` по умолчанию), чтобы провайдер не подменял ответы.

### Подготовка Keenetic/Netcraze

- Прочитайте инструкцию полностью, прежде, чем начать что-то делать!

- Установить entware на маршрутизатор по инструкции [на встроенную память роутера](https://help.keenetic.com/hc/ru/articles/360021888880) или [на USB-накопитель](https://help.keenetic.com/hc/ru/articles/360021214160).

- В разделе "Интернет-фильтры" отключить все сторонние фильтры (NextDNS, SkyDNS, Яндекс DNS и другие).

- Все дальнейшие команды выполняются не в cli роутера, а **в среде entware**. Подключиться в неё можно несколькими способами:
  - Через telnet: в терминале выполнить `telnet 192.168.1.1`, а потом `exec sh`.
  - Или же подключиться напрямую через SSH (логин - `root`, пароль по умолчанию - `keenetic`, порт - 222 или 22). Для этого в терминале написать `ssh 192.168.1.1 -l root -p 222`.

- Если geodns раньше ставился вручную (архивом), удалите его файлы (настройки сохранятся в `/opt/etc/geodns.manual`)
  ```bash
  /opt/etc/init.d/S55geodns stop
  rm -f /opt/bin/geodns /opt/bin/nfqws2-helper /opt/etc/init.d/S55geodns
  mv /opt/etc/geodns /opt/etc/geodns.manual
  sed -i '/geodns/d' /opt/etc/dnsmasq.conf
  ```
  Без последней команды dnsmasq не запустится (его конфиг ссылается на файлы в `/opt/etc/geodns`) — и в сети пропадёт интернет, пока пакет не установлен.

---

### Установка на Keenetic/Netcraze и другие системы с Entware

1. Установите необходимые зависимости
   ```bash
   opkg update
   opkg install ca-certificates wget-ssl
   opkg remove wget-nossl
   ```

2. Установите opkg-репозиторий в систему
   ```bash
   mkdir -p /opt/etc/opkg
   echo "src/gz keenetic-geodns https://spectacoolare.github.io/keenetic-geodns/all" > /opt/etc/opkg/keenetic-geodns.conf
   ```
   Репозиторий универсальный, поддерживаемые архитектуры: `mipsel`, `mips`, `aarch64`, `armv7`.

   <details>
     <summary>Или можете выбрать репозиторий под конкретную архитектуру</summary>

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
   </details>

3. Установите пакет
   ```bash
   opkg update
   opkg install keenetic-geodns
   ```

4. Через минуту-две проверьте, что серверы выбраны
   ```bash
   geodns status
   ```

##### Обновление

```bash
opkg update
opkg upgrade keenetic-geodns
```

##### Удаление

```bash
opkg remove --autoremove keenetic-geodns
```

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
