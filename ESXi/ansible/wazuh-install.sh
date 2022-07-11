#!/bin/bash

# Wazuh installer
# Copyright (C) 2015, Wazuh Inc.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

readonly repogpg="https://packages.wazuh.com/key/GPG-KEY-WAZUH"
readonly repobaseurl="https://packages.wazuh.com/4.x"
readonly reporelease="stable"
readonly filebeat_wazuh_module="${repobaseurl}/filebeat/wazuh-filebeat-0.2.tar.gz"
readonly bucket="packages.wazuh.com"
readonly repository="4.x"

readonly wazuh_major="4.3"
readonly wazuh_version="4.3.4"
readonly wazuh_revision_deb="1"
readonly wazuh_revision_rpm="1"
readonly indexer_revision_deb="1"
readonly indexer_revision_rpm="1"
readonly dashboard_revision_deb="1"
readonly dashboard_revision_rpm="1"
readonly filebeat_version="7.10.2"
readonly wazuh_install_vesion="0.1"
readonly resources="https://${bucket}/${wazuh_major}"
readonly base_url="https://${bucket}/${repository}"
readonly base_path="$(dirname $(readlink -f "$0"))"
config_file="${base_path}/config.yml"
readonly tar_file_name="wazuh-install-files.tar"
tar_file="${base_path}/${tar_file_name}"
readonly filebeat_wazuh_template="https://raw.githubusercontent.com/wazuh/wazuh/${wazuh_major}/extensions/elasticsearch/7.x/wazuh-template.json"
readonly dashboard_cert_path="/etc/wazuh-dashboard/certs"
readonly filebeat_cert_path="/etc/filebeat/certs"
readonly indexer_cert_path="/etc/wazuh-indexer/certs"
readonly logfile="/var/log/wazuh-install.log"
debug=">> ${logfile} 2>&1"
readonly base_dest_folder="wazuh-offline"
readonly manager_deb_base_url="${base_url}/apt/pool/main/w/wazuh-manager"
readonly manager_deb_package="wazuh-manager_${wazuh_version}-${wazuh_revision_deb}_amd64.deb"
readonly filebeat_deb_base_url="${base_url}/apt/pool/main/f/filebeat"
readonly filebeat_deb_package="filebeat-oss-${filebeat_version}-amd64.deb"
readonly indexer_deb_base_url="${base_url}/apt/pool/main/w/wazuh-indexer"
readonly indexer_deb_package="wazuh-indexer_${wazuh_version}-${indexer_revision_deb}_amd64.deb"
readonly dashboard_deb_base_url="${base_url}/apt/pool/main/w/wazuh-dashboard"
readonly dashboard_deb_package="wazuh-dashboard_${wazuh_version}-${dashboard_revision_deb}_amd64.deb"
readonly manager_rpm_base_url="${base_url}/yum"
readonly manager_rpm_package="wazuh-manager-${wazuh_version}-${wazuh_revision_rpm}.x86_64.rpm"
readonly filebeat_rpm_base_url="${base_url}/yum"
readonly filebeat_rpm_package="filebeat-oss-${filebeat_version}-x86_64.rpm"
readonly indexer_rpm_base_url="${base_url}/yum"
readonly indexer_rpm_package="wazuh-indexer-${wazuh_version}-${indexer_revision_rpm}.x86_64.rpm"
readonly dashboard_rpm_base_url="${base_url}/yum"
readonly dashboard_rpm_package="wazuh-dashboard-${wazuh_version}-${dashboard_revision_rpm}.x86_64.rpm"
readonly wazuh_gpg_key="https://${bucket}/key/GPG-KEY-WAZUH"
readonly filebeat_config_file="${resources}/tpl/wazuh/filebeat/filebeat.yml"

config_file_indexer_indexer_all_in_one="network.host: \"127.0.0.1\"
node.name: \"node-1\"
cluster.initial_master_nodes:
- \"node-1\"
cluster.name: \"wazuh-cluster\"

node.max_local_storage_nodes: \"3\"
path.data: /var/lib/wazuh-indexer
path.logs: /var/log/wazuh-indexer

plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.http.enabled: true
plugins.security.ssl.transport.enforce_hostname_verification: false
plugins.security.ssl.transport.resolve_hostname: false

plugins.security.authcz.admin_dn:
- \"CN=admin,OU=Wazuh,O=Wazuh,L=California,C=US\"
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.nodes_dn:
- \"CN=indexer,OU=Wazuh,O=Wazuh,L=California,C=US\"
plugins.security.restapi.roles_enabled:
- \"all_access\"
- \"security_rest_api_access\"

plugins.security.system_indices.enabled: true
plugins.security.system_indices.indices: [\".opendistro-alerting-config\", \".opendistro-alerting-alert*\", \".opendistro-anomaly-results*\", \".opendistro-anomaly-detector*\", \".opendistro-anomaly-checkpoints\", \".opendistro-anomaly-detection-state\", \".opendistro-reports-*\", \".opendistro-notifications-*\", \".opendistro-notebooks\", \".opensearch-observability\", \".opendistro-asynchronous-search-response*\", \".replication-metadata-store\"]

### Option to allow Filebeat-oss 7.10.2 to work ###
compatibility.override_main_response_version: true"

config_file_indexer_indexer="network.host: 0.0.0.0
node.name: node-1
cluster.initial_master_nodes: node-1

plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false
plugins.security.ssl.transport.resolve_hostname: false
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.nodes_dn:
- CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US
plugins.security.authcz.admin_dn:
- CN=admin,OU=Wazuh,O=Wazuh,L=California,C=US

plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled: [\"all_access\", \"security_rest_api_access\"]
cluster.routing.allocation.disk.threshold_enabled: false
node.max_local_storage_nodes: 3

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

### Option to allow Filebeat-oss 7.10.2 to work ###
compatibility.override_main_response_version: true"

config_file_indexer_indexer_unattended_distributed="node.master: true
node.data: true
node.ingest: true

cluster.name: wazuh-indexer-cluster
cluster.routing.allocation.disk.threshold_enabled: false

node.max_local_storage_nodes: \"3\"
path.data: /var/lib/wazuh-indexer
path.logs: /var/log/wazuh-indexer


plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.http.enabled: true
plugins.security.ssl.transport.enforce_hostname_verification: false
plugins.security.ssl.transport.resolve_hostname: false

plugins.security.authcz.admin_dn:
- \"CN=admin,OU=Wazuh,O=Wazuh,L=California,C=US\"
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.restapi.roles_enabled:
- \"all_access\"
- \"security_rest_api_access\"

plugins.security.system_indices.enabled: true
plugins.security.system_indices.indices: [\".opendistro-alerting-config\", \".opendistro-alerting-alert*\", \".opendistro-anomaly-results*\", \".opendistro-anomaly-detector*\", \".opendistro-anomaly-checkpoints\", \".opendistro-anomaly-detection-state\", \".opendistro-reports-*\", \".opendistro-notifications-*\", \".opendistro-notebooks\", \".opensearch-observability\", \".opendistro-asynchronous-search-response*\", \".replication-metadata-store\"]

### Option to allow Filebeat-oss 7.10.2 to work ###
compatibility.override_main_response_version: true"

config_file_indexer_roles_internal_users="---
# This is the internal user database
# The hash value is a bcrypt hash and can be generated with plugin/tools/hash.sh

_meta:
  type: \"internalusers\"
  config_version: 2

# Define your internal users here

## Demo users

admin:
  hash: \"\$2a\$12\$VcCDgh2NDk07JGN0rjGbM.Ad41qVR/YFJcgHp0UGns5JDymv..TOG\"
  reserved: true
  backend_roles:
  - \"admin\"
  description: \"Demo admin user\"

kibanaserver:
  hash: \"\$2a\$12\$4AcgAt3xwOWadA5s5blL6ev39OXDNhmOesEoo33eZtrq2N0YrU3H.\"
  reserved: true
  description: \"Demo kibanaserver user\"

kibanaro:
  hash: \"\$2a\$12\$JJSXNfTowz7Uu5ttXfeYpeYE0arACvcwlPBStB1F.MI7f0U9Z4DGC\"
  reserved: false
  backend_roles:
  - \"kibanauser\"
  - \"readall\"
  attributes:
    attribute1: \"value1\"
    attribute2: \"value2\"
    attribute3: \"value3\"
  description: \"Demo kibanaro user\"

logstash:
  hash: \"\$2a\$12\$u1ShR4l4uBS3Uv59Pa2y5.1uQuZBrZtmNfqB3iM/.jL0XoV9sghS2\"
  reserved: false
  backend_roles:
  - \"logstash\"
  description: \"Demo logstash user\"

readall:
  hash: \"\$2a\$12\$ae4ycwzwvLtZxwZ82RmiEunBbIPiAmGZduBAjKN0TXdwQFtCwARz2\"
  reserved: false
  backend_roles:
  - \"readall\"
  description: \"Demo readall user\"

snapshotrestore:
  hash: \"\$2y\$12\$DpwmetHKwgYnorbgdvORCenv4NAK8cPUg8AI6pxLCuWf/ALc0.v7W\"
  reserved: false
  backend_roles:
  - \"snapshotrestore\"
  description: \"Demo snapshotrestore user\"

wazuh_admin:
  hash: \"\$2y\$12\$d2awHiOYvZjI88VfsDON.u6buoBol0gYPJEgdG1ArKVE0OMxViFfu\"
  reserved: true
  hidden: false
  backend_roles: []
  attributes: {}
  opendistro_security_roles: []
  static: false
  
wazuh_user:
  hash: \"\$2y\$12\$BQixeoQdRubZdVf/7sq1suHwiVRnSst1.lPI2M0.GPZms4bq2D9vO\"
  reserved: true
  hidden: false
  backend_roles: []
  attributes: {}
  opendistro_security_roles: []
  static: false  "

config_file_indexer_roles_roles_mapping="---
# In this file users, backendroles and hosts can be mapped to Open Distro Security roles.
# Permissions for Opendistro roles are configured in roles.yml

_meta:
  type: \"rolesmapping\"
  config_version: 2

# Define your roles mapping here

## Demo roles mapping

all_access:
  reserved: false
  backend_roles:
  - \"admin\"
  description: \"Maps admin to all_access\"

own_index:
  reserved: false
  users:
  - \"*\"
  description: \"Allow full access to an index named like the username\"

logstash:
  reserved: false
  backend_roles:
  - \"logstash\"

kibana_user:
  reserved: false
  backend_roles:
  - \"kibanauser\"
  users:
  - \"wazuh_user\"
  - \"wazuh_admin\"
  description: \"Maps kibanauser to kibana_user\"

readall:
  reserved: false
  backend_roles:
  - \"readall\"

manage_snapshots:
  reserved: false
  backend_roles:
  - \"snapshotrestore\"

kibana_server:
  reserved: true
  users:
  - \"kibanaserver\"

wazuh_ui_admin:
  reserved: true
  hidden: false
  backend_roles: []
  hosts: []
  users:
  - \"wazuh_admin\"
  - \"kibanaserver\"
  and_backend_roles: []

wazuh_ui_user:
  reserved: true
  hidden: false
  backend_roles: []
  hosts: []
  users:
  - \"wazuh_user\"
  and_backend_roles: []"

config_file_indexer_roles_roles="_meta:
  type: \"roles\"
  config_version: 2

# Restrict users so they can only view visualization and dashboard on kibana
kibana_read_only:
  reserved: true

# The security REST API access role is used to assign specific users access to change the security settings through the REST API.
security_rest_api_access:
  reserved: true

# Allows users to view monitors, destinations and alerts
alerting_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/alerting/alerts/get'
    - 'cluster:admin/opendistro/alerting/destination/get'
    - 'cluster:admin/opendistro/alerting/monitor/get'
    - 'cluster:admin/opendistro/alerting/monitor/search'

# Allows users to view and acknowledge alerts
alerting_ack_alerts:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/alerting/alerts/*'

# Allows users to use all alerting functionality
alerting_full_access:
  reserved: true
  cluster_permissions:
    - 'cluster_monitor'
    - 'cluster:admin/opendistro/alerting/*'
  index_permissions:
    - index_patterns:
        - '*'
      allowed_actions:
        - 'indices_monitor'
        - 'indices:admin/aliases/get'
        - 'indices:admin/mappings/get'

# Allow users to read Anomaly Detection detectors and results
anomaly_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/ad/detector/info'
    - 'cluster:admin/opendistro/ad/detector/search'
    - 'cluster:admin/opendistro/ad/detectors/get'
    - 'cluster:admin/opendistro/ad/result/search'
    - 'cluster:admin/opendistro/ad/tasks/search'

# Allows users to use all Anomaly Detection functionality
anomaly_full_access:
  reserved: true
  cluster_permissions:
    - 'cluster_monitor'
    - 'cluster:admin/opendistro/ad/*'
  index_permissions:
    - index_patterns:
        - '*'
      allowed_actions:
        - 'indices_monitor'
        - 'indices:admin/aliases/get'
        - 'indices:admin/mappings/get'

# Allows users to read Notebooks
notebooks_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/notebooks/list'
    - 'cluster:admin/opendistro/notebooks/get'

# Allows users to all Notebooks functionality
notebooks_full_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/notebooks/create'
    - 'cluster:admin/opendistro/notebooks/update'
    - 'cluster:admin/opendistro/notebooks/delete'
    - 'cluster:admin/opendistro/notebooks/get'
    - 'cluster:admin/opendistro/notebooks/list'

# Allows users to read and download Reports
reports_instances_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/reports/instance/list'
    - 'cluster:admin/opendistro/reports/instance/get'
    - 'cluster:admin/opendistro/reports/menu/download'

# Allows users to read and download Reports and Report-definitions
reports_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/reports/definition/get'
    - 'cluster:admin/opendistro/reports/definition/list'
    - 'cluster:admin/opendistro/reports/instance/list'
    - 'cluster:admin/opendistro/reports/instance/get'
    - 'cluster:admin/opendistro/reports/menu/download'

# Allows users to all Reports functionality
reports_full_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/reports/definition/create'
    - 'cluster:admin/opendistro/reports/definition/update'
    - 'cluster:admin/opendistro/reports/definition/on_demand'
    - 'cluster:admin/opendistro/reports/definition/delete'
    - 'cluster:admin/opendistro/reports/definition/get'
    - 'cluster:admin/opendistro/reports/definition/list'
    - 'cluster:admin/opendistro/reports/instance/list'
    - 'cluster:admin/opendistro/reports/instance/get'
    - 'cluster:admin/opendistro/reports/menu/download'

# Allows users to use all asynchronous-search functionality
asynchronous_search_full_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/asynchronous_search/*'
  index_permissions:
    - index_patterns:
        - '*'
      allowed_actions:
        - 'indices:data/read/search*'

# Allows users to read stored asynchronous-search results
asynchronous_search_read_access:
  reserved: true
  cluster_permissions:
    - 'cluster:admin/opendistro/asynchronous_search/get'

wazuh_ui_user:
  reserved: true
  hidden: false
  cluster_permissions: []
  index_permissions:
  - index_patterns:
    - \"wazuh-*\"
    dls: \"\"
    fls: []
    masked_fields: []
    allowed_actions:
    - \"read\"
  tenant_permissions: []
  static: false

wazuh_ui_admin:
  reserved: true
  hidden: false
  cluster_permissions: []
  index_permissions:
  - index_patterns:
    - \"wazuh-*\"
    dls: \"\"
    fls: []
    masked_fields: []
    allowed_actions:
    - \"read\"
    - \"delete\"
    - \"manage\"
    - \"index\"
  tenant_permissions: []
  static: false"

config_file_filebeat_filebeat_elastic_cluster="# Wazuh - Filebeat configuration file
output.elasticsearch:
  hosts: [\"<elasticsearch_ip_node_1>:9200\", \"<elasticsearch_ip_node_2>:9200\", \"<elasticsearch_ip_node_3>:9200\"]
  protocol: https
  username: \${username}
  password: \${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: \"/etc/filebeat/certs/filebeat.pem\"
  ssl.key: \"/etc/filebeat/certs/filebeat-key.pem\"
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false

filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false"

config_file_filebeat_filebeat_unattended="# Wazuh - Filebeat configuration file
output.elasticsearch.hosts:
        - 127.0.0.1:9200
#        - <elasticsearch_ip_node_2>:9200 
#        - <elasticsearch_ip_node_3>:9200

output.elasticsearch:
  protocol: https
  username: \${username}
  password: \${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: \"/etc/filebeat/certs/filebeat.pem\"
  ssl.key: \"/etc/filebeat/certs/filebeat-key.pem\"
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false

filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644"

config_file_filebeat_filebeat="# Wazuh - Filebeat configuration file
output.elasticsearch:
  hosts: [\"<elasticsearch_ip>:9200\"]
  protocol: https
  username: \${username}
  password: \${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: \"/etc/filebeat/certs/filebeat.pem\"
  ssl.key: \"/etc/filebeat/certs/filebeat-key.pem\"
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false

filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false"

config_file_filebeat_filebeat_all_in_one="# Wazuh - Filebeat configuration file
output.elasticsearch:
  hosts: [\"127.0.0.1:9200\"]
  protocol: https
  username: \${username}
  password: \${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: \"/etc/filebeat/certs/filebeat.pem\"
  ssl.key: \"/etc/filebeat/certs/filebeat-key.pem\"
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false

filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false"

config_file_filebeat_filebeat_distributed="# Wazuh - Filebeat configuration file
output.elasticsearch:
  protocol: https
  username: \${username}
  password: \${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: \"/etc/filebeat/certs/filebeat.pem\"
  ssl.key: \"/etc/filebeat/certs/filebeat-key.pem\"
setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.overwrite: true
setup.ilm.enabled: false

filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644"

config_file_dashboard_dashboard_unattended_distributed="server.port: 443
opensearch.ssl.verificationMode: certificate
# opensearch.username: kibanaserver
# opensearch.password: kibanaserver
opensearch.requestHeadersWhitelist: [\"securitytenant\",\"Authorization\"]
opensearch_security.multitenancy.enabled: false
opensearch_security.readonly_mode.roles: [\"kibana_read_only\"]
server.ssl.enabled: true
server.ssl.key: \"/etc/wazuh-dashboard/certs/dashboard-key.pem\"
server.ssl.certificate: \"/etc/wazuh-dashboard/certs/dashboard.pem\"
opensearch.ssl.certificateAuthorities: [\"/etc/wazuh-dashboard/certs/root-ca.pem\"]
uiSettings.overrides.defaultRoute: /app/wazuh"

config_file_dashboard_dashboard_all_in_one="server.host: 0.0.0.0
server.port: 443
opensearch.hosts: https://localhost:9200
opensearch.ssl.verificationMode: certificate
# opensearch.username: kibanaserver
# opensearch.password: kibanaserver
opensearch.requestHeadersWhitelist: [\"securitytenant\",\"Authorization\"]
opensearch_security.multitenancy.enabled: false
opensearch_security.readonly_mode.roles: [\"kibana_read_only\"]
server.ssl.enabled: true
server.ssl.key: \"/etc/wazuh-dashboard/certs/kibana-key.pem\"
server.ssl.certificate: \"/etc/wazuh-dashboard/certs/kibana.pem\"
opensearch.ssl.certificateAuthorities: [\"/etc/wazuh-dashboard/certs/root-ca.pem\"]
uiSettings.overrides.defaultRoute: /app/wazuh"

config_file_dashboard_dashboard_unattended="server.host: 0.0.0.0
opensearch.hosts: https://127.0.0.1:9200
server.port: 443
opensearch.ssl.verificationMode: certificate
# opensearch.username: kibanaserver
# opensearch.password: kibanaserver
opensearch.requestHeadersWhitelist: [\"securitytenant\",\"Authorization\"]
opensearch_security.multitenancy.enabled: false
opensearch_security.readonly_mode.roles: [\"kibana_read_only\"]
server.ssl.enabled: true
server.ssl.key: \"/etc/wazuh-dashboard/certs/dashboard-key.pem\"
server.ssl.certificate: \"/etc/wazuh-dashboard/certs/dashboard.pem\"
opensearch.ssl.certificateAuthorities: [\"/etc/wazuh-dashboard/certs/root-ca.pem\"]
uiSettings.overrides.defaultRoute: /app/wazuh"

config_file_dashboard_dashboard="server.host: \"<kibana-ip>\"
opensearch.hosts: https://<elasticsearch-ip>:9200
server.port: 443
opensearch.ssl.verificationMode: certificate
# opensearch.username: kibanaserver
# opensearch.password: kibanaserver
opensearch.requestHeadersWhitelist: [\"securitytenant\",\"Authorization\"]
opensearch_security.multitenancy.enabled: false
opensearch_security.readonly_mode.roles: [\"kibana_read_only\"]
server.ssl.enabled: true
server.ssl.key: \"/etc/wazuh-dashboard/certs/kibana-key.pem\"
server.ssl.certificate: \"/etc/wazuh-dashboard/certs/kibana.pem\"
opensearch.ssl.certificateAuthorities: [\"/etc/wazuh-dashboard/certs/root-ca.pem\"]
server.defaultRoute: /app/wazuh"

config_file_certificate_config="nodes:
  # Wazuh indexer nodes
  indexer:
    - name: indexer-1
      ip: <indexer-node-ip>
    - name: indexer-2
      ip: <indexer-node-ip>
    - name: indexer-3
      ip: <indexer-node-ip>
  server:
    - name: server-1
      ip: <server-node-ip>
      node_type: master
    - name: server-2
      ip: <server-node-ip>
      node_type: worker
    - name: server-3
      ip: <server-node-ip>
      node_type: worker
  dashboard:
    - name: dashboard-1
      ip: <dashboard-node-ip>
    - name: dashboard-2
      ip: <dashboard-node-ip>
    - name: dashboard-3
      ip: <dashboard-node-ip>"

config_file_certificate_config_aio="nodes:
  indexer:
    - name: wazuh-indexer
      ip: 127.0.0.1
  server:
    - name: wazuh-server
      ip: 127.0.0.1
  dashboard:
    - name: wazuh-dashboard
      ip: 127.0.0.1"

trap installCommon_cleanExit SIGINT
export JAVA_HOME="/usr/share/wazuh-indexer/jdk/"
# ------------ installCommon.sh ------------ 
function installCommon_cleanExit() {

    rollback_conf=""

    if [ -n "$spin_pid" ]; then
        eval "kill -9 $spin_pid ${debug}"
    fi

    until [[ "${rollback_conf}" =~ ^[N|Y|n|y]$ ]]; do
        echo -ne "\nDo you want to remove the ongoing installation?[Y/N]"
        read -r rollback_conf
    done
    if [[ "${rollback_conf}" =~ [N|n] ]]; then
        exit 1
    else
        installCommon_rollBack
        exit 1
    fi

}
function installCommon_addWazuhRepo() {

    common_logger -d "Adding the Wazuh repository."

    if [ -n "${development}" ]; then
        if [ "${sys_type}" == "yum" ]; then
            eval "rm -f /etc/yum.repos.d/wazuh.repo ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "rm -f /etc/zypp/repos.d/wazuh.repo ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "rm -f /etc/apt/sources.list.d/wazuh.list ${debug}"
        fi
    fi

    if [ ! -f "/etc/yum.repos.d/wazuh.repo" ] && [ ! -f "/etc/zypp/repos.d/wazuh.repo" ] && [ ! -f "/etc/apt/sources.list.d/wazuh.list" ] ; then
        if [ "${sys_type}" == "yum" ]; then
            eval "rpm --import ${repogpg} ${debug}"
            eval "echo -e '[wazuh]\ngpgcheck=1\ngpgkey=${repogpg}\nenabled=1\nname=EL-\${releasever} - Wazuh\nbaseurl='${repobaseurl}'/yum/\nprotect=1' | tee /etc/yum.repos.d/wazuh.repo ${debug}"
            eval "chmod 644 /etc/yum.repos.d/wazuh.repo ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "rpm --import ${repogpg} ${debug}"
            eval "echo -e '[wazuh]\ngpgcheck=1\ngpgkey=${repogpg}\nenabled=1\nname=EL-\${releasever} - Wazuh\nbaseurl='${repobaseurl}'/yum/\nprotect=1' | tee /etc/zypp/repos.d/wazuh.repo ${debug}"
            eval "chmod 644 /etc/zypp/repos.d/wazuh.repo ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "curl -s ${repogpg} --max-time 300 | apt-key add - ${debug}"
            eval "echo \"deb ${repobaseurl}/apt/ ${reporelease} main\" | tee /etc/apt/sources.list.d/wazuh.list ${debug}"
            eval "apt-get update -q ${debug}"
            eval "chmod 644 /etc/apt/sources.list.d/wazuh.list ${debug}"
        fi
    else
        common_logger -d "Wazuh repository already exists. Skipping addition."
    fi

    if [ -n "${development}" ]; then
        common_logger "Wazuh development repository added."
    else
        common_logger "Wazuh repository added."
    fi

}
function installCommon_aptInstall() {

    package="${1}"
    version="${2}"
    attempt=0
    if [ -n "${version}" ]; then
        installer=${package}${sep}${version}
    else
        installer=${package}
    fi
    command="DEBIAN_FRONTEND=noninteractive apt-get install ${installer} -y -q ${debug}"
    seconds=30
    eval "${command}"
    install_result="${PIPESTATUS[0]}"
    eval "tail -n 2 ${logfile} | grep -q 'Could not get lock'"
    grep_result="${PIPESTATUS[0]}"
    while [ "${grep_result}" -eq 0 ] && [ "${attempt}" -lt 10 ]; do
        attempt=$((attempt+1))
        common_logger "An external process is using APT. This process has to end to proceed with the Wazuh installation. Next retry in ${seconds} seconds (${attempt}/10)"
        sleep "${seconds}"
        eval "${command}"
        install_result="${PIPESTATUS[0]}"
        eval "tail -n 2 ${logfile} | grep -q 'Could not get lock'"
        grep_result="${PIPESTATUS[0]}"
    done

}
function installCommon_createCertificates() {

    if [ -n "${AIO}" ]; then
        eval "installCommon_getConfig certificate/config_aio.yml ${config_file} ${debug}"
    fi

    cert_readConfig

    if [ -d /tmp/wazuh-certificates/ ]; then
        eval "rm -rf /tmp/wazuh-certificates/ ${debug}"
    fi
    eval "mkdir /tmp/wazuh-certificates/ ${debug}"


    cert_generateRootCAcertificate
    cert_generateAdmincertificate
    cert_generateIndexercertificates
    cert_generateFilebeatcertificates
    cert_generateDashboardcertificates
    cert_cleanFiles
    eval "chmod 400 /tmp/wazuh-certificates/* ${debug}"
    eval "mv /tmp/wazuh-certificates/* /tmp/wazuh-install-files ${debug}"
    eval "rm -rf /tmp/wazuh-certificates/ ${debug}"

}
function installCommon_createClusterKey() {

    openssl rand -hex 16 >> "/tmp/wazuh-install-files/clusterkey"

}
function installCommon_createInstallFiles() {

    if [ -d /tmp/wazuh-install-files ]; then
        eval "rm -rf /tmp/wazuh-install-files ${debug}"
    fi

    if eval "mkdir /tmp/wazuh-install-files ${debug}"; then
        common_logger "Generating configuration files."
        if [ -n "${configurations}" ]; then
            cert_checkOpenSSL
        fi
        installCommon_createCertificates
        if [ -n "${server_node_types[*]}" ]; then
            installCommon_createClusterKey
        fi
        gen_file="/tmp/wazuh-install-files/passwords.wazuh"
        passwords_generatePasswordFile
        # Using cat instead of simple cp because OpenSUSE unknown error.
        eval "cat '${config_file}' > '/tmp/wazuh-install-files/config.yml'"
        eval "chown root:root /tmp/wazuh-install-files/*"
        eval "tar -zcf '${tar_file}' -C '/tmp/' wazuh-install-files/ ${debug}"
        eval "rm -rf '/tmp/wazuh-install-files' ${debug}"
        common_logger "Created ${tar_file_name}. It contains the Wazuh cluster key, certificates, and passwords necessary for installation."
    else
        common_logger -e "Unable to create /tmp/wazuh-install-files"
        exit 1
    fi
}
function installCommon_changePasswords() {

    common_logger -d "Setting Wazuh indexer cluster passwords."
    if [ -f "${tar_file}" ]; then
        eval "tar -xf ${tar_file} -C /tmp wazuh-install-files/passwords.wazuh ${debug}"
        p_file="/tmp/wazuh-install-files/passwords.wazuh"
        common_checkInstalled
        if [ -n "${start_indexer_cluster}" ] || [ -n "${AIO}" ]; then
            changeall=1
            passwords_readUsers
        fi
        installCommon_readPasswordFileUsers
    else
        common_logger -e "Cannot find passwords file. Exiting"
        exit 1
    fi
    if [ -n "${start_indexer_cluster}" ] || [ -n "${AIO}" ]; then
        passwords_getNetworkHost
        passwords_createBackUp
        passwords_generateHash
    fi

    passwords_changePassword

    if [ -n "${start_indexer_cluster}" ] || [ -n "${AIO}" ]; then
        passwords_runSecurityAdmin
    fi

}
function installCommon_extractConfig() {

    if ! $(tar -tf "${tar_file}" | grep -q wazuh-install-files/config.yml); then
        common_logger -e "There is no config.yml file in ${tar_file}."
        exit 1
    fi
    eval "tar -xf ${tar_file} -C /tmp wazuh-install-files/config.yml ${debug}"

}
function installCommon_getConfig() {

    if [ "$#" -ne 2 ]; then
        common_logger -e "installCommon_getConfig should be called with two arguments"
        exit 1
    fi

    config_name="config_file_$(eval "echo ${1} | sed 's|/|_|g;s|.yml||'")"
    if [ -z "$(eval "echo \${${config_name}}")" ]; then
        common_logger -e "Unable to find configuration file ${1}. Exiting."
        installCommon_rollBack
        exit 1
    fi
    eval "echo \"\${${config_name}}\"" > "${2}"
}
function installCommon_getPass() {

    for i in "${!users[@]}"; do
        if [ "${users[i]}" == "${1}" ]; then
            u_pass=${passwords[i]}
        fi
    done
}
function installCommon_installPrerequisites() {

    if [ "${sys_type}" == "yum" ]; then
        dependencies=( curl libcap tar gnupg openssl )
        not_installed=()
        for dep in "${dependencies[@]}"; do
            if [ -z "$(yum list installed 2>/dev/null | grep ${dep})" ];then
                not_installed+=("${dep}")
            fi
        done

        if [ "${#not_installed[@]}" -gt 0 ]; then
            common_logger "--- Dependencies ---"
            for dep in "${not_installed[@]}"; do
                common_logger "Installing $dep."
                eval "yum install ${dep} -y ${debug}"
                if [  "${PIPESTATUS[0]}" != 0  ]; then
                    common_logger -e "Cannot install dependency: ${dep}."
                    exit 1
                fi
            done
        fi

    elif [ "${sys_type}" == "apt-get" ]; then
        eval "apt update -q ${debug}"
        dependencies=( apt-transport-https curl libcap2-bin tar software-properties-common gnupg openssl )
        not_installed=()

        for dep in "${dependencies[@]}"; do
            if [ -z "$(apt list --installed 2>/dev/null | grep ${dep})" ];then
                not_installed+=("${dep}")
            fi
        done

        if [ "${#not_installed[@]}" -gt 0 ]; then
            common_logger "--- Dependencies ----"
            for dep in "${not_installed[@]}"; do
                common_logger "Installing $dep."
                installCommon_aptInstall ${dep}
                if [ "${install_result}" != 0 ]; then
                    common_logger -e "Cannot install dependency: ${dep}."
                    exit 1
                fi
            done
        fi
    fi

}
function installCommon_readPasswordFileUsers() {

    filecorrect=$(grep -Ev '^#|^\s*$' "${p_file}" | grep -Pzc "\A(\s*username:[ \t]+[\'\"]?\w+[\'\"]?\s*password:[ \t]+[\'\"]?[A-Za-z0-9.*+?]+[\'\"]?\s*)+\Z")
    if [[ "${filecorrect}" -ne 1 ]]; then
        common_logger -e "The password file doesn't have a correct format or password uses invalid characters. Allowed characters: A-Za-z0-9.*+?

# Description
  username: name
  password: password

# Wazuh indexer admin user
  username: kibanaserver
  password: NiwXQw82pIf0dToiwczduLBnUPEvg7T0

"
	    installCommon_rollBack
        exit 1
    fi

    sfileusers=$(grep username: "${p_file}" | awk '{ print substr( $2, 1, length($2) ) }' | sed -e "s/[\'\"]//g")
    sfilepasswords=$(grep password: "${p_file}" | awk '{ print substr( $2, 1, length($2) ) }' | sed -e "s/[\'\"]//g")

    fileusers=(${sfileusers})
    filepasswords=(${sfilepasswords})

    if [ -n "${changeall}" ]; then
        for j in "${!fileusers[@]}"; do
            supported=false
            for i in "${!users[@]}"; do
                if [[ ${users[i]} == "${fileusers[j]}" ]]; then
                    passwords[i]=${filepasswords[j]}
                    supported=true
                fi
            done
            if [ "${supported}" = false ] && [ -n "${indexer_installed}" ]; then
                common_logger -e -d "The given user ${fileusers[j]} does not exist"
            fi
        done
    else
        finalusers=()
        finalpasswords=()

        if [ -n "${dashboard_installed}" ] &&  [ -n "${dashboard}" ]; then
            users=( kibanaserver admin )
        fi

        if [ -n "${filebeat_installed}" ] && [ -n "${wazuh}" ]; then
            users=( admin )
        fi

        for j in "${!fileusers[@]}"; do
            supported=false
            for i in "${!users[@]}"; do
                if [[ "${users[i]}" == "${fileusers[j]}" ]]; then
                    finalusers+=(${fileusers[j]})
                    finalpasswords+=(${filepasswords[j]})
                    supported=true
                fi
            done
            if [ "${supported}" = "false" ] && [ -n "${indexer_installed}" ] && [ -n "${changeall}" ]; then
                common_logger -e -d "The given user ${fileusers[j]} does not exist"
            fi
        done

        users=()
        users=(${finalusers[@]})
        passwords=(${finalpasswords[@]})
        changeall=1
    fi

}
function installCommon_restoreWazuhrepo() {

    if [ -n "${development}" ]; then
        if [ "${sys_type}" == "yum" ] && [ -f "/etc/yum.repos.d/wazuh.repo" ]; then
            file="/etc/yum.repos.d/wazuh.repo"
        elif [ "${sys_type}" == "zypper" ] && [ -f "/etc/zypp/repos.d/wazuh.repo" ]; then
            file="/etc/zypp/repos.d/wazuh.repo"
        elif [ "${sys_type}" == "apt-get" ] && [ -f "/etc/apt/sources.list.d/wazuh.list" ]; then
            file="/etc/apt/sources.list.d/wazuh.list"
        else
            common_logger -w -d "Wazuh repository does not exists."
        fi
        eval "sed -i 's/-dev//g' ${file} ${debug}"
        eval "sed -i 's/pre-release/4.x/g' ${file} ${debug}"
        eval "sed -i 's/unstable/stable/g' ${file} ${debug}"
    fi

}
function installCommon_rollBack() {

    if [ -z "${uninstall}" ]; then
        common_logger "--- Removing existing Wazuh installation ---"
    fi

    if [ -f "/etc/yum.repos.d/wazuh.repo" ]; then
        eval "rm /etc/yum.repos.d/wazuh.repo"
    elif [ -f "/etc/zypp/repos.d/wazuh.repo" ]; then
        eval "rm /etc/zypp/repos.d/wazuh.repo"
    elif [ -f "/etc/apt/sources.list.d/wazuh.list" ]; then
        eval "rm /etc/apt/sources.list.d/wazuh.list"
    fi

    if [[ -n "${wazuh_installed}" && ( -n "${wazuh}" || -n "${AIO}" || -n "${uninstall}" ) ]];then
        common_logger "Removing Wazuh manager."
        if [ "${sys_type}" == "yum" ]; then
            eval "yum remove wazuh-manager -y ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "zypper -n remove wazuh-manager ${debug}"
            eval "rm -f /etc/init.d/wazuh-manager ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "apt remove --purge wazuh-manager -y ${debug}"
        fi
        common_logger "Wazuh manager removed."
    fi

    if [[ ( -n "${wazuh_remaining_files}"  || -n "${wazuh_installed}" ) && ( -n "${wazuh}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        eval "rm -rf /var/ossec/ ${debug}"
    fi

    if [[ -n "${indexer_installed}" && ( -n "${indexer}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        common_logger "Removing Wazuh indexer."
        if [ "${sys_type}" == "yum" ]; then
            eval "yum remove wazuh-indexer -y ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "zypper -n remove wazuh-indexer ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "apt remove --purge wazuh-indexer -y ${debug}"
        fi
        common_logger "Wazuh indexer removed."
    fi

    if [[ ( -n "${indexer_remaining_files}" || -n "${indexer_installed}" ) && ( -n "${indexer}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        eval "rm -rf /var/lib/wazuh-indexer/ ${debug}"
        eval "rm -rf /usr/share/wazuh-indexer/ ${debug}"
        eval "rm -rf /etc/wazuh-indexer/ ${debug}"
    fi

    if [[ -n "${filebeat_installed}" && ( -n "${wazuh}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        common_logger "Removing Filebeat."
        if [ "${sys_type}" == "yum" ]; then
            eval "yum remove filebeat -y ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "zypper -n remove filebeat ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "apt remove --purge filebeat -y ${debug}"
        fi
        common_logger "Filebeat removed."
    fi

    if [[ ( -n "${filebeat_remaining_files}" || -n "${filebeat_installed}" ) && ( -n "${wazuh}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        eval "rm -rf /var/lib/filebeat/ ${debug}"
        eval "rm -rf /usr/share/filebeat/ ${debug}"
        eval "rm -rf /etc/filebeat/ ${debug}"
    fi

    if [[ -n "${dashboard_installed}" && ( -n "${dashboard}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        common_logger "Removing Wazuh dashboard."
        if [ "${sys_type}" == "yum" ]; then
            eval "yum remove wazuh-dashboard -y ${debug}"
        elif [ "${sys_type}" == "zypper" ]; then
            eval "zypper -n remove wazuh-dashboard ${debug}"
        elif [ "${sys_type}" == "apt-get" ]; then
            eval "apt remove --purge wazuh-dashboard -y ${debug}"
        fi
        common_logger "Wazuh dashboard removed."
    fi

    if [[ ( -n "${dashboard_remaining_files}" || -n "${dashboard_installed}" ) && ( -n "${dashboard}" || -n "${AIO}" || -n "${uninstall}" ) ]]; then
        eval "rm -rf /var/lib/wazuh-dashboard/ ${debug}"
        eval "rm -rf /usr/share/wazuh-dashboard/ ${debug}"
        eval "rm -rf /etc/wazuh-dashboard/ ${debug}"
        eval "rm -rf /run/wazuh-dashboard/ ${debug}"
    fi

    elements_to_remove=(    "/var/log/wazuh-indexer/"
                            "/var/log/filebeat/"
                            "/etc/systemd/system/opensearch.service.wants/"
                            "/securityadmin_demo.sh"
                            "/etc/systemd/system/multi-user.target.wants/wazuh-manager.service"
                            "/etc/systemd/system/multi-user.target.wants/filebeat.service"
                            "/etc/systemd/system/multi-user.target.wants/opensearch.service"
                            "/etc/systemd/system/multi-user.target.wants/wazuh-dashboard.service"
                            "/etc/systemd/system/wazuh-dashboard.service"
                            "/lib/firewalld/services/dashboard.xml"
                            "/lib/firewalld/services/opensearch.xml" )

    eval "rm -rf ${elements_to_remove[*]}"

    if [ -z "${uninstall}" ]; then
        if [ -n "${rollback_conf}" ] || [ -n "${overwrite}" ]; then
            common_logger "Installation cleaned."
        else
            common_logger "Installation cleaned. Check the ${logfile} file to learn more about the issue."
        fi
    fi

}
function installCommon_startService() {

    if [ "$#" -ne 1 ]; then
        common_logger -e "installCommon_startService must be called with 1 argument."
        exit 1
    fi

    common_logger "Starting service ${1}."

    if ps -e | grep -E -q "^\ *1\ .*systemd$"; then
        eval "systemctl daemon-reload ${debug}"
        eval "systemctl enable ${1}.service ${debug}"
        eval "systemctl start ${1}.service ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -xe -u ${1} >> ${logfile}"
            fi
            installCommon_rollBack
            exit 1
        else
            common_logger "${1} service started."
        fi
    elif ps -e | grep -E -q "^\ *1\ .*init$"; then
        eval "chkconfig ${1} on ${debug}"
        eval "service ${1} start ${debug}"
        eval "/etc/init.d/${1} start ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -u ${1} >> ${logfile}"
            fi
            installCommon_rollBack
            exit 1
        else
            common_logger "${1} service started."
        fi
    elif [ -x "/etc/rc.d/init.d/${1}" ] ; then
        eval "/etc/rc.d/init.d/${1} start ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -u ${1} >> ${logfile}"
            fi
            installCommon_rollBack
            exit 1
        else
            common_logger "${1} service started."
        fi
    else
        common_logger -e "${1} could not start. No service manager found on the system."
        exit 1
    fi

}
# ------------ manager.sh ------------ 
function manager_startCluster() {

    for i in "${!server_node_names[@]}"; do
        if [[ "${server_node_names[i]}" == "${winame}" ]]; then
            pos="${i}";
        fi
    done

    for i in "${!server_node_types[@]}"; do
        if [[ "${server_node_types[i],,}" == "master" ]]; then
            master_address=${server_node_ips[i]}
        fi
    done

    key=$(tar -axf "${tar_file}" wazuh-install-files/clusterkey -O)
    bind_address="0.0.0.0"
    port="1516"
    hidden="no"
    disabled="no"
    lstart=$(grep -n "<cluster>" /var/ossec/etc/ossec.conf | cut -d : -f 1)
    lend=$(grep -n "</cluster>" /var/ossec/etc/ossec.conf | cut -d : -f 1)

    eval 'sed -i -e "${lstart},${lend}s/<name>.*<\/name>/<name>wazuh_cluster<\/name>/" \
        -e "${lstart},${lend}s/<node_name>.*<\/node_name>/<node_name>${winame}<\/node_name>/" \
        -e "${lstart},${lend}s/<node_type>.*<\/node_type>/<node_type>${server_node_types[pos],,}<\/node_type>/" \
        -e "${lstart},${lend}s/<key>.*<\/key>/<key>${key}<\/key>/" \
        -e "${lstart},${lend}s/<port>.*<\/port>/<port>${port}<\/port>/" \
        -e "${lstart},${lend}s/<bind_addr>.*<\/bind_addr>/<bind_addr>${bind_address}<\/bind_addr>/" \
        -e "${lstart},${lend}s/<node>.*<\/node>/<node>${master_address}<\/node>/" \
        -e "${lstart},${lend}s/<hidden>.*<\/hidden>/<hidden>${hidden}<\/hidden>/" \
        -e "${lstart},${lend}s/<disabled>.*<\/disabled>/<disabled>${disabled}<\/disabled>/" \
        /var/ossec/etc/ossec.conf'

}
function manager_install() {

    common_logger "Starting the Wazuh manager installation."
    if [ "${sys_type}" == "zypper" ]; then
        eval "${sys_type} -n install wazuh-manager=${wazuh_version}-${wazuh_revision_rpm} ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "yum" ]; then
        eval "${sys_type} install wazuh-manager${sep}${wazuh_version}-${wazuh_revision_rpm} -y ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "apt-get" ]; then
        installCommon_aptInstall "wazuh-manager" "${wazuh_version}-${wazuh_revision_deb}"
    fi
    
    common_checkInstalled
    if [  "$install_result" != 0  ] || [ -z "${wazuh_installed}" ]; then
        common_logger -e "Wazuh installation failed."
        installCommon_rollBack
        exit 1
    else
        common_logger "Wazuh manager installation finished."
    fi
}

# ------------ filebeat.sh ------------ 
function filebeat_configure(){

    eval "curl -so /etc/filebeat/wazuh-template.json ${filebeat_wazuh_template} --max-time 300 ${debug}"
    eval "chmod go+r /etc/filebeat/wazuh-template.json ${debug}"
    eval "curl -s ${filebeat_wazuh_module} --max-time 300 | tar -xvz -C /usr/share/filebeat/module ${debug}"
    if [ -n "${AIO}" ]; then
        eval "installCommon_getConfig filebeat/filebeat_unattended.yml /etc/filebeat/filebeat.yml ${debug}"
    else
        eval "installCommon_getConfig filebeat/filebeat_distributed.yml /etc/filebeat/filebeat.yml ${debug}"
        if [ ${#indexer_node_names[@]} -eq 1 ]; then
            echo -e "\noutput.elasticsearch.hosts:" >> /etc/filebeat/filebeat.yml
            echo "  - ${indexer_node_ips[0]}:9200" >> /etc/filebeat/filebeat.yml
        else
            echo -e "\noutput.elasticsearch.hosts:" >> /etc/filebeat/filebeat.yml
            for i in "${indexer_node_ips[@]}"; do
                echo "  - ${i}:9200" >> /etc/filebeat/filebeat.yml
            done
        fi
    fi

    eval "mkdir /etc/filebeat/certs ${debug}"
    filebeat_copyCertificates

    eval "filebeat keystore create ${debug}"
    eval "echo admin | filebeat keystore add username --force --stdin ${debug}"
    eval "echo admin | filebeat keystore add password --force --stdin ${debug}"

    common_logger "Filebeat post-install configuration finished."
}
function filebeat_copyCertificates() {

    if [ -f "${tar_file}" ]; then
        if [ -n "${AIO}" ]; then
            if [ -z "$(tar -tvf ${tar_file} | grep ${server_node_names[0]})" ]; then
                common_logger -e "Tar file does not contain certificate for the node ${server_node_names[0]}."
                installCommon_rollBack
                exit 1;
            fi
            eval "sed -i s/filebeat.pem/${server_node_names[0]}.pem/ /etc/filebeat/filebeat.yml ${debug}"
            eval "sed -i s/filebeat-key.pem/${server_node_names[0]}-key.pem/ /etc/filebeat/filebeat.yml ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} --wildcards wazuh-install-files/${server_node_names[0]}.pem --strip-components 1 ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} --wildcards wazuh-install-files/${server_node_names[0]}-key.pem --strip-components 1 ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} wazuh-install-files/root-ca.pem --strip-components 1 ${debug}"
            eval "rm -rf ${filebeat_cert_path}/wazuh-install-files/ ${debug}"
        else
            if [ -z "$(tar -tvf ${tar_file} | grep ${winame})" ]; then
                common_logger -e "Tar file does not contain certificate for the node ${winame}."
                installCommon_rollBack
                exit 1;
            fi
            eval "sed -i s/filebeat.pem/${winame}.pem/ /etc/filebeat/filebeat.yml ${debug}"
            eval "sed -i s/filebeat-key.pem/${winame}-key.pem/ /etc/filebeat/filebeat.yml ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} wazuh-install-files/${winame}.pem --strip-components 1 ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} wazuh-install-files/${winame}-key.pem --strip-components 1 ${debug}"
            eval "tar -xf ${tar_file} -C ${filebeat_cert_path} wazuh-install-files/root-ca.pem --strip-components 1 ${debug}"
            eval "rm -rf ${filebeat_cert_path}/wazuh-install-files/ ${debug}"
        fi
        eval "chmod 500 ${filebeat_cert_path} ${debug}"
        eval "chmod 400 ${filebeat_cert_path}/* ${debug}"
        eval "chown root:root ${filebeat_cert_path}/* ${debug}"
    else
        common_logger -e "No certificates found. Could not initialize Filebeat"
        exit 1;
    fi

}
function filebeat_install() {

    common_logger "Starting Filebeat installation."
    if [ "${sys_type}" == "zypper" ]; then
        eval "zypper -n install filebeat-${filebeat_version} ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "yum" ]; then
        eval "yum install filebeat${sep}${filebeat_version} -y -q  ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "apt-get" ]; then
        installCommon_aptInstall "filebeat" "${filebeat_version}"
    fi

    install_result="${PIPESTATUS[0]}"
    common_checkInstalled
    if [  "$install_result" != 0  ] || [ -z "${filebeat_installed}" ]; then
        common_logger -e "Filebeat installation failed."
        exit 1
    else
        common_logger "Filebeat installation finished."
    fi

}

# ------------ checks.sh ------------ 
function checks_arch() {

    arch=$(uname -m)

    if [ "${arch}" != "x86_64" ]; then
        common_logger -e "Uncompatible system. This script must be run on a 64-bit system."
        exit 1
    fi
}
function checks_arguments() {

    # -------------- Configurations ---------------------------------

    if [ -f "${tar_file}" ]; then
        if [ -n "${AIO}" ]; then
            rm -f "${tar_file}"
        fi
        if [ -n "${configurations}" ]; then
            common_logger -e "File ${tar_file} already exists. Please remove it if you want to use a new configuration."
            exit 1
        fi
    fi

    if [[ -n "${configurations}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboard}" || -n "${wazuh}" || -n "${overwrite}" || -n "${start_indexer_cluster}" || -n "${tar_conf}" || -n "${uninstall}" ) ]]; then
        common_logger -e "The argument -g|--generate-config-files can't be used with -a|--all-in-one, -o|--overwrite, -s|--start-cluster, -t|--tar, -u|--uninstall, -wd|--wazuh-dashboard, -wi|--wazuh-indexer, or -ws|--wazuh-server."
        exit 1
    fi

    # -------------- Overwrite --------------------------------------

    if [ -n "${overwrite}" ] && [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboard}" ] && [ -z "${wazuh}" ]; then 
        common_logger -e "The argument -o|--overwrite must be used in conjunction with -a|--all-in-one, -wd|--wazuh-dashboard, -wi|--wazuh-indexer, or -ws|--wazuh-server."
        exit 1
    fi

    # -------------- Uninstall --------------------------------------

    if [ -n "${uninstall}" ]; then

        if [ -n "$AIO" ] || [ -n "$indexer" ] || [ -n "$dashboard" ] || [ -n "$wazuh" ]; then
            common_logger -e "It is not possible to uninstall and install in the same operation. If you want to overwrite the components use -o|--overwrite."
            exit 1
        fi

        if [ -z "${wazuh_installed}" ] && [ -z "${wazuh_remaining_files}" ]; then
            common_logger "Wazuh manager not found in the system so it was not uninstalled."
        fi

        if [ -z "${filebeat_installed}" ] && [ -z "${filebeat_remaining_files}" ]; then
            common_logger "Filebeat not found in the system so it was not uninstalled."
        fi

        if [ -z "${indexer_installed}" ] && [ -z "${indexer_remaining_files}" ]; then
            common_logger "Wazuh indexer not found in the system so it was not uninstalled."
        fi

        if [ -z "${dashboard_installed}" ] && [ -z "${dashboard_remaining_files}" ]; then
            common_logger "Wazuh dashboard not found in the system so it was not uninstalled."
        fi

    fi

    # -------------- All-In-One -------------------------------------

    if [ -n "${AIO}" ]; then

        if [ -n "$indexer" ] || [ -n "$dashboard" ] || [ -n "$wazuh" ]; then
            common_logger -e "Argument -a|--all-in-one is not compatible with -wi|--wazuh-indexer, -wd|--wazuh-dashboard or -ws|--wazuh-server."
            exit 1
        fi

        if [ -n "${overwrite}" ]; then
            installCommon_rollBack
        fi

        if [ -z "${overwrite}" ] && ([ -n "${wazuh_installed}" ] || [ -n "${wazuh_remaining_files}" ]); then
            common_logger -e "Wazuh manager already installed."
            installedComponent=1
        fi
        if [ -z "${overwrite}" ] && ([ -n "${indexer_installed}" ] || [ -n "${indexer_remaining_files}" ]);then 
            common_logger -e "Wazuh indexer already installed."
            installedComponent=1
        fi
        if [ -z "${overwrite}" ] && ([ -n "${dashboard_installed}" ] || [ -n "${dashboard_remaining_files}" ]); then
            common_logger -e "Wazuh dashboard already installed."
            installedComponent=1
        fi
        if [ -z "${overwrite}" ] && ([ -n "${filebeat_installed}" ] || [ -n "${filebeat_remaining_files}" ]); then
            common_logger -e "Filebeat already installed."
            installedComponent=1
        fi
        if [ -n "${installedComponent}" ]; then
            common_logger "If you want to overwrite the current installation, run this script adding the option -o/--overwrite. This will erase all the existing configuration and data."
            exit 1
        fi

    fi

    # -------------- Indexer ----------------------------------

    if [ -n "${indexer}" ]; then

        if [ -n "${indexer_installed}" ] || [ -n "${indexer_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh indexer is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Wazuh dashboard --------------------------------

    if [ -n "${dashboard}" ]; then
        if [ -n "${dashboard_installed}" ] || [ -n "${dashboard_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh dashboard is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Wazuh ------------------------------------------

    if [ -n "${wazuh}" ]; then
        if [ -n "${wazuh_installed}" ] || [ -n "${wazuh_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi

        if [ -n "${filebeat_installed}" ] || [ -n "${filebeat_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Filebeat is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Cluster start ----------------------------------

    if [[ -n "${start_indexer_cluster}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboard}" || -n "${wazuh}" || -n "${overwrite}" || -n "${configurations}" || -n "${tar_conf}" || -n "${uninstall}") ]]; then
        common_logger -e "The argument -s|--start-cluster can't be used with -a|--all-in-one, -g|--generate-config-files,-o|--overwrite , -u|--uninstall, -wi|--wazuh-indexer, -wd|--wazuh-dashboard, -s|--start-cluster, -ws|--wazuh-server."
        exit 1
    fi

    # -------------- Global -----------------------------------------

    if [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboard}" ] && [ -z "${wazuh}" ] && [ -z "${start_indexer_cluster}" ] && [ -z "${configurations}" ] && [ -z "${uninstall}" ] && [ -z "${download}" ]; then
        common_logger -e "At least one of these arguments is necessary -a|--all-in-one, -g|--generate-config-files, -wi|--wazuh-indexer, -wd|--wazuh-dashboard, -s|--start-cluster, -ws|--wazuh-server, -u|--uninstall, -dw|--download-wazuh."
        exit 1
    fi

    if [ -n "${force}" ] && [ -z  "${dashboard}" ]; then
        common_logger -e "The -fd|--force-install-dashboard argument needs to be used alongside -wd|--wazuh-dashboard."
        exit 1
    fi 

}
function check_dist() {
    dist_detect
    if [ "${DIST_NAME}" != "centos" ] && [ "${DIST_NAME}" != "rhel" ] && [ "${DIST_NAME}" != "amzn" ] && [ "${DIST_NAME}" != "ubuntu" ]; then
        notsupported=1
    fi
    if ([ "${DIST_NAME}" == "centos" ] || [ "${DIST_NAME}" == "rhel" ]) && ([ "${DIST_VER}" -ne "7" ] && [ "${DIST_VER}" -ne "8" ]); then
        notsupported=1
    fi
    if ([ "${DIST_NAME}" == "amzn" ]) && ([ "${DIST_VER}" -ne "2" ]); then
        notsupported=1
    fi
    if ([ "${DIST_NAME}" == "ubuntu" ]) && ([ "${DIST_VER}" -ne "16" ] && [ "${DIST_VER}" -ne "18" ] && [ "${DIST_VER}" -ne "20" ] && [ "${DIST_VER}" -ne "22" ]); then
        notsupported=1
    fi
    if ([ "${DIST_NAME}" == "ubuntu" ]) && ([ "${DIST_VER}" -eq "16" ] || [ "${DIST_VER}" -eq "18" ] || [ "${DIST_VER}" -eq "20" ] || [ "${DIST_VER}" -eq "22" ]) &&  ([ "${DIST_SUBVER}" != "04" ]); then
        notsupported=1
    fi
    if [ -n "${notsupported}" ] && [ -z "${ignore}" ]; then
        common_logger -e "The recommended systems are: Red Hat Enterprise Linux 7, 8; CentOS 7, 8; Amazon Linux 2; Ubuntu 16.04, 18.04, 20.04, 22.04. The current system doesn't match this list. Use -i|--ignore-check to skip this check."
        exit 1
    fi
}
function checks_health() {

    logger "Verifying that your system meets the recommended minimum hardware requirements."
    
    checks_specifications

    if [ -n "${indexer}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        fi
    fi

    if [ -n "${dashboard}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        fi
    fi

    if [ -n "${wazuh}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 1700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 2Gb of RAM and 2 CPU cores . If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        fi
    fi

    if [ -n "${AIO}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        fi
    fi

}
function checks_names() {

    if [ -n "${indxname}" ] && [ -n "${dashname}" ] && [ "${indxname}" == "${dashname}" ]; then
        common_logger -e "The node names for Wazuh indexer and Wazuh dashboard must be different."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -n "${winame}" ] && [ "${indxname}" == "${winame}" ]; then
        common_logger -e "The node names for Elastisearch and Wazuh must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -n "${dashname}" ] && [ "${winame}" == "${dashname}" ]; then
        common_logger -e "The node names for Wazuh server and Wazuh indexer must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -z "$(echo "${server_node_names[@]}" | grep -w "${winame}")" ]; then
        common_logger -e "The Wazuh server node name ${winame} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -z "$(echo "${indexer_node_names[@]}" | grep -w "${indxname}")" ]; then
        common_logger -e "The Wazuh indexer node name ${indxname} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${dashname}" ] && [ -z "$(echo "${dashboard_node_names[@]}" | grep -w "${dashname}")" ]; then
        common_logger -e "The Wazuh dashboard node name ${dashname} does not appear on the configuration file."
        exit 1
    fi

    if [[ "${dashname}" == -* ]] || [[ "${indxname}" == -* ]] || [[ "${winame}" == -* ]]; then
        common_logger -e "Node name cannot start with \"-\""
        exit 1
    fi

}
function checks_previousCertificate() {
    if [ ! -f "${tar_file}" ]; then
        common_logger -e "Cannot find ${tar_file}. Run the script with the option -g|--generate-config-files to create it or copy it from another node."
        exit 1
    fi

    if [ -n "${indxname}" ]; then
        if [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${indxname}.pem)" ] || [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${indxname}-key.pem)" ]; then
            common_logger -e "There is no certificate for the indexer node ${indxname} in ${tar_file}."
            exit 1
        fi
    fi

    if [ -n "${dashname}" ]; then
        if [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${dashname}.pem)" ] || [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${dashname}-key.pem)" ]; then
            common_logger -e "There is no certificate for the Wazuh dashboard node ${dashname} in ${tar_file}."
            exit 1
        fi
    fi

    if [ -n "${winame}" ]; then
        if [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${winame}.pem)" ] || [ -z "$(tar -tf ${tar_file} | egrep ^wazuh-install-files/${winame}-key.pem)" ]; then
            common_logger -e "There is no certificate for the wazuh server node ${winame} in ${tar_file}."
            exit 1
        fi
    fi
}
function checks_specifications() {

    cores=$(cat /proc/cpuinfo | grep -c processor )
    ram_gb=$(free -m | awk '/^Mem:/{print $2}')

}
# ------------ dashboard.sh ------------ 
function dashboard_configure() {

    if [ -n "${AIO}" ]; then
        eval "installCommon_getConfig dashboard/dashboard_unattended.yml /etc/wazuh-dashboard/opensearch_dashboards.yml ${debug}"
        dashboard_copyCertificates
    else
        eval "installCommon_getConfig dashboard/dashboard_unattended_distributed.yml /etc/wazuh-dashboard/opensearch_dashboards.yml ${debug}"
        dashboard_copyCertificates
        if [ "${#dashboard_node_names[@]}" -eq 1 ]; then
            pos=0
            ip=${dashboard_node_ips[0]}
        else
            for i in "${!dashboard_node_names[@]}"; do
                if [[ "${dashboard_node_names[i]}" == "${dashname}" ]]; then
                    pos="${i}";
                fi
            done
            ip=${dashboard_node_ips[pos]}
        fi

        echo 'server.host: "'${ip}'"' >> /etc/wazuh-dashboard/opensearch_dashboards.yml

        if [ "${#indexer_node_names[@]}" -eq 1 ]; then
            echo "opensearch.hosts: https://"${indexer_node_ips[0]}":9200" >> /etc/wazuh-dashboard/opensearch_dashboards.yml
        else
            echo "opensearch.hosts:" >> /etc/wazuh-dashboard/opensearch_dashboards.yml
            for i in "${indexer_node_ips[@]}"; do
                    echo "  - https://${i}:9200" >> /etc/wazuh-dashboard/opensearch_dashboards.yml
            done
        fi
    fi

    common_logger "Wazuh dashboard post-install configuration finished."

}
function dashboard_copyCertificates() {

    eval "rm -f ${dashboard_cert_path}/* ${debug}"
    name=${dashboard_node_names[pos]}

    if [ -f "${tar_file}" ]; then
        if [ -z "$(tar -tvf ${tar_file} | grep ${name})" ]; then
            common_logger -e "Tar file does not contain certificate for the node ${name}."
            installCommon_rollBack
            exit 1;
        fi
        eval "mkdir ${dashboard_cert_path} ${debug}"
        eval "sed -i s/dashboard.pem/${name}.pem/ /etc/wazuh-dashboard/opensearch_dashboards.yml ${debug}"
        eval "sed -i s/dashboard-key.pem/${name}-key.pem/ /etc/wazuh-dashboard/opensearch_dashboards.yml ${debug}"
        eval "tar -xf ${tar_file} -C ${dashboard_cert_path} wazuh-install-files/${name}.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${dashboard_cert_path} wazuh-install-files/${name}-key.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${dashboard_cert_path} wazuh-install-files/root-ca.pem --strip-components 1 ${debug}"
        eval "chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/ ${debug}"
        eval "chmod 500 ${dashboard_cert_path} ${debug}"
        eval "chmod 400 ${dashboard_cert_path}/* ${debug}"
        eval "chown wazuh-dashboard:wazuh-dashboard ${dashboard_cert_path}/* ${debug}"
        common_logger -d "Wazuh dashboard certificate setup finished."
    else
        common_logger -e "No certificates found. Wazuh dashboard  could not be initialized."
        exit 1
    fi

}
function dashboard_initialize() {

    common_logger "Initializing Wazuh dashboard web application."
    installCommon_getPass "admin"
    j=0

    if [ "${#dashboard_node_names[@]}" -eq 1 ]; then
        nodes_dashboard_ip=${dashboard_node_ips[0]}
    else
        for i in "${!dashboard_node_names[@]}"; do
            if [[ "${dashboard_node_names[i]}" == "${dashname}" ]]; then
                pos="${i}";
            fi
        done
        nodes_dashboard_ip=${dashboard_node_ips[pos]}
    fi

    if [ "${nodes_dashboard_ip}" == "localhost" ] || [[ "${nodes_dashboard_ip}" == 127.* ]]; then
        print_ip="<wazuh-dashboard-ip>"
    else
        print_ip="${nodes_dashboard_ip}"
    fi

    until [ "$(curl -XGET https://${nodes_dashboard_ip}/status -uadmin:${u_pass} -k -w %{http_code} -s -o /dev/null)" -eq "200" ] || [ "${j}" -eq "12" ]; do
        sleep 10
        j=$((j+1))
    done

    if [ ${j} -lt 12 ]; then
        if [ "${#server_node_names[@]}" -eq 1 ]; then
            wazuh_api_address=${server_node_ips[0]}
        else
            for i in "${!server_node_types[@]}"; do
                if [[ "${server_node_types[i]}" == "master" ]]; then
                    wazuh_api_address=${server_node_ips[i]}
                fi
            done
        fi
        if [ -f "/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml" ]; then
            eval "sed -i 's,url: https://localhost,url: https://${wazuh_api_address},g' /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml ${debug}"
        fi

        common_logger "Wazuh dashboard web application initialized."
        common_logger -nl "--- Summary ---"
        common_logger -nl "You can access the web interface https://${print_ip}\n    User: admin\n    Password: ${u_pass}"

    elif [ ${j} -eq 12 ]; then
        flag="-w"
        if [ -z "${force}" ]; then
            flag="-e"
        fi
        failed_nodes=()
        common_logger "${flag}" "Cannot connect to Wazuh dashboard."

        for i in "${!indexer_node_ips[@]}"; do
            curl=$(curl -XGET https://${indexer_node_ips[i]}:9200/ -uadmin:${u_pass} -k -s)
            exit_code=${PIPESTATUS[0]}
            if [[ "${exit_code}" -eq "7" ]]; then
                failed_connect=1
                failed_nodes+=("${indexer_node_names[i]}")
            fi
            if [ "${curl}" == "OpenSearch Security not initialized." ]; then
                sec_not_initialized=1
            fi
        done
        if [ -n "${failed_connect}" ]; then
            common_logger "${flag}" "Failed to connect with ${failed_nodes[*]}. Connection refused."
        fi

        if [ -n "${sec_not_initialized}" ]; then
            common_logger "${flag}" "Wazuh indexer security settings not initialized. Please run the installation assistant using -s|--start-cluster in one of the wazuh indexer nodes."
        fi

        if [ -z "${force}" ]; then
            common_logger "If you want to install Wazuh dashboard without waiting for the Wazuh indexer cluster, use the -fd option"
            installCommon_rollBack
            exit 1
        else
            common_logger -nl "--- Summary ---"
            common_logger -nl "When Wazuh dashboard is able to connect to your Wazuh indexer cluster, you can access the web interface https://${print_ip}\n    User: admin\n    Password: ${u_pass}"
        fi
    fi

    passwords_updateDashboard_WUI_Password

}
function dashboard_initializeAIO() {

    common_logger "Initializing Wazuh dashboard web application."
    installCommon_getPass "admin"
    until [ "$(curl -XGET https://localhost/status -uadmin:${u_pass} -k -w %{http_code} -s -o /dev/null)" -eq "200" ] || [ "${i}" -eq 12 ]; do
        sleep 10
        i=$((i+1))
    done
    if [ ${i} -eq 12 ]; then
        common_logger -e "Cannot connect to Wazuh dashboard."
        installCommon_rollBack
        exit 1
    fi

    passwords_updateDashboard_WUI_Password

    common_logger "Wazuh dashboard web application initialized."
    common_logger -nl "--- Summary ---"
    common_logger -nl "You can access the web interface https://<wazuh-dashboard-ip>\n    User: admin\n    Password: ${u_pass}"
}
function dashboard_install() {

    common_logger "Starting Wazuh dashboard installation."
    if [ "${sys_type}" == "zypper" ]; then
        eval "zypper -n install wazuh-dashboard=${wazuh_version}-${dashboard_revision_rpm} ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "yum" ]; then
        eval "yum install wazuh-dashboard${sep}${wazuh_version}-${dashboard_revision_rpm} -y ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "apt-get" ]; then
        installCommon_aptInstall "wazuh-dashboard" "${wazuh_version}-${dashboard_revision_deb}"
    fi
    common_checkInstalled
    if [  "$install_result" != 0  ] || [ -z "${dashboard_installed}" ]; then
        common_logger -e "Wazuh dashboard installation failed."
        installCommon_rollBack
        exit 1
    else
        common_logger "Wazuh dashboard installation finished."
    fi

}

# ------------ installMain.sh ------------ 
function getHelp() {

    echo -e ""
    echo -e "NAME"
    echo -e "        $(basename "$0") - Install and configure Wazuh central components: Wazuh server, Wazuh indexer, and Wazuh dashboard."
    echo -e ""
    echo -e "SYNOPSIS"
    echo -e "        $(basename "$0") [OPTIONS] -a | -c | -s | -wi <indexer-node-name> | -wd <dashboard-node-name> | -ws <server-node-name>"
    echo -e ""
    echo -e "DESCRIPTION"
    echo -e "        -a,  --all-in-one"
    echo -e "                Install and configure Wazuh server, Wazuh indexer, Wazuh dashboard."
    echo -e ""
    echo -e "        -c,  --config-file <path-to-config-yml>"
    echo -e "                Path to the configuration file used to generate wazuh-install-files.tar file containing the files that will be needed for installation. By default, the Wazuh installation assistant will search for a file named config.yml in the same path as the script."
    echo -e ""
    echo -e "        -fd,  --force-install-dashboard"
    echo -e "                Force Wazuh dashboard installation to continue even when it is not capable of connecting to the Wazuh indexer."
    echo -e ""
    echo -e "        -g,  --generate-config-files"
    echo -e "                Generate wazuh-install-files.tar file containing the files that will be needed for installation from config.yml. In distributed deployments you will need to copy this file to all hosts."
    echo -e ""
    echo -e "        -h,  --help"
    echo -e "                Display this help and exit."
    echo -e ""
    echo -e "        -i,  --ignore-check"
    echo -e "                Ignore the check for system compatibility and minimum hardware requirements."
    echo -e ""
    echo -e "        -o,  --overwrite"
    echo -e "                Overwrites previously installed components. This will erase all the existing configuration and data."
    echo -e ""
    echo -e "        -s,  --start-cluster"
    echo -e "                Initialize Wazuh indexer cluster security settings."
    echo -e ""
    echo -e "        -t,  --tar <path-to-certs-tar>"
    echo -e "                Path to tar file containing certificate files. By default, the Wazuh installation assistant will search for a file named wazuh-install-files.tar in the same path as the script."
    echo -e ""
    echo -e "        -u,  --uninstall"
    echo -e "                Uninstalls all Wazuh components. This will erase all the existing configuration and data."
    echo -e ""
    echo -e "        -v,  --verbose"
    echo -e "                Shows the complete installation output."
    echo -e ""
    echo -e "        -V,  --version"
    echo -e "                Shows the version of the script and Wazuh packages."
    echo -e ""
    echo -e "        -wd,  --wazuh-dashboard <dashboard-node-name>"
    echo -e "                Install and configure Wazuh dashboard, used for distributed deployments."
    echo -e ""
    echo -e "        -wi,  --wazuh-indexer <indexer-node-name>"
    echo -e "                Install and configure Wazuh indexer, used for distributed deployments."
    echo -e ""
    echo -e "        -ws,  --wazuh-server <server-node-name>"
    echo -e "                Install and configure Wazuh manager and Filebeat, used for distributed deployments."
    echo -e ""
    echo -e "        -dw,  --download-wazuh <deb|rpm>"
    echo -e "                Download all the packages necessary for offline installation."
    exit 1

}
function main() {
    umask 177

    if [ -z "${1}" ]; then
        getHelp
    fi

    while [ -n "${1}" ]
    do
        case "${1}" in
            "-a"|"--all-in-one")
                AIO=1
                shift 1
                ;;
            "-c"|"--config-file")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-config-yml> after -c|--config-file"
                    getHelp
                    exit 1
                fi
                file_conf=1
                config_file="${2}"
                shift 2
                ;;
            "-fd"|"--force-install-dashboard")
                force=1
                shift 1
                ;;
            "-g"|"--generate-config-files")
                configurations=1
                shift 1
                ;;
            "-h"|"--help")
                getHelp
                ;;
            "-i"|"--ignore-check")
                ignore=1
                shift 1
                ;;
            "-o"|"--overwrite")
                overwrite=1
                shift 1
                ;;
            "-s"|"--start-cluster")
                start_indexer_cluster=1
                shift 1
                ;;
            "-t"|"--tar")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-certs-tar> after -t|--tar"
                    getHelp
                    exit 1
                fi
                tar_conf=1
                tar_file="${2}"
                shift 2
                ;;
            "-u"|"--uninstall")
                uninstall=1
                shift 1
                ;;
            "-v"|"--verbose")
                debugEnabled=1
                debug="2>&1 | tee -a ${logfile}"
                shift 1
                ;;
            "-V"|"--version")
                showVersion=1
                shift 1
                ;;
            "-wd"|"--wazuh-dashboard")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -wd|---wazuh-dashboard"
                    getHelp
                    exit 1
                fi
                dashboard=1
                dashname="${2}"
                shift 2
                ;;
            "-wi"|"--wazuh-indexer")
                if [ -z "${2}" ]; then
                    common_logger -e "Arguments contain errors. Probably missing <node-name> after -wi|--wazuh-indexer."
                    getHelp
                    exit 1
                fi
                indexer=1
                indxname="${2}"
                shift 2
                ;;
            "-ws"|"--wazuh-server")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -ws|--wazuh-server"
                    getHelp
                    exit 1
                fi
                wazuh=1
                winame="${2}"
                shift 2
                ;;
            "-dw"|"--download-wazuh")
                if [ "${2}" != "deb" ] && [ "${2}" != "rpm" ]; then
                    common_logger -e "Error on arguments. Probably missing <deb|rpm> after -dw|--download-wazuh"
                    getHelp
                    exit 1
                fi
                download=1
                package_type="${2}"
                shift 2
                ;;
            *)
                echo "Unknow option: "${1}""
                getHelp
        esac
    done

    cat /dev/null > "${logfile}"

    if [ -z "${download}" ] && [ -z "${showVersion}" ]; then
        common_checkRoot
    fi

    if [ -n "${showVersion}" ]; then
        common_logger "Wazuh version: ${wazuh_version}"
        common_logger "Filebeat version: ${filebeat_version}"
        common_logger "Wazuh installation assistant version: ${wazuh_install_vesion}"
        exit 0
    fi

    common_logger "Starting Wazuh installation assistant. Wazuh version: ${wazuh_version}"
    common_logger "Verbose logging redirected to ${logfile}"

# -------------- Uninstall case  ------------------------------------

    check_dist
    common_checkSystem
    common_checkInstalled
    checks_arguments
    if [ -n "${uninstall}" ]; then
        installCommon_rollBack
        exit 0
    fi

# -------------- Preliminary checks  --------------------------------

    if [ -z "${configurations}" ] && [ -z "${AIO}" ] && [ -z "${download}" ]; then
        checks_previousCertificate
    fi
    checks_arch
    if [ -n "${ignore}" ]; then
        common_logger -w "Hardware and system checks ignored."
    else
        checks_health
    fi
    if [ -n "${AIO}" ] ; then
        rm -f "${tar_file}"
    fi

# -------------- Prerequisites and Wazuh repo  ----------------------
    if [ -n "${AIO}" ] || [ -n "${indexer}" ] || [ -n "${dashboard}" ] || [ -n "${wazuh}" ]; then
        installCommon_installPrerequisites
        installCommon_addWazuhRepo
    fi

# -------------- Configuration creation case  -----------------------

    # Creation certificate case: Only AIO and -g option can create certificates.
    if [ -n "${configurations}" ] || [ -n "${AIO}" ]; then
        common_logger "--- Configuration files ---"
        installCommon_createInstallFiles
    fi

    if [ -z "${configurations}" ] && [ -z "${download}" ]; then
        installCommon_extractConfig
        config_file="/tmp/wazuh-install-files/config.yml"
        cert_readConfig
    fi

    # Distributed architecture: node names must be different
    if [[ -z "${AIO}" && -z "${download}" && ( -n "${indexer}"  || -n "${dashboard}" || -n "${wazuh}" ) ]]; then
        checks_names
    fi

# -------------- Wazuh indexer case -------------------------------

    if [ -n "${indexer}" ]; then
        common_logger "--- Wazuh indexer ---"
        indexer_install
        indexer_configure
        installCommon_startService "wazuh-indexer"
        indexer_initialize
    fi

# -------------- Start Wazuh indexer cluster case  ------------------

    if [ -n "${start_indexer_cluster}" ]; then
        indexer_startCluster
        installCommon_changePasswords
    fi

# -------------- Wazuh dashboard case  ------------------------------

    if [ -n "${dashboard}" ]; then
        common_logger "--- Wazuh dashboard ----"

        dashboard_install
        dashboard_configure
        installCommon_changePasswords
        installCommon_startService "wazuh-dashboard"
        dashboard_initialize

    fi

# -------------- Wazuh case  ---------------------------------------

    if [ -n "${wazuh}" ]; then
        common_logger "--- Wazuh server ---"

        manager_install
        if [ -n "${server_node_types[*]}" ]; then
            manager_startCluster
        fi
        installCommon_startService "wazuh-manager"
        filebeat_install
        filebeat_configure
        installCommon_changePasswords
        passwords_changePasswordAPI
        installCommon_startService "filebeat"
    fi

# -------------- AIO case  ------------------------------------------

    if [ -n "${AIO}" ]; then

        common_logger "--- Wazuh indexer ---"
        indexer_install
        indexer_configure
        installCommon_startService "wazuh-indexer"
        indexer_initialize
        common_logger "--- Wazuh server ---"
        manager_install
        installCommon_startService "wazuh-manager"
        filebeat_install
        filebeat_configure
        installCommon_startService "filebeat"
        common_logger "--- Wazuh dashboard ---"
        dashboard_install
        dashboard_configure
        installCommon_startService "wazuh-dashboard"
        installCommon_changePasswords
        passwords_changePasswordAPI
        dashboard_initializeAIO
        
    fi

# -------------- Offline case  ------------------------------------------

    if [ -n "${download}" ]; then
        common_logger "--- Download Packages ---"
        offline_download
    fi


# -------------------------------------------------------------------

    if [ -z "${configurations}" ] && [ -z "${download}" ]; then
        installCommon_restoreWazuhrepo
    fi

    if [ -n "${AIO}" ] || [ -n "${indexer}" ] || [ -n "${dashboard}" ] || [ -n "${wazuh}" ]; then
        eval "rm -rf /tmp/wazuh-install-files ${debug}"
        common_logger "Installation finished."
    elif [ -n "${start_indexer_cluster}" ]; then
        common_logger "Wazuh indexer cluster started."
    fi

}

# ------------ indexer.sh ------------ 
function indexer_configure() {

    common_logger -d "Configuring Wazuh indexer."
    eval "export JAVA_HOME=/usr/share/wazuh-indexer/jdk/"

    # Configure JVM options for Wazuh indexer
    ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    ram="$(( ram_mb / 2 ))"

    if [ "${ram}" -eq "0" ]; then
        ram=1024;
    fi
    eval "sed -i "s/-Xms1g/-Xms${ram}m/" /etc/wazuh-indexer/jvm.options ${debug}"
    eval "sed -i "s/-Xmx1g/-Xmx${ram}m/" /etc/wazuh-indexer/jvm.options ${debug}"

    if [ -n "${AIO}" ]; then
        eval "installCommon_getConfig indexer/indexer_all_in_one.yml /etc/wazuh-indexer/opensearch.yml ${debug}"
    else
        eval "installCommon_getConfig indexer/indexer_unattended_distributed.yml /etc/wazuh-indexer/opensearch.yml ${debug}"
        if [ "${#indexer_node_names[@]}" -eq 1 ]; then
            pos=0
            echo "node.name: ${indxname}" >> /etc/wazuh-indexer/opensearch.yml
            echo "network.host: ${indexer_node_ips[0]}" >> /etc/wazuh-indexer/opensearch.yml
            echo "cluster.initial_master_nodes: ${indxname}" >> /etc/wazuh-indexer/opensearch.yml

            echo "plugins.security.nodes_dn:" >> /etc/wazuh-indexer/opensearch.yml
            echo '        - CN='${indxname}',OU=Wazuh,O=Wazuh,L=California,C=US' >> /etc/wazuh-indexer/opensearch.yml
        else
            echo "node.name: ${indxname}" >> /etc/wazuh-indexer/opensearch.yml
            echo "cluster.initial_master_nodes:" >> /etc/wazuh-indexer/opensearch.yml
            for i in "${indexer_node_names[@]}"; do
                echo '        - "'${i}'"' >> /etc/wazuh-indexer/opensearch.yml
            done

            echo "discovery.seed_hosts:" >> /etc/wazuh-indexer/opensearch.yml
            for i in "${indexer_node_ips[@]}"; do
                echo '        - "'${i}'"' >> /etc/wazuh-indexer/opensearch.yml
            done

            for i in "${!indexer_node_names[@]}"; do
                if [[ "${indexer_node_names[i]}" == "${indxname}" ]]; then
                    pos="${i}";
                fi
            done

            echo "network.host: ${indexer_node_ips[pos]}" >> /etc/wazuh-indexer/opensearch.yml

            echo "plugins.security.nodes_dn:" >> /etc/wazuh-indexer/opensearch.yml
            for i in "${indexer_node_names[@]}"; do
                    echo '        - CN='${i}',OU=Wazuh,O=Wazuh,L=California,C=US' >> /etc/wazuh-indexer/opensearch.yml
            done
        fi
    fi

    indexer_copyCertificates

    jv=$(java -version 2>&1 | grep -o -m1 '1.8.0' )
    if [ "$jv" == "1.8.0" ]; then
        echo "wazuh-indexer hard nproc 4096" >> /etc/security/limits.conf
        echo "wazuh-indexer soft nproc 4096" >> /etc/security/limits.conf
        echo "wazuh-indexer hard nproc 4096" >> /etc/security/limits.conf
        echo "wazuh-indexer soft nproc 4096" >> /etc/security/limits.conf
        echo -ne "\nbootstrap.system_call_filter: false" >> /etc/wazuh-indexer/opensearch.yml
    fi

    common_logger "Wazuh indexer post-install configuration finished."
}
function indexer_copyCertificates() {

    eval "rm -f ${indexer_cert_path}/* ${debug}"
    name=${indexer_node_names[pos]}

    if [ -f "${tar_file}" ]; then
        if [ -z "$(tar -tvf ${tar_file} | grep ${name})" ]; then
            common_logger -e "Tar file does not contain certificate for the node ${name}."
            installCommon_rollBack
            exit 1;
        fi
        eval "mkdir ${indexer_cert_path} ${debug}"
        eval "sed -i s/indexer.pem/${name}.pem/ /etc/wazuh-indexer/opensearch.yml ${debug}"
        eval "sed -i s/indexer-key.pem/${name}-key.pem/ /etc/wazuh-indexer/opensearch.yml ${debug}"
        eval "tar -xf ${tar_file} -C ${indexer_cert_path} wazuh-install-files/${name}.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${indexer_cert_path} wazuh-install-files/${name}-key.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${indexer_cert_path} wazuh-install-files/root-ca.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${indexer_cert_path} wazuh-install-files/admin.pem --strip-components 1 ${debug}"
        eval "tar -xf ${tar_file} -C ${indexer_cert_path} wazuh-install-files/admin-key.pem --strip-components 1 ${debug}"
        eval "rm -rf ${indexer_cert_path}/wazuh-install-files/"
        eval "chown -R wazuh-indexer:wazuh-indexer ${indexer_cert_path} ${debug}"
        eval "chmod 500 ${indexer_cert_path} ${debug}"
        eval "chmod 400 ${indexer_cert_path}/* ${debug}"
    else
        common_logger -e "No certificates found. Could not initialize Wazuh indexer"
        installCommon_rollBack
        exit 1;
    fi

}
function indexer_initialize() {

    common_logger "Initializing Wazuh indexer cluster security settings."
    i=0
    until curl -XGET https://${indexer_node_ips[pos]}:9200/ -uadmin:admin -k --max-time 120 --silent --output /dev/null || [ "${i}" -eq 12 ]; do
        sleep 10
        i=$((i+1))
    done
    if [ ${i} -eq 12 ]; then
        common_logger -e "Cannot initialize Wazuh indexer cluster."
        installCommon_rollBack
        exit 1
    fi

    if [ -n "${AIO}" ]; then
        eval "sudo -u wazuh-indexer JAVA_HOME=/usr/share/wazuh-indexer/jdk/ OPENSEARCH_PATH_CONF=/etc/wazuh-indexer /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -cd /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig -icl -p 9300 -cd /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig -nhnv -cacert ${indexer_cert_path}/root-ca.pem -cert ${indexer_cert_path}/admin.pem -key ${indexer_cert_path}/admin-key.pem -h 127.0.0.1 ${debug}"
    fi

    if [ "${#indexer_node_names[@]}" -eq 1 ] && [ -z "${AIO}" ]; then
        installCommon_changePasswords
    fi

    common_logger "Wazuh indexer cluster initialized."

}
function indexer_install() {

    common_logger "Starting Wazuh indexer installation."

    if [ "${sys_type}" == "yum" ]; then
        eval "yum install wazuh-indexer-${wazuh_version}-${indexer_revision_rpm} -y ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "zypper" ]; then
        eval "zypper -n install wazuh-indexer=${wazuh_version}-${indexer_revision_rpm} ${debug}"
        install_result="${PIPESTATUS[0]}"
    elif [ "${sys_type}" == "apt-get" ]; then
        installCommon_aptInstall "wazuh-indexer" "${wazuh_version}-${indexer_revision_deb}"
    fi

    common_checkInstalled
    if [  "$install_result" != 0  ] || [ -z "${indexer_installed}" ]; then
        common_logger -e "Wazuh indexer installation failed."
        installCommon_rollBack
        exit 1
    else
        common_logger "Wazuh indexer installation finished."
    fi

    eval "sysctl -q -w vm.max_map_count=262144 ${debug}"

}
function indexer_startCluster() {

    retries=0    
    for ip_to_test in "${indexer_node_ips[@]}"; do
        eval "curl -XGET https://"${ip_to_test}":9300/ -k -s -o /dev/null"
        e_code="${PIPESTATUS[0]}"
        until [ "${e_code}" -ne 7 ] || [ "${retries}" -eq 12 ]; do
            sleep 10
            retries=$((retries+1))
            eval "curl -XGET https://"${ip_to_test}":9300/ -k -s -o /dev/null"
            e_code="${PIPESTATUS[0]}"
        done
        if [ ${retries} -eq 12 ]; then
            common_logger -e "Connectivity check failed on node ${ip_to_test} port 9300. Possible causes: Wazuh indexer not installed on the node, the Wazuh indexer service is not running or you have connectivity issues with that node. Please check this before trying again."
            exit 1
        fi
    done
    eval "wazuh_indexer_ip=( $(cat /etc/wazuh-indexer/opensearch.yml | grep network.host | sed 's/network.host:\s//') )"
    eval "sudo -u wazuh-indexer JAVA_HOME=/usr/share/wazuh-indexer/jdk/ OPENSEARCH_PATH_CONF=/etc/wazuh-indexer /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -p 9300 -cd /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig/ -icl -nhnv -cacert /etc/wazuh-indexer/certs/root-ca.pem -cert /etc/wazuh-indexer/certs/admin.pem -key /etc/wazuh-indexer/certs/admin-key.pem -h ${wazuh_indexer_ip} ${debug}"
    if [  "${PIPESTATUS[0]}" != 0  ]; then
        common_logger -e "The Wazuh indexer cluster security configuration could not be initialized."
        installCommon_rollBack
        exit 1
    else
        common_logger "Wazuh indexer cluster security configuration initialized."
    fi
    eval "curl --silent ${filebeat_wazuh_template} | curl -X PUT 'https://${indexer_node_ips[pos]}:9200/_template/wazuh' -H 'Content-Type: application/json' -d @- -uadmin:admin -k --silent ${debug}"
    if [  "${PIPESTATUS[0]}" != 0  ]; then
        common_logger -e "The wazuh-alerts template could not be inserted into the Wazuh indexer cluster."
        installCommon_rollBack
        exit 1
    else
        common_logger -d "Inserted wazuh-alerts template into the Wazuh indexer cluster."
    fi

}
# ------------ wazuh-offline-download.sh ------------ 
function offline_download() {

  common_logger "Starting Wazuh packages download."
  common_logger "Downloading Wazuh ${package_type} packages for ${arch}."
  dest_path="${base_dest_folder}/wazuh-packages"

  if [ -d ${dest_path} ]; then
    eval "rm -f ${dest_path}/*" # Clean folder before downloading specific versions
    eval "chmod 700 ${dest_path}"
  else
    eval "mkdir -m700 -p ${dest_path}" # Create folder if it does not exist
  fi

  packages_to_download=( "manager" "filebeat" "indexer" "dashboard" )

  for package in "${packages_to_download[@]}"
  do

    package_name="${package}_${package_type}_package"
    eval "package_base_url=${package}_${package_type}_base_url"

    eval "curl -so ${dest_path}/${!package_name} ${!package_base_url}/${!package_name}"
    if [  "${PIPESTATUS[0]}" != 0  ]; then
        common_logger -e "The ${package} package could not be downloaded. Exiting."
        exit 1
    else
        common_logger "The ${package} package was downloaded."
    fi

  done

  common_logger "The packages are in ${dest_path}"

# --------------------------------------------------

  common_logger "Downloading configuration files and assets."
  dest_path="${base_dest_folder}/wazuh-files"

  if [ -d ${dest_path} ]; then
    eval "rm -f ${dest_path}/*" # Clean folder before downloading specific versions
    eval "chmod 700 ${dest_path}"
  else
    eval "mkdir -m700 -p ${dest_path}" # Create folder if it does not exist
  fi

  files_to_download=( ${wazuh_gpg_key} ${filebeat_config_file} ${filebeat_wazuh_template} ${filebeat_wazuh_module} )

  eval "cd ${dest_path}"
  for file in "${files_to_download[@]}"
  do

    eval "curl -sO ${file}"
    if [  "${PIPESTATUS[0]}" != 0  ]; then
        common_logger -e "The resource ${file} could not be downloaded. Exiting."
        exit 1
    else
        common_logger "The resource ${file} was downloaded."
    fi

  done
  eval "cd - > /dev/null"

  eval "chmod 500 ${base_dest_folder}"

  common_logger "The configuration files and assets are in ${dest_path}"

  eval "tar -czf ${base_dest_folder}.tar.gz ${base_dest_folder}"
  eval "chmod -R 700 ${base_dest_folder} && rm -rf ${base_dest_folder}"

  common_logger "You can follow the installation guide here https://documentation.wazuh.com/current/installation-guide/more-installation-alternatives/offline-installation.html"

}
function dist_detect() {


DIST_NAME="Linux"
DIST_VER="0"
DIST_SUBVER="0"

if [ -r "/etc/os-release" ]; then
    . /etc/os-release
    DIST_NAME=$ID
    DIST_VER=$(echo $VERSION_ID | sed -rn 's/[^0-9]*([0-9]+).*/\1/p')
    if [ "X$DIST_VER" = "X" ]; then
        DIST_VER="0"
    fi
    if [ "$DIST_NAME" = "amzn" ] && [ "$DIST_VER" != "2" ]; then
        DIST_VER="1"
    fi
    DIST_SUBVER=$(echo $VERSION_ID | sed -rn 's/[^0-9]*[0-9]+\.([0-9]+).*/\1/p')
    if [ "X$DIST_SUBVER" = "X" ]; then
        DIST_SUBVER="0"
    fi
fi

if [ ! -r "/etc/os-release" ] || [ "$DIST_NAME" = "centos" ]; then
    # CentOS
    if [ -r "/etc/centos-release" ]; then
        DIST_NAME="centos"
        DIST_VER=`sed -rn 's/.* ([0-9]{1,2})\.*[0-9]{0,2}.*/\1/p' /etc/centos-release`
        DIST_SUBVER=`sed -rn 's/.* [0-9]{1,2}\.*([0-9]{0,2}).*/\1/p' /etc/centos-release`

    # Fedora
    elif [ -r "/etc/fedora-release" ]; then
        DIST_NAME="fedora"
        DIST_VER=`sed -rn 's/.* ([0-9]{1,2}) .*/\1/p' /etc/fedora-release`

    # RedHat
    elif [ -r "/etc/redhat-release" ]; then
        if grep -q "CentOS" /etc/redhat-release; then
            DIST_NAME="centos"
        else
            DIST_NAME="rhel"
        fi
        DIST_VER=`sed -rn 's/.* ([0-9]{1,2})\.*[0-9]{0,2}.*/\1/p' /etc/redhat-release`
        DIST_SUBVER=`sed -rn 's/.* [0-9]{1,2}\.*([0-9]{0,2}).*/\1/p' /etc/redhat-release`

    # Ubuntu
    elif [ -r "/etc/lsb-release" ]; then
        . /etc/lsb-release
        DIST_NAME="ubuntu"
        DIST_VER=$(echo $DISTRIB_RELEASE | sed -rn 's/.*([0-9][0-9])\.[0-9][0-9].*/\1/p')
        DIST_SUBVER=$(echo $DISTRIB_RELEASE | sed -rn 's/.*[0-9][0-9]\.([0-9][0-9]).*/\1/p')

    # Gentoo
    elif [ -r "/etc/gentoo-release" ]; then
        DIST_NAME="gentoo"
        DIST_VER=`sed -rn 's/.* ([0-9]{1,2})\.[0-9]{1,2}.*/\1/p' /etc/gentoo-release`
        DIST_SUBVER=`sed -rn 's/.* [0-9]{1,2}\.([0-9]{1,2}).*/\1/p' /etc/gentoo-release`

    # SuSE
    elif [ -r "/etc/SuSE-release" ]; then
        DIST_NAME="suse"
        DIST_VER=`sed -rn 's/.*VERSION = ([0-9]{1,2}).*/\1/p' /etc/SuSE-release`
        DIST_SUBVER=`sed -rn 's/.*PATCHLEVEL = ([0-9]{1,2}).*/\1/p' /etc/SuSE-release`
        if [ "$DIST_SUBVER" = "" ]; then #openSuse
          DIST_SUBVER=`sed -rn 's/.*VERSION = ([0-9]{1,2})\.([0-9]{1,2}).*/\1/p' /etc/SuSE-release`
        fi

    # Arch
    elif [ -r "/etc/arch-release" ]; then
        DIST_NAME="arch"
        DIST_VER=$(uname -r | sed -rn 's/[^0-9]*([0-9]+).*/\1/p')
        DIST_SUBVER=$(uname -r | sed -rn 's/[^0-9]*[0-9]+\.([0-9]+).*/\1/p')

    # Debian
    elif [ -r "/etc/debian_version" ]; then
        DIST_NAME="debian"
        DIST_VER=`sed -rn 's/[^0-9]*([0-9]+).*/\1/p' /etc/debian_version`
        DIST_SUBVER=`sed -rn 's/[^0-9]*[0-9]+\.([0-9]+).*/\1/p' /etc/debian_version`

    # Slackware
    elif [ -r "/etc/slackware-version" ]; then
        DIST_NAME="slackware"
        DIST_VER=`sed -rn 's/.* ([0-9]{1,2})\.[0-9].*/\1/p' /etc/slackware-version`
        DIST_SUBVER=`sed -rn 's/.* [0-9]{1,2}\.([0-9]).*/\1/p' /etc/slackware-version`

    # Darwin
    elif [ "$(uname)" = "Darwin" ]; then
        DIST_NAME="darwin"
        DIST_VER=$(uname -r | sed -En 's/[^0-9]*([0-9]+).*/\1/p')
        DIST_SUBVER=$(uname -r | sed -En 's/[^0-9]*[0-9]+\.([0-9]+).*/\1/p')

    # Solaris / SunOS
    elif [ "$(uname)" = "SunOS" ]; then
        DIST_NAME="sunos"
        DIST_VER=$(uname -r | cut -d\. -f1)
        DIST_SUBVER=$(uname -r | cut -d\. -f2)

    # HP-UX
    elif [ "$(uname)" = "HP-UX" ]; then
        DIST_NAME="HP-UX"
        DIST_VER=$(uname -r | cut -d\. -f2)
        DIST_SUBVER=$(uname -r | cut -d\. -f3)

    # AIX
    elif [ "$(uname)" = "AIX" ]; then
        DIST_NAME="AIX"
        DIST_VER=$(oslevel | cut -d\. -f1)
        DIST_SUBVER=$(oslevel | cut -d\. -f2)

    # BSD
    elif [ "X$(uname)" = "XOpenBSD" -o "X$(uname)" = "XNetBSD" -o "X$(uname)" = "XFreeBSD" -o "X$(uname)" = "XDragonFly" ]; then
        DIST_NAME="bsd"
        DIST_VER=$(uname -r | sed -rn 's/[^0-9]*([0-9]+).*/\1/p')
        DIST_SUBVER=$(uname -r | sed -rn 's/[^0-9]*[0-9]+\.([0-9]+).*/\1/p')

    elif [ "X$(uname)" = "XLinux" ]; then
        DIST_NAME="Linux"

    fi
    if [ "X$DIST_SUBVER" = "X" ]; then
        DIST_SUBVER="0"
    fi
fi
}
function common_logger() {

    now=$(date +'%d/%m/%Y %H:%M:%S')
    mtype="INFO:"
    debugLogger=
    nolog=
    if [ -n "${1}" ]; then
        while [ -n "${1}" ]; do
            case ${1} in
                "-e")
                    mtype="ERROR:"
                    shift 1
                    ;;
                "-w")
                    mtype="WARNING:"
                    shift 1
                    ;;
                "-d")
                    debugLogger=1
                    mtype="DEBUG:"
                    shift 1
                    ;;
                "-nl")
                    nolog=1
                    shift 1
                    ;;
                *)
                    message="${1}"
                    shift 1
                    ;;
            esac
        done
    fi

    if [ -z "${debugLogger}" ] || ( [ -n "${debugLogger}" ] && [ -n "${debugEnabled}" ] ); then
        if [ "$EUID" -eq 0 ] && [ -z "${nolog}" ]; then
            printf "${now} ${mtype} ${message}\n" | tee -a ${logfile}
        else
            printf "${now} ${mtype} ${message}\n"
        fi
    fi

}
function common_checkRoot() {

    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root."
        exit 1;
    fi

}
function common_checkInstalled() {

    wazuh_installed=""
    indexer_installed=""
    filebeat_installed=""
    dashboard_installed=""

    if [ "${sys_type}" == "yum" ]; then
        wazuh_installed=$(yum list installed 2>/dev/null | grep wazuh-manager)
    elif [ "${sys_type}" == "zypper" ]; then
        wazuh_installed=$(zypper packages | grep wazuh-manager | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        wazuh_installed=$(apt list --installed  2>/dev/null | grep wazuh-manager)
    fi

    if [ -d "/var/ossec" ]; then
        wazuh_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        indexer_installed=$(yum list installed 2>/dev/null | grep wazuh-indexer)
    elif [ "${sys_type}" == "zypper" ]; then
        indexer_installed=$(zypper packages | grep wazuh-indexer | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        indexer_installed=$(apt list --installed 2>/dev/null | grep wazuh-indexer)
    fi

    if [ -d "/var/lib/wazuh-indexer/" ] || [ -d "/usr/share/wazuh-indexer" ] || [ -d "/etc/wazuh-indexer" ] || [ -f "${base_path}/search-guard-tlstool*" ]; then
        indexer_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        filebeat_installed=$(yum list installed 2>/dev/null | grep filebeat)
    elif [ "${sys_type}" == "zypper" ]; then
        filebeat_installed=$(zypper packages | grep filebeat | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        filebeat_installed=$(apt list --installed  2>/dev/null | grep filebeat)
    fi

    if [ -d "/var/lib/filebeat/" ] || [ -d "/usr/share/filebeat" ] || [ -d "/etc/filebeat" ]; then
        filebeat_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        dashboard_installed=$(yum list installed 2>/dev/null | grep wazuh-dashboard)
    elif [ "${sys_type}" == "zypper" ]; then
        dashboard_installed=$(zypper packages | grep wazuh-dashboard | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        dashboard_installed=$(apt list --installed  2>/dev/null | grep wazuh-dashboard)
    fi

    if [ -d "/var/lib/wazuh-dashboard/" ] || [ -d "/usr/share/wazuh-dashboard" ] || [ -d "/etc/wazuh-dashboard" ] || [ -d "/run/wazuh-dashboard/" ]; then
        dashboard_remaining_files=1
    fi

}
function common_checkSystem() {

    if [ -n "$(command -v yum)" ]; then
        sys_type="yum"
        sep="-"
    elif [ -n "$(command -v zypper)" ]; then
        sys_type="zypper"
        sep="-"
    elif [ -n "$(command -v apt-get)" ]; then
        sys_type="apt-get"
        sep="="
    else
        common_logger -e "Couldn'd find type of system"
        exit 1
    fi

}
function cert_cleanFiles() {

    eval "rm -f /tmp/wazuh-certificates/*.csr ${debug}"
    eval "rm -f /tmp/wazuh-certificates/*.srl ${debug}"
    eval "rm -f /tmp/wazuh-certificates/*.conf ${debug}"
    eval "rm -f /tmp/wazuh-certificates/admin-key-temp.pem ${debug}"

}
function cert_checkOpenSSL() {

    if [ -z "$(command -v openssl)" ]; then
        common_logger -e "OpenSSL not installed."
        exit 1
    fi

}
function cert_checkRootCA() {

    if  [[ -n ${rootca} || -n ${rootcakey} ]]; then
        # Verify variables match keys
        if [[ ${rootca} == *".key" ]]; then
            ca_temp=${rootca}
            rootca=${rootcakey}
            rootcakey=${ca_temp}
        fi
        # Validate that files exist
        if [[ -e ${rootca} ]]; then
            eval "cp ${rootca} /tmp/wazuh-certificates/root-ca.pem ${debug}"
        else
            common_logger -e "The file ${rootca} does not exists"
            cert_cleanFiles
            exit 1
        fi
        if [[ -e ${rootcakey} ]]; then
            eval "cp ${rootcakey} /tmp/wazuh-certificates/root-ca.key ${debug}"
        else
            common_logger -e "The file ${rootcakey} does not exists"
            cert_cleanFiles
            exit 1
        fi
    else
        cert_generateRootCAcertificate
    fi

}
function cert_generateAdmincertificate() {

    eval "openssl genrsa -out /tmp/wazuh-certificates/admin-key-temp.pem 2048 ${debug}"
    eval "openssl pkcs8 -inform PEM -outform PEM -in /tmp/wazuh-certificates/admin-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out /tmp/wazuh-certificates/admin-key.pem ${debug}"
    eval "openssl req -new -key /tmp/wazuh-certificates/admin-key.pem -out /tmp/wazuh-certificates/admin.csr -batch -subj '/C=US/L=California/O=Wazuh/OU=Wazuh/CN=admin' ${debug}"
    eval "openssl x509 -days 3650 -req -in /tmp/wazuh-certificates/admin.csr -CA /tmp/wazuh-certificates/root-ca.pem -CAkey /tmp/wazuh-certificates/root-ca.key -CAcreateserial -sha256 -out /tmp/wazuh-certificates/admin.pem ${debug}"

}
function cert_generateCertificateconfiguration() {

    cat > "/tmp/wazuh-certificates/${1}.conf" <<- EOF
        [ req ]
        prompt = no
        default_bits = 2048
        default_md = sha256
        distinguished_name = req_distinguished_name
        x509_extensions = v3_req

        [req_distinguished_name]
        C = US
        L = California
        O = Wazuh
        OU = Wazuh
        CN = cname

        [ v3_req ]
        authorityKeyIdentifier=keyid,issuer
        basicConstraints = CA:FALSE
        keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
        subjectAltName = @alt_names

        [alt_names]
        IP.1 = cip
	EOF

    conf="$(awk '{sub("CN = cname", "CN = '${1}'")}1' "/tmp/wazuh-certificates/${1}.conf")"
    echo "${conf}" > "/tmp/wazuh-certificates/${1}.conf"

    isIP=$(echo "${2}" | grep -P "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$")
    isDNS=$(echo "${2}" | grep -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$" )

    if [[ -n "${isIP}" ]]; then
        conf="$(awk '{sub("IP.1 = cip", "IP.1 = '${2}'")}1' "/tmp/wazuh-certificates/${1}.conf")"
        echo "${conf}" > "/tmp/wazuh-certificates/${1}.conf"
    elif [[ -n "${isDNS}" ]]; then
        conf="$(awk '{sub("CN = cname", "CN =  '${2}'")}1' "/tmp/wazuh-certificates/${1}.conf")"
        echo "${conf}" > "/tmp/wazuh-certificates/${1}.conf"
        conf="$(awk '{sub("IP.1 = cip", "DNS.1 = '${2}'")}1' "/tmp/wazuh-certificates/${1}.conf")"
        echo "${conf}" > "/tmp/wazuh-certificates/${1}.conf"
    else
        common_logger -e "The given information does not match with an IP address or a DNS."
        exit 1
    fi

}
function cert_generateIndexercertificates() {

    if [ ${#indexer_node_names[@]} -gt 0 ]; then
        common_logger -d "Creating the Wazuh indexer certificates."

        for i in "${!indexer_node_names[@]}"; do
            cert_generateCertificateconfiguration "${indexer_node_names[i]}" "${indexer_node_ips[i]}"
            eval "openssl req -new -nodes -newkey rsa:2048 -keyout /tmp/wazuh-certificates/${indexer_node_names[i]}-key.pem -out /tmp/wazuh-certificates/${indexer_node_names[i]}.csr -config /tmp/wazuh-certificates/${indexer_node_names[i]}.conf -days 3650 ${debug}"
            eval "openssl x509 -req -in /tmp/wazuh-certificates/${indexer_node_names[i]}.csr -CA /tmp/wazuh-certificates/root-ca.pem -CAkey /tmp/wazuh-certificates/root-ca.key -CAcreateserial -out /tmp/wazuh-certificates/${indexer_node_names[i]}.pem -extfile /tmp/wazuh-certificates/${indexer_node_names[i]}.conf -extensions v3_req -days 3650 ${debug}"
        done
    fi

}
function cert_generateFilebeatcertificates() {

    if [ ${#server_node_names[@]} -gt 0 ]; then
        common_logger -d "Creating the Wazuh server certificates."

        for i in "${!server_node_names[@]}"; do
            cert_generateCertificateconfiguration "${server_node_names[i]}" "${server_node_ips[i]}"
            eval "openssl req -new -nodes -newkey rsa:2048 -keyout /tmp/wazuh-certificates/${server_node_names[i]}-key.pem -out /tmp/wazuh-certificates/${server_node_names[i]}.csr -config /tmp/wazuh-certificates/${server_node_names[i]}.conf -days 3650 ${debug}"
            eval "openssl x509 -req -in /tmp/wazuh-certificates/${server_node_names[i]}.csr -CA /tmp/wazuh-certificates/root-ca.pem -CAkey /tmp/wazuh-certificates/root-ca.key -CAcreateserial -out /tmp/wazuh-certificates/${server_node_names[i]}.pem -extfile /tmp/wazuh-certificates/${server_node_names[i]}.conf -extensions v3_req -days 3650 ${debug}"
        done
    fi

}
function cert_generateDashboardcertificates() {

    if [ ${#dashboard_node_names[@]} -gt 0 ]; then
        common_logger -d "Creating the Wazuh dashboard certificates."

        for i in "${!dashboard_node_names[@]}"; do
            cert_generateCertificateconfiguration "${dashboard_node_names[i]}" "${dashboard_node_ips[i]}"
            eval "openssl req -new -nodes -newkey rsa:2048 -keyout /tmp/wazuh-certificates/${dashboard_node_names[i]}-key.pem -out /tmp/wazuh-certificates/${dashboard_node_names[i]}.csr -config /tmp/wazuh-certificates/${dashboard_node_names[i]}.conf -days 3650 ${debug}"
            eval "openssl x509 -req -in /tmp/wazuh-certificates/${dashboard_node_names[i]}.csr -CA /tmp/wazuh-certificates/root-ca.pem -CAkey /tmp/wazuh-certificates/root-ca.key -CAcreateserial -out /tmp/wazuh-certificates/${dashboard_node_names[i]}.pem -extfile /tmp/wazuh-certificates/${dashboard_node_names[i]}.conf -extensions v3_req -days 3650 ${debug}"

        done
    fi

}
function cert_generateRootCAcertificate() {

    common_logger -d "Creating the root certificate."

    eval "openssl req -x509 -new -nodes -newkey rsa:2048 -keyout /tmp/wazuh-certificates/root-ca.key -out /tmp/wazuh-certificates/root-ca.pem -batch -subj '/OU=Wazuh/O=Wazuh/L=California/' -days 3650 ${debug}"

}
function cert_parseYaml() {

    local prefix=${2}
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_]*'
    local fs=$(echo @|tr @ '\034')
    sed -re "s|^(\s+)-\s+name|\1  name|" ${1} |
    sed -ne "s|^\($s\):|\1|" \
            -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
            -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
        }
    }'

}
function cert_readConfig() {

    if [ -f "${config_file}" ]; then
        if [ ! -s "${config_file}" ]; then
            common_logger -e "File ${config_file} is empty"
            exit 1
        fi
        eval "$(cert_convertCRLFtoLF "${config_file}")"
        eval "$(cert_parseYaml "${config_file}")"
        eval "indexer_node_names=( $(cert_parseYaml "${config_file}" | grep nodes_indexer__name | sed 's/nodes_indexer__name=//' | sed -r 's/\s+//g') )"
        eval "server_node_names=( $(cert_parseYaml "${config_file}" | grep nodes_server__name | sed 's/nodes_server__name=//' | sed -r 's/\s+//g') )"
        eval "dashboard_node_names=( $(cert_parseYaml "${config_file}" | grep nodes_dashboard__name | sed 's/nodes_dashboard__name=//' | sed -r 's/\s+//g') )"

        eval "indexer_node_ips=( $(cert_parseYaml "${config_file}" | grep nodes_indexer__ip | sed 's/nodes_indexer__ip=//' | sed -r 's/\s+//g') )"
        eval "server_node_ips=( $(cert_parseYaml "${config_file}" | grep nodes_server__ip | sed 's/nodes_server__ip=//' | sed -r 's/\s+//g') )"
        eval "dashboard_node_ips=( $(cert_parseYaml "${config_file}" | grep nodes_dashboard__ip | sed 's/nodes_dashboard__ip=//' | sed -r 's/\s+//g') )"

        eval "server_node_types=( $(cert_parseYaml "${config_file}" | grep nodes_server__node_type | sed 's/nodes_server__node_type=//' | sed -r 's/\s+//g') )"

        unique_names=($(echo "${indexer_node_names[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_names[@]}" -ne "${#indexer_node_names[@]}" ]; then 
            common_logger -e "Duplicated indexer node names."
            exit 1
        fi

        unique_ips=($(echo "${indexer_node_ips[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_ips[@]}" -ne "${#indexer_node_ips[@]}" ]; then 
            common_logger -e "Duplicated indexer node ips."
            exit 1
        fi

        unique_names=($(echo "${server_node_names[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_names[@]}" -ne "${#server_node_names[@]}" ]; then 
            common_logger -e "Duplicated Wazuh server node names."
            exit 1
        fi

        unique_ips=($(echo "${server_node_ips[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_ips[@]}" -ne "${#server_node_ips[@]}" ]; then 
            common_logger -e "Duplicated Wazuh server node ips."
            exit 1
        fi

        unique_names=($(echo "${dashboard_node_names[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_names[@]}" -ne "${#dashboard_node_names[@]}" ]; then
            common_logger -e "Duplicated dashboard node names."
            exit 1
        fi

        unique_ips=($(echo "${dashboard_node_ips[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if [ "${#unique_ips[@]}" -ne "${#dashboard_node_ips[@]}" ]; then
            common_logger -e "Duplicated dashboard node ips."
            exit 1
        fi

        if [ "${#server_node_names[@]}" -ne "${#server_node_ips[@]}" ]; then 
            common_logger -e "Different number of Wazuh server node names and IPs."
            exit 1
        fi

        for i in "${server_node_types[@]}"; do
            if ! echo "$i" | grep -ioq master && ! echo "$i" | grep -ioq worker; then
                common_logger -e "Incorrect node_type $i must be master or worker"
                exit 1
            fi
        done

        if [ "${#server_node_names[@]}" -le 1 ]; then
            if [ "${#server_node_types[@]}" -ne 0 ]; then
                common_logger -e "The tag node_type can only be used with more than one Wazuh server."
                exit 1
            fi
        elif [ "${#server_node_names[@]}" -gt "${#server_node_types[@]}" ]; then
            common_logger -e "The tag node_type needs to be specified for all Wazuh server nodes."
            exit 1
        elif [ "${#server_node_names[@]}" -lt "${#server_node_types[@]}" ]; then
            common_logger -e "Found extra node_type tags."
            exit 1
        elif [ $(grep -io master <<< ${server_node_types[*]} | wc -l) -ne 1 ]; then
            common_logger -e "Wazuh cluster needs a single master node."
            exit 1
        elif [ $(grep -io worker <<< ${server_node_types[*]} | wc -l) -ne $(( ${#server_node_types[@]} - 1 )) ]; then
            common_logger -e "Incorrect number of workers."
            exit 1
        fi

        if [ "${#dashboard_node_names[@]}" -ne "${#dashboard_node_ips[@]}" ]; then
            common_logger -e "Different number of dashboard node names and IPs."
            exit 1
        fi

    else
        common_logger -e "No configuration file found."
        exit 1
    fi

}
function cert_setpermisions() {
    eval "chmod -R 744 /tmp/wazuh-certificates ${debug}"
}
function cert_convertCRLFtoLF() {
    if [[ ! -d "/tmp/wazuh-install-files" ]]; then
        mkdir "/tmp/wazuh-install-files"
    fi
    eval "chmod -R 755 /tmp/wazuh-install-files ${debug}"
    eval "tr -d '\015' < $1 > /tmp/wazuh-install-files/new_config.yml"
    eval "mv /tmp/wazuh-install-files/new_config.yml $1"
}
function passwords_changePassword() {

    if [ -n "${changeall}" ]; then
        for i in "${!passwords[@]}"
        do
            if [ -n "${indexer_installed}" ] && [ -f "/usr/share/wazuh-indexer/backup/internal_users.yml" ]; then
                awk -v new=${hashes[i]} 'prev=="'${users[i]}':"{sub(/\042.*/,""); $0=$0 new} {prev=$1} 1' /usr/share/wazuh-indexer/backup/internal_users.yml > internal_users.yml_tmp && mv -f internal_users.yml_tmp /usr/share/wazuh-indexer/backup/internal_users.yml
            fi

            if [ "${users[i]}" == "admin" ]; then
                adminpass=${passwords[i]}
            elif [ "${users[i]}" == "kibanaserver" ]; then
                dashpass=${passwords[i]}
            fi

        done
    else
        if [ -n "${indexer_installed}" ] && [ -f "/usr/share/wazuh-indexer/backup/internal_users.yml" ]; then
            awk -v new="$hash" 'prev=="'${nuser}':"{sub(/\042.*/,""); $0=$0 new} {prev=$1} 1' /usr/share/wazuh-indexer/backup/internal_users.yml > internal_users.yml_tmp && mv -f internal_users.yml_tmp /usr/share/wazuh-indexer/backup/internal_users.yml
        fi

        if [ "${nuser}" == "admin" ]; then
            adminpass=${password}
        elif [ "${nuser}" == "kibanaserver" ]; then
            dashpass=${password}
        fi

    fi

    if [ "${nuser}" == "admin" ] || [ -n "${changeall}" ]; then
        if [ -n "${filebeat_installed}" ]; then
            if [ -n "$(filebeat keystore list | grep password)" ];then
                eval "echo ${adminpass} | filebeat keystore add password --force --stdin ${debug}"
            else
                wazuhold=$(grep "password:" /etc/filebeat/filebeat.yml )
                ra="  password: "
                wazuhold="${wazuhold//$ra}"
                conf="$(awk '{sub("password: .*", "password: '${adminpass}'")}1' /etc/filebeat/filebeat.yml)"
                echo "${conf}" > /etc/filebeat/filebeat.yml
            fi
            passwords_restartService "filebeat"
        fi
    fi

    if [ "$nuser" == "kibanaserver" ] || [ -n "$changeall" ]; then
        if [ -n "${dashboard_installed}" ] && [ -n "${dashpass}" ]; then
            if [ -n "$(/usr/share/wazuh-dashboard/bin/opensearch-dashboards-keystore --allow-root list | grep opensearch.password)" ]; then
                eval "echo ${dashpass} | /usr/share/wazuh-dashboard/bin/opensearch-dashboards-keystore --allow-root add -f --stdin opensearch.password ${debug_pass}"
            else
                wazuhdashold=$(grep "password:" /etc/wazuh-dashboard/opensearch_dashboards.yml )
                rk="opensearch.password: "
                wazuhdashold="${wazuhdashold//$rk}"
                conf="$(awk '{sub("opensearch.password: .*", "opensearch.password: '${dashpass}'")}1' /etc/wazuh-dashboard/opensearch_dashboards.yml)"
                echo "${conf}" > /etc/wazuh-dashboard/opensearch_dashboards.yml
            fi
            passwords_restartService "wazuh-dashboard"
        fi
    fi

}
function passwords_checkUser() {

    for i in "${!users[@]}"; do
        if [ "${users[i]}" == "${nuser}" ]; then
            exists=1
        fi
    done

    if [ -z "${exists}" ]; then
        common_logger -e "The given user does not exist"
        exit 1;
    fi

}
function passwords_createBackUp() {

    if [ -z "${indexer_installed}" ] && [ -z "${dashboard_installed}" ] && [ -z "${filebeat_installed}" ]; then
        common_logger -e "Cannot find Wazuh indexer, Wazuh dashboard or Filebeat on the system."
        exit 1;
    else
        if [ -n "${indexer_installed}" ]; then
            capem=$(grep "plugins.security.ssl.transport.pemtrustedcas_filepath: " /etc/wazuh-indexer/opensearch.yml )
            rcapem="plugins.security.ssl.transport.pemtrustedcas_filepath: "
            capem="${capem//$rcapem}"
            if [[ -z "${adminpem}" ]] || [[ -z "${adminkey}" ]]; then
                passwords_readAdmincerts
            fi
        fi
    fi

    common_logger -d "Creating password backup."
    eval "mkdir /usr/share/wazuh-indexer/backup ${debug}"
    eval "JAVA_HOME=/usr/share/wazuh-indexer/jdk/ OPENSEARCH_PATH_CONF=/etc/wazuh-indexer /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -icl -p 9300 -backup /usr/share/wazuh-indexer/backup -nhnv -cacert ${capem} -cert ${adminpem} -key ${adminkey} -h ${IP} ${debug}"
    if [ "${PIPESTATUS[0]}" != 0 ]; then
        common_logger -e "The backup could not be created"
        exit 1;
    fi
    common_logger -d "Password backup created in /usr/share/wazuh-indexer/backup."

}
function passwords_generateHash() {

    if [ -n "${changeall}" ]; then
        common_logger -d "Generating password hashes."
        for i in "${!passwords[@]}"
        do
            nhash=$(bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "${passwords[i]}" | grep -v WARNING)
            if [  "${PIPESTATUS[0]}" != 0  ]; then
                common_logger -e "Hash generation failed."
                exit 1;
            fi
            hashes+=("${nhash}")
        done
        common_logger -d "Password hashes generated."
    else
        common_logger "Generating password hash"
        hash=$(bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p ${password} | grep -v WARNING)
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "Hash generation failed."
            exit 1;
        fi
        common_logger -d "Password hash generated."
    fi

}
function passwords_generatePassword() {

    if [ -n "${nuser}" ]; then
        common_logger -d "Generating random password."
        pass=$(< /dev/urandom tr -dc "A-Za-z0-9.*+?" | head -c ${1:-31};echo;)
        special_char=$(< /dev/urandom tr -dc ".*+?" | head -c ${1:-1};echo;)
        password="$(echo ${pass}${special_char} | fold -w1 | shuf | tr -d '\n')"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "The password could not been generated."
            exit 1;
        fi
    else
        common_logger -d "Generating random passwords."
        for i in "${!users[@]}"; do
            pass=$(< /dev/urandom tr -dc "A-Za-z0-9.*+?" | head -c ${1:-31};echo;)
            special_char=$(< /dev/urandom tr -dc ".*+?" | head -c ${1:-1};echo;)
            passwords+=("$(echo ${pass}${special_char} | fold -w1 | shuf | tr -d '\n')")
            if [ "${PIPESTATUS[0]}" != 0 ]; then
                common_logger -e "The password could not been generated."
                exit 1;
            fi
        done
    fi
}
function passwords_generatePasswordFile() {

    users=( admin kibanaserver kibanaro logstash readall snapshotrestore wazuh_admin wazuh_user wazuh wazuh_wui)
    user_description=(
        "Admin user for the web user interface and Wazuh indexer. Use this user to log in to Wazuh dashboard"
        "Wazuh dashboard user for establishing the connection with Wazuh indexer"
        "Regular Dashboard user, only has read permissions to all indices and all permissions on the .kibana index"
        "Filebeat user for CRUD operations on Wazuh indices"
        "User with READ access to all indices"
        "User with permissions to perform snapshot and restore operations"
        "Admin user used to communicate with Wazuh API"
        "Regular user to query Wazuh API"
        "Password for wazuh API user"
        "Password for wazuh-wui API user"
    )
    passwords_generatePassword
    for i in "${!users[@]}"; do
        echo "# ${user_description[${i}]}" >> "${gen_file}"
        echo "  username: '${users[${i}]}'" >> "${gen_file}"
        echo "  password: '${passwords[${i}]}'" >> "${gen_file}"
        echo ""	>> "${gen_file}"
    done

}
function passwords_getNetworkHost() {
    IP=$(grep -hr "network.host:" /etc/wazuh-indexer/opensearch.yml)
    NH="network.host: "
    IP="${IP//$NH}"

    #allow to find ip with an interface
    if [[ ${IP} =~ _.*_ ]]; then
        interface="${IP//_}"
        IP=$(ip -o -4 addr list ${interface} | awk '{print $4}' | cut -d/ -f1)
    fi

    if [ ${IP} == "0.0.0.0" ]; then
        IP="localhost"
    fi
}
function passwords_readAdmincerts() {

    if [[ -f /etc/wazuh-indexer/certs/admin.pem ]]; then
        adminpem="/etc/wazuh-indexer/certs/admin.pem"
    else
        common_logger -e "No admin certificate indicated. Please run the script with the option -c <path-to-certificate>."
        exit 1;
    fi

    if [[ -f /etc/wazuh-indexer/certs/admin-key.pem ]]; then
        adminkey="/etc/wazuh-indexer/certs/admin-key.pem"
    elif [[ -f /etc/wazuh-indexer/certs/admin.key ]]; then
        adminkey="/etc/wazuh-indexer/certs/admin.key"
    else
        common_logger -e "No admin certificate key indicated. Please run the script with the option -k <path-to-key-certificate>."
        exit 1;
    fi

}
function passwords_readFileUsers() {

    filecorrect=$(grep -Ev '^#|^\s*$' "${p_file}" | grep -Pzc "\A(\s*username:[ \t]+[\'\"]?\w+[\'\"]?\s*password:[ \t]+[\'\"]?[A-Za-z0-9.*+?]+[\'\"]?\s*)+\Z")
    if [[ "${filecorrect}" -ne 1 ]]; then
        common_logger -e "The password file doesn't have a correct format or password uses invalid characters. Allowed characters: A-Za-z0-9.*+?

It must have this format:

# Description
  username: name
  password: password

# Wazuh indexer admin user
  username: kibanaserver
  password: NiwXQw82pIf0dToiwczduLBnUPEvg7T0

"
	    exit 1
    fi

    sfileusers=$(grep username: "${p_file}" | awk '{ print substr( $2, 1, length($2) ) }' | sed -e "s/[\'\"]//g")
    sfilepasswords=$(grep password: "${p_file}" | awk '{ print substr( $2, 1, length($2) ) }' | sed -e "s/[\'\"]//g")

    fileusers=(${sfileusers})
    filepasswords=(${sfilepasswords})

    if [ -n "${changeall}" ]; then
        for j in "${!fileusers[@]}"; do
            supported=false
            for i in "${!users[@]}"; do
                if [[ "${users[i]}" == "${fileusers[j]}" ]]; then
                    passwords[i]=${filepasswords[j]}
                    supported=true
                fi
            done
            if [ "${supported}" = false ] && [ -n "${indexer_installed}" ]; then
                common_logger -e "The given user ${fileusers[j]} does not exist"
            fi
        done
    else
        finalusers=()
        finalpasswords=()

        for j in "${!fileusers[@]}"; do
            supported=false
            for i in "${!users[@]}"; do
                if [[ "${users[i]}" == "${fileusers[j]}" ]]; then
                    finalusers+=("${fileusers[j]}")
                    finalpasswords+=("${filepasswords[j]}")
                    supported=true
                fi
            done
            if [ ${supported} = false ] && [ -n "${indexer_installed}" ]; then
                common_logger -e "The given user ${fileusers[j]} does not exist"
            fi
        done

        users=()
        passwords=()
        users=(${finalusers[@]})
        passwords=(${finalpasswords[@]})
        changeall=1
    fi

}
function passwords_readUsers() {

    susers=$(grep -B 1 hash: /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig/internal_users.yml | grep -v hash: | grep -v "-" | awk '{ print substr( $0, 1, length($0)-1 ) }')
    users=($susers)

}
function passwords_restartService() {

    if [ "$#" -ne 1 ]; then
        common_logger -e "passwords_restartService must be called with 1 argument."
        exit 1
    fi

    if ps -e | grep -E -q "^\ *1\ .*systemd$"; then
        eval "systemctl daemon-reload ${debug}"
        eval "systemctl restart ${1}.service ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -u ${1} >> ${logfile}"
            fi
            if [[ $(type -t installCommon_rollBack) == "function" ]]; then
                installCommon_rollBack
            fi
            exit 1;
        else
            common_logger -d "${1} started"
        fi
    elif ps -e | grep -E -q "^\ *1\ .*init$"; then
        eval "/etc/init.d/${1} restart ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -u ${1} >> ${logfile}"
            fi
            if [[ $(type -t installCommon_rollBack) == "function" ]]; then
                installCommon_rollBack
            fi
            exit 1;
        else
            common_logger -d "${1} started"
        fi
    elif [ -x "/etc/rc.d/init.d/${1}" ] ; then
        eval "/etc/rc.d/init.d/${1} restart ${debug}"
        if [  "${PIPESTATUS[0]}" != 0  ]; then
            common_logger -e "${1} could not be started."
            if [ -n "$(command -v journalctl)" ]; then
                eval "journalctl -u ${1} >> ${logfile}"
            fi
            if [[ $(type -t installCommon_rollBack) == "function" ]]; then
                installCommon_rollBack
            fi
            exit 1;
        else
            common_logger -d "${1} started"
        fi
    else
        if [[ $(type -t installCommon_rollBack) == "function" ]]; then
            installCommon_rollBack
        fi
        common_logger -e "${1} could not start. No service manager found on the system."
        exit 1;
    fi

}
function passwords_runSecurityAdmin() {

    common_logger -d "Loading new passwords changes."
    eval "cp /usr/share/wazuh-indexer/backup/* /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig/ ${debug}"
    eval "OPENSEARCH_PATH_CONF=/etc/wazuh-indexer /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -p 9300 -cd /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig/ -nhnv -cacert ${capem} -cert ${adminpem} -key ${adminkey} -icl -h ${IP} ${debug}"
    if [  "${PIPESTATUS[0]}" != 0  ]; then
        common_logger -e "Could not load the changes."
        exit 1;
    fi
    eval "rm -rf /usr/share/wazuh-indexer/backup/ ${debug}"

    if [[ -n "${nuser}" ]] && [[ -n ${autopass} ]]; then
        common_logger -nl $'\nThe password for user '${nuser}' is '${password}''
        common_logger -w "Password changed. Remember to update the password in the Wazuh dashboard and Filebeat nodes if necessary, and restart the services."
    fi

    if [[ -n "${nuser}" ]] && [[ -z ${autopass} ]]; then
        common_logger -w "Password changed. Remember to update the password in the Wazuh dashboard and Filebeat nodes if necessary, and restart the services."
    fi

    if [ -n "${changeall}" ]; then
        if [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboard}" ] && [ -z "${wazuh}" ] && [ -z "${start_indexer_cluster}" ]; then
            for i in "${!users[@]}"; do
                common_logger -nl $'The password for user '${users[i]}' is '${passwords[i]}''
            done
            common_logger -w "Passwords changed. Remember to update the password in the Wazuh dashboard and Filebeat nodes if necessary, and restart the services."
        else
            common_logger -d "Passwords changed."
        fi
    fi

}
function passwords_changePasswordAPI() {

    #Change API password tool

    if [[ -n "${api}" ]]; then
        if [[ -n "${adminAPI}" ]]; then
            common_logger $"Changing API user ${nuser} password"
            WAZUH_PASS_API='{"password":"'"$password"'"}'
            TOKEN_API=$(curl -s -u "${adminUser}":"${adminPassword}" -k -X GET "https://localhost:55000/security/user/authenticate?raw=true")
            eval 'curl -s -k -X PUT -H "Authorization: Bearer $TOKEN_API" -H "Content-Type: application/json" -d "$WAZUH_PASS_API" "https://localhost:55000/security/users/${id}" -o /dev/null'
            common_logger $"API password changed"
            common_logger -nl $"The new password for user ${nuser} is ${password}"
        else
            common_logger $"Changing API user ${nuser} password"
            WAZUH_PASS_API='{"password":"'"$password"'"}'
            TOKEN_API=$(curl -s -u "${nuser}":"${currentPassword}" -k -X GET "https://localhost:55000/security/user/authenticate?raw=true")
            eval 'curl -s -k -X PUT -H "Authorization: Bearer $TOKEN_API" -H "Content-Type: application/json" -d "$WAZUH_PASS_API" "https://localhost:55000/security/users/${id}" -o /dev/null'
            common_logger $"API password changed"
            common_logger -nl $"The new password for user ${nuser} is ${password}"
        fi
    else
        password_wazuh=$(grep -A 1 "username: 'wazuh'" "${p_file}" | tail -n1 | awk -F': ' '{print $2}' | sed -e "s/[\'\"]//g")
        password_wazuh_wui=$(grep -A 1 "username: 'wazuh_wui'" "${p_file}" | tail -n1 | awk -F': ' '{print $2}' | sed -e "s/[\'\"]//g")
        WAZUH_PASS='{"password":"'"$password_wazuh"'"}'
        WAZUH_WUI_PASS='{"password":"'"$password_wazuh_wui"'"}'

        TOKEN=$(curl -s -u wazuh:wazuh -k -X GET "https://localhost:55000/security/user/authenticate?raw=true")
        eval 'curl -s -k -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$WAZUH_PASS" "https://localhost:55000/security/users/1" -o /dev/null'

        TOKEN_WUI=$(curl -s -u wazuh-wui:wazuh-wui -k -X GET "https://localhost:55000/security/user/authenticate?raw=true")
        eval 'curl -s -k -X PUT -H "Authorization: Bearer $TOKEN_WUI" -H "Content-Type: application/json" -d "$WAZUH_WUI_PASS" "https://localhost:55000/security/users/2" -o /dev/null'
    fi

}
function passwords_updateDashboard_WUI_Password() {

    if [ -f "/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml" ]; then
        password_wazuh_wui=$(grep -A 1 "username: 'wazuh_wui'" "${p_file}" | tail -n1 | awk -F': ' '{print $2}' | sed -e "s/[\'\"]//g")
        eval 'sed -i "s|password: wazuh-wui|password: ${password_wazuh_wui}|g" /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml'
    else
        common_logger -e "File /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml does not exist"
    fi

}

main "$@"
