# The test case and the run the console names the files of a Commission test
# after, as the export form submits them — see `TestFiles`.
class TestRun
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SubmittedCriteria

  attribute :test_case, :string, default: 'TC06'
  attribute :run, :string, default: '01'

  # Letters and digits for the case, two digits for the run: both enter a file
  # name, which the convention wants without spaces and whose parts `-` and `_`
  # separate. `\z` and not `$`, which would let a value ending in a newline
  # through.
  validates :test_case, format: { with: /\A[A-Za-z0-9]+\z/, message: :format }
  validates :run, format: { with: /\A\d{2}\z/, message: :format }
end
