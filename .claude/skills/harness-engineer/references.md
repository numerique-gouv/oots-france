# Références de la méthode

Quatre textes fondent la méthode, et on les rouvre plutôt que de s'en souvenir :

- [What is harness engineering ?](https://harnessengineering.academy/blog/what-is-harness-engineering-introduction-2026/) — les trois piliers : contexte, contraintes, entropie.
- [Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) (Fowler) — la distinction entre ce qui guide avant l'action et ce qui contrôle après.
- [Spécifier, c'est coder](https://yoandev.co/specifier-c-est-coder) — la boucle de rétroaction : chaque correction faite à la main pose la question « aurait-elle dû être dans un fichier du dépôt ? ».
- [awesome-harness-engineering](https://github.com/walkinglabs/awesome-harness-engineering) donne le reste, dont [Better Harness](https://github.com/QoderAI/better-harness), qui fait de la preuve de session la seule base d'une recommandation (« *missing or partial evidence remains explicit* »).

Pour la forme des fichiers eux-mêmes :

- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) (Anthropic) — `SKILL.md` sous 500 lignes, description sous 1 024 caractères, frères à un niveau de profondeur, sommaire au-delà de 100 lignes, pas d'information datée hors d'une section « old patterns ».
- [`writing-for-agents`](https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md) et [`invocation.md`](https://github.com/mattpocock/skills/blob/main/.agents/invocation.md) (mattpocock) — pointeurs de contexte, hiérarchie de l'information, no-ops, négation, mots-clés, et l'appel d'un skill par l'outil plutôt que par un `/nom` dans la prose.
- [Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md) (HumanLayer) — moins de 300 lignes, universel, jamais un travail de linter.
