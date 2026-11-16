require 'rails_helper'
require 'open3'

# The script is run as it ships, in a directory of its own holding the scripts
# and templates of the repository, under an environment holding only what an
# operator would pass: the suite's own variables would otherwise read as
# secrets passed on the command line.
RSpec.describe 'scripts/setup_server.sh' do
  let(:root) { Pathname(File.expand_path('../..', __dir__)) }

  def run_with(environment)
    Dir.mktmpdir do |directory|
      FileUtils.cp_r(root.join('scripts'), directory)
      root.glob('.env*.template').each { |template| FileUtils.cp(template, directory) }
      output, status = Open3.capture2e({ 'PATH' => ENV.fetch('PATH'), 'URL_OOTS_FRANCE' => 'https://x.example' }
        .merge(environment), 'sh', 'scripts/setup_server.sh', chdir: directory, unsetenv_others: true)

      yield output, status, Pathname(directory)
    end
  end

  def template_token = root.join('.env.oots.template').read[/^JETON_API_PARTICULIER=(\S+)/, 1]

  # RG23.
  it 'keeps the public token of the staging where the deployment joins the staging' do
    run_with({}) do |output, status, directory|
      expect(status).to be_success, output
      expect(directory.join('.env.oots').read).to include("JETON_API_PARTICULIER=#{template_token}")
    end
  end

  it 'demands the token where the deployment joins another address' do
    run_with('URL_API_PARTICULIER' => 'https://particulier.api.gouv.fr') do |output, status|
      expect(status).not_to be_success
      expect(output).to include('JETON_API_PARTICULIER est délivré par un tiers')
    end
  end

  it 'takes the token passed beside another address' do
    run_with('URL_API_PARTICULIER' => 'https://particulier.api.gouv.fr', 'JETON_API_PARTICULIER' => 'jeton-datapass') do |output, status, directory|
      expect(status).to be_success, output
      expect(directory.join('.env.oots').read).to include('JETON_API_PARTICULIER=jeton-datapass')
    end
  end
end
