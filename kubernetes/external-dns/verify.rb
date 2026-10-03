# Reads rendered Helm YAML on stdin. No cluster access or extra gems.
require 'yaml'
docs = YAML.load_stream(STDIN.read).compact
abort 'unexpected Service or Secret' if docs.any? { |d| %w[Service Secret].include?(d['kind']) }
deployment = docs.find { |d| d['kind'] == 'Deployment' }
abort 'missing deployment' unless deployment
containers = deployment.dig('spec', 'template', 'spec', 'containers')
dns = containers.find { |c| c['name'] == 'external-dns' }
webhook = containers.find { |c| c['name'] == 'webhook' }
args = dns.fetch('args')
abort 'wrong Gateway namespace' unless args.include?('--gateway-namespace=gateway')
abort 'dry-run unexpectedly enabled' if args.any? { |a| a == '--dry-run' || a == '--dry-run=true' }
abort 'wrong replica count' unless deployment.dig('spec', 'replicas') == 1
abort 'wrong webhook URL' unless args.include?('--webhook-provider-url=http://127.0.0.1:8888')
%w[--source=gateway-httproute --policy=upsert-only --registry=txt --txt-owner-id=home-cloud --txt-prefix=external-dns-].each do |arg|
  abort "missing safety flag #{arg}" unless args.include?(arg)
end
abort 'unexpected source' unless args.grep(/^--source=/) == ['--source=gateway-httproute']
abort 'wrong image' unless webhook['image'].end_with?(':v1.6.3')
env = webhook.fetch('env').to_h { |e| [e['name'], e] }
abort 'webhook not loopback' unless env.dig('SERVER_HOST', 'value') == '127.0.0.1'
abort 'TLS verification disabled' unless env.dig('MIKROTIK_SKIP_TLS_VERIFY', 'value') == 'false'
%w[MIKROTIK_BASEURL MIKROTIK_USERNAME MIKROTIK_PASSWORD].each do |key|
  abort "inline credential #{key}" unless env.dig(key, 'valueFrom', 'secretKeyRef', 'name') == 'mikrotik-credentials'
end
filter = Regexp.new(args.find { |a| a.start_with?('--regex-domain-filter=') }.split('=', 2).last)
deny = Regexp.new(args.find { |a| a.start_with?('--regex-domain-exclusion=') }.split('=', 2).last)
%w[test.home.antonu.org argocd.home.antonu.org ha.home.antonu.org external-dns-a-test.home.antonu.org].each do |name|
  abort "expected permitted #{name}" unless filter.match?(name) && !deny.match?(name)
end
%w[*.home.antonu.org home.antonu.org test.example.org].each do |name|
  abort "unexpected allowed #{name}" if filter.match?(name)
end
%w[pulsar mealie grafana router printer k8s].each do |name|
  abort "missing exclusion #{name}" unless deny.match?("#{name}.home.antonu.org")
end
roles = docs.select { |d| d['kind'] == 'ClusterRole' }
roles.each do |role|
  role.fetch('rules').each do |rule|
    abort 'write RBAC' unless (rule['verbs'] - %w[get list watch]).empty?
    abort 'secret RBAC' if rule['resources'].include?('secrets')
  end
end
puts "ExternalDNS: #{docs.size} objects; write-enabled/upsert-only, one replica, TXT ownership, exact-name filters and loopback webhook verified"
