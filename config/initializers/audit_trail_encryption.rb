# The exchange log of chapter 4.8 holds personal data and must survive twelve
# months; its columns are encrypted at rest.
#
# Configured from `Settings` rather than from Rails credentials: this
# application takes its whole configuration from the environment, and a
# `master.key` would be a second secret store to deploy and rotate.
#
# This runs in every process that loads the framework, including the rake tasks
# that prepare a database or render the specimen messages — neither of which
# ever reads the log. Hence keys that may be absent here, and `Settings::REQUIRED`
# as the guard: `config.ru` refuses to serve without them.
Rails.application.config.to_prepare do
  ActiveRecord::Encryption.configure(**Settings.audit_trail_encryption)
end
