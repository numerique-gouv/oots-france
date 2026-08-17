# A member of the team that runs the deployment, and the only one who may open
# the administration space. Never a user of a procedure: see
# docs/espace_administration.md for what that space is and is not.
class Administrator < ApplicationRecord
  has_secure_password

  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :email, presence: true, uniqueness: true

  # `allow_nil`, because `has_secure_password` leaves `password` nil on a record
  # read back from the database: without it, saving one to change anything else
  # would fail this length check. A new record still needs a password, which the
  # presence check on `password_digest` already demands.
  validates :password, length: { minimum: 12 }, allow_nil: true
end
