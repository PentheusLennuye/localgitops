# OpenLDAP

## A. Default Group

The OpenLDAP system does not have any group containers when started. To create
them:

1. Click on _dc=gitops,dc=local > Create new entry here_
2. Generic: Organisation Unit
  - Organisational Unit: __groups__
  - Click on _Create Object_

3. Click on _ou=groups_
4. Click on _Create a child entry_
5. Templates: _Generic: PosixGroup_
  - Group: __Default__
  - Click on _Create Object_

## B. Users

1. Click on _ou=users > Create new entry here_
2. Templates: _Generic: user account_
   - Password: _clear_ and enter the password
   - GID Number: _Default_
   - Create Object
3. Click on the user you just created under _ou=users_
4. Click on _Add new attribute_
   - Add Attribute: _Email_
5. Add the email address

## C. Second Series of Groups

One may wish to experiment with the core services. Recommended groups are:

- harbor_users
- harbor_admins
- jenkins_users
- jenkins_admins
- vault_users
- vault_admins

When creating a group for Harbor, Jenkins, or Vault credentials, select
_ou=groups_ and:

1. Create a child entry
2. Templates: _Generic: PosixGroup_
  - members: select accordingly
3. Create Object

