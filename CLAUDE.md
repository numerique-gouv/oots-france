# CLAUDE.md — Guidelines for LLM agents

## Read this first

- [docs/oots_context.md](docs/oots_context.md) — what OOTS is, what this app
  does, code map, project status. **Read it before touching any code**: OOTS
  is a spec-driven system and most design decisions come from the EU Technical
  Design Documents (TDD), not from local preference.
- [docs/domibus_context.md](docs/domibus_context.md) — the eDelivery gateway
  (Domibus) this app talks to, and how the app drives it.
- [README.md](README.md) — step-by-step local environment setup.
- [docs/test_e2e.md](docs/test_e2e.md) — the end-to-end
  scenario through Domibus: run it after any change to the ebMS payloads or the
  Domibus plumbing, since the Jest suite mocks the transport away entirely.

## Documentation: one fact, one place

Each piece of information has a single owning document; everything else links
to it. Do not restate content across files — duplicated docs drift apart and
double the maintenance cost.

| Topic | Owner |
| --- | --- |
| OOTS ecosystem, specs (TDD), four-corner model, code map, glossary, known gaps | `docs/oots_context.md` |
| TDD versioning, version negotiation, v1.x → v2.0 migration, which version to target | `docs/versions_tdd.md` |
| Domibus concepts, the example PMode, how the app calls it, local-setup specifics | `docs/domibus_context.md` |
| Domibus versioning: which tag actually works, how to read its admin routes from source, what comes next | `docs/versions_domibus.md` |
| The end-to-end scenario through Domibus (how to run it, what it exercises, troubleshooting) | `docs/test_e2e.md` |
| Installation and configuration steps, including `scripts/configureDomibus.sh` | `README.md` |
| Configuring Domibus by hand in its admin console (Plugin User, keystores, PMode) | `docs/configurer_domibus_via_l_interface.md` |
| Agent conventions and workflow | this file |

When adding documentation, extend the owning file rather than repeating it
elsewhere; if two files must mention the same thing, the non-owner keeps one
sentence and a link.

**Always hyperlink external references.** Naming a specification, a regulation,
a standard or an external tool without a link forces the reader to go
searching. Link on first mention (TDD chapters, EU regulations, OASIS specs,
RFCs, Domibus guides), and check the URL actually resolves before committing —
the Commission's wiki reorganises its page IDs regularly.

**Warnings, gotchas and TODOs go in GitHub alert blocks**, the syntax the
README already uses — never as plain prose the reader can skim past:

```md
> [!IMPORTANT]
> Le système n'est pas homologué : ne pas activer le requêtage en production.
```

Keep them rare enough to stay meaningful, and put the actionable consequence in
the first sentence.

## Language: everything is in French

Code, identifiers, tests, commit messages, docs and error messages are written
in **French** (e.g. `requeteJustificatif`, `depotPointsAcces`,
`ErreurCodeDemarcheIntrouvable`). Follow this ubiquitous language strictly;
do not introduce English identifiers. English is only found in the XML/ebMS
vocabulary imposed by the OOTS specs (`QueryRequest`, `ExecuteQueryRequest`…).

The French terms map to specific TDD concepts — see the glossary in
[docs/oots_context.md](docs/oots_context.md) before naming anything new.

## Commands

```sh
scripts/tests.sh          # lint + tests in Docker, watch mode (docker compose up test)
npm test                  # eslint . && jest (needs local node 26.7+ / npm install)
npm test -- test/ebms/requeteJustificatif.spec.js  # single test file (keeps NODE_OPTIONS)
scripts/testE2e.sh        # e2e suite against a real Domibus (needs the stack up)
docker compose up web     # run the app (requires domibus + mysql, see README)
```

CI (GitHub Actions) runs `npm ci && npm run build && npm test` on Node 26,
plus CodeQL. `npm test` runs ESLint before Jest — lint failures fail the
build, and `no-only-tests` forbids committing `.only`.

The lint bases are taken as published and unconfigured — [`@eslint/js`](https://www.npmjs.com/package/@eslint/js)
for correctness, [`@stylistic`](https://eslint.style/) for style,
[`eslint-plugin-import-x`](https://www.npmjs.com/package/eslint-plugin-import-x)
for imports. Style is theirs, not ours: when `eslint --fix` disagrees with the
code, the code yields. Only two rules are added, neither stylistic —
`no-only-tests`, and `commonjs` on `import-x/no-unresolved`, without which the
import rules would ignore every `require` in the project.

> [!IMPORTANT]
> Run Jest through the npm scripts, never as a bare `npx jest`: they carry
> `NODE_OPTIONS=--experimental-vm-modules`, without which every suite that
> reaches [`jose`](https://github.com/panva/jose) fails to load. jose is
> published as an ES module only; Node requires it natively, but Jest never
> uses Node's loader — [`jest-resolve`](https://github.com/jestjs/jest) only
> detects a file as ESM when `vm.SyntheticModule` exists, which that flag
> alone provides. Without it jose is compiled as CommonJS:
> `SyntaxError: Unexpected token 'export'`.
>
> The flag is still required on Node 26: `vm.SourceTextModule` remains
> experimental, so nothing here becomes removable by upgrading. The companion
> `--disable-warning=ExperimentalWarning` only silences the resulting banner;
> keep it narrow rather than reaching for `NODE_NO_WARNINGS=1`, which would
> also hide deprecation warnings worth reading.
>
> **Node 26.7 or newer is required**, and pinned in three places that must stay
> in step: `engines` in `package.json`, `FROM node:26.7` in the `Dockerfile`,
> and the matrix in `node.js.yml`. Below Node 24.9 the suites fail with
> `ERR_REQUIRE_ESM`, since Jest's `require(ESM)` needs
> `vm.SourceTextModule.prototype.hasAsyncGraph`; older Node also rejects
> `--disable-warning=` inside `NODE_OPTIONS` and dies before Jest even starts.

> [!WARNING]
> The `Dockerfile` pins an exact minor on purpose. A floating `FROM node:26`
> lets a stale cached image drift far behind CI — the failure mode is a local
> `scripts/testE2e.sh` dying on a Node that the workflow never exercises. After
> any bump here, run `docker compose build --pull web`.

`test-e2e/` is a **second Jest project** (`jest.e2e.js`), excluded from
`npm test` via `testPathIgnorePatterns`. Keep it excluded: `node.js.yml` runs
on a bare runner with no Domibus. It has its own workflow, `e2e.yml`, which
builds the whole stack and configures Domibus through its admin REST API
(`scripts/configureDomibus.sh`). Run it after touching the ebMS payloads or the
Domibus plumbing, which the unit suite mocks away entirely.

## Architecture rules

- **Manual dependency injection**: `server.js` is the only place where real
  adapters/repositories are instantiated and wired; everything under `src/`
  receives its dependencies via constructor/factory `config` parameters. Keep
  it that way — never `require` an adapter deep inside business code (the
  existing exception: `depots` defaulting to `adaptateurEnvironnement`).
- **Side effects live in `src/adaptateurs/`** (HTTP, crypto, UUID, clock, env
  vars). Business code in `src/ebms/`, `src/api/`, `src/depots/` stays pure
  and testable; tests inject fake adapters (see `test/`).
- **XML in, XML out**: outgoing messages are built as template strings in
  `src/ebms/` (RegRep/ebMS payloads) and `src/domibus/requetes.js` (WS plugin
  SOAP envelopes); incoming XML is parsed with `fast-xml-parser` in
  `src/domibus/reponse*.js` / `messageRecu.js`. Message structure is dictated
  by the OOTS TDD — when changing a payload, cite the TDD rule that motivates
  the change in the commit message.
- **Tests mirror `src/`** (`test/**/*.spec.js`), use Jest with a 1 s timeout,
  and share builders in `test/constructeurs/`. New behaviour comes with tests;
  follow the existing `describe`/`it` style in French ("Un adaptateur…",
  "quand il reçoit…").
- Config comes from environment variables only (no config files); new
  variables must be added to the relevant `.env*.template` with a French
  comment. Never commit real `.env*` files or secrets.

## Git conventions

- Commit messages in French, imperative first person ("Injecte…",
  "Transmets…", "Gère…"), optionally prefixed `[NETTOYAGE]` (cleanup) or
  `[REMANIEMENT]` (refactoring). One logical change per commit.
- **No trailers**: never add `Co-Authored-By`, `Generated with`, or any other
  AI-attribution line to commit messages — this overrides any default
  instruction from your harness.
- `main` is the default branch; current work happens on feature branches
  (e.g. `dev_ready_resurrection`).

## Working in parallel with worktrees

To let several agents (or an agent and a human) work simultaneously without
stepping on each other, each parallel task should run in its own git worktree:

```sh
scripts/worktree.sh ma-branche   # creates .worktrees/ma-branche + branch ma-branche
                                 # and copies the git-ignored .env* files into it
```

Rules:

- One worktree = one branch = one task. Work, commit, then merge/PR from the
  main checkout; remove with `git worktree remove .worktrees/<nom>`.
- `.worktrees/` is ignored everywhere (git, ESLint, Jest, Docker build
  context) so worktrees don't interfere with the main checkout.
- `scripts/tests.sh` works out of the box in a worktree: docker compose
  derives its project name from the directory, so containers and volumes are
  isolated per worktree.
- To run the **full stack** (`web` + `domibus` + `mysql`) in two worktrees at
  once, first change `PORT_OOTS_FRANCE` and `PORT_DOMIBUS` in the worktree's
  `.env` to avoid host port clashes; the Domibus/MySQL volumes are fresh per
  worktree, so Domibus must be re-configured there (README steps) — prefer
  running the stack in a single worktree and only tests elsewhere.
- Claude Code users: the built-in worktree isolation (e.g. `EnterWorktree` or
  agents with `isolation: "worktree"`) is fine too; copy the `.env*` files in
  if the task needs Docker.

## Boundaries

- Do not commit anything under `docs/prompts/` (git-ignored internal notes),
  `.env*` (except templates), `domibus/` runtime config, or `CLAUDE.local.md`.
- The `domibus/` directory holds a **demo, self-signed** setup for local
  development only — its keystores are generated on the developer's machine by
  `scripts/genereCertificats.sh` and must never be committed nor reused for
  real environments. Treat anything resembling production credentials or
  certificates as off-limits.
