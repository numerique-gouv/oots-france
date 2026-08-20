require 'cucumber/rails'
require 'webrick'

ActionController::Base.allow_rescue = false

# France's own country code, which `Conversation` reads to say which of its two
# countries is which: a page of the operator console therefore depends on it,
# and not only the directory clients. Set here rather than borrowed from
# `spec/support/test_environment.rb`, which erases the directory URLs the
# end-to-end scenarios precisely need.
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
