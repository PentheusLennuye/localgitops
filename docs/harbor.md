# Harbor

## A. Requirements

Almost everything you need to know is in
[Deploying Harbor with HA](https://goharbor.io/docs/2.7.0/install-config/harbor-ha-helm/).

However, note that of version 1.0.0 of this automation project, Harbor does not
like PostgreSQL 14, so keep the version of PostgreSQL in _localhost.yaml_ to
the 13's.

## B. Using Harbor

### B.1 With Docker

One can use the same hostname to log in to Docker whether in the kubernetes
cluster or out of it:

```
docker login harbor.<domain>
```

#### B.1.3 From CI/CD

One needs a robot account.
