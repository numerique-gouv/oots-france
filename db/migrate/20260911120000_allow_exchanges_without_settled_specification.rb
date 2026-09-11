class AllowExchangesWithoutSettledSpecification < ActiveRecord::Migration[8.1]
  # A column that does not know must be able to say so. An exchange
  # `EvidenceRequest::ChooseSpecification` gave up on — the access point
  # announced no version France speaks — was conducted in no version at all,
  # and so was one whose choice has not happened yet; the default made both
  # read as exchanges conducted in 2.0.
  #
  # One migration and no backfill: nothing is in service, and the seeds are
  # rebuilt rather than migrated.
  def change
    change_column_null :exchanges, :specification, true
    change_column_default :exchanges, :specification, from: 'oots-edm:v2.0', to: nil
  end
end
