# The namespaces of the messages, bound once, by URI.
#
# Never by prefix. A single envelope captured from Domibus binds `ns5:` to the
# ebMS namespace in its header and to the SOAP one in its body, and binds the
# plugin namespace to both `ns2:` and `ns4:`. A prefix therefore identifies
# nothing on its own, and stripping prefixes before reading only hides that —
# it leaves any comparison against a prefixed attribute *value*, such as
# `rs:AuthorizationExceptionType`, working by accident.
module OotsNamespaces
  NAMESPACES = {
    'soap' => 'http://www.w3.org/2003/05/soap-envelope',
    'eb' => 'http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/',
    'ws' => 'http://eu.domibus.wsplugin/',
    'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
    'query' => 'urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0',
    'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0',
    'sdg' => 'http://data.europa.eu/p4s',
    'xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
    'xlink' => 'http://www.w3.org/1999/xlink',
  }.freeze

  private

  def at(scope, path) = scope.at_xpath(path, NAMESPACES)

  def all(scope, path) = scope.xpath(path, NAMESPACES)

  def text_at(scope, path) = at(scope, path)&.text

  # An attribute carrying a namespace is not reachable through `node['name']`,
  # which only looks at attributes without one.
  def attribute(node, name, namespace = nil)
    return node&.[](name) if namespace.nil?

    node&.attribute_with_ns(name, NAMESPACES.fetch(namespace))&.value
  end
end
