class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # A job answers correspondents, writes records and the log, all in the default
  # locale: ActiveJob would otherwise replay it under the language of the
  # browser whose request enqueued it, which it serializes with the job.
  around_perform { |_job, perform| I18n.with_locale(I18n.default_locale, &perform) }
end
