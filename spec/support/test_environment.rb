# The message builders read the gateway identity from the environment, as the
# application does at runtime. The suite gives them fixed values so no spec has
# to arrange them, and so that a developer running `bundle exec rspec` on a
# machine with no `.env` still gets a green suite.
#
# `||=` rather than plain assignment: a value already set — by the CI, or by a
# developer pointing the suite at a real configuration — wins.
# Assigned at load time rather than from a `before(:suite)` hook: a spec that
# manipulates the environment restores it in an `ensure`, and a hook leaves a
# window where the order of two files decides whether the value is there.
ENV['SUFFIXE_IDENTIFIANTS_DOMIBUS'] ||= 'oots.eu'
ENV['IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'AP_FR_01'
ENV['TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'
ENV['IDENTIFIANT_FOURNISSEUR_FRANCAIS'] ||= '00000000000001'
ENV['NOM_FOURNISSEUR_FRANCAIS'] ||= 'Direction interministérielle du numérique'
ENV['URL_OOTS_FRANCE'] ||= 'http://localhost:3000'
ENV['ENVIRONNEMENT_SERVICES_COMMUNS'] ||= 'acc'
ENV['PAYS_SERVICES_COMMUNS'] ||= 'FR'
ENV['DUREE_CACHE_SERVICES_COMMUNS'] ||= '3600'
ENV['DELAI_MAX_SERVICES_COMMUNS'] ||= '10000'
ENV['CERTIFICATS_SERVICES_COMMUNS'] ||= Rails.root.join('config/certificats/services_communs_acc.pem').to_s
