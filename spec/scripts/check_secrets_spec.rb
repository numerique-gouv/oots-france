require 'rails_helper'
require 'open3'

# The script is exercised as it ships, in a directory of its own holding the
# templates of the repository and the files a deployment would have written
# from them — every secret replaced, but what an example sets.
RSpec.describe 'scripts/check_secrets.sh' do
  let(:root) { Pathname(File.expand_path('../..', __dir__)) }
  let(:secrets) do
    root.join('scripts/secret_variables').readlines.filter_map { |line| line[/\A([A-Z_0-9]+)\s/, 1] } +
      %w[MOT_DE_PASSE_BASE_DE_DONNEES]
  end
  let(:public_token) { template_value('JETON_API_PARTICULIER') }

  def template_value(name)
    root.glob('.env*.template').each do |template|
      line = template.readlines.find { |read| read.start_with?("#{name}=") }
      return line.delete_prefix("#{name}=").split(' #').first.strip if line
    end
  end

  def verdict_with(overrides)
    Dir.mktmpdir do |directory|
      directory = Pathname(directory)
      directory.join('scripts').mkpath
      %w[check_secrets.sh secret_variables].each { |file| FileUtils.cp(root.join('scripts', file), directory.join('scripts')) }
      root.glob('.env*.template').each { |template| install(template, directory, overrides) }

      Open3.capture2e('sh', directory.join('scripts/check_secrets.sh').to_s)
    end
  end

  def install(template, directory, overrides)
    FileUtils.cp(template, directory)
    installed = template.readlines.filter_map { |line| installed_line(line, overrides) }
    directory.join(template.basename.to_s.delete_suffix('.template')).write(installed.join)
  end

  def installed_line(line, overrides)
    name = line[/\A([A-Z_0-9]+)=/, 1] or return
    value = overrides.fetch(name) { "deploiement-#{name.downcase}" if secrets.include?(name) }
    "#{name}=#{value || line.delete_prefix("#{name}=").split(' #').first.strip}\n"
  end

  # CA21.
  it 'admet le jeton public du staging à côté de l’adresse du staging' do
    output, status = verdict_with('JETON_API_PARTICULIER' => public_token)

    expect(status).to be_success, output
  end

  it 'refuse le jeton public à côté de toute autre adresse' do
    output, status = verdict_with('JETON_API_PARTICULIER' => public_token,
      'URL_API_PARTICULIER' => 'https://particulier.api.gouv.fr')

    expect(status).not_to be_success
    expect(output).to include('JETON_API_PARTICULIER porte encore la valeur de développement')
  end

  it 'refuse toujours une autre valeur de développement' do
    output, status = verdict_with('JETON_API_PARTICULIER' => public_token,
      'POSTGRES_PASSWORD' => template_value('POSTGRES_PASSWORD'))

    expect(status).not_to be_success
    expect(output).to include('POSTGRES_PASSWORD porte encore la valeur de développement')
  end
end
