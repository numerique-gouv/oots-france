# Reads the reference messages of `spec/fixtures/reference/`. See
# `spec/fixtures/README.md` for what each directory is worth as evidence:
# `reference/` and `incoming/reel/` are authoritative, `incoming/` is not.
module Fixtures
  def reference_message(name) = read_fixture("reference/messages/#{name}.xml")

  def reference_header(name) = read_fixture("reference/messages/#{name}.entete.xml")

  def reference_envelope(name) = read_fixture("reference/soap/#{name}.xml")

  def real_envelope(name) = read_fixture("incoming/reel/#{name}.xml")

  def built_envelope(name) = read_fixture("incoming/#{name}.xml")

  # A directory answer captured on the acceptance environment, with the two
  # headers that carry its signature.
  def common_services_answer(name)
    body = read_fixture("common_services/#{name}.xml")
    headers = read_fixture("common_services/#{name}.headers").lines.to_h do |line|
      field, value = line.split(':', 2)
      [field.strip.downcase, value.to_s.strip]
    end

    [body, headers]
  end

  private

  def read_fixture(path) = Rails.root.join('spec/fixtures', path).read
end
