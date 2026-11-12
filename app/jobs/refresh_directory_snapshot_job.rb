# Takes the copy of the production directories the public page of available
# evidence reads, every night and whenever the administrator asks.
#
# One at a time: a second enqueued while one is waiting or running is not
# enqueued at all, so a click during a sweep starts nothing.
class RefreshDirectorySnapshotJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(total_limit: 1, key: 'refresh_directory_snapshot')

  def perform = DirectorySnapshotting::Take.call
end
