## Structure

```
init.sh
tools
  - datadog
     - install.sh
     - component
       - emr
         - conf.d
         - datadog.yaml
       - spotlight
         - conf.d
         - datadog.yaml
```

## EMR

- bootstrap-action (cronjob to
  - pull init.sh from `main` and execute with params e.g datadog/emr OR datadog/spotlight
  - init.sh (spotlight-utils version mgmt)
    - checks for latest release of tools
    - compares to currently extracted
    - updates accordingly
  - process the paramters (datadog/emr, etc)
    - install/update datadog (based on changes to datadog.yaml and conf.d)
