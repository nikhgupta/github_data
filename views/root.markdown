## Available Methods

### Statistics

All of the following methods expect a `user` (Github user to query data
for) and `token` (Github token for API authentication) parameter in the
`GET` request.

- __Contributions__: returns daily, weekly and monthly contributions
  (public) made on Github by the user, as well as, last contribution
  date, total contributions made and contribution streak for given user.
  Data is scraped by requesting:
  `http://github.com/users/<user>/contributions`

        GET /stats/contributions

- __Gists__: returns gists updated in the last week, month and the year
  by the user, as well as since the beginning grouped by `updated_at`.
  A different grouping method can be requested by adding `&group_by=`
  parameter.

        GET /stats/gists

- __Repos__: returns repositories grouped by `pushed_at` field in
  a daily, monthly, weekly and yearly graph data form. A different
  grouping method can be requested by adding `&group_by` parameter.

        GET /stats/repos

- __Open Issues__: returns open issues grouped by `updated_at` field in 
  a daily, monthly, weekly and yearly graph data form. A different
  grouping method can be requested by adding `&group_by` parameter.

        GET /stats/open_issues

- __Issues__: returns open and closed issues grouped by `updated_at`
  field in a daily, monthly, weekly and yearly graph data form.
  A different grouping method can be requested by adding `&group_by`
  parameter. Note that this method is really expensive, and should only
  be called when required.

        GET /stats/issues

### Listing

- __Open Issues__: returns list of open issues for the given user across
  all repositories.

        GET /list/open_issues

### Combined method

You can request all the data that you need in a single request to this server by using the following method. Provide a comma separated list of methods that you need to access to this method.

        GET /stats/gists,open_issues,repos,contributions/list/open_issues?user=<user>&token=<token>

The above request will provide statistics for the gists, open issues, repos and contributions done by the user as well as a list of open issues for the given user in the following format:

        {
            "stats": {
                "gists": {
                    ...
                },
                "open_issues": {
                    ...
                },
                "repos": {
                    ...
                },
                "contributions": {
                    ...
                }
            },
            "lists": {
                "open_issues": {
                    ...
                }
            }
        }
