# Offline only: synthetic configuration and loopback HTTP/TLS servers.
require 'minitest/autorun'
require 'tempfile'
require_relative 'wait'

class StartupGateTest < Minitest::Test
  def endpoint(body, status: 200, tls: false)
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    if tls
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      factory = OpenSSL::X509::ExtensionFactory.new
      factory.subject_certificate = factory.issuer_certificate = cert
      cert.add_extension(factory.create_extension('basicConstraints', 'CA:TRUE', true))
      cert.add_extension(factory.create_extension('subjectAltName', 'DNS:localhost'))
      cert.sign(key, OpenSSL::Digest::SHA256.new)
      context = OpenSSL::SSL::SSLContext.new
      context.cert, context.key = cert, key
      listener = OpenSSL::SSL::SSLServer.new(server, context)
    else
      listener = server
    end
    captured = Queue.new
    thread = Thread.new do
      begin
        socket = listener.accept
        request = ''
        request << socket.gets until request.end_with?("\r\n\r\n")
        captured << request
        socket.write("HTTP/1.1 #{status} Test\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        socket.close
      rescue OpenSSL::SSL::SSLError, IOError, Errno::EPIPE
        # Expected for rejected TLS certificates.
      end
    end
    client = {'host' => '127.0.0.1', 'port' => port, 'https' => tls}
    yield client, captured, cert
  ensure
    server.close if server
    thread.kill if thread
    thread.join if thread
  end

  def success
    JSON.generate('success' => true, 'data' => {'SYNO.API.Auth' => {'path' => 'auth.cgi'}})
  end

  def test_http_api_and_no_credentials_or_proxy
    endpoint(success) do |client, captured, _|
      client.merge!('username' => 'SYNTHETIC_USER', 'password' => 'SYNTHETIC_PASSWORD')
      assert_nil StartupGate.check(client)
      request = captured.pop
      assert_includes request, StartupGate::QUERY
      assert_includes request, "Host: 127.0.0.1:#{client['port']}"
      refute_match(/SYNTHETIC|Authorization|Cookie/, request)
    end
  end

  def test_http_and_api_failures
    [[success, 403, 'HTTP'], ['<html>login</html>', 200, 'API'],
     ['{"success":false}', 200, 'API'], ['{"success":true,"data":{}}', 200, 'API']].each do |body, status, expected|
      endpoint(body, status: status) { |client, _, _| assert_equal expected, StartupGate.check(client) }
    end
  end

  def test_tls_verification_and_configured_ca_and_identity
    endpoint(success, tls: true) { |client, _, _| assert_equal 'TLS', StartupGate.check(client) }
    endpoint(success, tls: true) do |client, _, cert|
      client.merge!('tlsCACert' => cert.to_pem, 'tlsServerName' => 'localhost')
      assert_nil StartupGate.check(client)
    end
    endpoint(success, tls: true) do |client, _, _|
      client['insecureSkipVerify'] = true
      assert_nil StartupGate.check(client)
    end
  end

  def test_dns_failure_timeout_and_unreachable_api
    client = {'host' => 'synthetic.invalid', 'port' => 443}
    Addrinfo.stub(:getaddrinfo, ->(*) { raise SocketError }) do
      assert_equal 'DNS', StartupGate.check(client)
    end
    Addrinfo.stub(:getaddrinfo, ->(*) { raise Timeout::Error }) do
      assert_equal 'connection/configuration', StartupGate.check(client)
    end
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    assert_equal 'connection/configuration', StartupGate.check({'host' => '127.0.0.1', 'port' => port})
  end

  def test_configuration_errors_do_not_leak_values
    reads = 0
    out, = capture_io do
      StartupGate.stub(:clients, ->(_) { reads += 1; raise 'SYNTHETIC_SECRET' if reads == 1; [{}] }) do
        StartupGate.stub(:check, ->(_) { nil }) do
          StartupGate.stub(:sleep, ->(_) {}) { StartupGate.run('unused') }
        end
      end
    end
    assert_equal 2, reads
    assert_includes out, 'invalid/unavailable configuration'
    refute_includes out, 'SYNTHETIC_SECRET'
  end

  def test_configuration_and_multiple_clients
    Tempfile.create('synthetic-csi') do |file|
      file.write({'clients' => [{'host' => 'localhost', 'port' => 443, 'https' => true},
                               {'host' => '127.0.0.1', 'port' => 5000, 'https' => false}]}.to_yaml)
      file.flush
      assert_equal 2, StartupGate.clients(file.path).size
      file.rewind
      file.truncate(0)
      file.write("clients: []\n")
      file.flush
      assert_raises(ArgumentError) { StartupGate.clients(file.path) }
    end
  end

  def test_retry_gate_requires_every_client_and_rereads_configuration
    attempts = 0
    configurations = 0
    client = {'host' => 'synthetic.invalid', 'port' => 443}
    out, = capture_io do
      StartupGate.stub(:clients, ->(_) { configurations += 1; [client, client] }) do
        StartupGate.stub(:check, ->(_) { attempts += 1; attempts == 2 ? 'DNS' : nil }) do
          StartupGate.stub(:sleep, ->(_) {}) { StartupGate.run('unused') }
        end
      end
    end
    assert_equal 2, configurations
    assert_equal 4, attempts
    assert_includes out, 'waiting: DNS'
    assert_includes out, 'ready'
    refute_includes out, 'synthetic.invalid'
  end
end

