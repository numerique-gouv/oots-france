# `web` and `worker` connect with a restricted role, refused `UPDATE` on the
# exchange log. Its two variables go together, and one alone — a typo, a secret
# lost in a rotation — leaves the process connecting as the owner of the tables,
# the engine-level guarantee gone without a word. Reading them here refuses that.
#
# Here rather than in `config.ru`, which the web server loads and it alone:
# `worker` boots through `config/environment.rb` and would never meet the check,
# though it is the process that writes most of the log and runs the purge.
#
# Absent both, this reads `nil` and says nothing — what an installation that does
# not want the dispositif does, and what `.github/workflows/tests.yml` does. It
# needs neither gateway nor key, unlike the rest of `Settings::Contract`, which
# is why that one stays behind the web server.
#
# `after_initialize` rather than the body of this file, for two reasons that both
# only show at run time: `Settings` is autoloaded, and autoloading is not yet set
# up while the config initializers run; and `I18n.default_locale` is not applied
# either, so the refusal would come out as « Translation missing: en.… » — this
# application publishes French alone.
Rails.application.config.after_initialize do
  Settings.application_database_role
end
