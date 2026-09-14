# Answers the central directories with what they really answered, captured on
# the acceptance environment.
#
# Only the DNS is doubled. The signature of each answer is verified for real,
# against the trust store the deployment carries, so a spec built on this
# exercises the whole HTTP boundary — version header, refusal codes, signature
# — and not a shape someone wrote down.
module DirectoryStubs
  ACCEPTANCE = 'https://query.cs.acc.oots.tech.ec.europa.eu'.freeze

  def stub_directory_resolution
    allow(CommonServicesInstance).to receive(:new) do |service|
      instance_double(CommonServicesInstance, base_url: "#{ACCEPTANCE}/#{service}/")
    end
  end

  # The two Evidence Broker queries share an address and are told apart by
  # their `queryId`. `requirement:` narrows the second one further: a procedure
  # resting on several requirements is asked about each of them separately, and
  # a double answering all of them alike cannot tell which was asked for.
  def stub_directory(service, query_fragment, fixture, requirement: nil)
    body, headers = common_services_answer(fixture)

    stub_directory_body(service, query_fragment, body, headers, requirement:)
  end

  def stub_directory_body(service, query_fragment, body,
                          headers = { 'content-type' => 'application/x-ebrs+xml' }, requirement: nil)
    asked = { 'queryId' => a_string_including(query_fragment) }
    asked['requirement-id'] = requirement if requirement

    stub_request(:get, "#{ACCEPTANCE}/#{service}/rest/search")
      .with(query: hash_including(asked))
      .to_return(body:, headers:)
  end

  # The one directory answer the home page of the demonstration reads, which
  # every spec landing there needs whatever it came to prove. `T1` and not `00`:
  # the page stands under the title France declared its own procedure with, and
  # only the `T1` capture carries one.
  def stub_demonstration_requirements
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
  end

  # A body altered to make a case the captured answers do not hold no longer
  # matches the signature that came with it, and that check is what would fail
  # first. Doubling it is the only way to serve a hand-made answer through the
  # whole client.
  def stub_directory_signature
    allow(CommonServicesSignature).to receive(:new)
      .and_return(instance_double(CommonServicesSignature, verify!: true))
  end
end
