init_instance_tags
CLUSTER_ID=$(get_instance_tag 'aws:elasticmapreduce:job-flow-id')
CLUSTER_NAME=$(aws emr describe-cluster --cluster-id $CLUSTER_ID --region $AWS_REGION --query 'Cluster.Name' --output text)
DD_CLUSTER_NAME="${CLUSTER_NAME}-${CLUSTER_ID}"
HDFS_DATANODE_JMX_URI="http://$(hostname -f):9864"
