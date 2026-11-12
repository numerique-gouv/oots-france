module AvailableEvidenceHelper
  # The subtype of an `OOTSMediaTypes` code, as a reader names a format —
  # `application/pdf` reads PDF, `image/svg+xml` SVG. The code itself travels
  # in the title of the abbreviation.
  def format_label(media_type) = media_type.to_s.split('/').last.to_s.delete_suffix('+xml').upcase
end
