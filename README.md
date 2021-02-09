# Platform Utils

## General Installation

One shot install:

```shell
curl -fsSL -H "Cache-Control: no-cache" "https://raw.githubusercontent.com/Datameer-Inc/platform-utils/master/init.sh" | bash
```

This can also be placed in a cron job to pull latest `init.sh`, chmod, and execute

## Util Scripts

The general scripts contain scripts to

- install ansible
- configuration playbooks for various components

Example structure (NOTE: may not be completely up to date)

```shell
init.sh
process-tools.sh
tools
  - datadog
     - process.sh
     - component
       - basic
         - basic.sh
         - basic.yaml
       - emr
         - master-node.sh
         - master-node.yaml
         - core-node.sh
         - core-node.yaml
         - task-node.sh
         - task-node.yaml
       - spotlight
         - spotlight.sh
         - spotlight.yaml
  - toolX
     - process.sh
     - component
       - compX
         - compX.sh
         - compX.yaml
       - ...
       - ...
```

## Local Config

The configuration files local to the instance

e.g.

- `/config-files/platform-utils/datadog/.env`
  - holds env vars used by the playbooks above.
  - tools process.sh called when this file is found.
- `/config-files/platform-utils/datadog/components/emr/master-node.sh` (OPTIONAL)

  `/config-files/platform-utils/datadog/components/emr/master-node.yaml` (OPTIONAL)
  - custom playbook to use if necessary.

## Makefile Targets

<!-- START makefile-doc -->
```bash
$ make help


Usage:
  make <target>

Targets:
  dd-checks            For <TAG> (default: latest), list all config examples found in "/etc/datadog-agent/conf.d"
  dd-check/%           For <TAG> (default: latest), output the "/etc/datadog-agent/conf.d/<%>.d/conf.yaml.example"
  help                 Makefile Help Page
  docs                 Update the README documentation
  pre-commit           Initialize pre-commit and install the git-hooks
  guard-%              Util to check env var (e.g. guard-ENV_VAR)
```
<!-- END makefile-doc -->

## Util Scripts in Details

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

Installation/management scripts for the various tools.

### `tools/xxxxxxx/component`

Components created based on the type and use of instance. A `basic` profile is provided along with some specialised component profiles.

## Tool Configuration

In order to activate a tool, a `.env` file needs to be added with the appropriate environment variable, e.g.

```shell
$ cat /config-files/platform-utils/datadog/.env

DD_AGENT_ENABLED=true
```

To use a custom ansible configuration, simply place an equivalent file in the same relative path, e.g.

```shell
/config-files/platform-utils/datadog/.env
/config-files/platform-utils/datadog/component/emr/master-node.sh
/config-files/platform-utils/datadog/component/emr/master-node.yaml
```

## Testing

Automated testing to be defined and implemented.

You can find Vagrant file with a list of commands used to test configurations.

General steps:

- `vagrant up`
- `vagrant ssh`
- Use the commands to run and test the scripts in an isolated environment.
