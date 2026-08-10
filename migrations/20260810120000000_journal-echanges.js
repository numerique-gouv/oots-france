// Le journal des échanges exigé par l'article 17 du règlement d'exécution
// (UE) 2022/1463, décliné par le chapitre 4.8 des TDD.
//
// Tout est écrit en SQL brut plutôt qu'avec les constructeurs de
// `node-pg-migrate` : le déclencheur de chaînage, les privilèges et les vues
// n'ont de toute façon pas d'équivalent dans son API, et mélanger les deux
// idiomes éclaterait la définition d'une même table.

exports.up = (pgm) => {
  pgm.sql(`
    CREATE TABLE journal_echanges (
      id                            bigserial PRIMARY KEY,
      horodatage                    timestamptz NOT NULL DEFAULT now(),
      type_evenement                text NOT NULL,
      action_ebms                   text,
      id_conversation               text,
      id_message                    text,
      id_echange                    text,
      id_requete                    text,
      id_reponse                    text,
      autorite_requerante           text,
      schema_autorite_requerante    text,
      autorite_fournisseuse         text,
      schema_autorite_fournisseuse  text,
      id_requeteur                  text,
      sujet_justificatif            text,
      type_justificatif             text,
      code_demarche                 text,
      type_mime                     text,
      empreinte_justificatif        text,
      code_erreur                   text,
      empreinte                     text,
      empreinte_precedente          text,

      CONSTRAINT type_evenement_connu CHECK (type_evenement IN (
        'requete_emise',
        'reponse_recue',
        'erreur_recue',
        'requete_recue',
        'reponse_emise',
        'piece_transmise',
        'requete_refusee'
      ))
    );

    COMMENT ON TABLE journal_echanges IS
      'Journal des échanges de justificatifs (TDD 4.8, article 17 du règlement (UE) 2022/1463). Conservation douze mois. Ne porte jamais le justificatif lui-même, seulement son empreinte.';
    COMMENT ON COLUMN journal_echanges.empreinte_justificatif IS
      'SHA-256 de la pièce transportée. Suffit à prouver après coup qu''un document donné est celui qui a transité, sans le conserver.';
    COMMENT ON COLUMN journal_echanges.empreinte IS
      'Maillon de la chaîne : SHA-256 du contenu canonique de la ligne, préfixé de l''empreinte précédente. Calculé par le déclencheur, jamais par l''application.';

    CREATE INDEX journal_echanges_conversation ON journal_echanges (id_conversation);
    CREATE INDEX journal_echanges_horodatage ON journal_echanges (horodatage DESC);
  `)

  // Le contenu haché, défini une seule fois : le déclencheur le calcule à
  // l'insertion, la vérification le recalcule à la lecture. Deux expressions
  // séparées dériveraient, et toute la chaîne paraîtrait rompue.
  //
  // `concat_ws` est positionnel — d'où le `coalesce` sur chaque colonne, sans
  // lequel une valeur nulle décalerait les suivantes et deux lignes
  // différentes pourraient produire le même texte. L'horodatage est rendu en
  // UTC par `to_char` plutôt que laissé au format de la session, qui dépend du
  // fuseau du client et ferait varier l'empreinte d'une connexion à l'autre.
  pgm.sql(`
    CREATE FUNCTION contenu_canonique_journal(e journal_echanges) RETURNS text AS $$
      SELECT concat_ws('|',
        e.id::text,
        to_char(e.horodatage AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        coalesce(e.type_evenement, ''),
        coalesce(e.action_ebms, ''),
        coalesce(e.id_conversation, ''),
        coalesce(e.id_message, ''),
        coalesce(e.id_echange, ''),
        coalesce(e.id_requete, ''),
        coalesce(e.id_reponse, ''),
        coalesce(e.autorite_requerante, ''),
        coalesce(e.schema_autorite_requerante, ''),
        coalesce(e.autorite_fournisseuse, ''),
        coalesce(e.schema_autorite_fournisseuse, ''),
        coalesce(e.id_requeteur, ''),
        coalesce(e.sujet_justificatif, ''),
        coalesce(e.type_justificatif, ''),
        coalesce(e.code_demarche, ''),
        coalesce(e.type_mime, ''),
        coalesce(e.empreinte_justificatif, ''),
        coalesce(e.code_erreur, '')
      )
    $$ LANGUAGE sql STABLE;

    CREATE FUNCTION empreinte_journal(precedente text, contenu text) RETURNS text AS $$
      SELECT encode(sha256(convert_to(coalesce(precedente, '') || contenu, 'UTF8')), 'hex')
    $$ LANGUAGE sql IMMUTABLE;
  `)

  // Le verrou consultatif sérialise les insertions : sans lui, deux
  // transactions concurrentes liraient la même empreinte précédente et
  // produiraient deux maillons frères, ce qui romprait la chaîne. Un
  // `LOCK TABLE` ferait le même travail mais s'interbloquerait, chaque
  // transaction détenant déjà un ROW EXCLUSIVE que l'autre attendrait.
  //
  // Le coût est négligeable ici : quelques événements par requête OOTS, et le
  // verrou ne tient que le temps de l'insertion.
  pgm.sql(`
    CREATE FUNCTION chaine_journal_echanges() RETURNS trigger AS $$
    DECLARE
      precedente text;
    BEGIN
      PERFORM pg_advisory_xact_lock(hashtext('journal_echanges'));

      SELECT empreinte INTO precedente
      FROM journal_echanges
      ORDER BY id DESC
      LIMIT 1;

      NEW.empreinte_precedente := precedente;
      NEW.empreinte := empreinte_journal(precedente, contenu_canonique_journal(NEW));

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER chaine_journal_echanges
      BEFORE INSERT ON journal_echanges
      FOR EACH ROW EXECUTE FUNCTION chaine_journal_echanges();
  `)

  pgm.sql(`
    CREATE VIEW vue_journal_conversation AS
      SELECT e.*, empreinte_journal(e.empreinte_precedente, contenu_canonique_journal(e)) AS empreinte_attendue
      FROM journal_echanges e;

    COMMENT ON VIEW vue_journal_conversation IS
      'Le journal, augmenté de l''empreinte recalculée : toute ligne dont empreinte et empreinte_attendue diffèrent a été altérée.';

    CREATE VIEW vue_journal_verifie AS
      SELECT
        e.*,
        e.empreinte = e.empreinte_attendue AS empreinte_valide,
        lag(e.empreinte) OVER (ORDER BY e.id) IS NULL
          OR e.empreinte_precedente = lag(e.empreinte) OVER (ORDER BY e.id) AS maillon_valide
      FROM vue_journal_conversation e;

    COMMENT ON VIEW vue_journal_verifie IS
      'Les deux ruptures possibles, ligne par ligne : empreinte_valide dit qu''une ligne n''a pas été réécrite, maillon_valide qu''aucune ligne n''a disparu avant elle. La fenêtre porte sur tout le journal — filtrer sur une conversation après coup, jamais avant, sans quoi le maillon serait comparé à la ligne précédente de la seule conversation.';

    CREATE VIEW vue_dernieres_conversations AS
      SELECT
        id_conversation,
        min(horodatage) AS debut,
        max(horodatage) AS fin,
        count(*) AS nombre_evenements,
        max(code_demarche)     FILTER (WHERE code_demarche IS NOT NULL)     AS code_demarche,
        max(type_justificatif) FILTER (WHERE type_justificatif IS NOT NULL) AS type_justificatif,
        max(id_requeteur)      FILTER (WHERE id_requeteur IS NOT NULL)      AS id_requeteur,
        (array_agg(type_evenement ORDER BY id DESC))[1] AS dernier_evenement,
        (array_agg(code_erreur ORDER BY id DESC) FILTER (WHERE code_erreur IS NOT NULL))[1] AS dernier_code_erreur
      FROM journal_echanges
      WHERE id_conversation IS NOT NULL
      GROUP BY id_conversation;
  `)

  // Purge réservée au propriétaire : le rôle applicatif n'a pas le droit de
  // supprimer, et c'est précisément ce qui fait tenir le journal en ajout seul.
  //
  // Supprimer les plus anciennes lignes laisse la première survivante pointer
  // vers un maillon disparu : c'est attendu, la chaîne reste vérifiable à
  // partir d'elle.
  pgm.sql(`
    CREATE FUNCTION purge_journal_echanges() RETURNS bigint AS $$
    DECLARE
      supprimees bigint;
    BEGIN
      DELETE FROM journal_echanges WHERE horodatage < now() - interval '12 months';
      GET DIAGNOSTICS supprimees = ROW_COUNT;
      RETURN supprimees;
    END;
    $$ LANGUAGE plpgsql;

    COMMENT ON FUNCTION purge_journal_echanges() IS
      'Applique la conservation de douze mois de l''article 17. Rend le nombre de lignes supprimées.';
  `)

  // Le rôle applicatif n'obtient que l'ajout et la lecture : c'est ce qui rend
  // le journal inaltérable, et non une discipline de code. `oots_application`
  // est créé par docker/postgres/init/01-role-applicatif.sh, ou à la main
  // ailleurs.
  pgm.sql(`
    REVOKE ALL ON journal_echanges FROM PUBLIC;
    GRANT SELECT, INSERT ON journal_echanges TO oots_application;
    GRANT USAGE, SELECT ON SEQUENCE journal_echanges_id_seq TO oots_application;
    GRANT SELECT ON vue_journal_conversation, vue_journal_verifie, vue_dernieres_conversations TO oots_application;
  `)
}

// L'ordre compte : `contenu_canonique_journal` prend la table pour type
// d'argument, et la base refuse de supprimer une table dont un objet dépend.
exports.down = (pgm) => {
  pgm.sql(`
    DROP FUNCTION purge_journal_echanges();
    DROP VIEW vue_dernieres_conversations;
    DROP VIEW vue_journal_verifie;
    DROP VIEW vue_journal_conversation;
    DROP FUNCTION contenu_canonique_journal(journal_echanges);
    DROP TABLE journal_echanges;
    DROP FUNCTION chaine_journal_echanges();
    DROP FUNCTION empreinte_journal(text, text);
  `)
}
