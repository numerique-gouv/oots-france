# `DSD:ERR:0005`: the Data Service Directory holds several providers for this
# evidence type in this country, and cannot choose between them without the
# user answering first (chapter 3.1.4).
#
# Not a refusal, and the message says so itself — `R-DSD-ERR-C025` gives this
# code a severity of its own, `AdditionalInput`, which `R-DSD-ERR-C019` denies
# every other. `classifications` carries the questions to put to the user; the
# answers go back to the directory in a reissued query (OOTS-52).
#
# The code is fixed rather than taken from the caller: this class stands for
# that one code, and `Directories::CommonServices` reads `code` to decide
# whether an error of this family is really an unknown country or procedure.
# One built with a code from those lists would be requalified, silently taking
# its questions with it.
class UserAttributesRequired < CommonServicesError
  CODE = 'DSD:ERR:0005'.freeze

  attr_reader :classifications

  def initialize(message, classifications: [])
    super(message, code: CODE)
    @classifications = classifications
  end
end
