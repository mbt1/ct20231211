#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir/.."

sam local invoke SQSListener --parameter-overrides ParameterKey=ParEcsClusterName,ParameterValue=$TF_VAR_ECS_CLUSTER_NAME ParameterKey=ParEcsTaskDefinition,ParameterValue=$TF_VAR_ECS_TASK_DEFINITION ParameterKey=ParEcsSubnetId,ParameterValue=$TF_VAR_ECS_SUBNET_ID ParameterKey=ParEcsSecurityGroupId,ParameterValue=$TF_VAR_ECS_SECURITY_GROUP_ID ParameterKey=ParEcsSubnetMapPublicIp,ParameterValue=$TF_VAR_ECS_SUBNET_MAP_PUBLIC_IP

popd