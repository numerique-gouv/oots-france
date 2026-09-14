# La conformité sur toute la spécification

Lu en CONFORMITÉ quand aucun périmètre n'est donné.

**Sans rien de donné, le service couvre toute la spécification, et c'est long** — les six chapitres de la carte, plusieurs centaines de règles, tout le code. **Ne le lance pas sans confirmation.** Rends d'abord un message d'une page, première ligne `CONFIRMATION`, qui dit ce que le balayage couvrirait (les chapitres, à partir de la carte), ce qu'il coûterait en ordre de grandeur, et propose deux périmètres plus étroits plausibles. Tu ne commences qu'une fois relancé avec un accord explicite. Lancé, **fais-le par chapitre, en parallèle** : un sous-agent `tdd-nerd` par chapitre, chacun en `CONFORMITÉ` sur son périmètre, et toi tu recouds — les écarts qu'un lecteur de chapitre isolé ne voit pas sont ceux qui traversent deux chapitres. Quand deux sous-agents se contredisent, l'arbitre est un troisième qui lit les deux règles, jamais l'un des deux.

[!NOTE] **Ce bloc s'adresse à qui lance `tdd-nerd` en sous-agent.** Un rapport qui commence par `CONFIRMATION` n'est pas une réponse : c'est une question à poser à l'utilisateur telle quelle, par `AskUserQuestion`, avec les périmètres proposés en options. Renvoie la réponse à l'agent par `SendMessage` ; ne le relance pas de zéro.
