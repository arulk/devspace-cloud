package ingresshosts

ingressHostAnnotation = "devspace.cloud/allowed-hosts"
ingressAllowedHostPrefixesAnnotation = "devspace.cloud/ingress-allowed-host-prefixes"

operations = {"CREATE", "UPDATE"}

missing(obj, field) = true {
  not obj[field]
}

missing(obj, field) = true {
  obj[field] == ""
}

matches_any(str, patterns) {
  re_match(patterns[_], str)
}

hostPatterns = { patterns |
  namespace := data.inventory.cluster.v1.Namespace[input.request.object.metadata.namespace]
  allowedHosts := split(namespace.metadata.annotations[ingressHostAnnotation], ",")
  trimmedHosts := trim(allowedHosts[_], " ")

  patterns := concat("", ["^", replace(trimmedHosts, ".", "\\."), "$"])
}

prefixPatterns = { patterns | 
  namespace := data.inventory.cluster.v1.Namespace[input.request.object.metadata.namespace]
  allowedHosts := split(namespace.metadata.annotations[ingressHostAnnotation], ",")
  trimmedHosts := trim(allowedHosts[_], " ")
    
  prefixe := { prefix | prefixe := split(namespace.metadata.annotations[ingressAllowedHostPrefixesAnnotation], ","); prefix := trim(prefixe[_], " ") }
  replacedPrefixe := { prefix | prefix := replace(prefixe[_], ".", "\\.") }
  replacedPrefixe2 := replace(replacedPrefixe[_], "*", ".*")
    
  patterns := concat("", ["^", replacedPrefixe2, trimmedHosts, "$"]) 
}

violation[{"msg": msg}] {
  operations[input.request.operation]

  namespace := data.inventory.cluster.v1.Namespace[input.request.object.metadata.namespace]
  not missing(namespace.metadata.annotations, ingressHostAnnotation)

  ingress_hosts[{"msg":msg}]
}

ingress_hosts[{"msg":msg}] {
  not missing(input.request.object.spec, "backend")

  msg := "spec.backend is not allowed"
}

ingress_hosts[{"msg":msg}] {
  namespace := data.inventory.cluster.v1.Namespace[input.request.object.metadata.namespace]
  missing(namespace.metadata.annotations, ingressAllowedHostPrefixesAnnotation)

  host := input.request.object.spec.rules[_].host
  not matches_any(host, hostPatterns)

  msg := sprintf("ingress host %s is not allowed. Allowed hosts: %s", [host, namespace.metadata.annotations[ingressHostAnnotation]])
}

ingress_hosts[{"msg":msg}] {
  namespace := data.inventory.cluster.v1.Namespace[input.request.object.metadata.namespace]
  not missing(namespace.metadata.annotations, ingressAllowedHostPrefixesAnnotation)

  allPatterns := hostPatterns | prefixPatterns

  host := input.request.object.spec.rules[_].host
  not matches_any(host, allPatterns)

  msg := sprintf("ingress host %s is not allowed. Allowed hosts: %s, allowed prefixe: %s", [host, namespace.metadata.annotations[ingressHostAnnotation], namespace.metadata.annotations[ingressAllowedHostPrefixesAnnotation]])
}
