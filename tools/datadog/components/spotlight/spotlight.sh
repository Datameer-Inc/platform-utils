# spotlight needs
init_instance_tags
DD_GLOBAL_SERVICE=$(get_instance_tag 'StackName')
DD_GLOBAL_ENV=$(aws sts get-caller-identity --query Account --output text)
DD_GLOBAL_VERSION=$(get_instance_tag 'StackCftVersion')
