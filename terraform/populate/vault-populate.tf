locals {
  kcfg = yamldecode("${file("${path.module}/../kubeconfig")}")
  ca  = local.kcfg["clusters"][0]["cluster"]["certificate-authority-data"]
  ccd = local.kcfg["users"][0]["user"]["client-certificate-data"]
  cck = local.kcfg["users"][0]["user"]["client-key-data"]
}
resource "vault_auth_backend" "approle" {
  type = "approle"
}
resource "vault_auth_backend" "userpass" {
  type = "userpass"
}
resource "vault_auth_backend" "oidc" {
  type = "oidc"
}
resource "vault_mount" "kvv2" {
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}
resource "time_sleep" "wait_5_seconds" {
  depends_on = [vault_mount.kvv2]
  create_duration = "5s"
}
resource "vault_kv_secret_backend_v2" "config" {
  depends_on           = [ time_sleep.wait_5_seconds]
  mount                = vault_mount.kvv2.path
  max_versions         = 5
  delete_version_after = 12600
  cas_required         = false
}

# ===== Policies =============================================================

# Null policy
resource "vault_policy" "null" {
  name   = "null"
  policy = <<-EONULPOL
    path "*" {
      capabilities = []
    }
  EONULPOL
}

# CI/CD Least Privilege
resource "vault_policy" "ci" {
  name   = "ci"
  policy = <<-EOCIPOL
    path "kv/data/ci/*" {
      capabilities = [ "read" ]
    }
  EOCIPOL
}

# People Moderate Privilege
resource "vault_policy" "ro" {
  name   = "ro"
  policy = <<-EOHRPOL
    path "kv/*" {
      capabilities = [ "read", "list" ]
    }
  EOHRPOL
}

resource "vault_policy" "rw" {
  name   = "rw"
  policy = <<-EOHAPOL
    path "kv/*" {
      capabilities = [ "create", "read", "update", "delete", "list" ]
    }
  EOHAPOL
}

# Admin Big Privilege
resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<-EOADMINPOLICY
    path "sys/health"
    {
      capabilities = ["read", "sudo"]
    }
    
    # Create and manage ACL policies broadly across Vault
    
    # List existing policies
    path "sys/policies/acl"
    {
      capabilities = ["list"]
    }
    
    # Create and manage ACL policies
    path "sys/policies/acl/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    
    # Enable and manage authentication methods broadly across Vault
    
    # Manage auth methods broadly across Vault
    path "auth/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    
    # Create, update, and delete auth methods
    path "sys/auth/*"
    {
      capabilities = ["create", "update", "delete", "sudo"]
    }
    
    # List auth methods
    path "sys/auth"
    {
      capabilities = ["read"]
    }
    
    # Enable and manage the key/value secrets engine at `secret/` path
    
    # List, create, update, and delete key/value secrets
    path "kv/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    
    # Manage secrets engines
    path "sys/mounts/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    
    # List existing secrets engines.
    path "sys/mounts"
    {
      capabilities = ["read"]
    }
  EOADMINPOLICY
}

# Jenkins ====================================================================
resource "vault_policy" "localgitops-jenkins" {
  name   = "${var.jenkins_fqdn}"
  policy = <<-EOLGJPOL
    path "auth/approle/role/${var.jenkins_fqdn}/role-id" {
      capabilities = [ "read" ]
    }
    path "auth/approle/role/${var.jenkins_fqdn}/secret-id" {
      capabilities = [ "update" ]
    }
    path "kv/data/ci/*" {
      capabilities = [ "read" ]
    }
  EOLGJPOL
}

resource "vault_approle_auth_backend_role" "localgitops-jenkins" {
  backend               = vault_auth_backend.approle.path
  role_name             = "${var.jenkins_fqdn}"
  token_policies        = ["default", "${var.jenkins_fqdn}", "ci"]
  secret_id_bound_cidrs = ["10.42.0.0/16", "127.0.0.1/32"]
  secret_id_ttl         = 0
  secret_id_num_uses    = 0
  token_bound_cidrs     = ["10.42.0.0/16", "127.0.0.1/32"]
  token_num_uses        = 10
  token_ttl             = 600
  token_max_ttl         = 1800
  token_type            = "service"
}


# OIDC =======================================================================
resource "vault_policy" "localgitops-oidc" {
  name = "oidc-${var.domain}"
  policy = <<-EOOIDCPOL
    path "sys/auth/oidc" {
      capabilities = [ "create", "read", "update", "delete", "sudo" ]
    } 
    path "auth/oidc/*" {
      capabilities = [ "create", "read", "update", "delete", "list" ]
    }
    path "sys/policies/acl/*" {
      capabilities = [ "create", "read", "update", "delete", "list" ]
    }
    path "sys/mounts" {
      capabilities = [ "read" ]
    }
  EOOIDCPOL
}

# Groups tied to policies
resource "vault_identity_group" "kv_admin" {
  metadata = {
    responsibility = "Full Access to Vault"
  }
  name = "kv_admin"
  type = "external"
  policies = ["admin"]
}

resource "vault_identity_group" "kv_rw" {
  metadata = {
    responsibility = "Write, Edit, and Delete Secrets"
  }
  name = "kv_rw"
  type = "external"
  policies = ["rw"]
}

resource "vault_identity_group" "kv_ro" {
  metadata = {
    responsibility = "Write, Edit, and Delete Secrets"
  }
  name = "kv_ro"
  type = "external"
  policies = ["ro"]
}

# OIDC Group Aliases 
resource "vault_identity_group_alias" "vault_admins" {
  name = "vault_admins"
  mount_accessor = vault_auth_backend.oidc.accessor
  canonical_id = vault_identity_group.kv_admin.id
}
resource "vault_identity_group_alias" "vault_owners" {
  name = "vault_owners"
  mount_accessor = vault_auth_backend.oidc.accessor
  canonical_id = vault_identity_group.kv_rw.id
}
resource "vault_identity_group_alias" "vault_readers" {
  name = "vault_readers"
  mount_accessor = vault_auth_backend.oidc.accessor
  canonical_id = vault_identity_group.kv_ro.id
}

# ===== GITOPS SECRETS =======================================================
# Test Secret
resource "vault_kv_secret_v2" "kvtest" {
  depends_on                 = [ time_sleep.wait_5_seconds]
  mount                      = vault_mount.kvv2.path
  name                       = "ci/tests/test_keyvalue"
  delete_all_versions        = true
  data_json                  = jsonencode(
    {
      greeting  = "Hi",
      recipient = "Mum!"
    }
  )
}

# Terraform backend to local k8s cluster
resource "vault_kv_secret_v2" "tfbackend" {
  depends_on                 = [ time_sleep.wait_5_seconds]
  mount                      = vault_mount.kvv2.path
  name                       = "ci/tfbackend"
  delete_all_versions        = true
  data_json                  = jsonencode(
    {
      cluster_ca_certificate = local.ca,
      jenkins_k8s_client_certificate = local.ccd,
      jenkins_k8s_client_key = local.cck
    }
  )
}
