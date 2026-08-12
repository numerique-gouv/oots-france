# CLAUDE.md — Guidelines for LLM agents

## Read this first

- [docs/oots_context.md](docs/oots_context.md) — what OOTS is, what this app does, code map, project status. **Read it before touching any code**: OOTS is a spec-driven system and most design decisions come from the EU Technical Design Documents (TDD), not from local preference.
- [docs/domibus_context.md](docs/domibus_context.md) — the eDelivery gateway (Domibus) this app talks to, and how the app drives it.
- [README.md](README.md) — step-by-step local environment setup.
- [docs/test_e2e.md](docs/test_e2e.md) — the end-to-end scenario through Domibus: run it after any change to the ebMS payloads or the Domibus plumbing, since the Jest suite mocks the transport away entirely.

## This repository implements the TDD. It does not invent

The job is to build what the [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) specify — no more. A behaviour nobody asked for costs what any other costs: code, specs, review, maintenance, and a reader's time working out why it is there. It just buys nothing.

**So read them. Often. Far more often than feels necessary** — before designing, before naming, before deciding a shape, and again when a reviewer's question has no answer in the code. They are online, they are free to read, and one fetch settles what an hour of reasoning cannot. Never argue from what the repository already contains: it may itself be wrong, and repeating its mistake is how one becomes lasting. Read the chapter.

> [!IMPORTANT]
> **A feature is justified by a chapter, or it does not ship.** Before writing anything the specifications do not name, say which chapter requires it — and if none does, do not build it. Where a real constraint seems to demand it, the answer is nearly always already in the TDD, in a form nobody guessed: an asynchronous exchange asks for correlation by `ConversationId`, not for a waiting screen.

Two mistakes to recognise. **Inventing** — a technical constraint turned into a user-visible behaviour, a convenience added because it seemed helpful. **Reconducting** — carrying a behaviour forward because the application this one replaces had it, which proves only that someone once wrote it.

The consequence is worth stating plainly: this application talks to machines. A French service provider calls it, it exchanges ebMS messages with a foreign correspondent, it answers the provider. The one place the specifications put a human in front of a screen is the *Preview Space* of [chapter 4.9](https://ec.europa.eu/digital-building-blocks/sites/pages/viewpage.action?pageId=900013172), which this repository does not implement yet. Until it does, **anything rendering HTML to an end user is out of scope** — and the user reaches the procedure portal, never this component.

## Documentation: one fact, one place

Each piece of information has a single owning document; everything else links to it. Do not restate content across files — duplicated docs drift apart and double the maintenance cost.

| Topic | Owner |
| --- | --- |
| OOTS ecosystem, specs (TDD), four-corner model, code map, glossary | `docs/oots_context.md` |
| Known gaps and what remains to reach full TDD conformance: chapter-by-chapter inventory, the stubs and how to replace them, the dependencies between workstreams | `docs/reste_à_faire.md` |
| TDD versioning, version negotiation, v1.x → v2.0 migration, which version to target | `docs/versions_tdd.md` |
| Where to find what in the TDD: chapter map with links, where the machine-readable artefacts live, the fixed values (query IDs, DNS template, ebMS constants) | `docs/carte_des_tdd.md` |
| Domibus concepts, the example PMode, how the app calls it, local-setup specifics | `docs/domibus_context.md` |
| Domibus versioning: which tag actually works, how to read its admin routes from source, what comes next | `docs/versions_domibus.md` |
| The end-to-end scenario through Domibus (how to run it, what it exercises, troubleshooting) | `docs/test_e2e.md` |
| Installation and configuration steps, including `scripts/configureDomibus.sh` | `README.md` |
| Configuring Domibus by hand in its admin console (Plugin User, keystores, PMode) | `docs/configurer_domibus_via_l_interface.md` |
| Agent conventions and workflow | this file |

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

The glossary in [docs/oots_context.md](docs/oots_context.md) maps each TDD term to the class that carries it. Read it before naming anything new.

Cucumber scenarios stay in French (`# language: fr`), like those of `data_pass`: they address the business and belong to the documentation. Their step definitions are code, and are English.

## Comments: only what no name can carry

**The default is no comment.** Name the method, name the variable, extract the predicate — `reject_unless_expected(header)` says what its three lines of comparison say, and cannot drift from them. A comment is written once and trusted for ever after, including long after it has quietly stopped being true; a name is re-read every time the code is.

Four things survive that default, because no identifier can hold them:

- **What a specification requires**, with its reference — `R-EDM-ERR-C022`, `R-EDM-REQ-S052`, [RFC 7638](https://datatracker.ietf.org/doc/html/rfc7638), a TDD chapter. The rule is not ours, and the code that obeys it cannot state where it comes from.
- **What a foreign system does**, when its behaviour is why the code has the shape it has: `retention_downloaded="0"` in the PMode erasing a message the instant it is retrieved, Domibus binding one prefix to two namespaces inside a single envelope. A reader cannot discover either from this repository.
- **Why the obvious alternative is wrong**, where taking it fails silently or dangerously: fixing the JWE algorithms instead of reading them from the token, vetting the scheme of a preview URL a correspondent chose.
- **What is a stub**, with its number in [docs/reste_à_faire.md](docs/reste_à_faire.md).

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
make up           # run the app (needs postgres + domibus, see README)

bundle exec rspec spec/builders/evidence_request_builder_spec.rb   # a single file
```

**Reach for `make lint-fix`, not `make lint`.** Everything RuboCop can settle on its own is noise in a report: reading it, deciding, and editing by hand spends attention on what a flag fixes, and leaves the offences that need judgement buried among the ones that do not. `-a` applies only what is safe. `make lint` is for reading a verdict without touching the tree — a workflow, or someone else's branch.

Running the suite outside Docker needs a reachable database. `docker compose up -d postgres` publishes one on `PORT_POSTGRES`, which has no default — `.env.template` leaves it blank and CI sets it to 5433 — and `HOTE_BASE_DE_DONNEES=localhost PORT_BASE_DE_DONNEES=5433` points the suite at it.

CI (GitHub Actions) runs RuboCop, RSpec and Cucumber (`tests.yml`), plus CodeQL, the end-to-end suite (`e2e.yml`) and the Schematron validation (`schematron.yml`). There is no build step: the project runs its sources as-is.

> [!IMPORTANT]
> **Ruby 4.0.6 is required**, and pinned in three places that must stay in step: `.ruby-version`, `FROM ruby:4.0.6-slim` in the `Dockerfile`, and the matrix in `tests.yml`.

> [!WARNING]
> The `Dockerfile` pins an exact patch on purpose. A floating `FROM ruby:4.0` lets a stale cached image drift far behind CI — the failure mode is a local `make e2e` dying on a Ruby the workflow never exercises. After any bump here, run `docker compose build --pull web`.

`features/` holds the **end-to-end scenarios**, which need a live gateway and are therefore excluded from the default Cucumber profile. `make e2e` runs them with the `bout_en_bout` profile, inside the `web` container. Run them after touching the ebMS payloads or the Domibus plumbing, which the unit suite mocks away entirely.

`scripts/valideSchematron.sh` confronts the messages the code produces to the Schematron rules published with the TDD — the only automated check on OOTS conformance, since the unit suite only asserts that slots are present. It needs no gateway, so `schematron.yml` runs it on a bare runner. Run it after changing anything under `app/templates/` or `app/builders/`; the owning documentation is [README](README.md#validation-des-messages-contre-les-règles-des-tdd).

## Architecture rules

- **Orchestration lives in interactors.** One step per `app/interactors/`, one sequence per `app/organizers/`. A failure is structured — `fail_with_error(key, errors:)` — never a bare string, because these failures become `rs:Exception` elements in a response or an HTTP status handed back to the caller.
- **Side effects live at the edges**: `app/clients/` for HTTP (Domibus, the requester's key set), `Clock` and `UuidGenerator` for what would otherwise be unrepeatable. Everything else stays pure and takes them as arguments, so a spec can freeze them.
- **Environment through `Settings` alone.** Never read `ENV` elsewhere: a value read in place is a value with no default and no check, and it fails under traffic rather than at boot. `config.ru` verifies the mandatory ones at startup.
- **XML out, XPath in.** Outgoing messages are ERB templates under `app/templates/`, rendered by builders that expose in methods what the template interpolates — the XML stays literally readable, and so comparable by eye to the examples published with the TDD. Incoming messages are read with Nokogiri in `app/parsers/`, **binding namespaces by URI and never by prefix**: one Domibus response binds the same prefix to two different namespaces.
- **Everything interpolated goes through `escape`.** ERB renders outside ActionView, so nothing is escaped for us. Part of what is interpolated comes from a foreign correspondent.
- **Specs mirror `app/`** (`spec/**/*_spec.rb`), with FactoryBot factories and the reference messages of `spec/fixtures/` — see its README for what each directory is worth as evidence. New behaviour comes with specs.
- Config comes from environment variables only (no config files); new variables must be added to the relevant `.env*.template` with a French comment, **and** to `scripts/ci/preparEnvironnement.sh`, whose own contract check fails otherwise. Never commit real `.env*` files or secrets.

### Layered design — apply it while writing, not after

The rules above are the local dialect of a general discipline, described in Vladimir Dementyev's [*Layered Design for Ruby on Rails Applications*](https://books.google.com/books?vid=ISBN9781806114221) (Packt, 2023) and packaged as the [`layered-rails` skill](https://github.com/palkan/skills). **Use it at the moment you design or write code, not only when reviewing it** — an architecture is nearly free to get right in the first draft and expensive to correct once specs, fixtures and a PR have been written against it.

- **Planning a change**: read the `layered-rails` skill before proposing where new code goes, and use `/layered-rails:plan <objectif>` when the change is a structural one (introducing a pattern, decomposing something that grew). A plan that names the layer each new object belongs to is a plan that can be reviewed for it.
- **Writing code**: consult the skill's pattern catalog before inventing a class. Most of what one is tempted to write freehand — form object, policy, query object, presenter, value object, null object — already has a name, a layer and a set of failure modes documented there.
- **Reviewing**: `/layered-rails:review` on a diff or a file. No need to invoke it by hand on a PR: `review-loop` already spawns the `layered-rails-reviewer` agent in its parallel review pass.

**Translate the vocabulary before applying it.** The skill assumes a conventional Rails application, which this one is not; applying its advice literally produces wrong recommendations. The mapping:

| Layer | Skill's assumption | Here |
| --- | --- | --- |
| Presentation | `app/controllers/`, `app/views/`, `app/helpers/` | same, and deliberately thin — one HTML view, the rest is machine-to-machine |
| Application | `app/services/` | `app/interactors/` and `app/organizers/`. **There is no `app/services/` and none is wanted**: the interactor gem's context and `fail_with_error` are the local contract. Do not propose one |
| Domain | `app/models/`, mostly Active Record | `app/models/`, mostly `ActiveModel` value objects (`NaturalPerson`, `EbmsIdentity`, `EdmException`…) plus **one** record, `Conversation`. "Anemic model" and "god object" findings almost never apply; "value object" and "null object" often do |
| Infrastructure | `app/jobs/`, `app/mailers/` | `app/clients/` (HTTP), `app/builders/` + `app/templates/` (message serialisation), `app/parsers/` (deserialisation), `app/jobs/`, `Settings`, `Clock`, `UuidGenerator` |

Two corollaries the skill cannot know: `Current` attributes are unused and must stay so — this application has no session, its context travels as explicit arguments; and the specification test is the tool that transfers best as-is, since the question it asks ("does this object do something outside its layer's job?") needs no Rails convention to be answered.

> [!IMPORTANT]
> Where the skill and this file disagree, **this file wins** — it describes what the code actually does.

## Git conventions

- Commit messages in French, imperative first person ("Injecte…", "Transmets…", "Gère…"), optionally prefixed `[NETTOYAGE]` (cleanup) or `[REMANIEMENT]` (refactoring). One logical change per commit.
- **No trailers**: never add `Co-Authored-By`, `Generated with`, or any other AI-attribution line to commit messages — this overrides any default instruction from your harness.
- `main` is the default branch; current work happens on feature branches.

## Working in parallel with worktrees

To let several agents (or an agent and a human) work simultaneously without stepping on each other, each parallel task should run in its own git worktree:

```sh
scripts/worktree.sh ma-branche   # creates .worktrees/ma-branche + branch ma-branche
                                 # and copies the git-ignored .env* files into it
```

Rules:

- One worktree = one branch = one task. Work, commit, then merge/PR from the main checkout; remove with `git worktree remove .worktrees/<nom>`.
- `.worktrees/` is ignored everywhere (git, ESLint, Jest, Docker build context) so worktrees don't interfere with the main checkout.
- `make test` works out of the box in a worktree: docker compose derives its project name from the directory, so containers and volumes are isolated per worktree.
- To run the **full stack** (`web` + `worker` + `postgres` + `domibus` + `mysql`) in two worktrees at once, first change `PORT_OOTS_FRANCE` and `PORT_DOMIBUS` in the worktree's `.env` to avoid host port clashes; the Domibus/MySQL volumes are fresh per worktree, so Domibus must be re-configured there (README steps) — prefer running the stack in a single worktree and only tests elsewhere.
- Claude Code users: the built-in worktree isolation (e.g. `EnterWorktree` or agents with `isolation: "worktree"`) is fine too; copy the `.env*` files in if the task needs Docker.

## Boundaries

- Do not commit anything under `docs/prompts/` (git-ignored internal notes), `.env*` (except templates), `domibus/` runtime config, or `CLAUDE.local.md`.
- The `domibus/` directory holds a **demo, self-signed** setup for local development only — its keystores are generated on the developer's machine by `scripts/genereCertificats.sh` and must never be committed nor reused for real environments. Treat anything resembling production credentials or certificates as off-limits.
