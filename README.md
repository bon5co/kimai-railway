# kimai-railway

Wrapper over the upstream `kimai/kimai2` image (2.72.0) for Railway. It binds Apache to Railway's injected `PORT`, requires an administrator password, and seeds one API access token for the administrator from `KIMAI_API_TOKEN` after the database is installed, so a deploy has an API credential without anyone clicking through the web interface.

Published to `ghcr.io/bon5co/kimai-railway`. Used by the Railway template described in [bon5co/railwaytemplate2](https://github.com/bon5co/railwaytemplate2).
