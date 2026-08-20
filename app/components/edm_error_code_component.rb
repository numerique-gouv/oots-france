# The `EDM:ERR:*` code an exchange failed under, said in French beside the
# chapter that defines it.
#
# The published code list — `EDMErrorCodes-CodeList.gc` — carries one URN for
# the whole set and no anchor per code, so the link is the same for the eight.
# A code outside them, which a non-conforming correspondent can send, gets none:
# pointing at that chapter would claim it says something it does not.
class EdmErrorCodeComponent < ViewComponent::Base
  CHAPTER_URL = 'https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938'.freeze

  def initialize(code:)
    @code = code
    super()
  end

  attr_reader :code

  def wording = t("components.edm_error_code.codes.#{code}", default: nil)
end
