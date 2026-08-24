# Chapter 4.4: « If an Online Procedure Portals implements timeout, then it
# shall generate a timeout error in case the Data Service did not reply using
# either a successful evidence response or an exception response to an issued
# evidence request within a configured timeout interval. » Nothing arrives to
# trigger it — that is what a response which never comes means — hence the
# sweep.
#
# `expire!` row by row and not `update_all`: each transition takes the lock that
# keeps a response arriving at the same instant from being overwritten, and
# `update_all` would take none, nor run the validations.
class ExpireExchangesJob < ApplicationJob
  queue_as :default

  def perform
    Exchange.expired.find_each do |exchange|
      expire(exchange)
    end
  end

  private

  # No row may carry away the others. `find_each` walks in primary-key order, so
  # an exception raised on one would leave every later exchange waiting on a
  # sweep that never reaches it — and a row that fails every time would hold
  # them for ever, the cron replaying the same walk each minute. What the batch
  # query itself raises is another matter, and stays out: it strands nothing
  # beyond the current minute.
  def expire(exchange)
    exchange.expire!
  # `StandardError` and not the Active Record family alone: the promise above
  # holds whatever the cause, and `expire!` runs validations and callbacks —
  # `NormalisesCountryCode` upcasing a string whose encoding has been corrupted
  # raises `ArgumentError`, which no narrower net would hold.
  #
  # The cost is paid in visibility: what used to surface as a failed execution
  # in GoodJob's dashboard is now a log line, this deployment having no error
  # reporting behind it. Hence the class beside the message — a bad row and a
  # bug do not call for the same answer, and the log is where they are told
  # apart.
  rescue StandardError => e
    Rails.logger.error(
      I18n.t('jobs.expire_exchanges_job.failed',
        id: exchange.exchange_id, error: "#{e.class}: #{e.message}"),
    )
  end
end
