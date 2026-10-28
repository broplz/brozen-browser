# ADR-0012 · AI-команда: роли, конвейер задач и бюджет контекста

Oct 28, 2026 · @broplz

## Статус

Proposed — конфигурация собрана и прогнана на мок-репо и на одной настоящей задаче (см. «План
проверки»); после первого реального цикла на задачах ADR-0002 статус меняется на Accepted.

- Область: репо `broplz/brozen-browser`; `.claude/` (agents, hooks, skills, settings), `CLAUDE.md`,
  `scripts/agents/`, `tasks/`, `docs/reports/`.
- Основание: конфигурация AI-команды Rise of the Sentinels (RotS) и её память агентов (что
  ломалось и почему), документация Claude Code 2.1.312 (subagents, hooks, headless `-p`),
  рекомендации Anthropic по context engineering, практика комьюнити (Ralph-loop, fresh session
  per task). Ссылки — в конце.
- Воплощает решения владельца (28.10.2026): main сливает только человек; полную сборку агентам
  разрешаем по ролям; конвейер пишем заново, а не переносим скрипты RotS.

## Контекст и проблема

Один владелец ставит вектор и принимает ключевые решения; всю рутину — код слоя BB, ревью,
проверку, ребейзы — должны делать агенты в режиме «пока задача не сделана или не появился
блокер». Ограничения: один `engine/` и полная сборка ~40 мин на M1; GitHub из KZ ~30 КБ/с;
правила слоя из ADR-0002, которые легко нарушить незаметно; бюджет — одна подписка Max, поэтому
токены считаем.

Что дал опыт RotS (из CLAUDE.md, хуков и памяти агентов):

- Работает: файл задачи как единственное состояние; статусы и вердикты в нём; `allowed_paths`
  и хуки, а не просьбы; «одна команда на Bash-вызов»; three strikes с Handoff; merge только
  скриптом по APPROVE+PASS с проверкой SHA; память у reviewer/teamlead (повторяющиеся дефекты).
- Не работает: CEO-агент съедал 42 % дневных расходов, пересобирая состояние из файлов; nightly
  вставал, когда статус «не тот, что ожидался»; агенты забывали поле (`reviewed_sha`) — и всё
  стояло; developer писал файлы до переключения ветки; большие задачи (0002 ~800 строк) делились
  только после провала; teamlead-сессия на merge — $0.7–1.0 за детерминированную проверку.

## Требования

- R1. Человек принимает только ключевые решения: ADR, порядок бэклога, одобрение C++/патчей Zen,
  smoke после ребейза, `feat → main`. Всё остальное — без него.
- R2. Минимум токенов на задачу: короткие сессии, дешёвые модели там, где хватает, нулевые
  токены на детерминированное (merge, lint, отчёт).
- R3. Контекст не переполняется: сессия обрывается до того, как агент «захлебнётся», и работа
  продолжается с чекпоинта; задача, которая не влезает в сессию, режется мельче.
- R4. Режим «до готовности или блокера»: один запуск ведёт задачу (или очередь) до `done`,
  останавливаясь только на решении человека.
- R5. Правила ADR-0002 нельзя нарушить незаметно: они в хуках и в детерминированном линте, а не
  только в промптах.

## Решение 1 — роли и модели

| Роль | Модель | Делает | Не делает |
|---|---|---|---|
| teamlead | opus / high, память | ADR + бэклог → файлы задач; разблокировка (split / re-spec / escalate) | код, merge |
| developer | sonnet / medium | JS/CSS/prefs/скрипты в слое, ui-сборка | полная сборка, C++, engine/ |
| developer-hard | opus / high | C++/ObjC/IDL-патчи, хенки рядом с хенками Zen, полная сборка | — |
| reviewer | opus / high, память | вердикт по DoD, ADR и правилам слоя; читает только capped diff | код, сборка |
| qa | sonnet / medium | сборка нужного типа, lint, DoD буквально, PASS/FAIL с repro | правка кода |
| rebaser | opus / high, память | runbook ADR-0002 §4, конфликты по README патчей, отчёт | smoke, main |
| log-triage | haiku | выжимка из логов для qa/rebaser (субагент) | — |
| architect | fable / high, интерактивно | черновики ADR в репо по запросу владельца | конвейер |

Убрано относительно RotS: **CEO** (отчёт делает `scripts/agents/report.py` бесплатно; бэклог
ведёт человек, упорядочивает teamlead) и **ops** (скрипты — обычные задачи developer; деплоя у
BB нет). Добавлено: **rebaser** (ребейз — главная регулярная операция BB) и **architect**.

Варианты по модели reviewer: sonnet дешевле в 3–4 раза, но на RotS именно opus находил
реальные дефекты (фантомные тесты в Result, переполнения); оставляем opus с лимитом 15 ходов —
ревью стоит $0.12–0.23 за задачу (замер ниже). Пересмотр — по метрике returns.

## Решение 2 — задача как единица работы, сессия как расходник

Задача = `tasks/<id>-<slug>.md` (frontmatter + секции Goal / DoD / Notes / Handoff / Result /
Review / QA) = ветка `task/<id>-<slug>` от `base` (ветка `feat/*`). Размеры S/M/L с потолком
150/300/500 production-строк и 5/10/15 файлов; teamlead режет больше — на две задачи.

Контекст контролируется не уговорами, а механикой (R3):

1. **Свежая сессия на каждый прогон роли** (`claude -p --agent <role>`): в контексте только
   CLAUDE.md, роль, нужные ей правила (skills) и файл задачи. Состояние — файл задачи + ветка
   (structured note-taking по Anthropic). Между сессиями ничего не «помнится», кроме памяти
   reviewer/teamlead/rebaser о паттернах.
2. **Жёсткие лимиты**: `--max-turns` по роли и размеру (dev S 25 / M 40 / L 60, reviewer 15,
   qa 25, teamlead 30, rebaser 60) и `--max-budget-usd` (2–3× типичной цены; стоп для
   разбежавшейся сессии).
3. **Чекпоинт вместо обрыва**: хук предупреждает на 60 % и 85 % бюджета ходов — «закоммить,
   заполни Handoff, оставь in_progress»; драйвер автокоммитит всё, что агент не закоммитил;
   следующая сессия продолжает с Handoff. Три сессии без `review` → `blocked: too_big` →
   teamlead делит задачу.
4. **Гигиена входа** (хук guard_read): `engine/` и прочие большие деревья — только Grep с
   glob/type и head_limit, Read с offset/limit ≤ 400; `.log` — только через `triage_log.py`;
   файлы > 300 КБ без limit не читаются. Reviewer читает `diff.sh` (cap 1500 строк), а не файлы.
5. **Правила по ролям, а не всем**: три набора (`bb-task`, `bb-layer`, `bb-build`) драйвер
   подмешивает в system prompt только тем, кому они нужны; CLAUDE.md ~50 строк.
6. **Модели по цене ошибки**: haiku на логи, sonnet на код и QA, opus на ревью/декомпозицию/C++,
   fable — только по запросу человека.

## Решение 3 — конвейер «до готовности или блокера»

`scripts/agents/run_task.py <id>` (и `run_queue.py` для очереди) — цикл без LLM-оркестратора:

```
ready/returned/in_progress → developer(-hard) ─┬─ review → reviewer ─┬─ qa → qa ─┬─ approved → merge → done
                                               │                     │           └─ returned ─┐
                                               │                     └─ returned ─────────────┤ (×3 → blocked)
                                               └─ blocked / 3 сессии ──────────────────────────┘
blocked → teamlead unblock (один раз): split | re-spec | escalate → стоп, если решение человека
```

- Драйвер владеет git: создаёт и переключает ветки (агентам `git switch/merge/push` запрещены),
  автокоммитит хвосты, ведёт `returns`/`sessions`, сам записывает `reviewed_sha`/`qa_sha` =
  code head ветки после сессии (агент не может забыть поле — это и было стопом nightly в RotS),
  добавляет недостающий статус по вердикту.
- **Merge — скрипт, ноль токенов**: `merge_task.py` проверяет статус, оба вердикта, SHA,
  `layer_lint.py`, одобрение; squash в `feat/*` одним коммитом `<prefix>: <title> (<id>)`;
  push в origin — best effort (медленный GitHub не гейт). В `main` — только человек:
  `finish_feature.sh` (rebase от тега `bb/fork/<feat>`, сборка, smoke, ff-merge).
- **Точки человека**: `tasks/approvals.txt` (строка `<id> approved`) для `needs_approval` и для
  всего, где lint видит C++/ObjC/IDL или правку патча Zen; `docs/reports/decisions-needed.md`
  — append-only вопросы; `logs/ATTENTION.md` — что ждёт тебя (и `BB_NOTIFY_CMD` для Telegram).
- Один `engine/` → сборки последовательно (lock в `build.sh`), очередь последовательна.
  Параллельные агенты и worktrees не используем: каждому worktree нужен свой engine и 40 минут.
- `build.sh` выбирает тип по диффу (C/C++/ObjC/IDL/Rust/moz.build/mozconfig, включая цели
  `.patch` → full); developer не может запустить full (хук) — задача уходит на developer-hard.
  Strikes: 3 неудачных ui-сборки/теста или 2 полных → Handoff.

Варианты «вечного цикла»: Ralph-loop (Stop-хук в одной сессии) оставлен для уровня сессии —
`session_end.py` не даёт developer выйти с пустым Handoff (две «подсказки»), reviewer/qa — без
вердикта; на уровне задачи цикл делает драйвер свежими сессиями: контекст не растёт.

## Решение 4 — правила слоя в коде

- `guard_paths.py`: защищённые пути; `.patch` под `src/zen/` — никогда; патчи Zen — только с
  `allow_zen_patch`; существующие тесты — только qa/kind: test; `allowed_paths` + стандартные
  пути роли; `engine/` правят только developer-hard и rebaser (как черновик патча).
- `guard_bash.py`: без цепочек/переменных/редиректов; `npm`/`surfer`/`mach` только через
  `build.sh`/`test.sh`; логи только через triage; git-операции драйвера и `curl` запрещены;
  гейты ролей (full build, rebase.sh, git apply).
- `layer_lint.py` (qa и merge): файлы Zen без маркера `BB(eN)` или без записи в `layer.yaml`;
  патч без README или не в `src/bb/patches/<epic>/<name>/`; pref не из `bb.*`; TODO без id;
  выход за `allowed_paths`; превышение размера — WARN; C++/патч Zen → `NEEDS APPROVAL`.

## Последствия

Плюсы: цена цикла мала (замер на игрушечной задаче: developer $0.03 → reviewer $0.13 → qa $0.03
→ merge, 78 с); человек нужен только там, где решение его; протокольные ошибки агентов не
останавливают конвейер; состояние всегда читается одной командой (`run_queue.py --list`,
`report.py`).

Минусы и цена: ~20 файлов конвейера, которые надо поддерживать; задачи мельче — больше
оверхеда на сессию (CLAUDE.md + правила ≈ 5–7k токенов кэша на старте); memory-файлы агентов
попадают в коммиты (сознательно); ограничения на чтение `engine/` иногда заставят агента сделать
два вызова вместо одного.

## Риски и план проверки

| # | Риск | Как проверяем | Митигация |
|---|---|---|---|
| R1 | Хуки не грузятся в `-p` без trust репо (замечено в тесте: allow-список игнорируется) | первый запуск: `claude` интерактивно в репо, принять trust | INSTALL, шаг 1 |
| R2 | Агент обходит правило, которого нет в хуке | ревью первых 5 задач человеком по `diff.sh` | правило → хук/lint, не в промпт |
| R3 | Лимиты ходов слишком малы для M/L на реальном Zen | `report.py`: доля сессий с `too_big`/`max_turns` | поднять в `config.py`; делить задачи |
| R4 | `build.sh --ui` не подхватывает патч JS-файла Firefox | задача 0006 (учебный патч) | import перед сборкой уже есть; иначе full |
| R5 | Параллельная ручная работа в том же `engine/` во время прогона | lock + ATTENTION | не трогать репо, пока идёт очередь |

План: (1) установить комплект на `feat/e11-agents`, trust, `run_queue.py --list`; (2)
`new_feature.sh feat/layer`, `run_queue.py --plan` — teamlead пишет 0001–0003; (3) прогнать
0001–0003 (без сборки / ui) — первый реальный цикл; (4) по `report.py` скорректировать лимиты и
промпты; (5) Accepted.

## Как запускать

```
scripts/agents/new_feature.sh feat/layer        # ветка + тег форка + backlog
scripts/agents/run_queue.py --plan              # планирование и очередь до пустоты или блокера
scripts/agents/run_task.py 0003 [--once]        # одна задача (или один шаг)
scripts/agents/run_queue.py --list · report.py  # состояние и расходы
echo "0012 approved" >> tasks/approvals.txt     # одобрение, затем rerun
scripts/agents/finish_feature.sh feat/layer     # feat → main, руками
claude --agent architect                        # ADR в репо, интерактивно
```

Настройки: `scripts/agents/config.py` (лимиты, бюджеты, MAX_RETURNS/MAX_SESSIONS,
AUTO_UNBLOCK), `.claude/agents/*.md` (модели, effort), `BB_NOTIFY_CMD`, `BB_CLAUDE_ARGS`.

## Вне scope

Rebase-бот по расписанию и облачные Routines (E11, после первого ручного ребейза);
параллельные агенты/worktrees; sandbox Claude Code (Seatbelt) — возможное усиление после
Phase 0; Telegram-уведомления (хук есть, бот — отдельно); тесты для `src/bb/`.

## Ссылки

Конфигурация RotS (`.claude/`, CLAUDE.md, память агентов, 28.10.2026). Claude Code:
[subagents](https://code.claude.com/docs/en/sub-agents), [hooks](https://code.claude.com/docs/en/hooks),
[CLI](https://code.claude.com/docs/en/cli-reference), [headless](https://code.claude.com/docs/en/headless),
[worktrees](https://code.claude.com/docs/en/worktrees); `--permission-prompts none` (≥ 2.1.259),
`--max-budget-usd` ([разбор поведения](https://linuxjedi.co.uk/when-the-docs-fall-short-investigating-claude-codes-budget-cap/)),
[deny-fallback для unattended-запусков](https://agentpatterns.ai/patterns/agent-design/deny-fallback-unattended-permissions/),
[headless-режим на практике](https://eseospace.com/blog/claude-code-headless-mode-automation/).
Anthropic: [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
Комьюнити: [Ralph Wiggum plugin](https://gitcode.com/2301_77165880/claude-code/tree/main/plugins/ralph-wiggum)
(Stop-хук, completion promise, max-iterations).
