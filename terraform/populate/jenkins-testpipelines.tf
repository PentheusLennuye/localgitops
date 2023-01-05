resource "jenkins_folder" "test_suite" {
  depends_on   = [ jenkins_credential_vault_approle.vault-credential ]
  name         = "test_suite"
  display_name = "Self Tests"
  description  = "Jenkins Operations and Integration Tests"
}

resource "jenkins_job" "vault_test" {
  name     = "vault_test"
  folder   = jenkins_folder.test_suite.id
  template = templatefile("${path.module}/vault_test.xml", {
               description = "Ensuring Vault works with current credentials"
              })
}

resource "jenkins_job" "github_test" {
  name     = "github_test"
  folder   = jenkins_folder.test_suite.id
  template = templatefile("${path.module}/github_test.xml", {
               description = "Ensuring GitHub works with credentials in Vault"
              })
}

