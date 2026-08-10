#!/bin/sh
# Crée le rôle avec lequel l'application se connecte, distinct du propriétaire
# de la base.
#
# C'est ce qui donne sa réalité au journal en ajout seul : la migration retire
# `UPDATE` et `DELETE` à ce rôle sur `journal_echanges`, ce qui n'aurait aucun
# effet si l'application se connectait en propriétaire — un propriétaire peut
# toujours se redonner ce qu'on lui a retiré.
#
# L'image ne joue ce script qu'à la création du volume. Sur une base déjà
# initialisée, ou hors Docker, créer le rôle à la main :
#
#   CREATE ROLE oots_application LOGIN PASSWORD '…';
#   GRANT CONNECT ON DATABASE <base> TO oots_application;

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
CREATE ROLE oots_application LOGIN PASSWORD '$MOT_DE_PASSE_BASE_APPLICATION';
GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO oots_application;
SQL
