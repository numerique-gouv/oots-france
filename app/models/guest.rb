# An address outside the admitted domains the team running the deployment
# invited, in a console on the server, into the administration space: it then
# reaches what any admitted agent reaches, and the journal, the jobs and the
# access points only if it is also an `Administrator`. Read again at every
# request: inviting or withdrawing takes effect at the next page.
class Guest < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true

  def self.invite(email) = find_or_create_by!(email:)

  def self.withdraw(email) = where(email:).destroy_all

  def self.invited?(email) = email.present? && exists?(email:)
end
