require 'cucumber/rails'
require 'webrick'

ActionController::Base.allow_rescue = false

# Le code pays de la France, que `Conversation` lit pour dire lequel de ses deux
# pays est lequel : une page de l'espace d'administration en dépend donc, et pas
# seulement les clients d'annuaire. Posé ici et non emprunté à
# `spec/support/test_environment.rb`, qui efface les URL d'annuaires dont les
# scénarios de bout en bout ont justement besoin.
ENV['PAYS_SERVICES_COMMUNS'] ||= 'FR'

# No transaction around a scenario, because the `bout_en_bout` ones cannot have
# one: they drive a server and a background worker that run in their own
# processes, and a transaction held here would hide from them everything it
# wrote. What the administration scenarios write is undone by DatabaseCleaner,
# which `cucumber-rails` installs by default and which nothing here disables.
Cucumber::Rails::World.use_transactional_tests = false

Before('@bout_en_bout') do
  variables = %w[URL_OOTS_FRANCE DONNEES_REQUETEURS] + Settings::COMMON_SERVICES_BASE_URLS.values
  variables.each do |variable|
    next if ENV[variable].present?

    raise "#{variable} n'est pas renseignée : ces scénarios s'exécutent dans le conteneur `web`, " \
          'via `make e2e`.'
  end

  raise 'AVEC_REQUETE_PIECE_JUSTIFICATIVE ne vaut pas true : la route répondrait 501.' unless Settings.evidence_request_enabled?
end

After('@bout_en_bout') do
  @fake_requester&.stop
  @fake_common_services&.stop
end
