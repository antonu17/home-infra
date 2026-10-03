#!/usr/bin/env bash
# Local rendering only: downloads pinned chart/CRD sources, never calls a cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
for render_dir in kubernetes/cilium kubernetes/gateway kubernetes/gitops/bootstrap kubernetes/gitops/applications kubernetes/apps/home-assistant kubernetes/external-dns/policy kubernetes/external-dns/test/resources; do
  kubectl kustomize "$render_dir" | ruby -ryaml -e '
    docs = YAML.load_stream(STDIN.read).compact
    abort "empty rendering" if docs.empty?
    abort "unexpected Secret in GitOps" if docs.any? { |d| d["kind"] == "Secret" }
    puts docs.map { |d| "#{d["kind"]}/#{d.dig("metadata", "name")}" }
  '
done
kubectl kustomize kubernetes/gitops/bootstrap | ruby -ryaml -e '
  docs = YAML.load_stream(STDIN.read).compact
  projects = docs.select { |d| d["kind"] == "AppProject" }
  abort "expected three AppProjects" unless projects.size == 3
  wildcard = [{"group" => "*", "kind" => "*"}]
  projects.each do |project|
    abort "#{project.dig("metadata", "name")} does not allow all namespaced resources" unless project.dig("spec", "namespaceResourceWhitelist") == wildcard
  end
  puts "AppProjects: all namespaced resource kinds permitted within configured destinations"
'
kubectl kustomize kubernetes/apps/home-assistant | ruby -ryaml -e '
  docs = YAML.load_stream(STDIN.read).compact
  find = ->(kind, name) { docs.find { |d| d["kind"] == kind && d.dig("metadata", "name") == name } }
  ns = find.call("Namespace", "home-assistant") or abort "missing Home Assistant Namespace"
  sts = find.call("StatefulSet", "home-assistant") or abort "missing Home Assistant StatefulSet"
  pvc = find.call("PersistentVolumeClaim", "home-assistant-config") or abort "missing Home Assistant PVC"
  svc = find.call("Service", "home-assistant") or abort "missing Home Assistant Service"
  route = find.call("HTTPRoute", "home-assistant") or abort "missing Home Assistant HTTPRoute"
  redirect = find.call("HTTPRoute", "home-assistant-redirect") or abort "missing Home Assistant redirect HTTPRoute"
  matter_sts = find.call("StatefulSet", "matter-server") or abort "missing Matter Server StatefulSet"
  matter_pvc = find.call("PersistentVolumeClaim", "matter-server-data") or abort "missing Matter Server PVC"
  matter_svc = find.call("Service", "matter-server") or abort "missing Matter Server Service"
  image = sts.dig("spec", "template", "spec", "containers", 0, "image").to_s
  abort "Home Assistant image is not pinned" unless image.match?(%r{^ghcr\.io/home-assistant/home-assistant:\d{4}\.\d+\.\d+$})
  abort "Home Assistant must be a singleton" unless sts.dig("spec", "replicas") == 1
  abort "wrong StorageClass" unless pvc.dig("spec", "storageClassName") == "synology-block"
  abort "Namespace pruning is not disabled" unless ns.dig("metadata", "annotations", "argocd.argoproj.io/sync-options").to_s.split(",").include?("Prune=false")
  abort "PVC pruning is not disabled" unless pvc.dig("metadata", "annotations", "argocd.argoproj.io/sync-options").to_s.split(",").include?("Prune=false")
  abort "missing /config mount" unless sts.dig("spec", "template", "spec", "containers", 0, "volumeMounts").any? { |v| v["mountPath"] == "/config" }
  abort "Service is not ClusterIP:8123" unless svc.dig("spec", "type") == "ClusterIP" && svc.dig("spec", "ports").any? { |p| p["port"] == 8123 }
  abort "incorrect Home Assistant hostname" unless route.dig("spec", "hostnames") == ["ha.home.antonu.org"]
  parent = route.dig("spec", "parentRefs", 0)
  abort "incorrect Gateway parent" unless parent && parent.values_at("name", "namespace", "sectionName") == ["home-cloud", "gateway", "https"]
  backend = route.dig("spec", "rules", 0, "backendRefs", 0)
  abort "incorrect route backend" unless backend && backend.values_at("name", "port") == ["home-assistant", 8123]
  abort "incorrect redirect hostname" unless redirect.dig("spec", "hostnames") == ["ha.home.antonu.org"]
  redirect_parent = redirect.dig("spec", "parentRefs", 0)
  abort "incorrect redirect Gateway parent" unless redirect_parent && redirect_parent.values_at("name", "namespace", "sectionName") == ["home-cloud", "gateway", "http"]
  request_redirect = redirect.dig("spec", "rules", 0, "filters", 0, "requestRedirect")
  abort "incorrect HTTPS redirect" unless request_redirect && request_redirect.values_at("scheme", "statusCode") == ["https", 301]
  matter_image = matter_sts.dig("spec", "template", "spec", "containers", 0, "image").to_s
  abort "Matter Server image is not pinned" unless matter_image.match?(%r{^ghcr\.io/matter-js/matterjs-server:\d+\.\d+\.\d+$})
  matter_env = matter_sts.dig("spec", "template", "spec", "containers", 0, "env").to_h { |e| [e["name"], e["value"]] }
  abort "Matter restored fabric identity is not preserved" unless matter_env.values_at("VENDOR_ID", "FABRIC_ID") == ["4939", "2"]
  abort "Matter Server is not in the Home Assistant namespace" unless [matter_sts, matter_pvc, matter_svc].all? { |d| d.dig("metadata", "namespace") == "home-assistant" }
  abort "Matter host-network exception is not admitted" unless ns.dig("metadata", "labels", "pod-security.kubernetes.io/enforce") == "privileged"
  abort "Pod Security Baseline auditing is not enabled" unless ns.dig("metadata", "labels", "pod-security.kubernetes.io/audit") == "baseline"
  abort "Matter Server must be a singleton" unless matter_sts.dig("spec", "replicas") == 1
  abort "Matter Server requires host networking" unless matter_sts.dig("spec", "template", "spec", "hostNetwork") == true
  abort "Matter Server has wrong DNS policy" unless matter_sts.dig("spec", "template", "spec", "dnsPolicy") == "ClusterFirstWithHostNet"
  abort "Matter Server PVC ownership is not configured" unless matter_sts.dig("spec", "template", "spec", "securityContext").values_at("runAsUser", "runAsGroup", "fsGroup") == [1000, 1000, 1000]
  abort "wrong Matter StorageClass" unless matter_pvc.dig("spec", "storageClassName") == "synology-block"
  abort "Matter PVC pruning is not disabled" unless matter_pvc.dig("metadata", "annotations", "argocd.argoproj.io/sync-options").to_s.split(",").include?("Prune=false")
  abort "Matter PVC must not precede its WaitForFirstConsumer workload" if matter_pvc.dig("metadata", "annotations").to_h.key?("argocd.argoproj.io/sync-wave")
  abort "missing Matter /data mount" unless matter_sts.dig("spec", "template", "spec", "containers", 0, "volumeMounts").any? { |v| v["mountPath"] == "/data" }
  abort "Matter Service is not ClusterIP:5580" unless matter_svc.dig("spec", "type") == "ClusterIP" && matter_svc.dig("spec", "ports").any? { |p| p["port"] == 5580 }
  abort "obsolete Home Assistant hostname" if YAML.dump_stream(*docs).include?("hass.home.antonu.org")
  puts "Home Assistant: pinned image, retained PVC, Service and HTTPS route verified"
'
kubectl kustomize kubernetes/cilium/gateway-api | ruby -ryaml -e '
  docs = YAML.load_stream(STDIN.read).compact
  abort "expected ten CRDs" unless docs.size == 10 && docs.all? { |d| d["kind"] == "CustomResourceDefinition" }
  puts "Gateway API: ten CRDs rendered"
'
kustomize build --enable-helm kubernetes/argocd | ruby -ryaml -e '
    docs = YAML.load_stream(STDIN.read).compact
    cm = docs.find { |d| d["kind"] == "ConfigMap" && d.dig("metadata", "name") == "argocd-cm" }
    abort "missing argocd-cm" unless cm
    abort "annotation tracking is not enabled" unless cm.dig("data", "application.resourceTrackingMethod") == "annotation"
    abort "Helm-enabled Kustomize is not configured" unless cm.dig("data", "kustomize.buildOptions") == "--enable-helm"
    inclusions = YAML.safe_load(cm.dig("data", "resource.inclusions"))
    abort "resource discovery does not include Pods and ReplicaSets" unless inclusions == [{"apiGroups" => ["*"], "kinds" => ["*"], "clusters" => ["*"]}]
    params = docs.find { |d| d["kind"] == "ConfigMap" && d.dig("metadata", "name") == "argocd-cmd-params-cm" }
    abort "Argo backend HTTP is not enabled" unless params && params.dig("data", "server.insecure").to_s == "true"
    service = docs.find { |d| d["kind"] == "Service" && d.dig("metadata", "name") == "argocd-server" }
    abort "missing HTTP service" unless service && service.dig("spec", "type") == "ClusterIP" && service.dig("spec", "ports").any? { |p| p["name"] == "http" && p["port"] == 80 }
    controller_role = docs.find { |d| d["kind"] == "ClusterRole" && d.dig("metadata", "name") == "argocd-application-controller" }
    abort "controller cannot discover child resources" unless controller_role && controller_role["rules"].any? { |r| r["apiGroups"] == ["*"] && r["resources"] == ["*"] && r["verbs"] == ["*"] }
    root = docs.find { |d| d["kind"] == "Application" && d.dig("metadata", "name") == "home-cloud" }
    abort "missing built-in root Application" unless root && root.dig("spec", "project") == "default" && root.dig("spec", "source", "path") == "kubernetes/gitops/bootstrap"
    abort "unexpected Ingress" if docs.any? { |d| d["kind"] == "Ingress" }
    puts "Argo: #{docs.size} objects; self-managed root, child-resource discovery and HTTP Gateway backend verified"
  '
helm template cilium oci://quay.io/cilium/charts/cilium --version 1.20.2 \
  -n kube-system --kube-version 1.37.1 -f kubernetes/cilium/values.yaml | ruby -ryaml -e '
    docs = YAML.load_stream(STDIN.read).compact
    config = docs.find { |d| d["kind"] == "ConfigMap" && d.dig("metadata", "name") == "cilium-config" }
    abort "missing Cilium config" unless config
    %w[enable-gateway-api enable-l7-proxy kube-proxy-replacement].each do |key|
      abort "#{key} not enabled" unless config["data"][key].to_s == "true"
    end
    puts "Cilium: #{docs.size} objects; Gateway/L7/kube-proxy replacement enabled"
  '
dns_chart_version=$(ruby -ryaml -e 'puts YAML.load_file("kubernetes/gitops/applications/external-dns.yaml")["spec"]["sources"][0]["targetRevision"]')
helm template external-dns external-dns --repo https://kubernetes-sigs.github.io/external-dns/ \
  --version "$dns_chart_version" -n external-dns --kube-version 1.37.1 \
  -f kubernetes/external-dns/values.yaml | ruby kubernetes/external-dns/verify.rb
echo 'Local rendering passed. Live admission, certificate import and traffic tests are still required.'
