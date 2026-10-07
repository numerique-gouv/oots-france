# An agent the team running the deployment named, in a console on the server,
# to read the journal, act on the jobs and test the access points — the pages
# any other agent ProConnect admits does not reach. Known by the address
# ProConnect returns, and read again at every request: naming or dismissing
# takes effect at the next page, without signing in again.
class Administrator < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true

  def self.appoint(email) = find_or_create_by!(email:)

  def self.dismiss(email) = where(email:).destroy_all

  def self.appointed?(email) = email.present? && exists?(email:)
end
