# Documentation Map

> Last updated: 2026-07-31 — P0.09

*"If I am asking this question, where do I look?"*

## Binding files (repository root)

| File | What it is read for |
|---|---|
| [`AGENTS.md`](../AGENTS.md) | Invariants, working discipline, Definition of Done |
| [`BOOT.md`](../BOOT.md) | Session start protocol and health snapshot |
| [`TODO.md`](../TODO.md) | Next task, acceptance criteria, Run Log |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | MUST/MUST NOT invariants, ADR index |
| [`LEGAL.md`](../LEGAL.md) | Independent development boundaries — **every session** |
| [`SECURITY.md`](../SECURITY.md) | Security model and vulnerability disclosure |

## The `docs/` tree

### `product/` — What is this, for whom, how does it behave?

| File | The question it answers |
|---|---|
| [`overview.md`](product/overview.md) | What is the product, for whom, under which principles? |
| [`control-model.md`](product/control-model.md) | **The core abstraction** — how is fan behaviour defined? |
| [`scope.md`](product/scope.md) | Which feature lands in which release? What will not be built? |
| [`ui.md`](product/ui.md) | Screens, design language, accessibility |

### `architecture/` — How is it built, under which decisions?

| File | The question it answers |
|---|---|
| [`system.md`](architecture/system.md) | Components, trust boundaries, concurrency |
| [`hardware-access.md`](architecture/hardware-access.md) | How are sensor and fan data accessed? |
| [`privilege-model.md`](architecture/privilege-model.md) | Which permission, why, when? |
| [`configuration.md`](architecture/configuration.md) | Configuration schema and validation |
| [`adr/`](architecture/adr/README.md) | Why was this decision made this way? |

### `development/` — How is work done in this repository?

| File | The question it answers |
|---|---|
| [`setup.md`](development/setup.md) | How do I set up the environment, which commands exist? |
| [`repo-structure.md`](development/repo-structure.md) | Which code goes where? |
| [`testing.md`](development/testing.md) | How is it tested, what evidence is required? |
| [`localization.md`](development/localization.md) | How is text written, how is it translated? |

### `operations/` — What happens at runtime?

| File | The question it answers |
|---|---|
| [`observability.md`](operations/observability.md) | Logs, measurement recording, metrics |
| [`notifications.md`](operations/notifications.md) | Notifications and automation hooks |
| [`diagnostics.md`](operations/diagnostics.md) | How is hardware health reported? |
| [`troubleshooting.md`](operations/troubleshooting.md) | Something is not behaving — what is wrong, and what is deliberate? |

### `release/` — When and how is it released?

| File | The question it answers |
|---|---|
| [`build-and-sign.md`](release/build-and-sign.md) | Build, signing, notarisation, distribution |
| [`readme-spec.md`](release/readme-spec.md) | What belongs in the product README? |
| [`discoverability.md`](release/discoverability.md) | How will users find this project? |

### `reference/` — Where are the exact values?

| File | The question it answers |
|---|---|
| [`blueprint-map.md`](reference/blueprint-map.md) | Where did this blueprint section go? |
| [`decisions.md`](reference/decisions.md) | Which opening decisions are settled? |
| [`risks.md`](reference/risks.md) | Which risks are being tracked? |
| [`glossary.md`](reference/glossary.md) | What does this term mean? |

### `blueprint/` — The frozen source

[`blueprint/README.md`](blueprint/README.md) — **never edited**, historical reference only.

## Documentation rules

1. **One file = one topic.** The same fact is never written in two places; the second links to the first.
2. Every file starts with `> Last updated:` and `> Source: blueprint §X`.
3. **No code copies are kept** — once code exists, the documentation points at the source.
4. When you change something, consult the protocol in `AGENTS.md` §7.
