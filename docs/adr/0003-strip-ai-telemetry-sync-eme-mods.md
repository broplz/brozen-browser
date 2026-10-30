# ADR-0003 · Вырезание: AI, телеметрия, Sync, EME, Zen Mods — и панель переключателей BB

## Статус

Proposed — черновик 30.10.2026, решения владельца по Q1–Q3 внесены (раздел «Решения владельца»). После шага 0 (инвентаризация) и подтверждения механизмов статус меняется на Accepted, файл уходит в `docs/adr/0003-strip-ai-telemetry-sync-eme-mods.md`, декомпозиция — через teamlead в `tasks/`.

- Область: репо `broplz/brozen-browser`, база Zen 1.23.4b / Firefox 158.0.1, слой по ADR-0002, эпик `e1-strip`.
- Основание: `configs/common/mozconfig` и `configs/macos/mozconfig` Zen на теге 1.23.4b (прочитаны), документация Firefox по telemetry defines и `--enable-eme`, Bugzilla 1434706 (`identity.fxaccounts.enabled`), SUMO-тред по `browser.ml.*`, структура `patches/` (в т.ч. `pref-pane/`) и `settings/` LibreWolf. Что не удалось проверить из чата — помечено и вынесено в задачу инвентаризации (Решение 3, шаг 0).
- Связанные ADR: ADR-0002 (место в слое: `configs/bb/mozconfig`, `prefs/bb/strip.yaml`, `src/bb/strip/`), ADR-0004 (prefs безопасности и скорости — не здесь), E0 (бренд, апдейтер — задачи 0021–0023).

Теги утверждений: **[verified]** — прочитано в исходнике или официальной документации; **[не нашёл подтверждения]** — предположение, проверяется шагом 0; **[my judgment]** — оценка автора.

## Контекст и проблема

Хотелка из скоупа v1: BB не содержит AI-функций Firefox, не шлёт телеметрию, не предлагает Sync, не тянет Widevine, не показывает Zen Mods. Решение владельца (30.10.2026) уточняет принцип: **ничего не вырезается намертво — у каждого пункта есть выключатель, и пользователь сам решает, что включить**; переключатели собраны в отдельной вкладке настроек BB. Вопрос ADR — каким механизмом каждое выключается по умолчанию, как пользователь это включает обратно, и как это переживает еженедельные ребейзы.

Что уже сделано за нас:

- Zen собирается с `MOZ_DATA_REPORTING=`, `MOZ_SERVICES_HEALTHREPORT=`, `MOZ_TELEMETRY_REPORTING=` (и `mk_add_options`, и `ac_add_options`) в `configs/common/mozconfig`; в release-режиме ещё `--disable-crashreporter` **[verified]**. Телеметрия на уровне сборки уже выключена.
- Zen не кладёт API-ключи Mozilla/Google в сборку без файлов `~/.zen-keys/*.dat` **[verified]** — у нас их нет.
- Апдейтер отключён задачей 0022 (E0).

Что Zen **включает** и BB выключает по умолчанию:

- `configs/macos/mozconfig`: `ac_add_options --enable-eme=widevine` **[verified]**.
- Zen Mods — каталог `src/zen/mods/` **[verified, из tree в ADR-0002]**; как подключается (pref, `ZenPreloadedScripts.js`, `ZenComponents.manifest`) — **[не нашёл подтверждения]**.
- Zen Sync — каталог `src/zen/sync/` **[verified]**; надстройка над Firefox Sync/FxA, что именно делает — **[не нашёл подтверждения]**.
- AI Firefox (`browser.ml.*`): Zen дефолтов не меняет **[не нашёл подтверждения — проверить `prefs/zen/*.yaml` grep'ом]**.

Что остаётся включённым, но получает выключатель: Zen Boosts (`src/zen/boosts/`) **[verified каталог]**.

Ограничения из ADR-0002: прямая правка файлов Zen — только хук ≤ ~10 строк с маркером `// BB(e1)` и записью в `layer.yaml`; удаление каталогов Zen патчем — самая дорогая форма; каждый компонент выключается pref'ом до стокового Zen (F2). Для этого ADR F2 работает в обе стороны: `bb.strip.<x>=false` возвращает стоковый Zen.

Порядок сборки mozconfig в surfer: `configs/common/mozconfig` → `configs/<os>/mozconfig` → корневой `mozconfig` **[verified, ADR-0002 п.5]**. Хук BB стоит в `configs/common/mozconfig` — флаги BB читаются **до** `--enable-eme=widevine`.

## Требования

- S1. Каждый пункт имеет один механизм, одну запись в `layer.yaml` или `prefs/bb/strip.yaml`, один автоматический тест.
- S2. Ничего не удаляется из дерева Zen патчем, если то же достигается pref'ом или хуком в одну строку.
- S3. **Без замков.** Ни один pref этого ADR не блокируется (`lockPref`, `policies.json`): дефолт BB — выключено, решение о включении — за пользователем. Исключение — телеметрия и data reporting: они выключены на уровне сборки Zen, включать их нечем, и переключатель для них не делается.
- S4. Проверка — скриптом, без человека: `scripts/bb/strip-check.sh` сверяет build-defines и сгенерированные prefs с `strip.yaml`, падает на первом расхождении.
- S5. Не ломаем то, что оставляем: Safe Browsing, Remote Settings (сертификаты, блок-листы), OpenH264 GMP, Boosts.
- S6. **Все переключатели в одном месте**: категория «BROzen» в `about:preferences` с тумблерами для каждого пункта (EME, AI, Sync, Mods, Boosts), привязанными к `bb.strip.*`. Переключение не требует пересборки; где Firefox требует перезапуск (EME, FxA) — панель об этом пишет.

## Решение 1 — три уровня и правило выбора

| Уровень | Что это | Когда применять | Цена при ребейзе |
|---|---|---|---|
| L1 build | `ac_add_options --disable-*`, `MOZ_*=` в `configs/bb/mozconfig*` | Код не должен попасть в бинарь (крэш-репортер). **Несовместимо с S6** — пользователь включить не сможет, поэтому только для телеметрии/крэшей | Ноль: файл наш |
| L2 prefs | `prefs/bb/strip.yaml` → `zen.js`/`zen-static-prefs.inc` | Фича управляется pref'ом и Firefox сам прячет UI при `false` | Ноль; риск — переименование pref'а в новом Firefox, ловит strip-check |
| L3 hook | Хук ≤10 строк в файле Zen за pref'ом `bb.strip.<x>`, или CSS `display:none` в `src/bb/strip/strip.css` | Компонент Zen без собственного pref'а | Низкая: merge одной строки, `rerere` |
| L4 patch | `src/bb/patches/e1-strip/<имя>/` с README | Только если L1–L3 невозможны | Высокая; каждый случай — одобрение владельца |

Правило: сначала L2, потом L3, L4 — исключение; L1 — только там, где переключатель не нужен по S3. Все L2 — в одном `prefs/bb/strip.yaml`, секции по компонентам; все L3 — в `layer.yaml: edits` с `epic: e1-strip`. Пользовательские переключатели — namespace `bb.strip.*`: `BBStartup.mjs`/панель настроек транслируют их в конкретные pref'ы Firefox/Zen (`bb.strip.eme=true` → `media.eme.enabled=false` и т.д.), чтобы панель не зависела от имён внутренних pref'ов, которые Mozilla переименовывает.

## Решение 2 — по компонентам

### 2.1 Телеметрия и data reporting — без переключателя

| Вариант | Суть | Вердикт |
|---|---|---|
| A. Ничего, Zen уже выключил | полагаться на `MOZ_*=` Zen | Недостаточно: не проверяется, `datareporting.*` остаются дефолтными |
| B. Дублировать флаги в `configs/bb/mozconfig` | те же `MOZ_*=` | Отвергнут: ADR-0002 запрещает дублировать флаги Zen |
| C. **Prefs-подстраховка + strip-check** | L2: `datareporting.policy.dataSubmissionEnabled=false` (главный выключатель отправки **[verified, Firefox docs]**), `datareporting.healthreport.uploadEnabled=false`, `toolkit.telemetry.unified=false`, `toolkit.telemetry.enabled=false`, `toolkit.telemetry.server=""`, `toolkit.telemetry.archive.enabled=false`, `toolkit.telemetry.*Ping.enabled=false`, `browser.ping-centre.telemetry=false`, `app.shield.optoutstudies.enabled=false`, `app.normandy.enabled=false`, `app.normandy.api_url=""`, `browser.discovery.enabled=false`, `dom.private-attribution.submission.enabled=false`; strip-check проверяет и build-defines Zen, и эти pref'ы | **Рекомендован** |

Крэш-репортер: в dev-сборке (`ZEN_RELEASE` не задан) `--disable-crashreporter` Zen не действует **[verified]**. L1 в `configs/bb/mozconfig`: `ac_add_options --disable-crashreporter` безусловно — расширение на dev-режим, не дубль. Проверка: `MOZ_CRASHREPORTER` отсутствует в `config.status`.

### 2.2 AI (Firefox `browser.ml.*`) — переключатель `bb.strip.ai`, по умолчанию выключен

Build-флага для `browser.ml` в `moz.configure` нет **[не нашёл подтверждения — шаг 0]**. Механизм — L2.

Pref'ы (SUMO-тред Mozilla и блоги 2025–2026 **[verified как список; актуальность на Firefox 158 — шаг 0]**): `browser.ml.enable=false` (мастер), `browser.ml.chat.enabled=false`, `browser.ml.chat.sidebar=false`, `browser.ml.chat.shortcuts=false`, `browser.ml.chat.shortcuts.custom=false`, `browser.ml.chat.page=false`, `browser.ml.chat.page.footerBadge=false`, `browser.ml.chat.page.menuBadge=false`, `browser.ml.chat.menu=false`, `browser.ml.chat.hideFromLabs=true`, `browser.ml.chat.hideLabsShortcuts=true`, `browser.ml.linkPreview.enabled=false`, `browser.ml.pageAssist.enabled=false`, `browser.tabs.groups.smart.enabled=false`, `browser.tabs.groups.smart.userEnabled=false`, `extensions.ml.enabled=false`, `browser.search.visualSearch.featureGate=false`.

Без замков (S3). Риск: Mozilla включала `browser.ml.*` поэтапно через обновления **[verified, SUMO]** — после ребейза новый pref может появиться с `true`. Митигация — не замок, а strip-check: он сравнивает список `browser.ml.*` в `engine/browser/app/profile/firefox.js` нового Firefox с `strip.yaml` и падает на незнакомом имени; задача на обновление `strip.yaml` ставится агентом.

UI-остатки («Ask AI» в меню, шорткаты в Labs) при `browser.ml.enable=false` Firefox прячет сам **[my judgment по SUMO; проверяется smoke]**; иначе — CSS в `strip.css`.

### 2.3 Sync и Firefox Accounts — переключатель `bb.strip.sync`, по умолчанию выключен

L2: `identity.fxaccounts.enabled=false` — один pref прячет панель Sync и отключает FxA/Sync **[verified, Bugzilla 1434706; test browser_sync_disabled.js]**. Требует перезапуска **[verified, обсуждение в баге]** — панель BB предупреждает. `auth.uri`/`tokenserver.uri` не обнуляем: пользователь должен мочь включить Sync одним тумблером.

Zen Sync (`src/zen/sync/`): если это Sync-engines поверх FxA — при выключенном FxA мёртв, трогать не надо; если рисует UI или грузится безусловно — L3-хук за тем же `bb.strip.sync`. Решается шагом 0 **[не нашёл подтверждения]**.

Не путать с `zen.window-sync.enabled` (синхронизация вкладок между окнами) — не Sync, не трогаем.

### 2.4 EME / Widevine — переключатель `bb.strip.eme`, по умолчанию выключен

Решение владельца (Q1): выключено по умолчанию, включается пользователем. Это исключает L1 `--disable-eme` и правку `--enable-eme=widevine` у Zen.

L2: `media.eme.enabled=false`, `media.gmp-widevinecdm.enabled=false`, `media.gmp-widevinecdm.visible=false`, `browser.eme.ui.enabled=false` **[verified, tor-browser#42501: именно эти pref'ы выставляет `--enable-eme`]**. При `visible=false` в настройках нет пункта «Play DRM content» — пользователь включает через тумблер BB, который возвращает все четыре в `true`; CDM скачается при первом воспроизведении (штатное поведение Firefox). Smoke: Netflix не играет по умолчанию; после тумблера и перезапуска — играет.

### 2.5 Zen Mods — переключатель `bb.strip.mods`, по умолчанию выключен

Шаг 0 устанавливает: есть ли pref вроде `zen.mods.enabled` и как `src/zen/mods/` попадает в `ZenPreloadedScripts.js`/`ZenComponents.manifest` **[не нашёл подтверждения]**. Далее по правилу Решения 1:

1. Pref есть → L2 + CSS для входа в Settings, если Zen его не прячет сам.
2. Pref'а нет → L3: хук в `ZenPreloadedScripts.js` — пропуск модуля `mods` за `bb.strip.mods`; запись `layer.yaml: edits`. ≤10 строк, если скрипты перечислены массивом **[my judgment]**. Запасной путь (R2) — подмена инстанса `gZenMods*` из `BBStartup.mjs` (ADR-0002, Решение 2 п.2).
3. Удаление каталога (L4) — не делаем.

Остатки: ссылка на Mods store, `zen.mods.*` в about:preferences — smoke-пункт; при необходимости `strip.css`.

### 2.6 Zen Boosts — переключатель `bb.strip.boosts`, по умолчанию **включён** (Boosts работают)

Решение владельца (Q3): Boosts остаются, но с выключателем. Механизм тот же, что для Mods (шаг 0 ищет pref `zen.boosts.*`; иначе L3-хук за `bb.strip.boosts`). Отличие только в дефолте.

### 2.7 Панель переключателей — категория «BROzen» в `about:preferences`

| Вариант | Суть | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| A. Своя категория в `about:preferences` | как LibreWolf (`patches/pref-pane/`, категория с иконкой **[verified: каталог и `category-librewolf.svg` в репо]**) и как сам Zen делает для своих страниц настроек **[не нашёл подтверждения механизма — шаг 0: `grep -rn "zen-settings\|category-zen" src/zen src/browser`]** | Родное место, привычно пользователю Firefox/Zen | Если Zen вшивает свои страницы патчем на `preferences.xhtml` — наш вход туда либо хук в его файле (класс 2/3), либо отдельный патч | **Рекомендован**, механизм — по шагу 0 |
| B. Отдельная `about:brozen` | своя страница с тумблерами | Ноль пересечений с Zen | Пользователь не найдёт; две точки настроек | Запасной |
| C. Только about:config | ничего не делать | Ноль работы | Не соответствует решению владельца | Отвергнут |

Содержимое панели v1: пять тумблеров (EME, AI, Sync, Mods, Boosts) с одной строкой пояснения и пометкой «нужен перезапуск» где требуется; кнопка «Перезапустить». Логика — `src/bb/strip/BBStrip.mjs`: слушает `bb.strip.*`, транслирует в pref'ы Firefox/Zen из таблицы выше, при старте приводит внутренние pref'ы в соответствие с `bb.strip.*` (чтобы обновление Firefox, вернувшее `browser.ml.enable=true`, не пережило следующий запуск BB). Панель — отдельная задача после шага 0; этот ADR фиксирует контракт: имена `bb.strip.*`, дефолты, таблица трансляции.

### 2.8 Что сознательно не трогаем

Safe Browsing, Remote Settings, OpenH264 GMP, `app.update.*` (E0/0022), Pocket (удалён из Firefox в 2025; остатки поймает strip-check как «неизвестные pref'ы»), `zen.window-sync.*`. Prefs приватности сверх вырезания — ADR-0004.

## Решение 3 — проверка

Шаг 0, **инвентаризация** (первая задача декомпозиции, роль developer, без сборки, только чтение; результат — `docs/reports/strip-inventory.md`):

```
grep -rn "browser.ml\|fxaccounts\|telemetry\|datareporting\|eme\|widevine\|mods\|boosts" prefs/zen prefs/firefox prefs/fastfox prefs/privatefox
grep -n "mods\|boosts\|sync" src/zen/common/ZenPreloadedScripts.js src/zen/ZenComponents.manifest src/zen/moz.build
ls src/zen/mods src/zen/boosts src/zen/sync
grep -rn "zen-settings\|category-zen\|preferences.xhtml" src/zen src/browser | head -30
grep -rn "browser.ml" engine/browser/app/profile/firefox.js | head
```

Закрывает все **[не нашёл подтверждения]** и определяет для 2.2, 2.3, 2.5, 2.6, 2.7 уровень и механизм. Без него задачи на изменения не ставятся.

`scripts/bb/strip-check.sh` (S4), три части:

- build: `engine/obj-*/config.status` (или `mozinfo.json`) — отсутствие `MOZ_TELEMETRY_REPORTING`, `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `MOZ_CRASHREPORTER`.
- prefs: сгенерированные `engine/browser/app/profile/zen.js` и `zen-static-prefs.inc` против `prefs/bb/strip.yaml` построчно.
- drift: все `browser.ml.*`, `identity.fxaccounts.*`, `media.eme.*`, `media.gmp-widevinecdm.*` из `firefox.js` нового engine должны быть известны `strip.yaml` или явному allow-листу; незнакомое имя — код 1.

Вызывается из `smoke.sh` первым шагом и из QA-роли после сборки. Smoke-чеклист (`scripts/bb/smoke.d/e1.txt`): в настройках есть категория BROzen с пятью тумблерами; Sync-панели нет; «Ask AI» нет в меню и Labs; Mods нет в настройках, Boosts есть; Netflix не играет; включить EME тумблером → перезапуск → играет; выключить обратно; Browser Console без ошибок `ml`/`fxaccounts`/`mods`/`BBStrip` первые 30 с.

## Последствия

Плюсы: всё переключаемое — L2/L3, ноль патчей к Firefox при ожидаемом исходе шага 0; один файл `strip.yaml` + один модуль `BBStrip.mjs` как контракт; strip-check делает список исполняемым; пользователь получает одно место для решений, а не about:config.

Минусы и цена: панель настроек — UI-работа и вход в `about:preferences`, который у Zen может оказаться патчем (R1); L3-хуки для Mods/Boosts — merge-строка на каждом теге, где Zen меняет список скриптов; без замков дефолт `browser.ml.*` после ребейза может «уехать» до первого запуска BB — `BBStrip.mjs` приводит его в порядок на старте, strip-check ловит на сборке. Переименования pref'ов Firefox — постоянный фон, закрыт drift-проверкой.

## Риски и план проверки

| # | Риск | Как проверяем | Митигация |
|---|---|---|---|
| R1 | Вход в `about:preferences` у Zen — патч на `preferences.xhtml`, наш хук туда дорог | Шаг 0 | Хук в патче Zen по ADR-0002 Решение 2 п.4 или вариант B (`about:brozen`) |
| R2 | Mods/Boosts без pref'а и без явного списка скриптов → хук >10 строк | Шаг 0 | Подмена инстансов из `BBStartup.mjs` |
| R3 | `browser.ml.*` переименованы в Firefox 159+ | drift-часть strip-check после первого ребейза | Задача на `strip.yaml` + таблицу трансляции |
| R4 | Zen Sync грузит UI независимо от FxA | Шаг 0 + smoke | L3-хук за `bb.strip.sync` |
| R5 | Дубль имени pref'а в `prefs/zen` и `prefs/bb` → недетерминированный результат ffprefs | strip-check ищет дубли | Правило ADR-0002: дефолт Zen меняем правкой его строки |
| R6 | Включение EME тумблером не подтягивает CDM без `visible=true` в момент старта | Smoke: тумблер → перезапуск → Netflix | `BBStrip.mjs` ставит все четыре pref'а и требует перезапуск |

План: (1) шаг 0 → отчёт; (2) `strip.yaml` + `configs/bb/mozconfig` (crashreporter) + `strip-check.sh` — одна задача, QA с полной сборкой; (3) `BBStrip.mjs` + хуки Mods/Boosts по итогу шага 0; (4) панель «BROzen» в настройках — по итогу R1; (5) `smoke.d/e1.txt`; (6) ADR → Accepted после зелёного strip-check и smoke на первом ребейзе.

## Решения владельца (30.10.2026)

- **Q1. EME** — выключен по умолчанию, пользователь включает сам. Из сборки не вырезаем.
- **Q2. Замки** — не ставить. Пользователь сам решает, что включить; все переключатели — в отдельной вкладке настроек (→ S3, S6, 2.7).
- **Q3. Boosts** — остаются включёнными, с выключателем. Вырезаем по умолчанию только Mods.

## Вне scope

ADR-0004 (приватность/скорость: RFP, cookies, WebRTC, DoH, HTTPS-only, Betterfox-наследие Zen; `policies.json`, если когда-нибудь понадобится), uBlock Origin (E10), Mozilla-брендинг в urlbar/about-страницах (E0), Windows/Linux.

## Ссылки

- Zen 1.23.4b: `configs/common/mozconfig` (`MOZ_DATA_REPORTING=`, `MOZ_SERVICES_HEALTHREPORT=`, `MOZ_TELEMETRY_REPORTING=`, `--disable-crashreporter` под `ZEN_RELEASE`, `~/.zen-keys/*.dat`); `configs/macos/mozconfig` (`--enable-eme=widevine`).
- Firefox: [Telemetry preferences and defines](https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/internals/preferences.html) — `MOZ_TELEMETRY_REPORTING`, `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `datareporting.policy.dataSubmissionEnabled`.
- [Bugzilla 1434706](https://bugzilla.mozilla.org/show_bug.cgi?id=1434706) — `identity.fxaccounts.enabled` отключает Sync и FxA, прячет UI.
- [tor-browser#42501](https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/42501) — `--disable-eme` OS-зависим; эффект `--enable-eme` на `browser.eme.ui.enabled`, `media.gmp-widevinecdm.*`.
- [Bugzilla 1300654](https://bugzilla.mozilla.org/show_bug.cgi?id=1300654) — история `--enable-eme`/`--disable-eme`, `MOZ_EME_MODULES`.
- [SUMO 1542345](https://support.mozilla.org/questions/1542345) — список `browser.ml.*`, поэтапное включение Mozilla.
- [LibreWolf source](https://codeberg.org/librewolf/source) — `patches/pref-pane/` (своя категория в настройках), `patches/sed-patches/disable-pocket.patch`, `settings/`.
