require 'rails_helper'

RSpec.describe WebAddress do
  def address(declared) = described_class.new(declared)

  # The permissive reading: the console archives what a correspondent wrote,
  # and an address France refuses to follow is exactly the one a dispute will
  # be about.
  describe 'what a browser can be pointed at' do
    it 'admits https' do
      expect(address('https://apercu.example.org/dossier')).to be_openable
    end

    it 'admits http, which the console shows without going there' do
      expect(address('http://apercu.example.org/dossier')).to be_openable
    end

    # A foreign correspondent chooses this address and a browser follows it on
    # our own origin: Rails escapes the HTML but does not vet the scheme.
    it 'refuses a scheme that would execute rather than lead somewhere' do
      expect(address('javascript:alert(1)')).not_to be_openable
    end

    it 'refuses an address naming no host' do
      expect(address('https:///dossier')).not_to be_openable
    end

    it 'refuses what is no address at all, rather than raising over it' do
      expect(address('http://[oups')).not_to be_openable
    end

    it 'refuses nothing at all' do
      expect(address(nil)).not_to be_openable
    end
  end

  # Chapter 4.9 §4: « specify secure HTTP ("https://") as transport. The use of
  # "http://" URIs is not allowed. »
  describe 'what chapter 4.9 allows as a step of the journey' do
    it 'is https and nothing else' do
      expect(address('https://apercu.example.org/dossier')).to be_secure
    end

    it 'is not http, which the chapter forbids' do
      expect(address('http://apercu.example.org/dossier')).not_to be_secure
    end

    it 'is not an address that is no address' do
      expect(address('pas une adresse')).not_to be_secure
    end
  end
end
