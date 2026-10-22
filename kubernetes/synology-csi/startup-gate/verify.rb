require 'yaml'
resources = YAML.load_stream(STDIN.read).compact
raise 'unexpected Secret payload' if resources.any? { |r| r['kind'] == 'Secret' }
node = resources.find { |r| r['kind'] == 'DaemonSet' && r.dig('metadata', 'name') == 'synology-csi-node' }
spec = node.fetch('spec').fetch('template').fetch('spec')
raise 'network context changed' unless spec['hostNetwork'] && spec['dnsPolicy'] == 'ClusterFirstWithHostNet'
raise 'placement changed' unless spec['nodeSelector'] == {'storage.home.antonu.org/synology-iscsi' => 'true'}
gate = spec.fetch('initContainers').fetch(0)
raise 'gate missing' unless gate['name'] == 'wait-for-dsm'
raise 'wrong credential mount' unless gate['volumeMounts'].include?({'name' => 'client-info', 'mountPath' => '/etc/synology', 'readOnly' => true})
volume = spec['volumes'].find { |v| v['name'] == 'startup-gate' }
config = resources.find { |r| r['kind'] == 'ConfigMap' && r.dig('metadata', 'name') == volume.dig('configMap', 'name') }
raise 'script missing' unless config.dig('data', 'wait.rb') == File.read(File.join(__dir__, 'wait.rb'))
raise 'retention missing' unless config.dig('metadata', 'annotations', 'argocd.argoproj.io/sync-options').include?('Prune=false')
controller = resources.find { |r| r['kind'] == 'StatefulSet' }
raise 'controller gate unexpected' if controller.dig('spec', 'template', 'spec', 'initContainers')
raise 'plugin version changed' unless spec['containers'].find { |c| c['name'] == 'csi-plugin' }['image'] == 'synology/synology-csi:v1.3.1'
puts 'CSI startup gate render checks passed'
