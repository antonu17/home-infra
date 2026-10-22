# No authentication requests or configuration/error values may reach logs.
require 'yaml'
require 'json'
require 'net/http'
require 'openssl'
require 'socket'
require 'timeout'

module StartupGate
  QUERY = '/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=SYNO.API.Auth'.freeze

  def self.clients(path)
    config = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
    clients = config.fetch('clients')
    raise ArgumentError unless clients.is_a?(Array) && !clients.empty?
    clients.each do |client|
      raise ArgumentError unless client.is_a?(Hash)
      host = client.fetch('host')
      port = client.fetch('port')
      raise ArgumentError unless host.is_a?(String) && !host.empty? && host !~ /[\s\/@?#]/
      raise ArgumentError unless port.is_a?(Integer) && (1..65_535).cover?(port)
      %w[https insecureSkipVerify].each do |key|
        raise ArgumentError if client.key?(key) && ![true, false].include?(client[key])
      end
      %w[tlsCACert tlsServerName].each do |key|
        raise ArgumentError if client.key?(key) && !client[key].is_a?(String)
      end
    end
    clients
  end

  def self.check(client)
    host, port = client.values_at('host', 'port')
    addresses = Timeout.timeout(5) { Addrinfo.getaddrinfo(host, port, nil, :STREAM) }
    return 'DNS' if addresses.empty?
    # Separate TLS identity from the destination address while retaining HTTP Host.
    identity = client['tlsServerName'].to_s.empty? ? host : client['tlsServerName']
    http = Net::HTTP.new(identity, port, nil) # Never use inherited proxy variables.
    http.ipaddr = addresses.first.ip_address
    http.open_timeout = 5
    http.read_timeout = 5
    http.write_timeout = 5
    http.max_retries = 0
    if client['https']
      http.use_ssl = true
      http.verify_mode = client['insecureSkipVerify'] ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      pem = client['tlsCACert'].to_s
      pem.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).each do |cert|
        store.add_cert(OpenSSL::X509::Certificate.new(cert))
      end
      raise ArgumentError if !pem.empty? && !pem.include?('-----BEGIN CERTIFICATE-----')
      http.cert_store = store
    end
    request = Net::HTTP::Get.new(QUERY)
    authority = host.include?(':') ? "[#{host}]" : host
    request['Host'] = "#{authority}:#{port}"
    # Bound each attempt, including DNS, TLS and slow/trickling responses.
    response = Timeout.timeout(15) { http.request(request) }
    return 'HTTP' unless response.code == '200'
    body = JSON.parse(response.body)
    return 'API' unless body.is_a?(Hash) && body['success'] == true &&
                        body.dig('data', 'SYNO.API.Auth', 'path').is_a?(String) &&
                        !body.dig('data', 'SYNO.API.Auth', 'path').empty?
    nil
  rescue SocketError
    'DNS'
  rescue OpenSSL::SSL::SSLError, OpenSSL::X509::StoreError, OpenSSL::X509::CertificateError
    'TLS'
  rescue JSON::ParserError, TypeError, NoMethodError
    'API'
  rescue StandardError
    'connection/configuration'
  end

  def self.run(path)
    loop do
      begin
        configured = clients(path) # Re-read projected Secret after every failed pass.
        failures = configured.map { |client| check(client) }.compact
        if failures.empty?
          puts 'DSM startup gate ready; starting CSI containers'
          return
        end
        puts "DSM startup gate waiting: #{failures.uniq.join(', ')}"
      rescue StandardError
        puts 'DSM startup gate waiting: invalid/unavailable configuration'
      end
      sleep 5
    end
  end
end

if $PROGRAM_NAME == __FILE__
  $stdout.sync = true
  StartupGate.run('/etc/synology/client-info.yml')
end
