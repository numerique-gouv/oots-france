module AvailableEvidence
  # The button the administrator alone sees on the public page: the same
  # refresh as a night's. Anyone else is refused before anything is enqueued.
  class RefreshesController < ApplicationController
    include RecognisesAdministrator

    def create
      return head :forbidden unless named_administrator?

      # `perform_later` answers false when GoodJob's concurrency limit halts
      # the enqueue: an update is already waiting or running.
      notice = if RefreshDirectorySnapshotJob.perform_later
                 :'available_evidence.refreshes.create.launched'
               else
                 :'available_evidence.refreshes.create.already_running'
               end

      redirect_to available_evidence_index_path, notice:, status: :see_other
    end
  end
end
