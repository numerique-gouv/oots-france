# The web server reads the contract in `config.ru`, which the worker never
# loads: `good_job start` boots the application through `config/environment.rb`
# instead. Read nowhere else, the contract leaves the process that takes
# messages off the gateway free to start on a variable it will only miss once a
# message is in hand — and the PMode erases a message the instant it is
# retrieved (`retention_downloaded="0"`), so refusing to start is the only
# remedy there is.
#
# Guarded and not blanket, for the reason `config.ru` gives: several processes
# legitimately need none of these variables. `exe/good_job` sets `within_exe`
# before `GoodJob::CLI.start`, which is what loads the environment, so the flag
# is already true when this runs and stays nil everywhere else.
#
# In `after_initialize` rather than in the body of the file: `I18n.load_path` is
# only populated then, and a refusal raised earlier would read « translation
# missing » instead of naming the variables that are absent. The hook still runs
# before the capsule starts, hence before any job is taken.
Rails.application.config.after_initialize do
  Settings.verify! if GoodJob::CLI.within_exe?
end
