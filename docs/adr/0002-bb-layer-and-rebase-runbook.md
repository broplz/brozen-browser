# ADR-0002 · Слой BB и runbook ребейза

Oct 24, 2026 · @broplz

## Статус

Proposed — варианты на обсуждении; после выбора статус меняется на Accepted, и файл уходит в репо как `docs/adr/0002-bb-layer-and-rebase-runbook.md`.

- Область: репо `broplz/brozen-browser`, ветка `bb` (== тег Zen 1.23.4b, Firefox 158.0.1, 0 своих коммитов), surfer 1.14.9, сборка на M1 Pro.
- Основание: чтение исходников `@zen-browser/surfer@1.14.9` (как `import`/`export` работают на самом деле), свежий клон `bb`, даты и Firefox-версии девяти последних тегов Zen, вывод команд из приложения.
- Воплощает решения скоупа v1: следуем за тегами Zen, `main` — daily driver, фичи в ветках, своё в `src/bb/`, патчи к C++ — только где иначе нельзя, каждый отдельно с README.
- Связанные ADR: [ADR-0001](https://claude.ai/artifact/U2oF6RTwr1fKi8EG1Xf9RF) (Little BB — первый потребитель правил этого ADR); ADR-0003 (вырезание) и ADR-0012 (AI-команда) ещё не написаны и опираются на структуру отсюда.

## Контекст и проблема

Zen — это Firefox-тарбол в `engine/` плюс слой из `src/` и `prefs/`, который surfer накладывает при `npm run init`. BB кладёт ещё один слой сверху, и всё, что в этом ADR, сводится к одному вопросу: как сделать так, чтобы наш слой переживал смену тега Zen с минимумом ручной работы.

Как surfer накладывает слой (прочитано в `@zen-browser/surfer@1.14.9`, порядок — из `applyPatches()`):

1. `surfer download` кладёт тарбол в `.surfer/engine/firefox-<ver>.source.tar.xz` (кэш, повторно не качает), распаковывает в `engine/` и делает там git-репо с одним коммитом «Firefox \<ver>». Всё, что ниже, — незакоммиченные изменения поверх него.
2. `surfer import`: сначала внутренние патчи surfer, потом брендинг (`configs/branding/<brand>/`), потом **все не-`.patch` файлы из `src/` симлинкуются** в `engine/` по тому же пути (`src/zen/glance/x.mjs` → `engine/zen/glance/x.mjs`, путь дописывается в `engine/.gitignore`), потом **все `**/*.patch` под `src/`** накладываются `git apply --ignore-space-change --ignore-whitespace` в порядке `readdir` — порядок не гарантирован (перед наложением делается `git apply -R`, чтобы повторный import был идемпотентен).
3. `npm run import` = `ffprefs` (Rust, читает `prefs/**/*.yaml` рекурсивно, пишет `engine/browser/app/profile/zen.js` и `engine/modules/libpref/init/zen-static-prefs.inc`) → `update_service_dumps.py` → `surfer import`.
4. `surfer export <file>` = `git diff` файла против коммита «Firefox» и запись в `src/<dir>/<basename-с-точками-в-дефисы>.patch`: ровно один патч на файл, имя выводится из пути. Так Zen держит 263 патча; исключение — `src/external-patches/` (чужие многофайловые диффы с README и своими именами).
5. `surfer build` собирает `engine/mozconfig` из `configs/common/mozconfig` + `configs/<os>/mozconfig` + незакоммиченного корневого `mozconfig` + внутренних строк surfer (бренд, buildMode).

Что из этого следует для BB:

- Файлы `src/zen/*` патчить через `.patch` нельзя в принципе: в `engine/` это симлинки, а `git apply` не пишет сквозь симлинк (проверено на минимальном примере — `patch does not apply`). Их меняем только прямой правкой в ветке.
- Zen уже патчит `widget/cocoa/nsCocoaWindow.mm`, `browser/components/sessionstore/SessionStore.sys.mjs` и `browser/base/content/browser.js` — все три файла, в которые лезет ADR-0001. Второй патч на тот же файл возможен (Zen сам так делает: `nsCocoaWindow.mm` патчится и из `src/widget/cocoa/`, и из `external-patches/`), но только если хенки не пересекаются, и `surfer export` для такого файла использовать нельзя — он сольёт оба диффа в патч Zen.
- Точки подключения `src/zen/` в сборку — плоские файлы, не патчи: `src/zen/moz.build` (через `DIRS += ["../../zen"]` в `src/browser/base/moz-build.patch`), `src/browser/base/content/zen-assets.jar.inc.mn`, `zen-assets.inc.xhtml`, `src/zen/common/ZenPreloadedScripts.js`, `src/zen/ZenComponents.manifest`. Значит, BB может подключиться одной строкой в каждом из них без единого нового патча.

Реальный каденс апстрима (даты коммитов тегов, Firefox из `surfer.json` на теге):

| Тег Zen | Дата | Firefox | Сменился Firefox |
| --- | --- | --- | --- |
| 1.23.4b | 2026-10-20 | 158.0.1 | да (point) |
| 1.23.3b | 2026-10-16 | 158.0 | да (мажор) |
| 1.23.2b | 2026-10-09 | 157.0.1 | нет |
| 1.23.1b | 2026-10-06 | 157.0.1 | да (point) |
| 1.23b | 2026-10-03 | 157.0 | да (мажор) |
| 1.22.3b | 2026-09-22 | 156.0.1 | да (point) |
| 1.22.2b | 2026-09-15 | 156.0 | да (мажор) |
| 1.22.1b | 2026-09-11 | 155.0.1 | нет |
| 1.22b | 2026-09-04 | 155.0.1 | — |

Девять тегов за семь недель, Firefox сменился в семи из них: «каждый тег» на практике — еженедельный ребейз, почти всегда с новым тарболом (\~0,6 ГБ) и полной C++-сборкой (\~40 мин на M1 Pro). Мажор Firefox — раз в две недели (155 → 156 → 157 → 158), point-релизы `x.0.1` — через 3–7 дней после мажора, обычно security и стабильность. Это и есть исходная оценка скоупа «раз в \~2 недели», но только если триггером считать базу Firefox, а не каждый тег.

Сетевые ограничения: GitHub из Казахстана \~30 КБ/с (git идёт через `ProxyJump tool`), archive.mozilla.org и npm — быстро. Медленная часть ребейза — не тарбол, а всё, что тянется с GitHub: `git fetch upstream` и клон `mozilla-l10n/firefox-l10n` для release-сборки (скрипт Zen клонирует репо целиком и каждый раз заново).

## Требования и драйверы решения

Функциональные:

- F1. Весь код BB находится одной командой: `git diff <тег Zen>..main` — это и есть слой; никакого BB-кода, размазанного по патчам Zen без пометки.
- F2. Любой компонент BB можно выключить pref'ом и получить стоковое поведение Zen на том же билде — чтобы после ребейза отличать наши регрессии от апстримных.
- F3. Ребейз на новый тег Zen — один скрипт, который либо доводит до собранного и прокуренного билда, либо останавливается на первом конфликте с отчётом «что, где, какой эпик».
- F4. Штатные команды Zen (`npm run init`, `npm run build`, `build:ui`, `npm start`, `npm run package`) продолжают работать как есть; BB-обвязка только добавляет команды.
- F5. Для каждого изменения чужого файла есть README: зачем, какие файлы, как проверить — и это же README говорит, к какому эпику относить конфликт.

Нефункциональные:

- N1. Один разработчик: никаких PR-ритуалов, защищённых веток и CI-гейтов; force-push в `main` допустим.
- N2. Один `engine/` по умолчанию (переключение ветки = `surfer reset` → `import` → сборка); второй worktree — задокументированный, но необязательный режим. Диск >600 ГБ позволяет оба.
- N3. Долгие шаги не должны выглядеть зависшими: прогресс в терминале и `tee` в лог-файл на каждый шаг.
- N4. Всё, что тянется с GitHub, кэшируется между ребейзами; тарбол Firefox кэширует сам surfer.
- N5. Цена сопровождения измеряется: число конфликтов на ребейз в разрезе эпиков — единственная метрика, по которой в январе решаем про hard fork.

## Решение 1 — структура слоя BB

Слой живёт в четырёх корнях, и каждый лежит там, где его уже читает инструментарий Zen: код — в `src/bb/`, prefs — в `prefs/bb/`, сборочные флаги и брендинг — в `configs/`, обвязка — в `scripts/bb/`. Отступление от «всё в `src/bb/`» сознательное: `ffprefs` читает только `prefs/`, surfer собирает mozconfig только из `configs/` — класть их в `src/bb/` значило бы патчить сам инструментарий или держать симлинки ради красоты дерева.

```
src/bb/                        # симлинкуется в engine/bb/, в сборку — через moz.build
  moz.build                    # DIRS по модулям BB
  BBComponents.manifest        # компоненты и акторы; #include из ZenComponents.manifest
  jar.inc.mn                   # chrome://browser/content/bb/...; #include из zen-assets.jar.inc.mn
  bb-assets.inc.xhtml          # <link> на CSS BB; #include из zen-assets.inc.xhtml
  BBStartup.mjs                # одна строка в ZenPreloadedScripts.js; грузит модули по pref'ам
  common/                      # BBPrefs, лог, утилиты, isLittleWindow() и т.п.
  little-bb/                   # E3: BBLittle.mjs, actors/, bb-little.css
  split-view/                  # E6: BBSplitView — подмена ZenViewSplitter за pref
  <epic>/                      # command-bar, pip, containers, arc-import — по эпику
  patches/                     # патчи к файлам Firefox в engine/, по эпику
    e3-little-bb/
      cocoa-floating-window/
        cocoa-floating-window.patch
        README.md
    e1-strip/...
  layer.yaml                   # реестр слоя: хуки, прямые правки Zen, патчи → эпик
prefs/bb/                      # *.yaml, ffprefs читает без хуков; namespace bb.*
configs/bb/                    # mozconfig + mozconfig.macos; одна строка-хук в configs/common/mozconfig
configs/branding/bb/           # E0: бренд через штатный механизм surfer + surfer.json
scripts/bb/                    # rebase.sh, patches.sh, smoke.sh, report.sh, lib.sh
docs/adr/                      # NNNN-*.md
docs/rebase/                   # <тег>.md — отчёт каждого ребейза
CLAUDE.md                      # вход для агентов (E11): команды scripts/bb/ и правила этого ADR
```

Точки подключения — по одной строке, все в плоских файлах Zen (не в `.patch`), поэтому при ребейзе это обычный трёхсторонний merge строки, а не правка диффа:

| Файл Zen | Строка | Что даёт |
| --- | --- | --- |
| `src/zen/moz.build` | `DIRS += ["../bb"]` | `src/bb/moz.build` входит в сборку |
| `src/browser/base/content/zen-assets.jar.inc.mn` | `#include ../../../bb/jar.inc.mn` | chrome-пути `chrome://browser/content/bb/...` |
| `src/browser/base/content/zen-assets.inc.xhtml` | `#include ../../../bb/bb-assets.inc.xhtml` | CSS BB в `browser.xhtml` |
| `src/zen/common/ZenPreloadedScripts.js` | `"chrome://browser/content/bb/BBStartup.mjs"` последним в `scripts` | загрузка модулей BB после всех `gZen*` |
| `src/zen/ZenComponents.manifest` | `#include ../bb/BBComponents.manifest` | акторы и компоненты (только когда появятся) |
| `configs/common/mozconfig` | `. "$topsrcdir/../configs/bb/mozconfig"` | флаги сборки BB (содержимое — ADR-0003) |
| `package.json` | `"bb:rebase"`, `"bb:patches"`, `"bb:smoke"` | обвязка доступна через `npm run` |

`prefs/bb/` хуков не требует. Единственное правило: имя pref'а Zen в `prefs/bb/` не дублируем — `ffprefs` сортирует по имени стабильной сортировкой, и какой из двух одинаковых `pref()` окажется последним, зависит от порядка обхода каталогов. Дефолт Zen меняем правкой его строки в `prefs/zen/*.yaml`; своё — только в namespace `bb.*`.

Где лежат патчи BB к файлам Firefox — три варианта:

| Вариант | Суть | Плюсы | Минусы | Вердикт |
| --- | --- | --- | --- | --- |
| A. По конвенции surfer | `src/widget/cocoa/nsCocoaWindow-mm.patch` — то есть править патч Zen или создавать патч по его имени | Ноль инструментов, `npm run export` работает | Хенки BB и Zen в одном файле: конфликт при ребейзе — правка diff-of-diff; слой не отделить (F1); README некуда | Отвергнут как основной |
| B. `src/bb/patches/<эпик>/<имя>/` | Свой `.patch` + `README.md` на каждый; surfer накладывает их тем же глобом `**/*.patch`; правило непересечения хенков с Zen; свой `bb export` | Слой отделён, README рядом, `npm run init` без доработок; конфликт — падение конкретного патча с именем | Нужен `scripts/bb/patches.sh` (check, export); для файлов с BB-патчем `npm run export` под запретом | **Рекомендован** |
| C. Вне `src/` + свой applier | `bb/patches/` с series-файлом, накладывается после `surfer import` в явном порядке (quilt-style) | Детерминированный порядок, пересечение с хенками Zen допустимо | Второй механизм наложения рядом с surfer; `npm run init` сам по себе BB не даёт; re-export сложнее | Запасной, если непересечение не выдержать |

Побочный эффект B: `README.md` и прочие не-`.patch` файлы из `src/bb/patches/` тоже симлинкуются в `engine/bb/patches/` — это безвредно, сборка их не видит.

## Решение 2 — правила изменений чужого кода

Чужие файлы делятся на три класса, и класс файла определяет механизм; размер изменения определяет, хук это или подмена. Правило одно: сначала самый дешёвый для ребейза механизм из допустимых, и каждое изменение видно в `layer.yaml` или в README патча.

| Класс | Что это | Допустимые механизмы | Запрещено |
| --- | --- | --- | --- |
| 1. Файлы Firefox | Реальные файлы в `engine/` из тарбола (`widget/cocoa/*.mm`, `SessionStore.sys.mjs`, `browser.js`) | BB-патч в `src/bb/patches/`; в крайнем случае хенк в патче Zen | Прямая правка в `engine/` (сотрётся `surfer reset`) |
| 2. Плоские файлы Zen | `src/zen/**`, `src/browser/base/content/zen-*.inc.*`, `prefs/zen/*.yaml`, `configs/*/mozconfig`, `package.json` — обычные файлы ветки | Прямая правка коммитом (хук ≤ \~10 строк) или подмена модуля за pref | `.patch` (в `engine/` это симлинки — `git apply` не применится) |
| 3. Патчи Zen | `src/**/*.patch`, `src/external-patches/` | Правка только при неизбежном пересечении хенков, через `npm run export` | Любая правка «потому что проще» |

Как выбирать:

1. Нужно поведение Zen-модуля с другой логикой. Если разница — условие, вызов или проверка признака (`bb-little`, pref) в ≤ \~10 строках — прямая правка в `src/zen/` с маркером `// BB(e3): <зачем>` (CSS `/* BB(e3) */`, yaml `# BB(e3)`) и записью в `layer.yaml`. Если разница больше или логика переписывается — подмена: свой модуль в `src/bb/<feature>/`, Zen-модуль не трогаем.
2. Подмена работает через экземпляр: модули Zen заканчиваются на `window.gZenViewSplitter = new nsZenViewSplitter()`, а `BBStartup.mjs` грузится последним, поэтому за pref'ом `bb.<feature>.enabled` он заменяет экземпляр — `window.gZenViewSplitter = new BBSplitView()`, где `BBSplitView extends gZenViewSplitter.constructor` переопределяет нужные методы, либо реализует тот же интерфейс с нуля. Pref выключен — стоковый экземпляр Zen остаётся (F2). Модули `resource:///modules/zen/*.sys.mjs` без оконного экземпляра подменяются по решению ADR соответствующей фичи.
3. Нужно изменить файл Firefox, который Zen не патчит — BB-патч, без ограничений по размеру.
4. Нужно изменить файл Firefox, который Zen патчит — BB-патч, если хенки не пересекаются с хенками Zen (`scripts/bb/patches.sh check` это проверяет: патч должен накладываться и на чистый Firefox, и на Firefox + патч Zen). Пересекаются — хенк идёт в патч Zen через `npm run export <file>`, с кодовым маркером `// BB(eN)` внутри хенка и записью в `layer.yaml: zen_patches`.
5. C++/ObjC и IDL — только там, где иначе нельзя (ADR-0001 — единственный известный случай), всегда отдельный патч с README, и это одна из точек одобрения человеком из E11.
6. Дефолты pref'ов Zen меняем правкой строки в `prefs/zen/*.yaml`; своё — в `prefs/bb/*.yaml`, только `bb.*`.

Именование и README. Один патч = одно логическое изменение, может трогать несколько файлов (патч ADR-0001 трогает пять). Путь: `src/bb/patches/<eN-slug>/<kebab-name>/<kebab-name>.patch` + `README.md` рядом. Frontmatter README машиночитаем — его читают `patches.sh export` и `report.sh`:

```markdown
---
epic: e3-little-bb
adr: docs/adr/0001-little-bb-floating-window.md
files:
  - widget/cocoa/nsCocoaWindow.mm
  - widget/nsWidgetInitData.h
  - xpfe/appshell/nsAppShellService.cpp
  - toolkit/components/windowwatcher/nsWindowWatcher.cpp
  - toolkit/components/browser/nsIWebBrowserChrome.idl
upstream: none          # none | zen-pr | firefox-bug
rebuild: full           # full | ui
---
# Зачем
...
# Что меняет
...
# Как проверить
...
# Что обычно ломается при ребейзе
...
```

`src/bb/layer.yaml` — реестр всего, что не лежит в `src/bb/patches/`: хуки (`hooks`), прямые правки Zen (`edits`: файл, эпик, зачем) и патчи Zen с хенками BB (`zen_patches`). Конфликт в файле из `src/bb/**` относится к эпику по имени каталога, в любом другом файле — по `layer.yaml`; файл без записи — конфликт «без эпика», и это само по себе дефект реестра.

`scripts/bb/patches.sh` — три команды поверх git, без изменений surfer. `check` строит временный индекс (`GIT_INDEX_FILE`) из коммита «Firefox», накладывает в него `--cached` патчи Zen на те же файлы (их путь выводится из цели: `src/<dir>/<basename-с-дефисами>.patch`, плюс скан `external-patches/`) и делает `git apply --cached --check` патча BB — и то же против чистого коммита. `export <patch-dir>` на том же индексе делает `git diff -- <files из README>` и перезаписывает `.patch`: для файла с BB-патчем `npm run export` под запретом, иначе хенки BB уедут в патч Zen. `status` показывает, какие патчи BB сейчас наложены в `engine/`.

## Решение 3 — веточная модель

`main` — это тег Zen плюс линейная серия коммитов BB, переписываемая ребейзом на каждом обновлении базы; фичи ответвляются от `main`, живут на своём теге и ребейзятся на `main` один раз, при завершении. Для одного разработчика это минимум ритуала: нет PR, нет защищённых веток, force-push в `main` разрешён, но `main` меняется только через `rebase.sh` или ff-merge завершённой фичи.

```
upstream (теги)   1.23.4b ─────────────────── 1.23.5b ───────────────── 1.24b
                     │                           │
main (сейчас)        └─ hooks ─ e0 ─ e1 ─ e3a     │
                                                 │
main (после          ─────────────────────────── └─ hooks' ─ e0' ─ e1' ─ e3a' ─ «rebase: 1.23.5b»
 rebase.sh)
                          │
feat/e3-little-bb         └─ c1 ─ c2 ─ c3   →  finish: rebase --onto main, squash, ff-merge
```

| Имя | Что это | Правило |
| --- | --- | --- |
| `origin` | `github.com/broplz/brozen-browser` (SSH через `tool`) | единственный push-remote |
| `upstream` | `zen-browser/desktop` | только `fetch`, источник тегов; push запрещён |
| `main` | тег Zen + серия BB | daily driver; обновляется только `rebase.sh` и ff-merge фич; force-push допустим |
| `feat/<eN>-<slug>` | фича от `main` | не следует за `main`, пока идёт работа; ребейз один раз при завершении; удаляется после ff-merge |
| `rebase/<тег>` | рабочая ветка runbook'а | временная: после успеха `main` := `rebase/<тег>`, ветка удаляется; при провале остаётся для разбора |
| тег `bb/base/<тег Zen>` | метка на коммите апстрима, от которого построен `main` | ставится `rebase.sh`, пушится в `origin`; `git log bb/base/1.23.4b..main` = весь слой (F1) |
| `bb` (сейчас) | рабочая ветка == 1.23.4b | переименовать в `main`, сделать default в GitHub |
| `dev` (в форке) | зеркало апстрима | удалить: `upstream` как remote делает то же без копии |

Где зафиксирован текущий тег Zen: в `src/bb/layer.yaml` блок `base: {zen: 1.23.4b, firefox: 158.0.1, commit: 541ee55}` — единственный источник истины для скриптов и для `about:`-страниц BB; плюс тег `bb/base/<тег>` в git. `surfer.json` для этого не годится: `displayVersion` там станет версией BB в E0, а `version.version` — это Firefox, не Zen.

Жизненный цикл фичи:

1. `git switch -c feat/e3-little-bb main` — ветка стартует на том теге, на котором сейчас `main`; в коммите-заголовке ветки ничего менять не нужно, `bb/base/<тег>` уже есть.
2. Работа: коммиты с префиксом эпика (`e3: …`), патчи через `patches.sh`, сборка в том же `engine/`. Если `main` за это время уехал на новый тег — фича не следует за ним.
3. Завершение: `git rebase --onto main $(git merge-base --fork-point main feat/e3-little-bb) feat/e3-little-bb` (старая вершина `main` в reflog, этого хватает одному разработчику), затем интерактивный squash до осмысленных коммитов — патч и его README в одном коммите, хук и запись в `layer.yaml` в одном коммите.
4. На результате: `npm run import` → сборка → `smoke.sh` → `git switch main && git merge --ff-only feat/e3-little-bb` → ветка удаляется.
5. Правки в один присест (pref, строка-хук, ADR, отчёт ребейза) идут в `main` напрямую; ветка нужна, когда работа длиннее одного дня или ей нужно своё состояние `engine/` (C++-патч).

Сообщения коммитов: `<eN>: <что>` для фич, `layer: <что>` для хуков и реестра, `rebase: Zen <тег> (Firefox <ver>)` — единственный новый коммит, который добавляет `rebase.sh` (обновлённый `base` в `layer.yaml` и отчёт в `docs/rebase/`). По префиксу `report.sh` считает коммиты и конфликты по эпикам.

| Вариант отслеживания апстрима | Суть | Плюсы | Минусы | Вердикт |
| --- | --- | --- | --- | --- |
| A. Rebase | `main` переписывается поверх нового тега | слой = читаемая серия коммитов; `format-patch` отдаёт его целиком; конфликты по одному коммиту с его README | force-push; фичи завершаются через `--onto` | **Рекомендован** |
| B. Merge | `git merge <тег>` в `main` | история не переписывается, ff для фич всегда | слой размазан по merge-коммитам, серию не прочитать; конфликты те же, но «все сразу» в одном merge | Отвергнут |
| C. Внешняя патч-серия (quilt/stgit) поверх тега | слой хранится как стопка патчей, не как ветка | явный порядок | второй инструмент поверх git и surfer, которые уже держат по стопке патчей | Отвергнут |

## Решение 4 — runbook ребейза

Триггер ребейза — смена базы Firefox, а не каждый тег Zen: при выходе мажора Firefox (158 → 159) берём свежайший на тот момент тег Zen на этой базе; point-релиз (`x.0.1`) — только если в Mozilla security advisories для него есть High/Critical или exploited in the wild, либо он чинит то, во что мы упёрлись; Zen-only теги (Firefox не сменился) накапливаются до следующего ребейза, нужный фикс из них — cherry-pick. Напрямую на Firefox не ребейзимся никогда: ждём тег Zen (\~3 дня). Ожидаемый ритм — два плановых ребейза в месяц плюс редкие внеплановые, каждый ≈ 1–1,5 ч машинного времени (тарбол, import, полная сборка) плюс разбор конфликтов.

Runbook — это `scripts/bb/rebase.sh <тег Zen>`; у него одна цель — довести `main` до собранного и прокуренного билда на новом теге или остановиться на первом конфликте с отчётом. Человек нужен в двух местах: разобрать конфликт и пройти smoke; всё остальное скрипт делает сам.

1. Preflight. Чистое дерево, текущая ветка `main`, свободно ≥ 60 ГБ, установлен `gtar`. Читает `base` из `layer.yaml` (X) и целевой тег Y; открывает лог `$BB_LOG_DIR/rebase-<Y>-<дата>.log` (по умолчанию `../logs/`, как сейчас).
2. `git fetch upstream --tags --prune --progress` — через `ProxyJump tool`; дельта между тегами маленькая, но прогресс в терминале обязателен.
3. Разведка X → Y в лог и в отчёт: число коммитов апстрима, Firefox X → Y из `surfer.json`, изменения `.nvmrc`, `rust-toolchain.toml`, `package-lock.json`, `requirements.txt` (тулчейн меняется — скрипт говорит об этом до того, как что-то сломается), и «ожидаемые конфликты» — пересечение `git diff --name-only X Y` с файлами из `layer.yaml` и целями BB-патчей.
4. Ветка и ребейз: `git switch -c rebase/Y main` → `git rebase --onto Y bb/base/X`. Конфликт — стоп: список файлов с эпиком по `layer.yaml`, статус в отчёт; после `git rebase --continue` — `rebase.sh --continue Y`. `rerere` включён: повторяющиеся конфликты в хуках разрешаются сами.
5. Зависимости: `nvm use` при смене `.nvmrc`, `npm ci`. Быстро, npm доступен напрямую.
6. Engine. Firefox сменился — `rm -rf engine` → `npm run download` (тарбол из `.surfer/engine/`, если уже качали; с archive.mozilla.org — быстро) → `npm run bootstrap` при смене мажора. Firefox тот же — свой reset: `git -C engine reset -q && git -C engine checkout -q -- . && git -C engine clean -fdxq -e 'obj-*'`, чтобы сохранить objdir для инкрементальной сборки; штатный `npm run reset-ff` делает `git clean -fdx` и сносит objdir — для ребейза он не используется.
7. Патчи BB до import: `patches.sh check` на новом engine — каждый патч против чистого Firefox и против Firefox + патч Zen того же файла. Падение — стоп с именем патча и эпиком; разбор: `git apply --reject` в `engine/`, правка `.rej` руками или агентом, `patches.sh export`, снова `check`.
8. `npm run import` — ffprefs, dumps, surfer import (симлинки + 263 патча Zen + патчи BB). Любая ошибка surfer — стоп.
9. Сборка: `caffeinate -dims npm run build -- --jobs 6` с `tee` в лог; полная при смене Firefox (\~40 мин), инкрементальная иначе. Потом `npm run lint`.
10. Smoke: `smoke.sh` поднимает билд на копии рабочего профиля (`-profile /tmp/bb-smoke-<Y>`), печатает пункты чеклиста по одному и ждёт `y/n`; ответы уходят в отчёт. Чеклист собирается из `scripts/bb/smoke.d/<eN>.txt` — каждый ADR фичи добавляет свои пункты.
11. Финал при успехе: `npm run package` → DMG → установка в `/Applications` (daily driver — упакованное приложение, не `npm start` из objdir); коммит `rebase: Zen Y (Firefox ver)` с новым `base` в `layer.yaml` и отчётом `docs/rebase/<Y>.md`; `main := rebase/Y`, тег `bb/base/Y`, `git push --force-with-lease origin main --tags`, ветка `rebase/Y` удаляется. При провале `main` не тронут, `rebase/Y` остаётся для разбора, отчёт пишется со статусом failed и блокирующим пунктом.

Логирование — `scripts/bb/lib.sh`: обёртка `step "<имя>" <команда>` печатает заголовок с временем, ведёт `2>&1 | tee -a $LOG`, пишет длительность и код выхода; surfer и mach сами печатают прогресс, `git fetch` получает `--progress`, сборка — под `caffeinate`, чтобы ноутбук не уснул на 40-й минуте. Один лог на ребейз, по нему же `report.sh` берёт тайминги шагов.

Кэш — что хранится между ребейзами и где:

| Что | Где | Правило |
| --- | --- | --- |
| Тарбол Firefox (\~0,6 ГБ) | `.surfer/engine/firefox-<ver>.source.tar.xz` | surfer кэширует сам; `rebase.sh` оставляет два последних, старые удаляет |
| objdir | `engine/obj-*` | сохраняется при неизменном Firefox (свой reset в шаге 6); при смене Firefox сносится вместе с `engine/` |
| Тулчейны mach bootstrap | `~/.mozbuild` | общие, переживают всё; обновляются при смене мажора |
| Апстрим | `.git` (remote `upstream`) | дельта по тегам через `ProxyJump tool`; это единственный обязательный GitHub-трафик ребейза |
| `firefox-l10n` (release-сборка) | `~/zen-bro/cache/firefox-l10n` (bare mirror) | `scripts/bb/l10n.sh`: `fetch --depth 1 <hash из build/firefox-cache/>` + sparse-checkout только языков из `locales/supported-languages` (v1: en-US, ru) — вместо полного клона заново при каждом запуске, как делает скрипт Zen |

Режим `--worktree` — необязательный, для случая «фича с C++-патчем в работе, а ребейз делать надо»: `git worktree add ../rebase-<Y> rebase/<Y>`, `.surfer/engine` в нём — симлинк на общий `~/zen-bro/cache/firefox-src/`, полная сборка там; основной `engine/` и ветка фичи не прерываются. С >600 ГБ диска это дёшево, но по умолчанию engine один.

Smoke-чеклист v1 (пункты E0–E2; E3+ добавят свои):

- Запуск с копии рабочего профиля, окно рисуется, compact mode без рамок, нет новых ошибок в Browser Console в первые 30 с (сравнение с прошлым отчётом).
- Workspaces переключаются, новая вкладка попадает в контейнер своего workspace, essentials на месте.
- Glance, split, folders — открыть/закрыть по разу.
- `about:buildconfig` — флаги из `configs/bb/mozconfig` на месте; `about:config` — префы `bb.*` с ожидаемыми значениями.
- Вырезанное отсутствует по списку ADR-0003 (AI-кнопки, telemetry, sync, Zen Mods).
- uBlock Origin включён и блокирует (E10, когда появится).
- Перезапуск: сессия восстановилась, Little BB-окно не восстановилось (E3, когда появится).

Критерий «ребейз успешен» — все семь пунктов сразу: ребейз git завершён; `patches.sh check` зелёный; `npm run import` без ошибок; сборка прошла; `npm run lint` чист; smoke-чеклист весь `y`; отчёт записан. Mochitests Zen (`npm test`) в критерий не входят — запуск по желанию, когда ребейз задел `src/zen/tests`.

Метрика цены сопровождения — `docs/rebase/<Y>.md` на каждый ребейз и сводная таблица `docs/rebase/README.md` (строка на ребейз: тег, дата, Firefox, конфликты всего и по эпикам, часы). Конфликт считается в трёх видах, по эпику из `layer.yaml` и имени каталога: git-конфликт в ребейзе, BB-патч не наложился, хенк в патче Zen пришлось править. Эпик с ростом конфликтов от ребейза к ребейзу — кандидат на переход от прямых правок к подмене модуля; суммарная цена в часах — вход для январского чекпоинта про hard fork.

## Границы — где живут брендинг, mozconfig и вырезание

Содержимое этих трёх вещей решают E0 и ADR-0003; этот ADR фиксирует только место в слое, чтобы они с первого дня ложились по правилам Решений 1–2.

| Что | Где в слое | Механизм | Решает |
| --- | --- | --- | --- |
| Брендинг: имя, иконки, bundle id, `about:`-страницы, first-run | `configs/branding/bb/` + бренд `bb` в `surfer.json`; тексты — `src/bb/branding/` | штатный branding-patch surfer; `surfer.json` — прямая правка (класс 2) | E0 |
| `mozconfig` release (PGO/LTO, SDK) и build-флаги вырезания (`--disable-*`, `MOZ_*=`) | `configs/bb/mozconfig`, `configs/bb/mozconfig.macos` | одна строка-хук в `configs/common/mozconfig`; флаги Zen не дублируем, только добавляем или переопределяем | E0, ADR-0003 |
| Вырезание уровня «удалить файлы / заглушка» | `src/bb/patches/e1-strip/<имя>/` | BB-патчи по Решению 2, README с обоснованием на каждый | ADR-0003 |
| Вырезание уровня prefs/policies | `prefs/bb/strip.yaml`, `prefs/bb/security.yaml`; policies — `src/bb/policies/policies.json` через `distribution/` | без хуков (prefs); `distribution/` — через `jar.inc.mn` или `package` | ADR-0003, ADR-0004 |
| Апдейтер: отключить или перенацелить | `prefs/bb/updates.yaml` + `updateHostname` в `surfer.json` | prefs + прямая правка `surfer.json` | E0 |
| Предустановка uBlock Origin | `surfer.json: addons` (штатный механизм surfer) | без патчей | E10 |

Исключение из правила «один патч на файл» для вырезания не делается: если ADR-0003 потребует хенк в файле, который Zen уже патчит, работает пункт 4 Решения 2.

## Последствия

Плюсы:

- Слой читается одной командой (`git log bb/base/<тег>..main`) и в нём нет ничего, что нельзя отнести к эпику: каталог, README или строка в `layer.yaml`.
- Ничего не добавлено в механику surfer: `npm run init` на свежем клоне даёт BB-билд; обвязка BB только проверяет, экспортирует и отчитывается.
- Каждая фича выключается pref'ом до стокового Zen — регрессию после ребейза можно локализовать за минуты, не за часы.
- Ребейз — один скрипт с логом и отчётом; человек нужен ровно на конфликт и на smoke. Это же и вход для rebase-бота из E11 — ему не нужно ничего, кроме тех же команд.
- Хуки в плоских файлах Zen вместо патчей: конфликт по ним — обычный merge строки, и `rerere` решает его повторно сам.

Минусы и цена сопровождения:

- Появляется своя обвязка (`scripts/bb/`, \~5 скриптов) и два правила, которые нужно помнить: `npm run export` запрещён для файлов с BB-патчем, `npm run reset-ff` не используется в ребейзе. Оба записываются в `CLAUDE.md`.
- Правило непересечения хенков ограничивает: когда изменение попадает внутрь хенка Zen, остаётся правка патча Zen — самая дорогая форма. Сколько таких случаев, покажет ADR-0003 и E3.
- Force-push в `main` и завершение фич через `--onto`: ошибка в `rebase.sh` может снести `main` — отсюда `--force-with-lease` и правило «`main` трогает только скрипт».
- Триггер «по базе Firefox» означает, что между мажорами мы носим Zen-only фиксы с задержкой до двух недель; на компенсацию — cherry-pick.
- Порядок наложения патчей в surfer остаётся недетерминированным; `patches.sh check` снимает риск для BB-патчей, но не для гипотетического пересечения двух патчей Zen — это их проблема, не наша.
- Release-сборка с локалями по-прежнему зависит от GitHub (`firefox-l10n`); кэш и sparse-checkout снижают трафик, но не убирают зависимость.

## Риски и план проверки (фаза 0, до 7 ноября)

Ключевой риск — R1: патч ADR-0001 упрётся в хенки Zen в `SessionStore.sys.mjs` или `browser.js`, и «отдельный патч с README» для него окажется невозможен. Тогда либо правим патч Zen (самая дорогая форма), либо переносим исключение Little BB из `SessionStore` Firefox в `src/zen/sessionstore/` Zen — хук класса 2. Проверяется первым же реальным патчем.

| # | Риск | Как проверяем | Митигация |
| --- | --- | --- | --- |
| R1 | Хенки BB пересекаются с хенками Zen в файлах ADR-0001 | Написать патч ADR-0001, `patches.sh check` | Хенк в патч Zen (Решение 2, п. 4) или перенос логики в `src/zen/` хуком |
| R2 | `patches.sh export` (временный индекс) даёт патч, который surfer не накладывает | `export` → свой reset → `npm run import` → `status` | Те же флаги, что у `surfer export`: `--src-prefix=a/ --dst-prefix=b/ --full-index` |
| R3 | Недетерминированный порядок глоба всё же ломает import | Два прогона `import` подряд с BB-патчем на файле Zen | `check` гарантирует применимость в обоих порядках; иначе — вариант C |
| R4 | `--fork-point` по reflog берёт не ту базу при завершении фичи | Dry-run на тестовой ветке после force-push `main` | Тег `bb/fork/<feat>` при создании ветки — явная база вместо reflog |
| R5 | Новый тег меняет Node/Rust/SDK, сборка падает после часа работы | Шаг 3 runbook'а печатает diff тулчейна до ребейза | `nvm`, `rustup`, SDK-список в `configs/macos/mozconfig`; stop до сборки |
| R6 | Свой reset `engine/` (`clean -fdx -e obj-*`) оставляет мусор, ломающий import | Первый ребейз при неизменном Firefox | Fallback на `npm run reset-ff` ценой полной пересборки |
| R7 | Workflows Zen в `.github/` запускаются в форке на push в `main` | Посмотреть Actions после первого push | Выключить Actions в настройках форка; заготовка CI — E0 |
| R8 | Цена ребейза для одного человека выше, чем кажется | Хронометраж dry-run и первого реального ребейза | > 4 ч человеческого времени — пересмотр триггера на «только мажор» и правила непересечения в пользу C |

План проверки:

1. Скелет слоя: `src/bb/` с `moz.build`, `BBStartup.mjs`, `jar.inc.mn`, `layer.yaml`, `prefs/bb/bb.yaml` с одним pref `bb.layer.version`; пять строк-хуков. `npm run import && npm run build:ui` → в `about:config` есть `bb.*`, в Browser Console — строка от `BBStartup`.
2. Первый BB-патч — учебный, на файл, который Zen патчит (`browser.js`), вдали от его хенков: `check` → `export` → `import` → `status`; второй `import` подряд; `surfer reset` → `import`. Закрывает R2, R3.
3. Репо: `bb` → `main`, default в GitHub, `dev` удалён, Actions выключены, тег `bb/base/1.23.4b` запушен. Закрывает R7.
4. Dry-run runbook'а на существующих тегах, не дожидаясь Firefox 159 (тег Zen на нём ожидается после 7 ноября): собрать `main'` на 1.23.3b (Firefox 158.0) с тем же слоем и прогнать `rebase.sh 1.23.4b` — это полный путь со сменой тарбола, bootstrap не нужен. Измерить часы, получить первый `docs/rebase/1.23.4b.md`. Закрывает R5, R6, R8.
5. Патч ADR-0001 как первый настоящий потребитель Решения 2 — на старте фазы 1; результат `check` решает R1.

Go/No-Go: если dry-run (п. 4) не укладывается в 2 ч машинного и 2 ч человеческого времени, или R1 требует править патчи Zen в двух и более файлах, — вариант C (свой applier с явным порядком) выносится на отдельное обсуждение до начала E3.

## Вне scope

- Содержимое `configs/bb/mozconfig`, список вырезания и обоснования — ADR-0003; prefs безопасности и скорости — ADR-0004.
- Брендинг, Developer ID, нотаризация, DMG, update-канал — E0.
- Rebase-бот, release-бот, точки одобрения человека — ADR-0012; здесь только то, что `scripts/bb/` пригодны как их вход.
- Сборки Windows/Linux и CI Zen в форке (кроме «выключить»).
- Тесты для `src/bb/` (mochitests, `TESTING_JS_MODULES`) — после E3, когда появится что тестировать.
- Hard fork и режим «следуем за Firefox ESR» — январский чекпоинт по метрике из Решения 4.

## Ссылки

Документы BB: [скоуп v1](https://claude.ai/artifact/DxUCwLXfELAJX4qPTAiii5), [ADR-0001](https://claude.ai/artifact/U2oF6RTwr1fKi8EG1Xf9RF).

surfer 1.14.9 (`node_modules/@zen-browser/surfer/dist/`), прочитано для этого ADR:

- `commands/patches/command.js` — `applyPatches()`: порядок surfer-патчи → брендинг → симлинки → `**/*.patch` → cert; `copy-patches.js` — симлинки и `engine/.gitignore`; `git-patch.js` — `git apply -R` + `apply` с `--ignore-space-change --ignore-whitespace`
- `commands/export-file.js` — `git diff --src-prefix=a/ --dst-prefix=b/ --full-index`, имя патча из пути
- `commands/download/firefox.js` — кэш `.surfer/engine/`, скачивание только при отсутствии `engine/`; `commands/init.js` — `git init` + коммит «Firefox \<ver>»; `commands/reset.js` — `git clean -fdx`
- `commands/build.js` — сборка `engine/mozconfig` из `configs/common`, `configs/<os>`, корневого `mozconfig`

Zen (`src/`, `scripts/`, `tools/`): `src/browser/base/moz-build.patch` (единственный хук `src/zen/` в сборку), `src/zen/moz.build`, `src/zen/ZenComponents.manifest`, `src/zen/common/ZenPreloadedScripts.js`, `src/browser/base/content/zen-assets.jar.inc.mn`, `zen-assets.inc.xhtml`, `src/external-patches/manifest.json` + `README.md` (прецедент второго патча на файл с README), `tools/ffprefs/src/main.rs` (рекурсивное чтение `prefs/`, сортировка по имени, вывод в `zen.js` / `zen-static-prefs.inc`), `scripts/recalculate-patches.sh`, `scripts/update_ff.py` (как Zen бампает Firefox), `scripts/download-language-packs.sh` (полный клон `firefox-l10n` при каждом запуске).

Репозитории: [broplz/brozen-browser](https://github.com/broplz/brozen-browser), [zen-browser/desktop](https://github.com/zen-browser/desktop), [zen-browser/surfer](https://github.com/zen-browser/surfer); референс патч-серии поверх Firefox — [LibreWolf](https://codeberg.org/librewolf/source).

git: `rebase --onto`, `merge-base --fork-point`, `rerere`, `apply --reject` / `--cached` / `GIT_INDEX_FILE`, `worktree`, `push --force-with-lease`.

## Приложение — состояние репо (24.10.2026)

Вывод из свежего клона `origin/bb` (== 1.23.4b, `541ee55`); `git remote -v` здесь показывает клон, в локальной копии — `origin` и `upstream` по SSH. Локали в `tree` свёрнуты.

```
$ tree -L 2 -I 'engine|node_modules|.git'
.
|-- CODEOWNERS
|-- CODE_OF_CONDUCT.md
|-- LICENSE
|-- README.md
|-- SECURITY.md
|-- babel.config.json
|-- build
|   |-- AppDir
|   |-- firefox-cache          # l10n-last-commit-hash
|   |-- flatpak
|   |-- signing               # public_key.der
|   |-- ts
|   `-- windows
|-- configs
|   |-- branding              # release/, twilight/
|   |-- common                # mozconfig
|   |-- dumps
|   |-- linux
|   |-- macos                 # mozconfig
|   `-- windows
|-- crowdin.yml
|-- docs
|   |-- assets
|   |-- contribute.md
|   |-- issue-metrics
|   `-- live-folders-specs.md
|-- eslint.config.mjs
|-- locales
|   |-- <46 каталогов локалей: ar … zh-TW>
|   |-- language-maps
|   |-- supported-languages
|   `-- update-supported-languages.sh
|-- package-lock.json
|-- package.json
|-- prefs
|   |-- README.md
|   |-- fastfox
|   |-- firefox
|   |-- privatefox
|   `-- zen
|-- requirements.txt
|-- rust-toolchain.toml       # 1.95.0
|-- scripts                   # см. ниже
|-- src
|   |-- -prettierignore.patch
|   |-- -stylelintignore.patch
|   |-- -stylelintrc-js.patch
|   |-- accessible
|   |-- browser
|   |-- build
|   |-- devtools
|   |-- docshell
|   |-- dom
|   |-- editor
|   |-- eslint-file-globals-config-mjs.patch
|   |-- eslint-ignores-config-mjs.patch
|   |-- eslint-test-paths-config-mjs.patch
|   |-- external-patches      # firefox/, librewolf/, manifest.json
|   |-- gfx
|   |-- image
|   |-- layout
|   |-- modules
|   |-- python
|   |-- security
|   |-- services
|   |-- servo
|   |-- testing
|   |-- toolkit
|   |-- tools
|   |-- widget
|   |-- xpfe
|   `-- zen
|-- surfer.json
|-- svgo.config.js
|-- tools
|   |-- eslint-plugin-spidermonkey-js
|   |-- ffprefs
|   `-- virustotal-checker
`-- tsconfig.json

94 directories, 46 files
```

```
$ ls src/ src/zen/
src/:
-prettierignore.patch  -stylelintignore.patch  -stylelintrc-js.patch
accessible  browser  build  devtools  docshell  dom  editor
eslint-file-globals-config-mjs.patch  eslint-ignores-config-mjs.patch  eslint-test-paths-config-mjs.patch
external-patches  gfx  image  layout  modules  python  security  services  servo
testing  toolkit  tools  widget  xpfe  zen

src/zen/:
@types  ZenComponents.manifest  boosts  common  compact-mode  downloads  drag-and-drop
folders  fonts  glance  images  kbs  library  live-folders  media  mods  moz.build
sessionstore  share  space-routing  spaces  split-view  sync  tabs  tests  toolkit
urlbar  vendor  welcome  window-drag  zen.globals.mjs
```

```
$ cat surfer.json
{
  "name": "Zen Browser", "vendor": "Zen OSS Team", "appId": "zen", "binaryName": "zen",
  "version": { "product": "firefox", "version": "158.0.1", "candidate": "158.0.1", "candidateBuild": 1 },
  "buildOptions": { "generateBranding": true },
  "addons": {},
  "brands": {
    "release":  { "backgroundColor": "#282A33", "brandShorterName": "Zen", "brandShortName": "Zen",
                  "brandFullName": "Zen Browser",
                  "release": { "displayVersion": "1.23.4b", "github": { "repo": "zen-browser/desktop" },
                               "archives": { "windows": "windows.mar", "macos-aarch64": "macos-aarch64.mar",
                                             "linux": "linux.mar", "macos-x64": "macos-x64.mar",
                                             "windows-arm64": "windows-arm64.mar", "linux-aarch64": "linux-aarch64.mar" } } },
    "twilight": { "backgroundColor": "#282A33", "brandShorterName": "Zen", "brandShortName": "Twilight",
                  "brandFullName": "Zen Twilight",
                  "release": { "displayVersion": "1.24t", "github": { "repo": "zen-browser/desktop" } } }
  },
  "license": { "ignoredFiles": [ ".*\\.json" ], "licenseType": "MPL-2.0" },
  "updateHostname": "updates.zen-browser.app"
}
```

```
$ jq .scripts package.json
{
  "build": "surfer build",
  "build:ui": "surfer build --ui",
  "start": "cd engine && python3 ./mach run --noprofile",
  "start:bloat": "XPCOM_MEM_BLOAT_LOG=1 npm start",
  "import": "npm run ffprefs && npm run import:dumps && surfer import",
  "import:dumps": "python3 scripts/update_service_dumps.py",
  "export": "surfer export",
  "init": "npm run download && npm run import && npm run bootstrap",
  "download": "surfer download",
  "bootstrap": "surfer bootstrap",
  "package": "surfer package",
  "sync": "python3 scripts/update_ff.py",
  "sync:raw": "surfer update",
  "sync:rc": "python3 scripts/update_ff.py --rc",
  "sync:l10n": "python3 scripts/update_ff.py --just-l10n",
  "lint": "cd engine && ./mach lint zen",
  "lint:fix": "npm run lint -- --fix",
  "reset-ff": "surfer reset",
  "surfer": "surfer",
  "test": "python3 scripts/run_tests.py",
  "test:dbg": "python3 scripts/run_tests.py --jsdebugger --debug-on-failure",
  "test:gtest": "cd engine && ./mach gtest Zen*",
  "ffprefs": "cd tools/ffprefs && cargo run --bin ffprefs -- ../../",
  "lc": "surfer license-check",
  "lc:fix": "surfer license-check --fix",
  "use-moz-src": "cd engine && ./mach use-moz-src",
  "ci": "surfer ci --brand release --display-version"
}
```

```
$ ls scripts/
check_rc_response.py        download_pgo_extended_corpus.py  json_with_comments.py    recalculate-patches.sh  update-surfer.sh
copy_language_pack.py       fetch-formal-git-components.sh   mar_sign.sh              remove-failed-jobs.sh   update_en_US_packs.py
download-language-packs.sh  import_external_tests.py         mar_verify.sh            run_tests.py            update_external_patches.py
prepare-flatpak-release.py  update_ff.py                     update_service_dumps.py  update_ts_types.py
```

```
$ git remote -v && git log --oneline -5
origin   https://github.com/broplz/brozen-browser.git (fetch)   # локально: git@github.com:broplz/brozen-browser.git + upstream = zen-browser/desktop
origin   https://github.com/broplz/brozen-browser.git (push)
541ee55 gh-15457: Convert media tabs into a system module (gh-16058)      # == tag 1.23.4b == upstream/stable
c0dffc1 gh-16049: Check fullscreen attribute for space icons (gh-16053)
8766899 gh-16049: Ignore resizings if fullscreen (gh-16050)
4ac75ab gh-12140: Fixed multiple windows launching on startup (gh-16047)
ccf9c72 gh-14238: Route external links during startup (gh-15240)
```

Дополнительно: ветки форка — `bb`, `dev` (default); ветки апстрима — `dev`, `stable` (== 1.23.4b) и несколько feature-веток; патчей в `src/` — 263 (13 775 строк), самые большие — `Tabbrowser-sys-mjs.patch` (1 308), `backdrop_filter_reads_web_content.patch` (1 121), `UrlbarInputBase-mjs.patch` (698), `SessionStore-sys-mjs.patch` (437). Файлы, которые патчит и Zen, и его `external-patches/`: `toolkit/moz.configure`, `widget/cocoa/nsCocoaWindow.h`, `widget/cocoa/nsCocoaWindow.mm`.
