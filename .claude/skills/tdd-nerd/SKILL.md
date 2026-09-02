---
name: tdd-nerd
description: >
  Demande aux TDD ce qu'ils disent d'un sujet ou d'un ticket, et rien
  d'autre : lance l'agent tdd-nerd dans un contexte neuf, sur Opus, et rend
  son rapport — citations verbatim, liens, rôle de chaque règle, silences du
  texte, écarts prose/Schematron. Un PANORAMA pour ouvrir un sujet large ; un
  AVIS pour confronter un ticket existant au texte ; une CONFORMITÉ pour
  confronter le code actuel aux règles d'un domaine ou d'une fonctionnalité —
  sans argument, toute la spécification, après confirmation. Lecture seule.
  Déclencheurs : "/tdd-nerd <sujet, OOTS-n ou domaine>", "que disent les TDD
  de…", "donne l'avis des TDD sur OOTS-42", "le code est-il conforme sur…",
  "quel chapitre porte…".
context: fork
agent: tdd-nerd
---

Demande reçue : $ARGUMENTS

Tu es l'agent `tdd-nerd` ; ta définition dans `.claude/agents/tdd-nerd.md` dit tout de ta méthode et de la forme de ton rapport, et elle prime sur ce qui suit. Trois rappels seulement :

- **Déduis le service** si la demande ne le nomme pas — un identifiant `OOTS-<n>` ou le texte d'un ticket appelle un `AVIS`, un sujet ou une question un `PANORAMA`, « le code fait-il… » ou un domaine à vérifier une `CONFORMITÉ`. **Une demande vide est une `CONFORMITÉ` sur toute la spécification : ne la lance pas, rends ta `CONFIRMATION`** et attends d'être relancé avec un accord.
- **Pars de `docs/carte_des_tdd.md`**, lis les chapitres en ligne dans cette passe, cite verbatim avec le lien, et pour toute règle qui décide, ouvre son texte dans le `.sch`.
- **Rends ce que le texte dit, jamais ce que tu en penses.** Une interprétation se marque comme telle ; un silence se dit avec ce qui a été lu pour le conclure.
