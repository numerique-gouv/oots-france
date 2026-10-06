# Reads the verdict of every connectivity test the gateway has accepted, then
# closes as « no verdict » those still pending past
# `ConnectivityTest::VERDICT_DEADLINE`, submitted or not. Reading first, so that
# a verdict that arrived late is still the one shown.
#
# Row by row, and no row carries the others away — for the reason
# `ExpireExchangesJob` gives.
class ReadConnectivityVerdictsJob < ApplicationJob
  queue_as :default

  def perform
    ConnectivityTest.awaiting_verdict.find_each do |test|
      guarded(test) { ConnectivityTesting::ReadVerdict.call(test:) }
    end

    ConnectivityTest.overdue.find_each do |test|
      guarded(test) { expire(test) }
    end
  end

  private

  def expire(test)
    Rails.logger.warn(I18n.t('jobs.read_connectivity_verdicts_job.overdue',
      party: test.party_name, id: test.message_id || '—'))
    test.no_verdict!
  end

  def guarded(test)
    yield
  rescue StandardError => e
    Rails.logger.error(I18n.t('jobs.read_connectivity_verdicts_job.failed',
      party: test.party_name, error: "#{e.class}: #{e.message}"))
  end
end
