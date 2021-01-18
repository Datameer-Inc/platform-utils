## Structure

```
init.sh
process-tools.sh
tools
  - datadog
     - install.sh
     - component (OPTIONAL TODO: default configs?)
       - emr
         - conf.d
         - datadog.yaml
       - spotlight
         - conf.d
         - datadog.yaml
```

## Scripts

### `init.sh`

Spotlight-utils version mgmt

- check for latest release of spotlight-utils
- compare to current extracted (location: `/opt/spotlight-utils`)
- update accordingly
- **STATUS:** latest released `spotlight-utils` installed
- execute

### `process-tools.sh`

- look in well-known locations (e.g `/config-files/spotlight-utils/datadog`) for possible configs
- install/update/delete as necessary according to config

### `tools` directory

Installation - CRUD - scripts for the various tools

### `tools/xxxxxxx/component`

n/a at the moment (a decision needs to be made on how to deliver configs)

## Tool Configuration

Example for datadog.

Under `/config-files/spotlight-utils/datadog` I could imagine the following

```
/config-files/spotlight-utils/datadog
- datadog.properties
- datadog.yaml
- conf.d
```

Where datadog.properties contains

```shell
DD_AGENT_ENABLED=true/false
# and possibly...
DD_AGENT_MAJOR_VERSION=7
```

## General Installation

- cron job to pull latest `init.sh`, chmod, and execute
