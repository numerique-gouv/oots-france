require 'rails_helper'

RSpec.describe PreviewLink do
  let(:back) { 'https://oots.example.fr/retour/3f2c1a4e-5b6d-4e7f-8a9b-0c1d2e3f4a5b' }
  let(:encoded) { 'returnurl=https%3A%2F%2Foots.example.fr%2Fretour%2F3f2c1a4e-5b6d-4e7f-8a9b-0c1d2e3f4a5b&returnmethod=GET' }

  def link(location, specification: EdmSpecification::V1_2, preview_method: 'GET')
    described_class.new(location:, return_location: back, specification:, preview_method:)
  end

  # On 2.0 the return address travels in `ReturnLocation`, and the link is the
  # preview address as the correspondent returned it.
  it 'is the preview address itself on 2.0' do
    presented = link('https://ap.example.si/espace?session=abc', specification: EdmSpecification::V2_0)

    expect([presented.address, presented.http_method, presented.body])
      .to eq(['https://ap.example.si/espace?session=abc', 'GET', nil])
  end

  # CA12 of OOTS-67: « the two key=value pairs are appended to the existing
  # query component ».
  it 'appends the return address to an existing query on 1.2' do
    expect(link('https://ap.example.si/espace?session=abc').address)
      .to eq("https://ap.example.si/espace?session=abc&#{encoded}")
  end

  it 'opens a query where the address has none' do
    expect(link('https://ap.example.si/espace').address).to eq("https://ap.example.si/espace?#{encoded}")
  end

  it 'follows a link with GET where the correspondent named no method' do
    expect(link('https://ap.example.si/espace', preview_method: nil).http_method).to eq('GET')
  end

  # CA13 of OOTS-67: « Include the URL encoded query component in the request
  # body ».
  it 'sends the return address in the body of a POST, leaving the address alone' do
    presented = link('https://ap.example.si/espace?session=abc', preview_method: 'POST')

    expect([presented.address, presented.http_method, presented.body])
      .to eq(['https://ap.example.si/espace?session=abc', 'POST', encoded])
  end

  it 'does the same for a PUT' do
    expect(link('https://ap.example.si/espace', preview_method: 'PUT').body).to eq(encoded)
  end
end
