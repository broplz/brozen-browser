# ADR-0003 · Вырезание: AI, телеметрия, Sync, EME, Zen Mods — и панель переключателей BB

## Статус

Accepted — 31.10.2026. Версия 2: учтён отчёт инвентаризации `docs/reports/strip-inventory.md` (задача 0024) и решения владельца. Проверка решений — задачи 0025–0028; при провале проверок ADR возвращается в Proposed с пометкой, что именно не подтвердилось.

- Область: репо `broplz/brozen-browser`, база Zen 1.23.4b / Firefox 158.0.1, слой по ADR-0002, эпик `e1-strip`.
- Основание: отчёт 0024 (каждое утверждение — с `file:line` в исходниках Zen/Firefox), `configs/common/mozconfig` и `configs/macos/mozconfig` Zen 1.23.4b, документация Firefox по telemetry defines, Bugzilla 1434706, tor-browser#42501, SUMO-тред по `browser.ml.*`, LibreWolf `patches/pref-pane/`.
- Связанные ADR: ADR-0002 (слой; это ADR ужесточает его правило для e1-strip), ADR-0004 (prefs приватности/скорости — не здесь), E0 (бренд, апдейтер — 0021–0023).

Теги: **[verified]** — исходник или официальная документация; **[my judgment]** — оценка; **[open]** — проверяется задачей, указан номер.

## Контекст и проблема

Хотелка скоупа v1: BB без AI Firefox, телеметрии, Sync, Widevine и Zen Mods. Решения владельца (30–31.10.2026):

1. Ничего не вырезается намертво — у каждого пункта есть выключатель, пользователь сам решает, что включить. Без замков на префы.
2. Переключатели — в отдельной вкладке настроек BB.
3. EME выключен по умолчанию, из сборки не вырезается. Mods выключены по умолчанию. Boosts включены, но с выключателем.
4. **Чисто**: файлы Zen и Firefox не правим — каждая такая правка это merge-конфликт на еженедельном теге. Всё живёт в `src/bb/`, `prefs/bb/`, `scripts/bb/`; наши изменения ставятся поверх Zen, а не внутрь него.

Что уже сделал Zen (отчёт 0024, **[verified]**):

- **AI**: `prefs/firefox/ai.yaml` ставит в `false` семь `browser.ml.*` (`chat.enabled`, `chat.shortcuts`, `chat.shortcuts.custom`, `chat.sidebar`, `chat.menu`, `linkPreview.enabled`, и Zen-собственный мастер `browser.ml.enable`). Не закрыты: `browser.ml.chat.page`, `chat.page.footerBadge`, `chat.page.menuBadge`, `chat.shortcuts.smartwindow`, `linkPreview.optin`, `browser.tabs.groups.smart.enabled/userEnabled/optin/searchTopicEnabled`, `browser.search.visualSearch.featureGate`, `extensions.ml.enabled` (`all.js:1784`, true).
- **Телеметрия**: `prefs/privatefox/privacy.yaml` — `datareporting.policy.dataSubmissionEnabled`, `healthreport.uploadEnabled`, `toolkit.telemetry.*` (9 имён), `app.shield.optoutstudies.enabled`, `app.normandy.*`, `browser.ping-centre.telemetry` — `false`, большинство `locked`. Не закрыт `browser.discovery.enabled` (ff.js:3082, true). В mozconfig Zen обнуляет `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT`, `MOZ_TELEMETRY_REPORTING`, но в текущем objdir `MOZ_DATA_REPORTING=1`, `MOZ_SERVICES_HEALTHREPORT=1` (`config.status:96-97`) — либо objdir старее этих строк, либо форма `ac_add_options X=` не снимает subst **[open, 0025]**.
- **Sync**: `src/zen/sync/` — Sync-engine для Spaces поверх Firefox Sync, без UI; без FxA мёртв. `identity.fxaccounts.enabled=true` — дефолт Firefox (ff.js:2481), Zen не трогает.
- **EME**: `configs/macos/mozconfig:8` `--enable-eme=widevine`; `prefs/zen/media.yaml:5` `media.eme.enabled=true`; `media.gmp-widevinecdm.enabled/visible` и `browser.eme.ui.enabled` — дефолты Firefox под `MOZ_WIDEVINE_EME`.
- **Mods**: pref'а-выключателя нет (`zen.mods.*` — только автообновление); модуль грузится строкой 21 `ZenPreloadedScripts.js`, инстанс `window.gZenMods`; вкладка Marketplace — в патче Zen на `preferences.xhtml`.
- **Boosts**: `zen.boosts.enabled` (`prefs/zen/boosts.yaml:5`, true); гейтит регистрацию actor'а и urlbar-действие; панель site-data и секция Library — не гейтят.
- **Панель настроек**: Zen добавляет вкладки патчами на `preferences.xhtml`/`preferences.js`/`jar.mn` плюс плоские файлы `zen-settings.js`, `zen*.inc.xhtml`.
- **Линт**: `layer_lint.py:127-130` отвергает не-`bb.*` имена в `prefs/bb/`.

## Требования

- S1. Каждый пункт: один механизм, одна запись (`strip.yaml` или `layer.yaml`), один автоматический тест.
- S2. **Ноль правок файлов Zen и Firefox** в e1-strip. Исключение — только с явным одобрением владельца, отдельной задачей с `needs_approval`.
- S3. Без замков. Дефолт BB — выключено; решение о включении — за пользователем. Телеметрия — без переключателя: она закрыта Zen'ом с замками, включать нечем.
- S4. Проверка скриптом: `scripts/bb/strip-check.sh` падает на первом расхождении.
- S5. Не ломаем: Safe Browsing, Remote Settings, OpenH264 GMP, Boosts, `zen.window-sync.*`.
- S6. Все переключатели в одном месте: вкладка «BROzen» в `about:preferences`, пять тумблеров (EME, AI, Sync, Mods, Boosts) с пометкой «нужен перезапуск», где требуется.

## Решение 1 — уровни и правило выбора

| Уровень | Что это | Когда | Цена при ребейзе |
|---|---|---|---|
| L2 prefs | `prefs/bb/strip.yaml` | Фича управляется pref'ом | ноль; переименование pref'а в новом Firefox ловит strip-check |
| L3 own-code | Подмена инстанса или инъекция из `src/bb/` (BBStartup грузится последним; свои actor'ы в `BBComponents.manifest`), CSS в `src/bb/strip/strip.css` | Компонент Zen без pref'а, UI-входы | ноль файловых; риск — смена внутреннего API/DOM Zen или Firefox, ловит smoke |
| L1 build | флаги в `configs/bb/mozconfig*` | Только без переключателя (крэш-репортер) | ноль |
| L4 edit/patch | правка файла Zen или патч на Firefox | **Запрещено** по S2 без одобрения | каждый тег |

Правило: L2 → L3 → стоп. L1 только для 2.1. Namespace тумблеров — `bb.strip.*` с дефолтами в `strip.yaml`; `src/bb/strip/BBStrip.mjs` транслирует тумблер во внутренние префы (таблица в 2.7) при переключении и приводит их в соответствие на старте. Дефолты внутренних префов живут в yaml, не в JS.

**Размещение префов (Q8 отчёта).** Правило ADR-0002 «чужие имена не в `prefs/bb/`» защищает от дубля с yaml Zen (недетерминированная сортировка ffprefs). Для e1-strip оно сужается: `layer_lint.py` разрешает не-`bb.*` имя в `prefs/bb/strip.yaml`, **если это имя не встречается ни в одном `prefs/{zen,firefox,fastfox,privatefox}/**/*.yaml`**; иначе — ошибка линта с текстом «Zen задаёт этот pref: не дублировать». Так в `strip.yaml` попадают только Firefox-only имена (≈13), дубля быть не может, Zen не трогается. Отдельная задача на линт идёт до 0025.

## Решение 2 — по компонентам

### 2.1 Телеметрия — без переключателя

Zen закрыл её префами с замками **[verified]**. BB добавляет в `strip.yaml` только `browser.discovery.enabled=false` (Firefox-only). `configs/bb/mozconfig`: `ac_add_options --disable-crashreporter` безусловно — у Zen он только под `ZEN_RELEASE` **[verified]**, в dev-сборке `MOZ_CRASHREPORTER=1`.

Открытое **[open, 0025]**: `MOZ_DATA_REPORTING=1` в objdir. QA 0025 делает свежую сборку и смотрит `config.status`. Если флаги остались `1` — добавляем в `configs/bb/mozconfig` форму, которая работает (`export MOZ_DATA_REPORTING=` / `mk_add_options`), и фиксируем в отчёте 0025, какая. Это не правка Zen: наш файл. Утечки нет и сейчас — префы отправки заперты Zen'ом.

Из списка v1 убраны: `dom.private-attribution.submission.enabled` — в Firefox 158 не найден **[verified, 0024]**.

### 2.2 AI — `bb.strip.ai`, по умолчанию выкл.

L2. Zen уже выключил семь имён; `strip.yaml` добавляет Firefox-only: `browser.ml.chat.page=false`, `chat.page.footerBadge=false`, `chat.page.menuBadge=false`, `chat.shortcuts.smartwindow=false`, `linkPreview.optin=false`, `browser.ml.pageAssist.enabled=false` (уже false, фиксируем), `browser.tabs.groups.smart.enabled=false`, `.userEnabled=false`, `.optin=false`, `.searchTopicEnabled=false`, `browser.search.visualSearch.featureGate=false`, `extensions.ml.enabled=false`. Убраны несуществующие `hideFromLabs`, `hideLabsShortcuts` **[verified, 0024]**.

Тумблер «AI» в `true` включает и семь имён Zen, и наши — через `BBStrip.mjs` как user-префы при переключении. Без замков; защита от «Mozilla включила новое по умолчанию» — drift-часть strip-check (2.9).

### 2.3 Sync — `bb.strip.sync`, по умолчанию выкл.

L2: `identity.fxaccounts.enabled=false` прячет панель Sync и отключает FxA **[verified, Bugzilla 1434706]**; требует перезапуска — панель предупреждает. Zen Spaces Sync — engine поверх FxA, без аккаунта не работает **[verified, 0024 Q3]**; хук не нужен. `auth.uri`/`tokenserver.uri` не трогаем — пользователь включает Sync одним тумблером.

### 2.4 EME — `bb.strip.eme`, по умолчанию выкл.

L2, три префа Firefox-only: `media.gmp-widevinecdm.enabled=false`, `media.gmp-widevinecdm.visible=false`, `browser.eme.ui.enabled=false` **[verified, tor-browser#42501: их выставляет `--enable-eme`]**. Строку Zen `media.eme.enabled=true` **не трогаем**: это включение API EME, без CDM DRM-контент не играет **[my judgment; проверка — smoke 0028: Netflix не играет по умолчанию, играет после тумблера и перезапуска]**. Если smoke покажет обратное — `media.eme.enabled` добавляется в таблицу трансляции как user-pref, выставляемый `BBStrip.mjs`; Zen по-прежнему не правим.

### 2.5 Zen Mods — `bb.strip.mods`, по умолчанию выкл.

L3 без правки Zen: `BBStartup.mjs` грузится последним в том же окне, модуль Zen импортирован с `{global:"current"}` **[verified, 0024 Q1]** — за `bb.strip.mods=true` BBStartup заменяет `window.gZenMods` на заглушку с тем же интерфейсом (методы no-op), до того как её дёрнут actor'ы Marketplace и `zen-settings.js`. Вкладка Marketplace прячется CSS: `#category-zen-marketplace{display:none}` в `strip.css`. Запасной путь (хук-фильтр в `ZenPreloadedScripts.js`, ~5 строк Zen) — только с одобрением владельца, если заглушка не держит.

### 2.6 Zen Boosts — `bb.strip.boosts`, по умолчанию **вкл.**

L2: `bb.strip.boosts=true` ⇄ `zen.boosts.enabled=false` (pref Zen, трансляция в `BBStrip.mjs` как user-pref; в `strip.yaml` его нет — он Zen-овский). Не гейтятся Zen'ом кнопка в site-data панели и секция Library **[verified, 0024 Q2]** — CSS в `strip.css` под атрибутом `bb-strip-boosts` на `#main-window`, который ставит `BBStrip.mjs`.

### 2.7 Панель «BROzen» — инъекция из своего кода

| Вариант | Что трогаем | Конфликты | Вердикт |
|---|---|---|---|
| A. Свой actor (`BBComponents.manifest`, наш файл): ловит загрузку `about:preferences`, из JS добавляет `moz-page-nav-button` «BROzen» и тело панели (`src/bb/strip/brozen-pane.js`, `.css`, `.ftl` через `jar.inc.mn`) | только `src/bb/` | ноль файловых; риск — смена DOM `preferences.xhtml` в новом Firefox, ловит smoke | **Рекомендован** [my judgment; доказывает 0028] |
| B. `about:brozen` — своя страница | только `src/bb/` | ноль | Запасной: вкладки в настройках нет |
| C. BB-патч на `preferences.xhtml`/`.js` | файлы Firefox рядом с хенками Zen | при смене Firefox и сдвиге хенков Zen | Отвергнут (S2) |
| D. Хук в `zen-settings.js` | файл Zen | каждый тег | Отвергнут (S2) |

Содержимое v1: пять тумблеров, строка пояснения, пометка «перезапуск» у EME и Sync, кнопка «Перезапустить».

Таблица трансляции (`BBStrip.mjs`, единственный источник):

| Тумблер | Дефолт | Внутренние префы при тумблере = «выключено» |
|---|---|---|
| `bb.strip.ai` | true | все `browser.ml.*`, `browser.tabs.groups.smart.*`, `browser.search.visualSearch.featureGate`, `extensions.ml.enabled` → false |
| `bb.strip.sync` | true | `identity.fxaccounts.enabled` → false |
| `bb.strip.eme` | true | `media.gmp-widevinecdm.enabled`, `.visible`, `browser.eme.ui.enabled` → false |
| `bb.strip.mods` | true | заглушка `gZenMods`, CSS |
| `bb.strip.boosts` | false | `zen.boosts.enabled` → false, CSS |

### 2.8 Не трогаем

Safe Browsing, Remote Settings, OpenH264 GMP, `app.update.*` (0022), `zen.window-sync.*`, `services.sync.prefs.sync.zen.*` (мертвы без FxA). Prefs приватности сверх этого — ADR-0004.

### 2.9 Проверка

`scripts/bb/strip-check.sh`, три части:

- **build**: `engine/obj-*/config.status` (формат `'KEY': 'value'` **[verified, 0024 Q9]**) — `MOZ_CRASHREPORTER` отсутствует; `MOZ_DATA_REPORTING`, `MOZ_SERVICES_HEALTHREPORT` отсутствуют (после разбора **[open, 0025]**).
- **prefs**: сгенерированный `engine/browser/app/profile/zen.js` (`pref("name", value[, locked]);`, с `#if`-блоками **[verified]**) против `prefs/bb/strip.yaml` построчно.
- **drift**: все `browser.ml.*`, `browser.tabs.groups.smart.*`, `identity.fxaccounts.*`, `media.gmp-widevinecdm.*`, `browser.eme.*` из `firefox.js` нового engine должны быть известны `strip.yaml`, yaml Zen или allow-листу `scripts/bb/strip-allow.txt`; незнакомое имя — код 1 и задача на обновление.

Вызов — первым шагом `smoke.sh` и из QA после сборки. Smoke `scripts/bb/smoke.d/e1.txt`: вкладка BROzen с пятью тумблерами; Sync-панели нет; «Ask AI» нет в меню; Marketplace нет, Boosts есть; Netflix не играет; тумблер EME → перезапуск → играет; обратно; Browser Console без ошибок `ml`/`fxaccounts`/`gZenMods`/`BBStrip` первые 30 с.

## Последствия

Плюсы: ни одной правки файлов Zen и Firefox — ребейз e1-strip бесконфликтен по построению; один yaml и один модуль как контракт; пользователь получает одно место для решений; strip-check делает список исполняемым.

Цена: наши L3-механизмы (заглушка `gZenMods`, инъекция в `about:preferences`) зависят от внутреннего API Zen и DOM Firefox — не от файлов, а от поведения; ломаются тихо, поэтому smoke e1 обязателен на каждом ребейзе. Линт получает исключение — одно, узкое, с проверкой дублей. Без замков дефолт нового `browser.ml.*` после ребейза может быть `true` до первого запуска BB; drift-проверка ловит это на сборке, `BBStrip.mjs` — на старте.

## Риски и план проверки

| # | Риск | Проверка | Митигация |
|---|---|---|---|
| R1 | Заглушка `gZenMods` не покрывает интерфейс → ошибки в actor'ах Marketplace / `zen-settings.js` | 0027, Browser Console | Расширить заглушку; крайний случай — хук в `ZenPreloadedScripts.js` с одобрением |
| R2 | Инъекция в `about:preferences` не находит точку монтирования (DOM изменился) | 0028, smoke | Запасной `about:brozen` |
| R3 | `media.eme.enabled=true` при выключенном CDM всё же даёт воспроизведение | smoke 0028 (Netflix) | Добавить его в трансляцию как user-pref |
| R4 | `MOZ_DATA_REPORTING=1` в свежей сборке | QA 0025 | Рабочая форма флага в `configs/bb/mozconfig`; отчёт 0025 фиксирует причину |
| R5 | Переименования `browser.ml.*` в Firefox 159+ | drift strip-check на первом ребейзе | Задача на `strip.yaml` + трансляцию |
| R6 | Узкое исключение в линте пропустит дубль из-за `@cond`/include в yaml Zen | тест линта | Линт сканирует все yaml рекурсивно, включая условные значения |

План: (1) задача на линт (узкое исключение + тест); (2) 0025: `strip.yaml` (Firefox-only имена), `configs/bb/mozconfig`, `strip-check.sh`, свежая сборка, разбор R4; (3) 0026: `BBStrip.mjs` — трансляция, приведение на старте, заглушка `gZenMods`, `strip.css`; (4) 0027: панель по варианту A, при провале — B; (5) 0028: `smoke.d/e1.txt`. Нумерация задач — как заведена в `tasks/` (0025 prefs/check, 0026 BBStrip, 0027 панель, 0028 smoke); «Proposed task changes» отчёта 0024 перенумерованы иначе и не являются источником.

## Решения владельца

- 30.10: EME выключен по умолчанию, включается пользователем; без замков; отдельная вкладка настроек; Boosts остаются, вырезаем по умолчанию только Mods.
- 31.10: ноль правок файлов Zen и Firefox в e1-strip, любое исключение — отдельное одобрение; свои изменения ставятся поверх.

## Вне scope

ADR-0004 (RFP, cookies, WebRTC, DoH, HTTPS-only, Betterfox-наследие; `policies.json`), uBlock Origin (E10), Mozilla-брендинг в urlbar/about (E0), Windows/Linux.

## Ссылки

- `docs/reports/strip-inventory.md` (0024) — все `file:line` по Zen 1.23.4b и Firefox 158.
- Zen 1.23.4b: `configs/common/mozconfig:95-100`, `configs/macos/mozconfig:8`, `prefs/firefox/ai.yaml`, `prefs/privatefox/privacy.yaml`, `prefs/zen/media.yaml:5`, `prefs/zen/boosts.yaml:5`, `src/zen/common/ZenPreloadedScripts.js:21`, `src/zen/mods/ZenMods.mjs:769`, `src/browser/components/preferences/preferences-xhtml.patch`.
- Firefox: [Telemetry preferences and defines](https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/internals/preferences.html); [Bugzilla 1434706](https://bugzilla.mozilla.org/show_bug.cgi?id=1434706) — `identity.fxaccounts.enabled`; [tor-browser#42501](https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/42501) — префы, которые выставляет `--enable-eme`.
- [SUMO 1542345](https://support.mozilla.org/questions/1542345) — поэтапное включение `browser.ml.*` Mozilla.
- [LibreWolf source](https://codeberg.org/librewolf/source) — `patches/pref-pane/` как референс своей вкладки (у нас — без патча).
