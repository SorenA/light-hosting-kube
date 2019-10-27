output "rancher_agent_node_command" {
  value = "${rancher2_cluster.default.cluster_registration_token.0.node_command}"
}