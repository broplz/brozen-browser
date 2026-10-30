# ADR-0001 · Little BB: плавающее окно (macOS Spaces/fullscreen) и изоляция от синхронизации Zen

## Статус

Proposed — v2, 31.10.2026. v1 от 24.10.2026 (@broplz) восстановлена из Claude Doc и закоммичена тем же днём; v2 учитывает Firefox bug 1688932 (вошёл в 158) и spike 31.10 через Browser Console. Статус меняется на Accepted после решения владельца по разделу «Решения владельца» и зелёного spike (задача e3-01).

- Область: `feat/layer` от тега 1.23.4b (Zen на Firefox 158.0.1), macOS в первую очередь; слой по ADR-0002, эпик `e3-little-bb`.
- Основание: Step 0 (24.10, `alwaysontop`), spike 31.10 (`mediapip`, `mediapip,alwaysontop`), код `engine/` 158.0.1 (строки ниже), Bugzilla 1688932.
- Связанные ADR (не написаны): маршрутизация внешних ссылок; UI/UX окна Little BB (туда уходит требование F7).

Теги: **[verified]** — код в `engine/`, Bugzilla или воспроизведено на сборке; **[open]** — проверяется задачей; **[my judgment]** — оценка.

## Контекст и проблема

Little BB — аналог Little Arc: ссылка из другого приложения открывается в компактном окне BB, а не во вкладке основного окна. Окно висит поверх всех окон, включая native fullscreen других приложений, живёт только на том Space, где пользователь был в момент клика, и остаётся обычным Gecko-окном: контейнеры, логины, расширения работают, а «Открыть в BB» переносит вкладку в основное окно без перезагрузки.

Step 0 (24.10, `openDialog` с `alwaysontop`) показал два разрыва:

1. `alwaysontop` в `nsCocoaWindow` = `NSFloatingWindowLevel` + `CanJoinAllSpaces` (`nsCocoaWindow.mm:5383–5387` **[verified]**) — поведение сделано под Picture-in-Picture. Окно на всех обычных десктопах, но в чужой fullscreen-Space не входит.
2. Окно — полный `browser.xhtml`, и session manager Zen клонирует в него вкладки workspace. Окно участвует в кросс-оконной синхронизации как обычное.

### Что изменилось с v1

Firefox bug 1688932 («PiP doesn't work in macOS full screen») закрыт FIXED, Target Milestone 158 Branch **[verified, Bugzilla]** — то есть механизм есть в нашей базе. Автор замерил через `SLSFindWindowByGeometry`: поверх чужого fullscreen-Space всплывает только окно с `NSWindowStyleMaskNonactivatingPanel` и без `FullScreenPrimary`; уровень окна роли не играет; обычный `NSWindow` с `CanJoinAllSpaces + FullScreenAuxiliary` — **не** всплывает **[verified, комм. 22]**. Целевая конфигурация v1 («`MoveToActiveSpace | FullScreenAuxiliary` на NSWindow») этому противоречит и в чистом виде не сработала бы.

Как это реализовано в 158.0.1 **[verified, engine]**:

- `nsWindowWatcher.cpp:2024` — chrome-only feature `mediapip` → `CHROME_MEDIA_PIP`; `:2018` — feature `suppressinitialfullscreen`.
- `nsAppShellService.cpp:504` — `CHROME_MEDIA_PIP` → `InitData.mPiPType = MediaPiP` (macOS включён).
- `nsCocoaWindow.mm:5389–5405` — для `MediaPiP`: `styleMask |= NonactivatingPanel`, `collectionBehavior |= FullScreenAuxiliary | FullScreenDisallowsTiling`; `:5420–5436` — такому окну не ставится `FullScreenPrimary` (зелёная кнопка — zoom, не fullscreen); `:8326–8341` — `BaseWindow` (всё ещё `NSWindow`, не `NSPanel`) сохраняет бит `NonactivatingPanel` переопределением `+_validateStyleMask:`; `:7723` — `hidesOnDeactivate = NO`.
- Для `alwaysontop` при показе подавляется восстановление `sizemode=fullscreen` **[verified, комм. 21]**.

### Spike 31.10 (Browser Console, `openDialog("chrome://browser/content/browser.xhtml", "_blank", <features>)`, переключение на fullscreen Arc за 5 с)

| Features | F1 поверх чужого fullscreen | F2 один Space | F3 Space не переключается | F6 не уходит в fullscreen сам | Ввод/клики в окне |
|---|---|---|---|---|---|
| `alwaysontop` (Step 0) | нет | нет | — | — | да |
| `mediapip` | **нет** — окно легло на Space BB | да | да | **нет** — восстановил `sizemode=fullscreen` основного окна | нет |
| `mediapip,alwaysontop` | **да** | **нет** — следует за свайпом | да | да | **нет** — адресная строка и кнопки не реагируют, даже когда BB активен |
| Штатный PiP-плеер (`player.xhtml`) поверх Arc | да | — | да | — | **да** — пауза, громкость, все кнопки |

Выводы **[verified, spike]**: F1 и F3 даёт штатный `mediapip,alwaysontop`, без патча. `CanJoinAllSpaces` (от `alwaysontop`) одновременно и пускает окно в чужой fullscreen-Space, и заставляет его следовать по Spaces — F1 и F2 штатно несовместимы. Панель принимает клики (плеер работает), но `browser.xhtml` на них не реагирует — проблема в Gecko/Zen-слое (активность/фокус окна), а не в окне macOS.

## Требования и драйверы решения

Функциональные:

- **F1.** Поверх всего, включая fullscreen-Space других приложений и BB в native fullscreen.
- **F2.** Только текущий Space: окно создаётся там, где был пользователь, и **не следует** за сменой Space. Решение владельца 31.10: обязательно для v1, стоит C++-патча.
- **F3.** Открытие ссылки не переключает Space на основное окно BB.
- **F4.** Полноценный браузинг: e10s/Fission, контейнеры, расширения, prompts, `window.open` из контента; ввод в адресную строку и клики по chrome работают, когда окно висит поверх чужого fullscreen.
- **F5.** Окно не участвует в Zen workspaces / pinned / essentials sync и не восстанавливается SessionStore как отдельное окно.
- **F6.** Окно никогда не становится отдельным fullscreen-окном со своим Space — ни само (persist `sizemode`), ни по зелёной кнопке.
- **F7.** Зелёная кнопка мини-окна → страница становится вкладкой в **активном** основном окне BB, мини-окно закрывается. Механика (перехват/свои кнопки титл-бара) — UI-ADR; здесь только требование.

Нефункциональные:

- **N1.** Минимальный и изолированный diff в C++/ObjC: каждый ребейз — конфликт-риск (263 патча Zen в `npm run init`). Это единственное оговорённое исключение из правила «ноль правок файлов Zen/Firefox»; каждая итерация — полная сборка.
- **N2.** Семантику `alwaysontop` и `mediapip` не менять: PiP-плеер Zen рассчитывает на них. Только аддитивный флаг, no-op на Windows/Linux.
- **N3.** Один механизм задаёт поведение при создании окна и виден и widget-слою, и JS.
- **N4.** Никаких новых AI-поверхностей (принцип BB).

## Решение 1 — уровень окна и Spaces на macOS

| Вариант | Суть | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| A. `alwaysontop` | Штатный feature | Ноль патчей | Не входит в чужой fullscreen; все Spaces | Отвергнут (Step 0) |
| B. Поменять семантику `alwaysontop` | Снять `CanJoinAllSpaces` в `nsCocoaWindow` | Минимальный diff | Ломает PiP (N2) | Отвергнут |
| **G. `mediapip,alwaysontop` штатно** | Конфигурация PiP-плеера из бага 1688932 | Ноль патчей; F1, F3, F6 **[verified]** | F2 нет (следует); `browser.xhtml` не принимает ввод **[verified]**; признак окна делится с реальным PiP | **База**: всё, что не требует патча, берём отсюда |
| **C′. `bbfloating` поверх G** | Feature `bbfloating` → `CHROME_BB_FLOATING` (`nsIWebBrowserChrome.idl`, `nsWindowWatcher.cpp` рядом с `:2024`) → `InitData.mBBFloating` (`nsAppShellService.cpp` рядом с `:504`) → `nsCocoaWindow.mm` рядом с `:5389`: как `MediaPiP` (`NonactivatingPanel`, `FullScreenAuxiliary|DisallowsTiling`, без `FullScreenPrimary`), **плюс** `NSFloatingWindowLevel`, **без** `CanJoinAllSpaces`, с `MoveToActiveSpace`; `alwaysontop` и `mediapip` не трогаются | Аддитивно, ~4 файла Firefox, по готовому паттерну; chromeFlags читаются из JS → тот же флаг = признак окна (Решение 2); F2 | F2 через `MoveToActiveSpace` без `CanJoinAllSpaces` **не проверено** — macOS может не пустить окно неактивного приложения в чужой fullscreen-Space **[open, e3-01]**; ввод в `browser.xhtml` патч сам по себе не чинит **[open, e3-01]** | **Рекомендован**, при условии зелёного spike |
| C″. Запасной для F2 | Если `MoveToActiveSpace` не пускает в fullscreen-Space: открывать с `CanJoinAllSpaces`, после первого `orderFront` снимать его из `nsCocoaWindow` (окно уже назначено Space) | Повторяет то, что точно работает (G) | Рантайм-мутация collectionBehavior — поведение AppKit надо мерить | Запасной путь внутри e3-01 |
| D. Рантайм API (`SetFloatingBehavior`) | Pin/unpin из JS | Динамика | IDL + заглушки во всех бэкендах; нет признака при старте | Отложен |
| E. XUL `<panel>` | `NSPopUpMenuWindowLevel` | Без C++ | Не key window, привязан к родителю, нет переноса вкладки | Отвергнут |
| F. Внешний helper (Swift + WKWebView) | Отдельная панель | Контроль над NSWindow | Не Gecko (F4) | Отвергнут |

Открытый вопрос, который решает spike, а не ADR: почему `browser.xhtml` в nonactivating-окне не реагирует на клики, когда `player.xhtml` реагирует. Гипотезы **[my judgment]**: (а) окно не становится key — для `BaseWindow`-`NSWindow` с чужим битом AppKit не делает его key по клику, а `player.xhtml` обходится без фокуса; (б) `browser.js`/Zen гейтят обработку на `window.windowState`/активность окна; (в) упстрим в комм. 32 перешёл на настоящий `NSPanel`-подкласс именно из-за этого — в 158 лежит хак с `_validateStyleMask:`. Если (а) — патч расширяется до `canBecomeKeyWindow`/`NSPanel`-подкласса для `mBBFloating`; если (б) — это JS-слой BB без C++.

## Решение 2 — признак окна и исключение из синхронизации Zen

Без изменений относительно v1, с одной поправкой: признак окна — `CHROME_BB_FLOATING`, а не `CHROME_MEDIA_PIP`, потому что последний делится с реальным PiP-плеером Zen.

Места, где Firefox и Zen считают Little BB «ещё одним окном браузера»:

- Session manager / workspaces Zen: при открытии клонирует вкладки workspace (Step 0 и spike: лог `ZenSessionManager.sys.mjs:125`, `ZenSpaceManager.mjs:93` **[verified]**), при изменениях рассылает их по всем окнам (`Services.wm.getEnumerator("navigator:browser")`, `BrowserWindowTracker.orderedWindows`).
- Sync pinned / essentials между окнами.
- `BrowserWindowTracker.getTopWindow()`: если Little BB — верхнее окно, следующая внешняя ссылка уйдёт в него.
- SessionStore: сохраняет и восстанавливает окно после рестарта.
- «Move tab to window», Mission Control, Cmd-` — UI-ADR.

| Вариант | Суть | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| E1. Popup по семантике Firefox | Features без toolbar/menubar → `window.toolbar.visible === false` | Без патчей: `BrowserWindowTracker` не отдаёт попапы в `getTopWindow`; SessionStore помечает `isPopup` | Zen sync про попапы не знает | База |
| E2. Явный признак + исключения в точках синка | Признак = `CHROME_BB_FLOATING`, обёртка `BBLittle.isLittleWindow(win)`; атрибут `bb-little` на `documentElement` до инициализации Zen; исключения в session manager/workspaces, pinned/essentials, `BrowserWindowTracker`, SessionStore | Полный `browser.xhtml` → F4; «Открыть в BB» = `gBrowser.adoptTab` | Точки итерации по окнам в Zen живут и переезжают | **Рекомендован** |
| E3. Свой windowtype (`navigator:bb-little`) | Окно не `navigator:browser` | Автоматически выпадает из перечислений | `browser.js`/Zen завязаны на `navigator:browser` | Гибрид с E2 для SessionStore |
| E4. Отдельный документ `bb-little.xhtml` | Один `<browser>` + мини-тулбар, как `player.xhtml` | Ничего не синкается; и — по spike — `player.xhtml` в nonactivating-окне **работает** | F4 заново: prompts, `window.open`, контекстное меню, контейнеры; перенос через `swapFrameLoaders` | Отвергнут для v1; **поднимается до запасного**, если ввод в `browser.xhtml` упрётся в (б) |

Механизм исключений — по ADR-0002/ADR-0003: подмена инстансов `gZen*` из `BBStartup.mjs` за префом, не хуки в `src/zen/`; хук в файле Zen — только с отдельным одобрением владельца **[my judgment]**.

## Рекомендуемое решение

G + C′ + E2 на базе E1:

1. Little BB — `browser.xhtml` через `Services.ww.openWindow` с features `chrome,dialog=no,resizable,titlebar,mediapip,bbfloating,suppressinitialfullscreen` плюс popup-набор (`toolbar=no,...`; точный список — UI-ADR). `mediapip` даёт nonactivating/Auxiliary штатно; `bbfloating` добавляет уровень, снимает `CanJoinAllSpaces`, ставит `MoveToActiveSpace` и служит признаком.
2. `bbfloating` → `CHROME_BB_FLOATING` → `InitData.mBBFloating` → `nsCocoaWindow::CreateNativeWindow`. Семантика `alwaysontop`/`mediapip` не трогается. Windows/Linux — no-op.
3. JS-признак: `BBLittle.isLittleWindow(win)` = `chromeFlags & CHROME_BB_FLOATING`; атрибут `bb-little` до инициализации Zen.
4. По признаку исключаются session manager/workspaces, pinned/essentials, `BrowserWindowTracker`, SessionStore (Решение 2).
5. «Открыть в BB» = `mainWin.gBrowser.adoptTab(tab)` в активное основное окно, затем `close()`; привязка к зелёной кнопке — UI-ADR (F7).

## Последствия

Плюсы:

- Основная тяжесть (nonactivating-панель поверх чужого fullscreen, не переключая Space) уже в Firefox и живёт там — наш патч стал меньше, чем в v1, и не дублирует upstream.
- Один источник истины для native и JS; полный `browser.xhtml`.

Минусы и цена:

- Патч в `widget/cocoa` + IDL: полная сборка на каждую итерацию (~45 мин на M3 Max), ребейз при каждом Firefox; отдельный `.patch` в `src/bb/patches/e3-little-bb/floating-window/` с README; `patches.sh check` против патчей Zen тех же файлов.
- Если ввод в `browser.xhtml` упрётся в key-поведение, патч расширяется (гипотеза (а)) — это уже не «~4 файла по паттерну».
- Список точек исключения в Zen — живой; чеклист на каждый ребейз.

## Риски и план проверки

| # | Риск | Статус / как проверяем | Митигация |
|---|---|---|---|
| R1 | Переключение Space при активации BB | **Закрыт** **[verified, spike]**: nonactivating-окно не активирует приложение | — |
| R2 | `NSFloatingWindowLevel` недостаточно | **Закрыт** **[verified, комм. 22]**: уровень не влияет | — |
| R3 | Трасса в 158 отличается | **Закрыт**: файлы и строки подтверждены (см. «Что изменилось») | — |
| R4 | `adoptTab` между окнами с разными chromeFlags и workspaces Zen | Перенос вкладки с логином без перезагрузки | Fallback `swapDocShells` |
| R5 | SessionStore восстанавливает Little BB | Открыть, перезапустить | Патч по признаку или гибрид E3 |
| R6 | Dev-билд не грузит `ZenGlanceChild`/`ZenBoostsChild`/`ZenWindowDragChild` | Разобраться до e3-01 | Иначе ошибки замаскированы |
| R7 | Конфликты патча при обновлении Firefox | На каждом ребейзе | Патч минимальный, отдельный `.patch` |
| **R8** | `browser.xhtml` не принимает ввод/клики в nonactivating-окне | **Открыт, блокер** **[verified, spike]**; e3-01: сравнить с `player.xhtml`, проверить `isKeyWindow`/`windowDidBecomeKey` | Гипотезы (а)/(б)/(в) выше; запасной путь E4 |
| **R9** | `MoveToActiveSpace` без `CanJoinAllSpaces` не пускает в чужой fullscreen-Space | **Открыт** **[open, e3-01]** | C″ |
| **R10** | Bug 2067479 (ASSIGNED): PiP не появляется при переходе на fullscreen-Space | Проверить на патченной сборке | Следить за upstream |
| **R11** | VoiceOver: `AXFrontmost` активирует приложение и уводит со Space (комм. 33, обход в `GeckoNSApplication`) — в 158 обход есть? | `grep AXFrontmost engine/widget/cocoa/` **[open]** | Повторить обход для `mBBFloating`, если его нет |

План:

- **e3-01 (spike, developer-hard, build full, `needs_approval: true`)**: патч C′ как отдельный BB-патч с README; Browser Console с `mediapip,bbfloating,suppressinitialfullscreen`. DoD: поверх fullscreen Arc; не следует при свайпе; Space не переключается; зелёная кнопка — zoom, не fullscreen; ввод в адресную строку и клик по кнопкам работают поверх Arc. Любой красный пункт → отчёт с измерениями (`isKeyWindow`, `collectionBehavior`), ADR остаётся Proposed, выбор между C″/E4.
- **e3-02 (JS, developer, build ui, параллельно)**: `BBLittle.isLittleWindow`, атрибут `bb-little`, исключение из session manager/workspaces и `BrowserWindowTracker` через подмену из `BBStartup.mjs`; проверка на окне из G (без патча — признак временно по `window.name`).
- После зелёного e3-01: ADR → Accepted; маршрутизация и UI — отдельные ADR.

## Решения владельца

- **31.10.2026:** F2 («не следует за Space») — обязательно для v1, патч оправдан. F6 — обязательно. F7 — зелёная кнопка превращает страницу во вкладку активного основного окна (UI-ADR).
- **Открыто:** одобрить e3-01 как первый C++-патч в репо (единственное исключение из «ноль правок»).

## Вне scope

- Маршрутизация внешних ссылок (`-osint`, `application:openURLs:`, Space Routing Zen) — отдельный ADR.
- UI/UX окна: размер, позиция, `chromehidden`, тулбар, pin, автозакрытие, Mission Control, перехват зелёной кнопки (F7) — отдельный ADR.
- Auto-PiP, шорткаты (Cmd+Shift+] у Zen занят под вкладки) — другие эпики.
- Паритет на Windows/Linux.

## Ссылки

- [Bugzilla 1688932](https://bugzilla.mozilla.org/show_bug.cgi?id=1688932) — комм. 21–22 (замеры, что load-bearing), 32 (переход на NSPanel-подкласс), 33 (VoiceOver/`AXFrontmost`); фикс в 158.
- [Bugzilla 2067479](https://bugzilla.mozilla.org/show_bug.cgi?id=2067479) — PiP не появляется при переходе на fullscreen-Space (открыт).
- `engine/` 158.0.1: `toolkit/components/windowwatcher/nsWindowWatcher.cpp:2018,2024`; `xpfe/appshell/nsAppShellService.cpp:504`; `widget/cocoa/nsCocoaWindow.mm:5383–5436, 6432, 7723, 8326–8341, 9392–9430`; `toolkit/components/browser/nsIWebBrowserChrome.idl`; `widget/InitData.h`.
- Firefox JS: `browser/components/BrowserWindowTracker.sys.mjs`, `browser/components/sessionstore/SessionStore.sys.mjs`, `toolkit/components/pictureinpicture/content/player.xhtml`.
- Zen (`src/zen/`): `ZenSessionManager.sys.mjs`, `ZenSpaceManager.mjs`, pinned/essentials — искать по `getEnumerator("navigator:browser")` и `BrowserWindowTracker`.
- Apple: `NSWindow.CollectionBehavior` (`moveToActiveSpace`, `fullScreenAuxiliary`, `canJoinAllSpaces`), `NSWindowStyleMask.nonactivatingPanel`, `NSWindow.Level`.
