# Lire les TDD

Lu au premier chapitre ouvert d'une passe. Partagé : `contradicteur`, `spec-nerd`, `plan-issue` et l'orchestrateur y renvoient.

**Commence par [`docs/carte_des_tdd.md`](../../../docs/carte_des_tdd.md).** Elle dit quel chapitre répond à quelle question, où vivent les artefacts machine, et donne les valeurs fixes qu'on recherche sans cesse. [`docs/versions_tdd.md`](../../../docs/versions_tdd.md) dit quelle version fait foi — cite cette version-là.

Puis les chapitres, **en ligne, dans la passe**. Quatre pièges, tous déjà tombés dedans :

- **Une page de chapitre qui paraît vide est une page mère.** Ses sous-pages ne sont pas dans le HTML servi ; la carte donne l'appel REST qui les énumère. Ne conclus jamais qu'un chapitre est muet sans l'avoir joué.
- **Les chapitres de règles injectent leur contenu par un macro** — 3.1.7, 3.2.6, 4.6, 4.7.2. `curl -L` sur l'URL de la page rend les règles ; `body.storage` de l'API ne les rend pas. Les mêmes règles sont en Git, `OOTS-EDM/xlsx/html/<chapitre>.html` au tag de version.
- **L'outil de lecture résume, et son résumé omet en silence.** Une première lecture du tableau des délais du 4.4.3 n'a rendu que les libellés des lignes ; les gloses, la colonne *Scope*, la note sous le tableau ont eu besoin d'une seconde lecture demandée *verbatim*, en nommant ce qu'on voulait voir. Demande le texte, pas le sens ; nomme les notes, les colonnes, la phrase qui clôt la section.
- **La prose et le Schematron divergent**, dans les deux sens : `R-EDM-REQ-S062` (FATAL) manque au 4.6, qui liste pourtant ses voisines `S060` et `S061` — seule la table des slots du 4.5.1 la cite ; `R-EDM-RESP-S047` assure *at least one* là où la prose du 4.5.2 écrit *Exactly one* ; la prose de 4.9 §4 nomme un slot que `R-EDM-ERR-S027` interdit. **Pour toute règle qui décide d'un verdict, lis son texte dans le `.sch`** — `.schematron/2.0.1/sch/` dans le dépôt (`grep -n -A6 'R-EDM-REQ-C074'` rend contexte, test et message), ou l'amont que la carte indique — et quand les deux divergent, rends l'écart sans le trancher.

**Lis chaque chapitre en un geste, pas en vingt.** Télécharge-le une fois dans le scratchpad, puis extrais-en d'un seul script tout ce que la question appelle — les sections, les règles, les notes sous les tableaux — plutôt que d'enchaîner les `grep` interactifs : chaque appel d'outil rejoue tout ton contexte, et vingt greps de 25 000 caractères sur un chapitre déjà chargé ont coûté 10 M de jetons à un seul panorama le 2026-09-07. Ce que tu as cité une fois ne se relit pas dans le contexte : garde-le dans ton rapport en cours, et fais tourner la prochaine extraction sur ce qui manque.

**Le silence du texte est une réponse**, souvent la plus utile. « Comment reconstruire une requête portant le bénéficiaire ? » n'a aucune réponse dans le 4.9 : ce silence dit que le modèle suppose un portail qui a l'usager devant lui, et c'est cela qu'il fallait rendre. Dis ce que tu as lu pour conclure au silence, pour qu'on puisse le contester.

**Attribue à qui de droit.** Le 4.4.2 item 3 dit « *the system* », pas « le portail ». Prêter un acteur à un texte qui n'en nomme aucun est la même faute qu'inventer une règle.

**Quand le code est en cause** — « le code fait-il ce que la règle dit ? » —, ouvre les fichiers que le chapitre gouverne et rends ce qu'ils font, avec le chemin et la ligne. Pas ce qu'un ticket ou une doc en raconte.
