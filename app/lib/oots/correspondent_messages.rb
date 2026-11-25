module Oots
  # The messages a correspondent sends France, frozen under
  # `spec/fixtures/correspondent/` rather than rendered by the builders they
  # judge: rendered by them, they would share their defects. See the README of
  # `spec/fixtures/`.
  class CorrespondentMessages
    DIRECTORY = 'spec/fixtures/correspondent'.freeze
    NAMES = %w[requete erreurPrevisualisationRequise].freeze
    FILES = %w[.xml .entete.xml].freeze

    def initialize(specification)
      @specification = specification
    end

    # Each file under `<prefix>.<name>`, beside the specimens, so that the
    # script confronts every pair from one directory.
    def copy_to(destination, prefix)
      NAMES.product(FILES).each do |name, suffix|
        destination.join("#{prefix}.#{name}#{suffix}").write(fixture(name, suffix))
      end
    end

    # As the gateway hands a message over, so that it is read by what reads it
    # in production: the header, and the body base64-encoded under the
    # reference the header declares for it.
    def received(name)
      header = fixture(name, '.entete.xml')
      reference = Nokogiri::XML(header).at_xpath('//eb:PartInfo/@href', OotsNamespaces::NAMESPACES).value

      RetrievedMessageParser.new(<<~XML)
        <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"><soap:Header>#{header}</soap:Header><soap:Body><ws:retrieveMessageResponse xmlns:ws="http://eu.domibus.wsplugin/"><payload payloadId="#{reference}" contentType="#{RetrievedMessageParser::REGREP}"><value>#{Base64.strict_encode64(fixture(name, '.xml'))}</value></payload></ws:retrieveMessageResponse></soap:Body></soap:Envelope>
      XML
    end

    private

    attr_reader :specification

    def fixture(name, suffix) = Rails.root.join(DIRECTORY, specification.segment, "#{name}#{suffix}").read
  end
end
