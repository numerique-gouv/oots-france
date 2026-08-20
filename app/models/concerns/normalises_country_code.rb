# The country of the two records the console lists by it. Eight places write
# one — six writers of the journal, two openers of an exchange — and the value
# comes from an ebMS agent's address, a French provider's query string, or an
# operator's form, none of which agree on a case.
#
# So it is settled here rather than at each of them: both filters upcase what
# they are asked, and a `fr` written as such would answer no search by country —
# on the journal article 17 requires to be readable back. Upcasing loses
# nothing, where refusing would lose the line itself.
module NormalisesCountryCode
  extend ActiveSupport::Concern

  included do
    before_validation { self.country_code = country_code.presence&.upcase }
  end
end
