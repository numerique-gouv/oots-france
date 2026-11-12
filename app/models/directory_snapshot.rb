# What the Evidence Broker and the Data Service Directory of production
# published, as the public page of available evidence reads it — never the
# directories themselves, chapter 3.7 §4 asking clients to « limit unnecessary
# access ».
#
# One row per attempt: a successful one carries `taken_at` and its answers, a
# failed one `failed_at` and what made it fail. Only the last success and the
# failure following it are kept, which is all the page says.
class DirectorySnapshot < ApplicationRecord
  has_many :answers, class_name: 'DirectorySnapshot::Answer', dependent: :delete_all

  scope :taken, -> { where.not(taken_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }

  def self.current = taken.order(taken_at: :desc).first

  # A success erases every failure before it, so whatever failure remains came
  # after the copy on display.
  def self.last_failure = failed.order(failed_at: :desc).first

  # In one transaction, so that a reader sees the previous copy or this one,
  # never half of each.
  def self.record!(bodies, taken_at:)
    transaction do
      snapshot = create!(taken_at:)
      rows = bodies.map { |key, body| { directory_snapshot_id: snapshot.id, key:, body: } }
      Answer.insert_all!(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
      where.not(id: snapshot.id).delete_all

      snapshot
    end
  end

  # The copy stays as it was: chapter 3.4 §4 has a cache serve stale content
  # when the origin fails, and a partial copy would show a country as
  # publishing nothing for a reason that is not one.
  def self.record_failure!(code:, detail:, failed_at:)
    transaction do
      failed.delete_all
      create!(failed_at:, failure_code: code, failure_detail: detail)
    end
  end

  def answer(key) = answers.find_by!(key:).body
end
