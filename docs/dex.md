# Dex

The well-known configuration endpoint that can be used in Jenkins automatic
configuration is (https://dex.gitops.local/.well-known/openid-config),
provided that the hostname and domain are the default "dex" and "gitops.local",
respectively.

At the time of writing, SSL verification is troublesome as the ca certs imports
are being ignored by Jenkins and Harbor. SSL verification might best be turned
off.

- In Jenkins: Manage Jenkins > Configure Global Security
  - Security Realm: Login with Openid Connect
    - ...
    - Advanced > Disable ssl verification
