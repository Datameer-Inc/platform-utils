# Platform Utils

## Structure

### Scripts

```shell
init.sh
process-tools.sh
tools
  - datadog
     - process.sh
     - component
       - emr
         - playbook.yaml
       - spotlight
         - playbook.yaml
  - toolx
     - process.sh
     - component
       - emr
         - playbook.yaml
       - spotlight
         - playbook.yaml
```

### Local Config

- `.env`
  - holds env vars used by the playbooks above.
  - tools process.sh called when this file is found.
- `playbook.yaml` (OPTIONAL)
  - custom playbook to use if necessary.

```shell
tools
  - datadog
     - .env
     - component
       - emr
         - playbook.yaml
       - spotlight
         - playbook.yaml
  - toolx
     - .env
     - component
       - emr
         - playbook.yaml
       - spotlight
         - playbook.yaml
```

## Makefile Targets

<!-- START makefile-doc -->
```bash
$ make help


Usage:
  make <target>

Targets:
  dd-checks            For <TAG> (default: latest), list all config examples found in "/etc/datadog-agent/conf.d"
  dd-check/%           For <TAG> (default: latest), output the "/etc/datadog-agent/conf.d/<%>.d/conf.yaml.example
  help                 Makefile Help Page
  docs                 Update the README documentation
  pre-commit           Initialize pre-commit and install the git-hooks
  guard-%              Util to check env var (e.g. guard-ENV_VAR)
```
<!-- END makefile-doc -->

## Scripts

### `init.sh`

Spotlight-utils version mgmt

- check for latest release of platform-utils
- compare to current extracted (location: `/opt/platform-utils`)
- update accordingly
- **STATUS:** latest release of `platform-utils` extracted for use
- execute `process-tools.sh`

### `process-tools.sh`

- look in well-known locations (e.g `/config-files/platform-utils/datadog`) for possible configs
- install/update/delete as necessary according to config

### `tools` directory

Installation - CRUD - scripts for the various tools

### `tools/xxxxxxx/component`

n/a at the moment (a decision needs to be made on how to deliver configs)

## Tool Configuration

Example for datadog.

Under `/config-files/platform-utils/datadog` I could imagine the following

```
/config-files/platform-utils/datadog
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

### Default Configurations per Component

See the `OPTIONAL TODO` above. The idea here would be to have a default/global config per component which can be changed gloablly w/o having to update all the individual instances.

The `/config-files/platform-utils/datadog/datadog.properties` could then include a simple

```shell
DD_AGENT_ENABLED=true/false
```

and the default configs would take care of the rest.

## General Installation

- cron job to pull latest `init.sh`, chmod, and execute
