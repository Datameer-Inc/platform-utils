init_instance_tags
CLUSTER_ID=$(get_instance_tag 'aws:elasticmapreduce:job-flow-id')
CLUSTER_NAME=$(aws emr describe-cluster --cluster-id $CLUSTER_ID --region $AWS_REGION --query 'Cluster.Name' --output text)
DD_CLUSTER_NAME="${CLUSTER_NAME}_${CLUSTER_ID}"
RESOURCEMANAGER_URI="http://$(hostname -f):8088"
HDFS_NAMENODE_JMX_URI="http://$(get_hadoop_property 'dfs.namenode.http-address' '/etc/hadoop/conf.empty/hdfs-site.xml')"
