require 'cucumber/rails'
require 'webrick'

ActionController::Base.allow_rescue = false

# The floor these scenarios read through `Settings`, which Cucumber finds
# nowhere else: it loads nothing from `spec/`, where
# `spec/support/test_environment.rb` gives the unit suite the same. `tests.yml`
# plays them on a bare runner, with no `.env` at all.
#
# Of the three, only the country code announces its own absence — `Exchange`
# reads it to say which of its two countries is which, and nothing catches
# that. The two the code list reads are swallowed instead: `CodeListClient`
# answers any failure with an empty list, a configuration error included, so
# the page renders under « Aucun label » and the scenario fails on what it
# displays rather than on what is missing.
#
# In a hook, and tagged, rather than at load: posted for every profile, a
# default would stand in for a `.env.oots` line that is simply absent, and
# `make e2e` would run against a test value taking it for the real one.
Before('not @bout_en_bout') do
  ENV['PAYS_SERVICES_COMMUNS'] ||= 'FR'
  ENV['DELAI_MAX_SERVICES_COMMUNS'] ||= '10000'
  ENV['DUREE_CACHE_SERVICES_COMMUNS'] ||= '3600'
end

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

# The fake FranceConnect+ is a role of the suite, not a step's doing: it is
# started once for the whole run, beside the scenarios, as the fake requester
# and the fake correspondent are mounted beside theirs.
#
# Two conditions, and neither is decoration. `URL_FAUX_FRANCE_CONNECT` absent,
# nothing starts: the default profile plays on a bare runner with no `.env` at
# all. Something already answering there, nothing starts either: the day the
# local stack runs the fake as a service of its own (OOTS-192), the scenarios
# drive that one rather than starting a second on a port already taken.
BeforeAll do
  # `webmock/cucumber` intercepts from the moment it loads, and this hook runs
  # before any scenario has settled which regime applies: probing the address
  # would raise rather than answer. Each scenario re-establishes its own regime
  # in `features/support/webmock.rb`, so taking it off here settles nothing for
  # them.
  WebMock.disable!

  issuer = ENV.fetch('URL_FAUX_FRANCE_CONNECT', nil)

  unless issuer.blank? || FakeFranceConnect::Runner.answering?(issuer)
    FakeFranceConnect.running = FakeFranceConnect::Runner.new(
      issuer: issuer, procedure_url: ENV.fetch('URL_OOTS_FRANCE'),
    ).start
  end
end

AfterAll do
  FakeFranceConnect.running&.stop
end
