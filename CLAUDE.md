# CLAUDE.md — Guidelines for LLM agents

## Read this first

- [docs/oots_context.md](docs/oots_context.md) — what OOTS is, what this app does, code map, project status. **Read it before touching any code**: OOTS is a spec-driven system and most design decisions come from the EU Technical Design Documents (TDD), not from local preference.
- [docs/glossaire.md](docs/glossaire.md) — every acronym and domain term in one sentence each (DSD, EDM, ebMS3, *requêteur*, *bouchon*…), with the class that carries it. **Look a word up here rather than guessing from context**, and define no term anywhere else.
- [docs/domibus_context.md](docs/domibus_context.md) — the eDelivery gateway (Domibus) this app talks to, and how the app drives it.
- [README.md](README.md) — step-by-step local environment setup.
- [docs/test_e2e.md](docs/test_e2e.md) — the end-to-end scenario through Domibus: run it after any change to the ebMS payloads or the Domibus plumbing, since the Jest suite mocks the transport away entirely.

## This repository implements the TDD. It does not invent

The job is to build what the [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) specify — no more. A behaviour nobody asked for costs what any other costs: code, specs, review, maintenance, and a reader's time working out why it is there. It just buys nothing.

**So read them. Often. Far more often than feels necessary** — before designing, before naming, before deciding a shape, and again when a reviewer's question has no answer in the code. They are online, they are free to read, and one fetch settles what an hour of reasoning cannot. Never argue from what the repository already contains: it may itself be wrong, and repeating its mistake is how one becomes lasting. Read the chapter.

> [!IMPORTANT]
> **A feature is justified by a chapter, or it does not ship.** Before writing anything the specifications do not name, say which chapter requires it — and if none does, do not build it. Where a real constraint seems to demand it, the answer is nearly always already in the TDD, in a form nobody guessed: an asynchronous exchange asks for correlation by `ConversationId`, not for a waiting screen.

Two mistakes to recognise. **Inventing** — a technical constraint turned into a user-visible behaviour, a convenience added because it seemed helpful. **Reconducting** — carrying a behaviour forward because the application this one replaces had it, which proves only that someone once wrote it.

**The same discipline applies to every dependency, not only to the TDD.** What Domibus, eDelivery or a Commission directory does is settled by **its published documentation and its source**, never by memory and never by inference from a local experiment. Read the doc first; read the code when the doc is silent — Domibus is open, and its behaviour is often only in there. An experiment then *confirms* what one has read; it is a poor way to *discover* it, because it shows one version's behaviour on one configuration and says nothing about what is guaranteed.

The consequence is worth stating plainly: this application talks to machines. A French service provider calls it, it exchanges ebMS messages with a foreign correspondent, it answers the provider. The one place the specifications put a human in front of a screen is the *Preview Space* of [chapter 4.9](https://ec.europa.eu/digital-building-blocks/sites/pages/viewpage.action?pageId=900013172), which this repository does not implement yet. Until it does, **anything rendering HTML to an end user is out of scope** — and the user reaches the procedure portal, never this component.

The rule is about an *audience*, and one exception faces none: the operator console of [docs/espace_administration.md](docs/espace_administration.md), which renders HTML to the team that runs the deployment, for an operational need no chapter names. It must never grow a screen an end user reaches.

## Documentation: one fact, one place

Each piece of information has a single owning document; everything else links to it. Do not restate content across files — duplicated docs drift apart and double the maintenance cost.

| Topic | Owner |
| --- | --- |
| OOTS ecosystem, specs (TDD), four-corner model, code map | `docs/oots_context.md` |
| Vocabulary: what an acronym or a domain term means, and the class that carries it | `docs/glossaire.md` |
| Macro state of TDD conformance: the chapter-by-chapter inventory, and the Linear project carrying each gap. Tasks, their order and their dependencies live in Linear, not here | `docs/reste_à_faire.md` |
| TDD versioning, version negotiation, v1.x → v2.0 migration, which version to target | `docs/versions_tdd.md` |
| Where to find what in the TDD: chapter map with links, where the machine-readable artefacts live, the fixed values (query IDs, DNS template, ebMS constants) | `docs/carte_des_tdd.md` |
| OOTS code published elsewhere: the Commission's own implementations, other Member States' repositories, reusable third-party components, and what each is worth | `docs/implementations_europeennes.md` |
| Domibus concepts, the example PMode, how the app calls it, local-setup specifics | `docs/domibus_context.md` |
| Domibus versioning: which tag actually works, how to read its admin routes from source, what comes next | `docs/versions_domibus.md` |
| The end-to-end scenario through Domibus (how to run it, what it exercises, troubleshooting) | `docs/test_e2e.md` |
| The Commission's Testing Services: the ITB test platform, the online validator, the mocked directories, the AS4 and LCM test components, and what can (and cannot) be submitted to them | `docs/testing_services.md` |
| Installation and configuration steps, including `scripts/configure_domibus.sh` | `README.md` |
| Configuring Domibus by hand in its admin console (Plugin User, keystores, PMode, admin accounts) | `docs/configurer_domibus_via_l_interface.md` |
| The operator console: what it shows, what it deliberately does not, the DSFR wiring, and the account that opens it | `docs/espace_administration.md` |
| The exchange log of article 17: what is recorded and where, the encryption and retention of personal data, how to read it back | `docs/journal_des_echanges.md` |
| The TLS profile the outgoing clients actually use towards the Common Services, confronted requirement by requirement with chapter 3.7: versions, cipher suites, key exchange groups, mutual TLS, the load the client puts on the directories, DNSSEC | `docs/securite_transport.md` |
| Agent conventions and workflow | this file |
| What each versioned skill does, and what stays local under `.claude/` | this file, section [What lives in `.claude/`](#what-lives-in-claude) |

When adding documentation, extend the owning file rather than repeating it elsewhere; if two files must mention the same thing, the non-owner keeps one sentence and a link.

**Always hyperlink external references.** Naming a specification, a regulation, a standard or an external tool without a link forces the reader to go searching. Link on first mention (TDD chapters, EU regulations, OASIS specs, RFCs, Domibus guides), and check the URL actually resolves before committing — the Commission's wiki reorganises its page IDs regularly.

**Warnings, gotchas and TODOs go in GitHub alert blocks**, the syntax the README already uses — never as plain prose the reader can skim past:

```md
> [!IMPORTANT]
> Le système n'est pas homologué : ne pas activer le requêtage en production.
```

Keep them rare enough to stay meaningful, and put the actionable consequence in the first sentence.

**Never hard-wrap markdown prose.** One paragraph is one line, however long; the editor wraps it. Do not reflow a paragraph to 80 columns — that convention was dropped deliberately, because every edit then forced a manual reflow of the whole paragraph. This applies to prose, list items and blockquotes alike; code blocks and tables keep their own line structure.

## Language: English code, French prose

**Code, identifiers and comments are written in English; documentation, commit messages and Cucumber scenarios stay in French.**

The domain loses nothing by this — it gains. The vocabulary of the TDD *is* English: `EvidenceRequester`, `NaturalPerson`, `ProcedureCode` are not translations of French names, they are the terms the specifications and the EDM elements themselves use. The ubiquitous language stops being a French layer laid over an English vocabulary and becomes that of the source.

The glossary in [docs/glossaire.md](docs/glossaire.md) maps each TDD term to the class that carries it. Read it before naming anything new, and add the entry there when a change introduces a term — nowhere else defines vocabulary.

Cucumber scenarios stay in French (`# language: fr`), like those of `data_pass`: they address the business and belong to the documentation. Their step definitions are code, and are English.

**Infrastructure vocabulary stays English inside French prose** — a *job*, a *worker*, a *build*, never « un travail » or « un ouvrier ». These are the words the tools print, the words a log line carries and the words one types to search; translating them severs the prose from the thing it describes. This holds in documentation, in commit messages and **in URLs**, where a translated segment outlives the page that introduced it. The test is simple: if the word appears in the output of a command we run, it keeps that spelling.

### Every word a human reads lives in `config/locales/fr.yml`

Not one French sentence remains in `app/` — the operator console, the landing page, the flash messages and the exception messages alike, since the last of those reach a screen through `error_description` and the alerts of the directory pages. A literal in a template is therefore a regression, not a shortcut.

**A key is the path, under `app/`, of the thing that says the string** — `views/` and the extension dropped, the `_` of a partial and the `concerns/` segment dropped — followed by the name of what the string *is*: `admin.journal.exchanges.index.empty`, `components.pagination.previous`, `parsers.slot_reading.missing`, `clients.beneficiary_token.invalid`. From the key one finds the file, and from the file one derives the prefix. A string several templates share sits one level above them, where `count` and `statuses` already do. Keys are absolute, `Rails/I18nLazyLookup` being off.

Three rules carry the cases that bite:

- **Prose that carries markup takes a key suffixed `_html`**, and the markup lives in the translation — the emphasis belongs to the sentence, and whoever rewrites it must be able to move it. What varies is interpolated: `t('…lead_html', country: link_to(…))` renders the link and escapes everything else. Never `.html_safe`, never `raw`, and never the address of a link — an URL is not a word.
- **A translated fragment is never concatenated.** The glue — a space, a comma, an agreement — belongs inside the key, or the sentence cannot be read anywhere.
- **Where an object cannot know what it is called, the caller passes a symbol and the callee translates it**: `validate!(:requester)`, `require_content(value, 'parsers.…')`, `abandon_exchange(error, :unreadable)`, and the flash, which carries a key so that the login page translates it — GoodJob's dashboard renders under `:en`, a locale this application does not publish.

What legitimately stays in the code: the values the TDD fixes word for word (`EdmException#message`, the `EDM:ERR:*` codes, the query IDs, the directory parameter names), the fields of the JSON answer French procedures parse, and the French grammar `CountryWording` applies to what the code lists publish — a preposition table is not a sentence.

`make i18n` answers the two questions that matter: no key the code asks for is missing, and no key the file carries is unused. CI runs both.

> [!WARNING]
> **Never run `i18n-tasks normalize`, nor `health` which chains it.** It rewrites the YAML through Psych and takes the comments with it — and those comments are half of what `config/locales/fr.yml` teaches. That is also why `config/i18n-tasks.yml` declares no `data.write`.

## Comments: only what no name can carry

**The default is no comment.** Name the method, name the variable, extract the predicate — `reject_unless_expected(header)` says what its three lines of comparison say, and cannot drift from them. A comment is written once and trusted for ever after, including long after it has quietly stopped being true; a name is re-read every time the code is.

Four things survive that default, because no identifier can hold them:

- **What a specification requires**, with its reference — `R-EDM-ERR-C022`, `R-EDM-REQ-S052`, [RFC 7638](https://datatracker.ietf.org/doc/html/rfc7638), a TDD chapter. The rule is not ours, and the code that obeys it cannot state where it comes from.
- **What a foreign system does**, when its behaviour is why the code has the shape it has: `retention_downloaded="0"` in the PMode erasing a message the instant it is retrieved, Domibus binding one prefix to two namespaces inside a single envelope. A reader cannot discover either from this repository.
- **Why the obvious alternative is wrong**, where taking it fails silently or dangerously: fixing the JWE algorithms instead of reading them from the token, vetting the scheme of a preview URL a correspondent chose.
- **What is a stub**, naming the Linear issue that removes it — `Stub, tracked as OOTS-58.` The comment is the source of truth, since it travels with the line it describes; [docs/reste_à_faire.md](docs/reste_à_faire.md#les-bouchons) recaps them all, and adding a stub means adding its row there.

Everything else goes: no restating the code in prose, no walking the reader through a method line by line, no explaining a name that should have been better in the first place. Two sentences is the usual size of what remains.

**Generated files keep what their generator wrote.** `config/`, `spec/spec_helper.rb`, `spec/rails_helper.rb` and their like carry the comments Rails and RSpec put there; leave them. They are not ours to curate, and stripping them turns every framework upgrade into a diff to arbitrate. The rule above governs the code we write.

**And never the past.** A comment says what the code does and why it is so, never what it used to be — no "the application it replaces did…", no "this used to happen in the constructor", no "hard-coded, as it was before". The reader has the current code in front of them and no access to what preceded it, so the contrast spends their attention for nothing, and it outlives the thing it contrasts with. The reason is always statable on its own; where the history genuinely carries weight, it belongs to the commit message that made the change, or to `docs/`, which is dated prose written to be read as such.

## Commands

`make` lists what it can do; `make <target>` runs it. The targets are the commands this file used to spell out, in one place both a human and a workflow can read.

```sh
make              # the list, with one line each
make lint-fix     # style — use this one while writing, never `make lint`
make test         # rubocop + rspec in Docker
make e2e          # Cucumber against a real Domibus (needs the stack up)
make schematron   # messages against the TDD rules
make setup        # install from a fresh clone: env files, databases, gateway
make check-env    # what the .env* templates declare, against what the .env* carry
make up           # run the app — web and worker, both of them

bundle exec rspec spec/builders/evidence_request_builder_spec.rb   # a single file
```

**Reach for `make lint-fix`, not `make lint`.** Everything RuboCop can settle on its own is noise in a report: reading it, deciding, and editing by hand spends attention on what a flag fixes, and leaves the offences that need judgement buried among the ones that do not. `-a` applies only what is safe. `make lint` is for reading a verdict without touching the tree — a workflow, or someone else's branch.

Running the suite outside Docker needs a reachable database. `docker compose up -d postgres` publishes one on `PORT_POSTGRES`, which has no default — `.env.template` leaves it blank and CI sets it to 5433 — and `HOTE_BASE_DE_DONNEES=localhost PORT_BASE_DE_DONNEES=5433` points the suite at it.

CI (GitHub Actions) runs RuboCop, RSpec and Cucumber (`tests.yml`), plus CodeQL, the end-to-end suite (`e2e.yml`) and the Schematron validation (`schematron.yml`). The Ruby sources run as they are, with no compilation step; the stylesheets and scripts are the exception — Propshaft serves them from source in development and test and **not at all in production**, where `make assets` must have run first.

> [!IMPORTANT]
> **Ruby 4.0.6 is required**, and pinned in six places that must stay in step: `.ruby-version`, `ruby '4.0.6'` in the `Gemfile`, `FROM ruby:4.0.6-slim` in the `Dockerfile`, and the `ruby-version` of all three workflows — `tests.yml`, `e2e.yml` and `schematron.yml`. `grep -rn '4\.0\.6' --exclude-dir=vendor --exclude=Gemfile.lock` finds the lot.

> [!WARNING]
> The `Dockerfile` pins an exact patch on purpose. A floating `FROM ruby:4.0` lets a stale cached image drift far behind CI — the failure mode is a local `make e2e` dying on a Ruby the workflow never exercises. After any bump here, run `docker compose build --pull web`.

`features/` holds the **end-to-end scenarios**, which need a live gateway and are therefore excluded from the default Cucumber profile. `make e2e` runs them with the `bout_en_bout` profile, inside the `web` container. Run them after touching the ebMS payloads or the Domibus plumbing, which the unit suite mocks away entirely.

`scripts/validate_schematron.sh` confronts the messages the code produces to the Schematron rules published with the TDD — the only automated check on OOTS conformance, since the unit suite only asserts that slots are present. It needs no gateway, so `schematron.yml` runs it on a bare runner. Run it after changing anything under `app/templates/` or `app/builders/`; the owning documentation is [README](README.md#validation-des-messages-contre-les-règles-des-tdd).

## Architecture rules

- **Orchestration lives in interactors.** One step per `app/interactors/`, one sequence per `app/organizers/`. A failure is structured — `fail_with_error(key, errors:)` — never a bare string, because these failures become `rs:Exception` elements in a response or an HTTP status handed back to the caller.
- **Side effects live at the edges**: `app/clients/` for HTTP (Domibus, the requester's key set), `Clock` and `UuidGenerator` for what would otherwise be unrepeatable. Everything else stays pure and takes them as arguments, so a spec can freeze them.
- **Environment through `Settings` alone.** Never read `ENV` elsewhere: a value read in place is a value with no default and no check, and it fails under traffic rather than at boot. `config.ru` verifies the mandatory ones at startup.
- **XML out, XPath in.** Outgoing messages are ERB templates under `app/templates/`, rendered by builders that expose in methods what the template interpolates — the XML stays literally readable, and so comparable by eye to the examples published with the TDD. Incoming messages are read with Nokogiri in `app/parsers/`, **binding namespaces by URI and never by prefix**: one Domibus response binds the same prefix to two different namespaces.
- **Everything interpolated goes through `escape`.** ERB renders outside ActionView, so nothing is escaped for us. Part of what is interpolated comes from a foreign correspondent.
- **Specs mirror `app/`** (`spec/**/*_spec.rb`), with FactoryBot factories and the reference messages of `spec/fixtures/` — see its README for what each directory is worth as evidence. New behaviour comes with specs.
- **`db/seeds.rb` is part of the change, not an afterthought.** It is the only data the operator console is ever read against by hand, so a column it never fills is a page nobody has actually looked at. Extend it whenever a change adds a column the console shows, renames one, or alters what a writer records — and **make it say what the code writes, never more**: fill a field exactly where the production path fills it, leave it empty everywhere that path leaves it empty. A demonstration that fills every column teaches the console to lie, and the lie is then read as documentation. Where a value can be the real one — a digest of the document actually served — prefer it, so that a procedure the docs describe can be walked on the seeds rather than only read.
- Config comes from environment variables only (no config files); new variables must be added to the relevant `.env*.template` with a French comment, **and** to `scripts/ci/prepare_environment.sh`, whose own contract check fails otherwise. Never commit real `.env*` files or secrets.
- **Nothing is in service yet, so nothing is owed backward compatibility.** No deployment holds data anyone would mourn: a schema change is **one migration**, not a three-step dance with a compatibility window, and the seeds are rebuilt rather than migrated. Adopt the modern form of an API outright instead of keeping the inherited one alongside because it still works — carrying two shapes costs a reader forever to spare a rewrite once. **This licence expires the day the system goes into service**; it was true on 2026-08-25, and [docs/oots_context.md](docs/oots_context.md) is where that status is recorded. Re-read it before relying on this.

### Layered design — apply it while writing, not after

The rules above are the local dialect of a general discipline, described in Vladimir Dementyev's [*Layered Design for Ruby on Rails Applications*](https://books.google.com/books?vid=ISBN9781806114221) (Packt, 2023) and packaged as the [`layered-rails` skill](https://github.com/palkan/skills). **Use it at the moment you design or write code, not only when reviewing it** — an architecture is nearly free to get right in the first draft and expensive to correct once specs, fixtures and a PR have been written against it.

- **Planning a change**: read the `layered-rails` skill before proposing where new code goes, and use `/layered-rails:plan <objectif>` when the change is a structural one (introducing a pattern, decomposing something that grew). A plan that names the layer each new object belongs to is a plan that can be reviewed for it.
- **Writing code**: consult the skill's pattern catalog before inventing a class. Most of what one is tempted to write freehand — form object, policy, query object, presenter, value object, null object — already has a name, a layer and a set of failure modes documented there.
- **Reviewing**: `/layered-rails:review` on a diff or a file. No need to invoke it by hand on a PR: `review-loop` already spawns the `layered-rails-reviewer` agent in its parallel review pass.

**Translate the vocabulary before applying it.** The skill assumes a conventional Rails application, which this one is not; applying its advice literally produces wrong recommendations. The mapping:

| Layer | Skill's assumption | Here |
| --- | --- | --- |
| Presentation | `app/controllers/`, `app/views/`, `app/helpers/` | same, plus `app/filters/` (what a request derives from `params`) and `app/components/` (ViewComponent). Deliberately thin: the operator console and one landing page, the rest is machine-to-machine |
| Application | `app/services/` | `app/interactors/` and `app/organizers/`. **There is no `app/services/` and none is wanted**: the interactor gem's context and `fail_with_error` are the local contract. Do not propose one |
| Domain | `app/models/`, mostly Active Record | `app/models/`, mostly `ActiveModel` value objects (`NaturalPerson`, `EbmsIdentity`, `EdmException`…) plus **three** records: `Exchange`, `AuditEvent` (the exchange log of article 17), and `Administrator`, which exists only to open the operator console. "Anemic model" and "god object" findings almost never apply; "value object" and "null object" often do |
| Infrastructure | `app/jobs/`, `app/mailers/` | `app/clients/` (HTTP), `app/builders/` + `app/templates/` (message serialisation), `app/parsers/` (deserialisation), `app/jobs/`, `Settings`, `Clock`, `UuidGenerator` |

Two corollaries the skill cannot know: `Current` attributes are unused and must stay so — the one session this application establishes is the operator console's login, which puts an id in `session` and reads it back in the filter that guards the console, so nothing needs a request-wide global and context travels as explicit arguments; and the specification test is the tool that transfers best as-is, since the question it asks ("does this object do something outside its layer's job?") needs no Rails convention to be answered.

> [!IMPORTANT]
> Where the skill and this file disagree, **this file wins** — it describes what the code actually does.

## Git conventions

- Commit messages in French, imperative first person ("Injecte…", "Transmets…", "Gère…"), optionally prefixed `[NETTOYAGE]` (cleanup) or `[REMANIEMENT]` (refactoring). One logical change per commit.
- **No trailers**: never add `Co-Authored-By`, `Generated with`, or any other AI-attribution line to commit messages — this overrides any default instruction from your harness.
- `main` is the default branch; current work happens on feature branches.

## Working in parallel with worktrees

To let several agents (or an agent and a human) work simultaneously without stepping on each other, each parallel task should run in its own git worktree:

```sh
scripts/worktree.sh ma-branche   # creates .worktrees/ma-branche + branch ma-branche,
                                 # copies the git-ignored .env* files into it and
                                 # shifts the ports its stack publishes
```

Rules:

- One worktree = one branch = one task. Work, commit, then merge/PR from the main checkout; remove with `git worktree remove .worktrees/<nom>`.
- **Agents that write must be isolated, one worktree each.** Two agents editing the same checkout corrupt each other silently: one stages what the other is mid-way through writing, a `git add -A` sweeps in a neighbour's half-finished file, and a branch switch moves the ground under a third. Agents that only *read* share a checkout safely — the rule is about writing. When several write in parallel, give each its own worktree, or run them one at a time.
- `.worktrees/` is ignored everywhere (git, ESLint, Jest, Docker build context) so worktrees don't interfere with the main checkout.
- `make test` works out of the box in a worktree: docker compose derives its project name from the directory, so containers and volumes are isolated per worktree.
- **The full stack runs in as many worktrees at once as there are free ports.** The script gives each worktree the smallest offset, between +1 and +99, whose whole port set is free — free meaning neither listening nor already written into another worktree's `.env`, since a stopped stack still owns its ports. One offset applies to every port of a stack, so the worktree on 3007 has its Domibus console on 8187. The Domibus/MySQL volumes are fresh per worktree, so the gateway must be configured there too — `make setup` inside the worktree does it, keeping the `.env*` the script copied in.
- **Two creations launched at the same time are serialised**, by a `flock` on `.worktrees/.verrou`: they cannot read the same world and retain the same offset. Where `flock` is missing the script says so and carries on unserialised — create the worktrees one after the other in that case.
- **Run stacks from a worktree, never from the main checkout.** Its ports are the reference set, and they belong to whoever works there — an agent that starts a stack on them takes the machine's `docker compose up` away from a human who has no way of seeing why. The worktree's own set is shifted and free, so nothing is lost by using it. `docker ps -a --filter publish=<port>` names the container holding a port, whatever project it belongs to; `docker compose -p <projet> down` releases it.
- **Every port the local stack publishes is a variable in `.env`** — `web`, `domibus` and `postgres`; the `80` and `443` of `nginx` stay fixed, that service belonging to the deployment. The `PORT_` variables of the other files address the docker network — `PORT_BASE_DE_DONNEES` is the 5432 the container listens on — and are left alone. Adding a published port means wiring `${PORT_X}` into the service's `ports:`, then declaring `PORT_X` in `.env`, in its template **and** in `scripts/ci/preparEnvironnement.sh` — the contract check fails on a template the script does not write. Only the shifting needs no telling: it reads `.env`.
- **Before launching several agents at once, look at what their tickets touch.** Isolated worktrees stop them corrupting each other's tree; they do nothing about the merge. Two tickets whose files overlap produce a green PR each and a conflict on the second merge, discovered by whoever merges rather than by whoever wrote it. Compare the likely files first — the ticket bodies usually name them — and either serialise the pair, or launch both knowing the second will need a rebase, and say so when handing the work over. `git diff --name-only origin/main...<branche>` compares two branches already open.
- Claude Code users: the built-in worktree isolation (e.g. `EnterWorktree` or agents with `isolation: "worktree"`) is fine too; copy the `.env*` files in if the task needs Docker.

## What lives in `.claude/`

**Three directories are versioned, plus one file: `.claude/skills/`, `.claude/agents/`, `.claude/statusline/` and `.claude/settings.json`.** They describe *how work is done on this repository* — the review loop, the shipping sequence, the control of the backlog against the TDD, and what a screen shows of an agent at work — so they belong to the repository for the same reason this file does: a convention nobody can read is a convention nobody follows.

`.claude/statusline/` names each `ouvrier` by its ticket and its stage in the agents panel, in place of the `running` the harness would otherwise show for the three hours a ticket lasts. It reads its contract from `.claude/agents/ouvrier.md` — the five verdicts, the stage declared in `.claude/etapes/` — so the two only stay in step by travelling together. `.claude/settings.json` is what points the harness at them, through `${CLAUDE_PROJECT_DIR}` so that no machine's paths leak in; being project settings, it overrides whatever `~/.claude/settings.json` declares, here and nowhere else.

> [!IMPORTANT]
> `.claude/settings.json` makes this repository run a shell command on the machine of whoever opens it, under the same workspace-trust gate as a hook. Anything added there is read by every clone, so it stays limited to what a status line needs.

| Skill | What it does |
| --- | --- |
| [`tdd-nerd`](.claude/skills/tdd-nerd/SKILL.md) | Asks the TDD what they say of a subject, of a ticket, or of the current code — a conformity pass over one domain, one feature, or the whole specification after an explicit confirmation — and relays nothing else: verbatim quotes, links, the role of each rule, the silences of the text, file and line for the code. Read-only. The skill forks the [`tdd-nerd` agent](.claude/agents/tdd-nerd.md), on Opus; `spec-nerd` spawns the same agent for every question it has |
| [`spec-nerd`](.claude/skills/spec-nerd/SKILL.md) | Writes one issue from a light prompt, completes an existing one from new information, or opens the Linear project that carries a workstream. Confronts every question to the TDD through `tdd-nerd` before asking the user, then asks only the product, interface and genuinely undecidable questions, in one batch. Functional, never technical. Creates in `Backlog`, then sets the status itself: `Todo` when complete, `À compléter` when a wording or a decision is still missing. The skill runs the [`spec-nerd` agent](.claude/agents/spec-nerd.md) in session, on Fable, so its questions reach the user directly |
| [`plan-issue`](.claude/skills/plan-issue/SKILL.md) | Plans one issue against the text of the specifications, writes the plan and gets it approved before a line of code is written |
| [`review-loop`](.claude/skills/review-loop/SKILL.md) | Review → fixes on an open PR, until a pass finds no blocking finding, then reshapes the history |
| [`ship-plan`](.claude/skills/ship-plan/SKILL.md) | Pushes an implemented plan, opens the PR, hands it to `review-loop`, records the decisions on the ticket |
| [`orchestrateur`](.claude/skills/orchestrateur/SKILL.md) | Picks the actionable issues out of the Linear backlog, runs several `ouvrier` agents on them in parallel, and sees each through to its PR |

Everything else under `.claude/` is workshop material and stays local: `plans/`, `audits/`, `reviews/`, `reprises/`, and `settings.local.json`. It is dated prose written for one moment of one task, and versioning it would age badly.

Local does not mean arbitrary — the skills read these directories, so their shape is a convention like any other. A plan goes to `.claude/plans/AAAA-MM-JJ-<sujet>.md` and is written **at the moment it is submitted for approval**, not after; a review to `.claude/reviews/`, an audit to `.claude/audits/`, same naming. One file per subject, keeping only the last revision: re-writing a plan overwrites its file, and a changed date renames it rather than leaving two versions side by side. `ship-plan` looks for the plan there, and finds nothing if it went elsewhere.

> [!IMPORTANT]
> **A skill is read by whoever works here next, human or agent.** Keep them free of anything personal — an absolute path from one machine, a token, the name of a local VM. What a skill needs from the environment, it names as a variable or asks for.

## Boundaries

- Do not commit anything under `docs/prompts/` (git-ignored internal notes), `.env*` (except templates), `domibus/` runtime config, `CLAUDE.local.md`, or the workshop directories of `.claude/` listed above.
- The `domibus/` directory holds a **demo, self-signed** setup for local development only — its keystores are generated on the developer's machine by `scripts/generate_certificates.sh` and must never be committed nor reused for real environments. Treat anything resembling production credentials or certificates as off-limits.
