# The subject of an evidence as `sdg:IsAbout` admits it: an `xs:choice` of a
# natural or a legal person, whichever the subject's own type names.
#
# Both branches are narrower on a response than on a request, and the legal one
# far more so. R-EDM-RESP-S041 and R-EDM-RESP-S042 (both FATAL) bound their
# children exactly — neither admits `sdg:LevelOfAssurance`, and the legal
# branch admits nothing besides `sdg:LegalPersonIdentifier` and `sdg:LegalName`,
# the sectoral identifiers included. Rendering the partials the request uses
# would therefore produce a response a correspondent refuses.
class EvidenceSubjectBuilder < ApplicationBuilder
  SUBJECT_TEMPLATES = {
    NaturalPerson => '_is_about_natural_person.xml.erb',
    LegalPerson => '_is_about_legal_person.xml.erb',
  }.freeze

  attr_reader :person

  def initialize(beneficiary:)
    @person = beneficiary
  end

  protected

  # `fetch` rather than a default: a subject of an unknown type must fail the
  # construction, where a silent fallback would answer without saying whom the
  # evidence is about — and R-EDM-RESP-S062 requires the element. As in
  # `EvidenceRequestBuilder`, `ConfigurationError` and not the bare `KeyError`,
  # which no interactor rescues.
  def template_name
    SUBJECT_TEMPLATES.fetch(person.class) do
      raise ConfigurationError,
        I18n.t('builders.evidence_subject_builder.unknown_subject', type: person.class)
    end
  end
end
