# The version of the Common Services interface the client asks for.
#
# Sent as the `Accept-Version` header of every query and echoed by the service
# in the `SpecificationIdentifier` slot of its answer. Distinct from
# `EdmSpecification`, which versions the messages exchanged with a
# correspondent: the two move independently. See chapter 3.6.2.
module CommonServicesSpecification
  IDENTIFIER = 'oots-cs:v2.0'.freeze

  MEDIA_TYPE = 'application/x-ebrs+xml'.freeze
end
