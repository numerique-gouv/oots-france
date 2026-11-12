module DirectorySnapshotting
  # Takes a new copy of the production directories, or records why it could
  # not — the previous copy staying as it was.
  class Take < ApplicationInteractor
    def call
      DirectorySnapshot.record!(sweep.call, taken_at: clock.now)
    rescue CommonServicesError, ConfigurationError => e
      record_failure(e)
      fail_with_error(:common_services_refused, errors: [e.message])
    rescue StandardError => e
      # Recorded all the same, for the administrator reads nothing else — a
      # resolver timing out raises `Resolv::ResolvTimeout`, which no client
      # converts —, and raised again, being no refusal this flow knows. Its
      # class says more than its message, which for that one is « timeout ».
      record_failure(e, detail: "#{e.class}: #{e.message}")
      raise
    end

    private

    def record_failure(error, detail: error.message)
      Rails.logger.error(LogLine.t('interactors.directory_snapshotting.take.failed', error: detail))
      DirectorySnapshot.record_failure!(code: error.try(:code), detail:, failed_at: clock.now)
    end

    def sweep = context.sweep ||= Directories::ProductionSweep.new
  end
end
