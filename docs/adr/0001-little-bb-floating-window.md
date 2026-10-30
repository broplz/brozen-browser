# ADR-0001 · Little BB: плавающее окно (macOS Spaces/fullscreen) и изоляция от синхронизации Zen

## Статус

Proposed — 24.10.2026, @broplz. Варианты на обсуждении; после выбора статус меняется на Accepted. Закоммичен в репо 31.10.2026 без изменений содержания (восстановлен из Claude Doc).

- Область: ветка от тега 1.23.4b (Zen на Firefox 158.0.1), macOS в первую очередь.
- Основание: прототип Step 0 через Browser Console.
- Связанные ADR (ещё не написаны): маршрутизация внешних ссылок; UI/UX окна Little BB.

## Контекст и проблема

Little BB — аналог Little Arc: ссылка, открытая из другого приложения, появляется в компактном окне Zen, а не во вкладке основного окна. Окно должно висеть поверх всех окон, включая native fullscreen других приложений, и жить только на том Space, где пользователь был в момент клика. При этом оно остаётся обычным Gecko-окном: контейнеры, логины, расширения работают, а «Открыть в Zen» переносит вкладку в основное окно без перезагрузки.

Step 0 (`openDialog` с feature `alwaysontop`) показал два разрыва:

1. Firefox-овый `alwaysontop` в `nsCocoaWindow` даёт `NSFloatingWindowLevel` + `NSWindowCollectionBehaviorCanJoinAllSpaces` — поведение сделано под Picture-in-Picture. В итоге окно видно на всех обычных десктопах, но не входит в fullscreen-Space (нет `FullScreenAuxiliary`): поверх Discord и Zen в fullscreen оно не показывается.
2. Открытое окно — полный `browser.xhtml`, и session manager Zen клонирует в него вкладки текущего workspace. Окно участвует в кросс-оконной синхронизации как обычное.

Отсюда два решения, которые фиксирует этот ADR: как задать нужный level/collectionBehavior из `widget/cocoa` и включать это из JS, и как надёжно пометить окно, чтобы JS-слой Zen и Firefox его исключали.

## Требования и драйверы решения

Функциональные:

- **F1.** Поверх всего, включая fullscreen-Space других приложений и Zen в native fullscreen.
- **F2.** Только текущий Space: окно создаётся там, где был пользователь, и не следует за сменой Space.
- **F3.** Открытие ссылки не переключает Space на основное окно Zen.
- **F4.** Полноценный браузинг: e10s/Fission, контейнеры, расширения, prompts, `window.open` из контента; «Открыть в Zen» переносит вкладку без перезагрузки.
- **F5.** Окно не участвует в Zen workspaces / pinned / essentials sync и не восстанавливается SessionStore как отдельное окно.

Нефункциональные:

- **N1.** Минимальный и изолированный diff в C++/ObjC: каждый релиз Firefox/Zen — ребейз (сейчас в `npm run init` 263 патча).
- **N2.** Пригодность для PR в Zen: семантику `alwaysontop` не менять (PiP рассчитывает на «все Spaces»), только аддитивные флаги, no-op на Windows/Linux.
- **N3.** Один механизм задаёт поведение при создании окна и виден и widget-слою, и JS.
- **N4.** Никаких новых AI-поверхностей (принцип BB).

## Решение 1 — уровень окна и Spaces на macOS

Целевая native-конфигурация одна для всех рабочих вариантов: level `NSFloatingWindowLevel`, collectionBehavior `MoveToActiveSpace | FullScreenAuxiliary`, без `CanJoinAllSpaces` и без `FullScreenPrimary`. Вопрос только в том, как её включать из JS.

| Вариант | Суть | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| A. `alwaysontop` как есть | Штатный feature | Ноль патчей | На всех Spaces, не входит в fullscreen (Step 0) | Отвергнут |
| B. Поменять семантику `alwaysontop` | В `nsCocoaWindow` заменить `CanJoinAllSpaces` на `MoveToActiveSpace + FullScreenAuxiliary` | Самый маленький diff | Ломает PiP (следование за всеми Spaces — фича) и любой код на `alwaysontop`; upstream не примет (N2) | Отвергнут |
| C. Новый флаг по трассе `alwaysontop` | Window feature `bbfloating` → `nsIWebBrowserChrome::CHROME_BB_FLOATING` (`nsWindowWatcher`) → `nsWidgetInitData::mBBFloating` (`nsAppShellService`) → `nsCocoaWindow::CreateNativeWindow` ставит level/collectionBehavior; на Win/Linux no-op | Аддитивно, ~5 файлов, повторяет существующий паттерн; chromeFlags читаются из JS сразу при старте окна → тот же флаг служит признаком Little BB (Решение 2) | Статично: нельзя переключить в рантайме (pin/unpin, «сделать обычным окном») | **Рекомендован** |
| D. Рантайм API | Новый метод `nsIWidget` (`SetFloatingBehavior`) + экспозиция в JS через `nsIBaseWindow`/`nsIAppWindow` или `nsIDOMWindowUtils` | Динамика: pin/unpin, превращение в обычное окно | IDL + заглушки во всех widget-бэкендах, больше поверхности для ребейза; не даёт признака окна при старте — нужен второй механизм | Отложен: добавлять поверх C, если понадобится |
| E. XUL `<panel>` (popup window type) | Окно-попап: `NSPanel` на `NSPopUpMenuWindowLevel` | Уже поверх всего и в fullscreen без C++ | Привязан к родителю и его Space, не key window, нет title bar/resize, проблемы фокуса/IME, вкладку не перенести | Отвергнут |
| F. Внешний helper (Swift + WKWebView) | Отдельное приложение-панель | Полный контроль над `NSWindow` | Не Gecko: нет контейнеров, расширений, переноса вкладки (F4) | Отвергнут |

Имя `bbfloating` / `CHROME_BB_FLOATING` — рабочее; для PR в Zen нужно нейтральное (например `floating`). Если `NSFloatingWindowLevel` окажется ниже чужих панелей, поднимаем до `NSStatusWindowLevel` — проверяется в Step 1.

## Решение 2 — признак окна и исключение из синхронизации Zen

Места, где Firefox и Zen считают Little BB «ещё одним окном браузера», и где его нужно исключить:

- Session manager / workspaces Zen: при открытии клонирует вкладки workspace (Step 0), при изменениях рассылает их по всем окнам (`Services.wm.getEnumerator("navigator:browser")`, `BrowserWindowTracker.orderedWindows`).
- Sync pinned / essentials между окнами.
- `BrowserWindowTracker.getTopWindow()`: если Little BB — верхнее окно, следующая внешняя ссылка уйдёт в него.
- SessionStore: сохраняет и восстанавливает окно после рестарта.
- Меню «Move tab to window», Mission Control, Cmd-` — второстепенно, решается в UI ADR.

| Вариант | Суть | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| E1. Popup по семантике Firefox | Features без toolbar/menubar → `window.toolbar.visible === false` | Без патчей: `BrowserWindowTracker` уже не отдаёт попапы в `getTopWindow`; SessionStore помечает `isPopup` | Zen sync про попапы не знает; поведение SessionStore с попапами надо проверить | База, но не решение |
| E2. Явный признак + патчи точек синка | Признак = `CHROME_BB_FLOATING` из Решения 1, обёрнут в `BBLittle.isLittleWindow(win)`; атрибут `bb-little` на `documentElement` до инициализации Zen; патчи: session manager/workspaces, pinned/essentials, `BrowserWindowTracker`, SessionStore | Полный `browser.xhtml` → F4 бесплатно, «Открыть в Zen» = `gBrowser.adoptTab`; признак явный и грепается; тот же флаг, что в C | Точки итерации по окнам в Zen живут и переезжают; пропуск проявляется как «утечка» состояния — нужен чеклист на каждый ребейз | **Рекомендован** |
| E3. Свой windowtype (`navigator:bb-little`) | Окно не `navigator:browser` | Всё, что перебирает `navigator:browser` (SessionStore, Zen sync, window mediator), исключает автоматически | `browser.js` и инициализация Zen местами завязаны на `navigator:browser` (places, downloads, context menu, `BrowserWindowTracker.track`); атрибут задан в разметке `browser.xhtml`, менять можно только в рантайме до init | Гибрид с E2 для SessionStore, если патч SessionStore выйдет грязным |
| E4. Отдельный chrome-документ (`bb-little.xhtml`) | Один `<browser>` + минимальный тулбар, как PiP `player.xhtml` или DevTools toolbox | Ничего не синкается по построению; минимальный UI; upstream-дружественно | F4 заново: `nsIBrowserDOMWindow` для `window.open`, PopupNotifications/permission prompts, контекстное меню, find bar, downloads, контейнеры Zen; перенос через `swapDocShells`/`swapFrameLoaders` вместо `adoptTab`; расходится с UI Zen | Отвергнут для v1; кандидат на v2, если E2 течёт |

Для SessionStore штатного per-window opt-out нет: исключаются только private-окна и не-`navigator:browser`. Нужен точечный патч по признаку или гибрид с E3.

## Рекомендуемое решение

C + E2 на базе E1: один chrome-флаг задаёт native-поведение и одновременно служит признаком окна для JS.

1. Little BB — это `browser.xhtml`, открываемый через `Services.ww.openWindow` с features `chrome,dialog=no,resizable,bbfloating` плюс popup-набор (`toolbar=no,...`; точный список — UI ADR).
2. `bbfloating` → `CHROME_BB_FLOATING` (`nsIWebBrowserChrome.idl`, `nsWindowWatcher`) → `nsWidgetInitData::mBBFloating` (`nsAppShellService::JustCreateTopWindow`) → `nsCocoaWindow::CreateNativeWindow`: `NSFloatingWindowLevel`, `MoveToActiveSpace | FullScreenAuxiliary`, без `CanJoinAllSpaces`. Семантика `alwaysontop` не трогается. На Windows/Linux флаг игнорируется (v1).
3. JS-признак: `BBLittle.isLittleWindow(win)` = `win.docShell.treeOwner → nsIAppWindow.chromeFlags & CHROME_BB_FLOATING`. В начале `browser.js`, до инициализации Zen, выставляется атрибут `bb-little` на `documentElement` для CSS и простых проверок.
4. По признаку исключаются: session manager / workspaces Zen (не клонировать workspace, не включать в рассылку), pinned/essentials sync, `BrowserWindowTracker` (не считать верхним окном для внешних ссылок), SessionStore (не сохранять окно).
5. «Открыть в Zen» = `mainWin.gBrowser.adoptTab(tab)` в основное окно нужного workspace, затем `close()` Little BB.

D (рантайм API) добавляется поверх этой связки только при реальной потребности в pin/unpin; E4 остаётся запасным путём, если список исключений в E2 окажется неподдерживаемым.

## Последствия

Плюсы:

- Один источник истины (chrome-флаг) для native и JS; C++-патч маленький, аддитивный, по готовому паттерну — дёшево ребейзить и реально предложить в Zen.
- Полный `browser.xhtml`: контейнеры, расширения, prompts и перенос вкладки работают без переписывания.
- `alwaysontop` и PiP не затронуты.

Минусы и цена сопровождения:

- Появляется ObjC-патч в `widget/cocoa` плюс IDL-константа: изменения требуют полной C++-сборки (~38 мин на M1 Pro), а не `npm run build:ui`; ребейз при каждом обновлении Firefox. Держать в отдельном `.patch`.
- Список точек исключения в JS-слое Zen — живой. Каждое обновление Zen: прогнать чеклист «не утекло ли состояние» (клонирование workspace, pinned/essentials, SessionStore, цель для внешней ссылки).
- Windows/Linux без «поверх fullscreen» в v1.
- Отдельное окно в Mission Control и Cmd-` — UX-решение (`IgnoresCycle`, `Transient`) откладывается в UI ADR.

## Риски и план проверки (Step 1 spike)

Ключевой риск — R1: macOS при активации приложения, у которого нет окон на текущем Space, сам переключается на Space с его окнами (настройка «When switching to an application, switch to a Space with open windows», включена по умолчанию). Если Little BB создаётся после того, как Launch Services активировал Zen, пользователь улетит на Space основного окна, и F3 провалится независимо от collectionBehavior.

| # | Риск | Как проверяем | Митигация |
|---|---|---|---|
| R1 | Переключение Space при активации Zen | Ссылка из fullscreen Discord; критерий: остаёмся в Discord-Space, окно сверху | По возрастанию грязности: (a) создавать окно синхронно в обработчике `application:openURLs:` / command line до `activateIgnoringOtherApps`; (b) `orderFrontRegardless` + `MoveToActiveSpace`; (c) постоянное невидимое 1×1 окно с `CanJoinAllSpaces` |
| R2 | `NSFloatingWindowLevel` недостаточно поверх fullscreen-Space | Проверить поверх Discord fullscreen и Zen в native fullscreen | Поднять до `NSStatusWindowLevel` |
| R3 | Трасса `alwaysontop` в Firefox 158 отличается от описанной | Подтвердить файлы и строки перед патчем | Повторить фактический паттерн; убедиться, что PiP не задет |
| R4 | `adoptTab` между окнами с разными chromeFlags и workspaces Zen | Перенос вкладки с формой/логином без перезагрузки | Fallback: `swapDocShells` на уровне `<browser>` |
| R5 | SessionStore восстанавливает Little BB после рестарта | Открыть окно, перезапустить | Патч по признаку или гибрид E3 |
| R6 | Dev-билд не грузит `ZenGlanceChild` / `ZenBoostsChild` / `ZenWindowDragChild` | Разобраться до spike | Иначе ошибки Little BB будут замаскированы |
| R7 | Конфликты C++-патча при обновлении Zen | На каждом ребейзе | Патч минимальный, в отдельном `.patch`, без правки `alwaysontop` |

Go/No-Go: если R1 решается только вариантом (c), это выносится на отдельное обсуждение — для PR в Zen такой хак самый спорный.

## Вне scope

- Маршрутизация: как отличить внешнюю ссылку (`-osint`, `application:openURLs:`, `BrowserContentHandler`) и когда Little BB не открывать — отдельный ADR.
- UI/UX окна: размер, позиция, набор `chromehidden`, тулбар, pin, автозакрытие, видимость в Mission Control — отдельный ADR.
- Паритет на Windows/Linux.

## Ссылки

Firefox (mozilla-central, ветка под 158):

- `widget/cocoa/nsCocoaWindow.mm` — `CreateNativeWindow`, обработка `mAlwaysOnTop`
- `widget/nsWidgetInitData.h`
- `xpfe/appshell/nsAppShellService.cpp` — `JustCreateTopWindow`
- `toolkit/components/windowwatcher/nsWindowWatcher.cpp` — `CalculateChromeFlagsForSystem`
- `toolkit/components/browser/nsIWebBrowserChrome.idl`
- `browser/components/BrowserWindowTracker.sys.mjs`, `browser/components/sessionstore/SessionStore.sys.mjs`

Zen (`src/zen/`): session manager, workspaces, pinned/essentials — точные модули найти по `getEnumerator("navigator:browser")` и `BrowserWindowTracker`.

Apple: `NSWindow.CollectionBehavior` (`moveToActiveSpace`, `fullScreenAuxiliary`, `canJoinAllSpaces`, `ignoresCycle`), `NSWindow.Level`.

Step 0: заметки прототипа через Browser Console (тег 1.23.4b).
