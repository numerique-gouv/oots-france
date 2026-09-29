# What chapter 4.9 asks of a received request: the flag that says whether the
# evidence must be previewed, and the two addresses a second request carries.
#
# Refusals go through `refuse`, which the parser including this defines.
module PreviewConformance
  # `rim.xsd` types the value of a `rim:BooleanValueType` as `xsd:boolean`,
  # whose lexical space is these four literals once whitespace is collapsed.
  # No Schematron rule judges the value — `R-EDM-REQ-S024` judges the type
  # alone — so the refusal names the schema.
  BOOLEAN_LITERALS = { 'true' => true, '1' => true, 'false' => false, '0' => false }.freeze
  BOOLEAN_SCHEMA = 'rim.xsd: rim:Value of xsd:boolean'.freeze

  # Chapter 4.9 §2, step 6: a request arriving with `PossibilityForPreview` true
  # is not served without the preview space.
  def possibility_for_preview?
    value = slot_text('PossibilityForPreview', request).strip

    BOOLEAN_LITERALS.fetch(value) do
      refuse(BOOLEAN_SCHEMA, 'parsers.evidence_request.possibility_for_preview_not_boolean', value:)
    end
  end

  # The address France issued on the first round trip, which marks a request
  # as the second one (chapter 4.9 §2, step 12).
  def preview_location = optional_slot_text('PreviewLocation', request)&.strip

  # Carried by the second request on the 2.0 line only: 1.2 hands it to the
  # preview space through the user's visit.
  def return_location = optional_slot_text('ReturnLocation', request)&.strip

  private

  def require_conformant_preview
    possibility_for_preview?
    require_paired_locations if specification.return_location_slot?
  end

  # `R-EDM-REQ-S062`, `C005` and `C120`, all three of 2.0.1. `http://` passes
  # where this deployment itself runs without TLS: the address France issued is
  # then in `http://`, and a correspondent echoing it back breaks no rule of
  # ours.
  def require_paired_locations
    found = %w[PreviewLocation ReturnLocation].map { |name| find_slot(name, request) }
    refuse('R-EDM-REQ-S062', 'parsers.evidence_request.preview_locations_unpaired') unless found.all? || found.none?

    require_secure(preview_location, 'R-EDM-REQ-C005', 'PreviewLocation')
    require_secure(return_location, 'R-EDM-REQ-C120', 'ReturnLocation')
  end

  def require_secure(location, rule, name)
    return if location.nil? || WebAddress.new(location).admitted?

    refuse(rule, 'parsers.evidence_request.location_not_secure', name:, location:)
  end
end
