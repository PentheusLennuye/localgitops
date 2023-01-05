resource "time_sleep" "wait_for_backend_role" {
  depends_on = [vault_approle_auth_backend_role.localgitops-jenkins]
  create_duration = "2s"
}
resource "vault_approle_auth_backend_role_secret_id" "jenkins" {
  depends_on   = [time_sleep.wait_for_backend_role]
  backend      = vault_auth_backend.approle.path
  role_name    = "${var.jenkins_fqdn}"
}
resource "time_sleep" "wait_for_secret_id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.jenkins]
  create_duration = "2s"
}
resource "jenkins_credential_vault_approle" "vault-credential" {
  depends_on   = [time_sleep.wait_for_secret_id]
  description = "${var.jenkins_fqdn} on Vault"
  name        = "${var.jenkins_fqdn}"
  path        = vault_auth_backend.approle.path
  role_id     = vault_approle_auth_backend_role.localgitops-jenkins.role_id
  secret_id   = vault_approle_auth_backend_role_secret_id.jenkins.secret_id
  scope       = "GLOBAL"
}
resource "jenkins_credential_secret_text" "github_credential" {
  name        = "github_machine_credentials"
  description = "GitHub Machine Account"
  scope       = "GLOBAL"
  secret      = var.github_machine_token
}
resource "jenkins_credential_username" "github_scm_credential" {
  name        = "github_machine_scm_credentials"
  description = "GitHub Machine Account SCM Credentials"
  scope       = "GLOBAL"
  username    = "unused_username"
  password    = var.github_machine_token
}
resource "jenkins_credential_secret_file" "localgitops_kubeconfig" {
  name        = "localgitops_kubeconfig"
  description = "Credentials to fire kubectl on Jenkins' own k8s host"
  scope       = "GLOBAL"
  filename    = "localgitops_kubeconfig"
  secretbytes = filebase64("${path.module}/jenkins_kubeconfig")
}
