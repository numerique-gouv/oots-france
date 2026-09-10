class AddSpecificationToExchanges < ActiveRecord::Migration[8.1]
  # The EDM version every message of the exchange is written in: chapter 4.7
  # §2.6.2 has request and response of one exchange share it, so it is settled
  # once and read back by whoever answers.
  #
  # One migration and no backfill — nothing is in service, and the default is
  # the version every exchange opened until now carried. A literal rather than
  # `EdmSpecification::V2_0`: a migration replayed against a later version of
  # the code must not depend on what that code will say then.
  def change
    add_column :exchanges, :specification, :string, null: false, default: 'oots-edm:v2.0'
  end
end
