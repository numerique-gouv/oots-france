require 'cucumber/rails'
require 'webrick'

# These scenarios cross a real gateway: nothing here is simulated. They are
# excluded from the default Cucumber profile and only run under `bout_en_bout`,
# which `make e2e` invokes inside the container.
ActionController::Base.allow_rescue = false

# No transaction around a scenario: nothing it observes is written by it. The
# server and the background worker have their own processes and their own
# database — so these scenarios never query the database, only what the
# application renders.
Cucumber::Rails::World.use_transactional_tests = false

Before('@bout_en_bout') do
  %w[URL_OOTS_FRANCE DONNEES_REQUETEURS].each do |variable|
    next if ENV[variable].present?

    raise "#{variable} n'est pas renseignée : ces scénarios s'exécutent dans le conteneur `web`, " \
          'via `make e2e`.'
  end

  raise 'AVEC_REQUETE_PIECE_JUSTIFICATIVE ne vaut pas true : la route répondrait 501.' unless Settings.evidence_request_enabled?
end

After('@bout_en_bout') { @fake_requester&.stop }
