require 'fileutils'
require 'open3'
require 'socket'
require 'tmpdir'

# The administration console, reduced to canned answers per route: what the
# script asked is recorded, and any route it was not given answers 500.
class FakeDomibusConsole
  attr_reader :requests

  def initialize(routes)
    @routes = routes
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0)
    @thread = Thread.new { serve_until_closed }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}/domibus"
  end

  def stop
    @server.close
    @thread.join
  end

  private

  def serve_until_closed
    loop { answer(@server.accept) }
  rescue IOError
    nil
  end

  def answer(client)
    method, target = client.gets.split
    length = read_headers(client).fetch('content-length', '0').to_i
    client.read(length)
    route = "#{method} #{target.split('?').first.delete_prefix('/domibus')}"
    @requests << route
    status, body = @routes.fetch(route, [500, 'unexpected'])
    cookie = route.end_with?('/authentication') ? "Set-Cookie: XSRF-TOKEN=jeton; Path=/\r\n" : ''
    client.write("HTTP/1.1 #{status} X\r\nContent-Length: #{body.bytesize}\r\n#{cookie}Connection: close\r\n\r\n#{body}")
    client.close
  end

  def read_headers(client)
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(':', 2)
      headers[name.downcase] = value.strip
    end
    headers
  end
end

# The script is exercised as it ships, as a process, from a throwaway directory
# carrying its own .env and .env.oots. The gateway is replaced by the local
# shell (`COMMANDE_DOMIBUS=env`) and a configuration directory of the spec's, and
# the console by an address nothing listens on: any call to it would fail the
# run, so a success proves none was made. Where a decision is the subject, a
# FakeDomibusConsole answers instead, and what the script asked it is the proof.
RSpec.describe 'scripts/configure_domibus.sh' do
  CONFIGURE_DOMIBUS = File.expand_path('../../scripts/configure_domibus.sh', __dir__)
  READ_VARIABLES = %w[
    PORT_OOTS_FRANCE PORT_DOMIBUS URL_NOTIFICATION MOT_DE_PASSE_KEYSTORE_TRUSTSTORE
    LOGIN_API_REST MOT_DE_PASSE_API_REST LOGIN_NOTIFICATION_DOMIBUS MOT_DE_PASSE_NOTIFICATION_DOMIBUS
    FICHIER_PMODE REPERTOIRE_KEYSTORE_TRUSTSTORE DOMIBUS_MOT_DE_PASSE_ADMIN IDENTIFIANT_EXPEDITEUR_DOMIBUS
  ].freeze
  PLUGIN_PROPERTIES = "wsplugin.push.enabled=false\nwsplugin.mode=PUSH".freeze

  attr_reader :directory

  around do |example|
    Dir.mktmpdir('configure-domibus-spec') do |path|
      @directory = path
      example.run
    end
  end

  before do
    FileUtils.mkdir_p(File.dirname(properties_path))
    File.write(properties_path, PLUGIN_PROPERTIES)
    File.write(File.join(directory, '.env'), <<~ENV)
      PORT_DOMIBUS=8180 # port d'accès à la console Domibus
      PORT_OOTS_FRANCE=3007 # port sur lequel le serveur écoute
      MOT_DE_PASSE_KEYSTORE_TRUSTSTORE=test123
    ENV
    write_env_oots(
      'LOGIN_API_REST' => 'oots_spec',
      'MOT_DE_PASSE_API_REST' => 'Spec-OotsFrance-2026!',
      'LOGIN_NOTIFICATION_DOMIBUS' => 'domibus_push',
      'MOT_DE_PASSE_NOTIFICATION_DOMIBUS' => 'Push&{"a":1}',
      'IDENTIFIANT_EXPEDITEUR_DOMIBUS' => 'AP_FR_01'
    )
  end

  def properties_path
    File.join(directory, 'config', 'plugins', 'config', 'ws-plugin.properties')
  end

  def properties
    File.read(properties_path)
  end

  def write_env_oots(values)
    File.write(File.join(directory, '.env.oots'), values.map { |name, value| "#{name}=#{value}\n" }.join)
  end

  def run_script(*, **variables)
    environment = READ_VARIABLES.product([nil]).to_h.merge(
      'COMMANDE_DOMIBUS' => 'env',
      'CONFIG_DOMIBUS' => File.join(directory, 'config'),
      'URL_DOMIBUS' => 'http://127.0.0.1:9/domibus'
    ).merge(variables.transform_keys(&:to_s))
    Open3.capture2e(environment, CONFIGURE_DOMIBUS, *, chdir: directory)
  end

  describe 'notification' do
    it 'writes the plugin properties with the values of the .env files, without calling the console' do
      write_env_oots('LOGIN_NOTIFICATION_DOMIBUS' => 'domibus_push', 'MOT_DE_PASSE_NOTIFICATION_DOMIBUS' => 'Push&{"a":1}')

      output, status = run_script('notification')

      expect(status).to be_success, output
      expect(properties).to include(
        'wsplugin.push.rules.oots.endpoint=http://web:3007/domibus/notifications',
        'wsplugin.push.auth.username=domibus_push',
        'wsplugin.push.auth.password=Push&{"a":1}',
        'wsplugin.push.rules.oots.type=MESSAGE_STATUS_CHANGE,RECEIVE_SUCCESS'
      )
      expect(output).not_to include('Authentification')
    end

    it 'takes a variable given on the command line over the one in .env' do
      output, status = run_script('notification', PORT_OOTS_FRANCE: '3042')

      expect(status).to be_success, output
      expect(properties).to include('wsplugin.push.rules.oots.endpoint=http://web:3042/domibus/notifications')
    end

    it 'replaces its block when replayed with other values' do
      expect(run_script('notification').last).to be_success
      expect(run_script('notification', PORT_OOTS_FRANCE: '3042').last).to be_success

      expect(properties.scan('# --- OOTS-France: push to backend').size).to eq(1)
      expect(properties).to start_with(PLUGIN_PROPERTIES)
      expect(properties).to include('http://web:3042/')
      expect(properties).not_to include('http://web:3007/')
    end
  end

  it 'stops before authenticating when a variable is in neither the command nor its file' do
    write_env_oots('LOGIN_API_REST' => 'oots_spec', 'MOT_DE_PASSE_API_REST' => 'x', 'MOT_DE_PASSE_NOTIFICATION_DOMIBUS' => 'y')

    output, status = run_script

    expect(status).not_to be_success
    expect(output).to include('LOGIN_NOTIFICATION_DOMIBUS', '.env.oots')
    expect(output).not_to include('Authentification')
    expect(properties).to eq(PLUGIN_PROPERTIES)
  end

  it 'refuses a step it does not know' do
    output, status = run_script('pmode')

    expect(status).not_to be_success
    expect(output).to include('pmode')
    expect(properties).to eq(PLUGIN_PROPERTIES)
  end

  it 'stops before authenticating when a variable of .env is missing' do
    File.write(File.join(directory, '.env'), "PORT_OOTS_FRANCE=3007\n")

    output, status = run_script

    expect(status).not_to be_success
    expect(output).to include('MOT_DE_PASSE_KEYSTORE_TRUSTSTORE', '.env')
    expect(output).not_to include('Authentification')
  end

  it 'composes the console address out of PORT_DOMIBUS when URL_DOMIBUS is not given' do
    output, = run_script(URL_DOMIBUS: nil, PORT_DOMIBUS: '9')

    expect(output).to include('Authentification sur http://localhost:9/domibus')
  end

  describe 'what a configured gateway keeps', if: system('command -v python3 > /dev/null') do
    EXAMPLE_PMODE = File.read(File.expand_path('../../exemples/configuration_PMode_Domibus.xml', __dir__))
    IMAGE_PMODE = <<~XML.freeze
      <db:configuration xmlns:db="http://domibus.eu/configuration" party="blue_gw">
        <businessProcesses><parties><party name="blue_gw"><identifier partyId="domibus-blue"/></party></parties></businessProcesses>
      </db:configuration>
    XML
    UPLOADS = ['POST /rest/internal/admin/pmode', 'POST /rest/internal/admin/keystore/save',
               'POST /rest/internal/admin/truststore/save'].freeze

    def run_against(routes, variables = {})
      console = FakeDomibusConsole.new(
        { 'POST /rest/public/security/authentication' => [200, ''] }.merge(routes)
      )
      output, = run_script(URL_DOMIBUS: console.url, **variables)
      [output, console.requests]
    ensure
      console&.stop
    end

    let(:current_pmode) { [200, ")]}',\n{\"id\":\"7\",\"current\":true}"] }
    let(:keystore_with_key) { [200, ")]}',\n{\"trustStoreList\":[{\"name\":\"ap_fr_01\"}]}"] }

    it 'keeps a PMode declaring AP_FR_01 and a keystore holding its key' do
      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE],
        'GET /rest/internal/admin/keystore/list' => keystore_with_key
      )

      expect(output).to include('  conservé ;', 'clé AP_FR_01 présente : keystore et truststore conservés')
      expect(requests).not_to include(*UPLOADS)
    end

    it "loads the example over the image's own PMode, which does not declare AP_FR_01" do
      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, IMAGE_PMODE],
        'GET /rest/internal/admin/keystore/list' => keystore_with_key
      )

      expect(output).to include('ne déclare pas AP_FR_01')
      expect(requests).to include('POST /rest/internal/admin/pmode')
    end

    it 'replaces nothing when the current PMode cannot be read' do
      output, requests = run_against('GET /rest/internal/admin/pmode/current' => [200, '<html>proxy</html>'])

      expect(output).to include('PMode de la passerelle illisible')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'replaces nothing when the keystore cannot be listed while its file exists' do
      keystore = File.join(directory, 'config', 'keystores', 'gateway_keystore.p12')
      FileUtils.mkdir_p(File.dirname(keystore))
      File.write(keystore, 'PKI')

      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE]
      )

      expect(output).to include('Keystore de la passerelle illisible (500)')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'replaces nothing when a listed keystore cannot be parsed' do
      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE],
        'GET /rest/internal/admin/keystore/list' => [200, '<html>proxy</html>']
      )

      expect(output).to include('Keystore de la passerelle illisible (200)')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'judges the PMode by the access point of .env.oots, not by a name of its own' do
      output, requests = run_against(
        { 'GET /rest/internal/admin/pmode/current' => current_pmode,
          'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE] },
        IDENTIFIANT_EXPEDITEUR_DOMIBUS: 'AP_XX_09'
      )

      expect(output).to include('ne déclare pas AP_XX_09', 'Aucune partie nommée AP_XX_09')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'judges the keystore by the access point of .env.oots, not by a name of its own' do
      output, requests = run_against(
        { 'GET /rest/internal/admin/pmode/current' => current_pmode,
          'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE.gsub('AP_FR_01', 'AP_XX_09')],
          'GET /rest/internal/admin/keystore/list' => keystore_with_key },
        IDENTIFIANT_EXPEDITEUR_DOMIBUS: 'AP_XX_09'
      )

      expect(output).to include('  conservé ;', 'aucune clé AP_XX_09 : génération')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'uploads no generated store that lacks the key of our access point',
      if: system('command -v keytool > /dev/null && command -v openssl > /dev/null') do
      output, requests = run_against(
        { 'GET /rest/internal/admin/pmode/current' => current_pmode,
          'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE.gsub('AP_FR_01', 'AP_XX_09')],
          'GET /rest/internal/admin/keystore/list' => keystore_with_key },
        IDENTIFIANT_EXPEDITEUR_DOMIBUS: 'AP_XX_09'
      )

      expect(output).to include("n'a pas engendré de clé AP_XX_09 : rien n'est téléversé")
      expect(requests).not_to include(*UPLOADS)
    end

    it 'loads the example on a gateway that has no PMode, without asking for one' do
      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => [200, ")]}',\n"],
        'GET /rest/internal/admin/keystore/list' => keystore_with_key
      )

      expect(output).to include("aucun : le PMode d'exemple sera chargé")
      expect(requests).to include('POST /rest/internal/admin/pmode')
      expect(requests).not_to include('GET /rest/internal/admin/pmode/7')
    end

    it 'generates stores for a keystore that does not hold the AP_FR_01 key' do
      output, = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE],
        'GET /rest/internal/admin/keystore/list' => [200, ")]}',\n{\"trustStoreList\":[{\"name\":\"blue_gw\"}]}"]
      )

      expect(output).to include('aucune clé AP_FR_01 : génération')
    end

    it 'replaces nothing when a listing carries no keystore entries at all' do
      output, requests = run_against(
        'GET /rest/internal/admin/pmode/current' => current_pmode,
        'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE],
        'GET /rest/internal/admin/keystore/list' => [200, ")]}',\n{}"]
      )

      expect(output).to include('Keystore de la passerelle illisible (200)')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'replaces nothing when the gateway cannot be asked whether its keystore file exists' do
      output, requests = run_against(
        { 'GET /rest/internal/admin/pmode/current' => current_pmode,
          'GET /rest/internal/admin/pmode/7' => [200, EXAMPLE_PMODE] },
        COMMANDE_DOMIBUS: 'false'
      )

      expect(output).to include('Keystore de la passerelle illisible (500)')
      expect(requests).not_to include(*UPLOADS)
    end

    it 'loads what it is given without looking at what the gateway holds' do
      stores = File.join(directory, 'stores')
      FileUtils.mkdir_p(stores)
      %w[keystore truststore].each { |store| File.write(File.join(stores, "gateway_#{store}.p12"), store) }

      _, requests = run_against(
        { 'POST /rest/internal/admin/truststore/save' => [200, ''],
          'POST /rest/internal/admin/keystore/save' => [200, ''],
          'GET /rest/internal/admin/keystore/list' => keystore_with_key },
        FICHIER_PMODE: File.expand_path('../../exemples/configuration_PMode_Domibus.xml', __dir__),
        REPERTOIRE_KEYSTORE_TRUSTSTORE: stores
      )

      expect(requests).to include(*UPLOADS)
      expect(requests).not_to include('GET /rest/internal/admin/pmode/current')
    end
  end
end
