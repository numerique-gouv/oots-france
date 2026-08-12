# Which instance of a Common Service to query.
#
# Chapter 3.4 lets every member state answer with the Commission's instance or
# with its own, and publishes the answer as a NAPTR record. Building the URL
# from the template instead would be wrong: production resolves to
# `https://query.cs.oots.tech.ec.europa.eu/`, which carries no `prod` segment.
class CommonServicesInstance
  EVIDENCE_BROKER = 'eb'.freeze
  DATA_SERVICE_DIRECTORY = 'dsd'.freeze

  # Chapter 3.4 fixes the major version of the interface at `v1`. The record
  # for `v2` is published beside it and resolves to the same instance.
  MAJOR_VERSION = 'v1'.freeze

  # RFC 4848 substitution expression. The flag is `U`, so the replacement is
  # the URI itself rather than a name to resolve further.
  SUBSTITUTION = /\A!\.\*!(?<uri>.+)!\z/
  TERMINAL_FLAG = 'U'.freeze

  def initialize(service)
    @service = service
  end

  def base_url
    Rails.cache.fetch("common_services/instance/#{name}", expires_in: Settings.common_services_cache_duration) do
      resolve
    end
  end

  def name
    format(
      '%<country>s.%<service>s.%<version>s.cs.%<environment>s.oots.tech.ec.europa.eu',
      country: Settings.common_services_country_code.downcase,
      service: @service,
      version: MAJOR_VERSION,
      environment: Settings.common_services_environment,
    )
  end

  private

  def resolve
    record = preferred(records)
    raise CommonServicesError, "Aucun enregistrement NAPTR pour « #{name} »." if record.nil?

    uri = record.regexp[SUBSTITUTION, :uri]
    raise CommonServicesError, "Enregistrement NAPTR illisible pour « #{name} » : #{record.regexp}." if uri.nil?

    uri
  end

  # `Resolv` swallows a timeout of its own accord — `ResolvTimeout` descends
  # from `Timeout::Error`, not from `ResolvError`, and `raise_timeout_errors`
  # is off by default — so a filtered resolver returns an empty list rather
  # than raising, and is reported below as a record that does not exist.
  def records
    Resolv::DNS.open { |dns| dns.getresources(name, Resolv::DNS::Resource::IN::NAPTR) }
  rescue Resolv::ResolvError => e
    raise CommonServicesError, "Résolution DNS impossible pour « #{name} » : #{e.message}."
  end

  # RFC 3403 orders by `order` first, then by `preference` within it.
  def preferred(found)
    found.select { |record| record.flags == TERMINAL_FLAG }
      .min_by { |record| [record.order, record.preference] }
  end
end
