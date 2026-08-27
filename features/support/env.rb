require 'cucumber/rails'
require 'webrick'

ActionController::Base.allow_rescue = false

# France's own country code, which `Exchange` reads to say which of its two
# countries is which: a page of the operator console therefore depends on it,
# and not only the directory clients. Set here because Cucumber loads nothing
# from `spec/`, where the unit suite pins the same value.
ENV['PAYS_SERVICES_COMMUNS'] ||= 'FR'

# No transaction around a scenario, because the `bout_en_bout` ones cannot have
# one: they drive a server and a background worker that run in their own
# processes, and a transaction held here would hide from them everything it
# wrote. What the administration scenarios write is undone by DatabaseCleaner,
# which `cucumber-rails` installs by default and which nothing here disables.
Cucumber::Rails::World.use_transactional_tests = false

Before('@bout_en_bout') do
  variables = %w[URL_OOTS_FRANCE DONNEES_REQUETEURS]
  variables.each do |variable|
    next if ENV[variable].present?

    raise "#{variable} n'est pas renseignée : ces scénarios s'exécutent dans le conteneur `web`, " \
          'via `make e2e`.'
  end

  raise 'AVEC_REQUETE_PIECE_JUSTIFICATIVE ne vaut pas true : la route répondrait 501.' unless Settings.evidence_request_enabled?

  # The mirror of the check above: these two must be *empty*, since a filled one
  # replaces the DNS discovery these scenarios exist to exercise. An `.env.oots`
  # predating the removal of the directory double still names a server nothing
  # starts any more, and the scenario would fail on a connection error naming a
  # host rather than on this.
  Settings::COMMON_SERVICES_BASE_URLS.each_value do |variable|
    next if ENV[variable].blank?

    raise "#{variable} est renseignée : ces scénarios interrogent les vrais annuaires, " \
          'et une adresse explicite court-circuite la découverte DNS. Voir docs/test_e2e.md.'
  end
end

After('@bout_en_bout') do
  @fake_requester&.stop
end
