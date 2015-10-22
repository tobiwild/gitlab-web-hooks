# Gitlab Web Hooks [![Build Status](https://travis-ci.org/tobiwild/gitlab-web-hooks.svg)](https://travis-ci.org/tobiwild/gitlab-web-hooks)

Small [Sinatra](http://www.sinatrarb.com/) app for providing Web hooks for [Gitlab](https://about.gitlab.com/)

## Reviewboard Web Hook

With this Web hook it is possible to transfer Merge Request changes in Gitlab to a [Reviewboard](https://www.reviewboard.org/) instance. The configuration is done in the `.env` file. To use the the Web Hook simply run `rackup` and add the server address as a Web hook for incoming Merge Request events in Gitlab.

How it works:

* the hook only transfers the changes when the Merge Request has a certain label (default = `reviewboard`)
* on the first transfer it creates a Review Request on the Reviewboard and writes a Merge Request comment with the ID (e.g. `REVIEW_ID: 234`)
* for every MR change it uploads a new Diff to Reviewboard and adds a MR comment with the link (e.g. `http://localhost:8000/r/234/diff/2-3/`)
* it uses the owner of the MR as the submitter of the Review Request, so make sure that:
  * the `REVIEWBOARD_USER` has the ["Can submit as user" permission](https://www.reviewboard.org/docs/manual/dev/admin/configuration/users/#can-submit-as-user-permission)
  * users in Gitlab and Reviewboard have the same names
  * when using LDAP the user with the `GITLAB_PRIVATE_TOKEN` has the Admin role (to be able to fetch LDAP user names)
