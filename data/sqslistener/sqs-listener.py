import boto3
import os

def ecs_event_handler(event, context):
    ecs_client = boto3.client('ecs')

    cluster_name = os.getenv('TF_VAR_ECS_CLUSTER_NAME')
    task_definition = os.getenv('TF_VAR_ECS_TASK_DEFINITION')
    launch_type = 'FARGATE'  
    subnet_id = os.getenv('TF_VAR_ECS_SUBNET_ID')
    security_group_id = os.getenv('TF_VAR_ECS_SECURITY_GROUP_ID')
    map_public_ip = ('true' == os.getenv('TF_VAR_ECS_SUBNET_MAP_PUBLIC_IP'))

    print("cluster_name: ",cluster_name)
    print("task_definition: ",task_definition)
    print("launch_type: ",launch_type)
    print("subnet_id: ",subnet_id)
    print("security_group_id: ",security_group_id)
    print("map_public_ip: ",map_public_ip)
    try:
        response = ecs_client.run_task(
            cluster=cluster_name,
            launchType=launch_type,
            taskDefinition=task_definition,
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet_id],
                    'securityGroups': [security_group_id],
                    'assignPublicIp': 'ENABLED' if map_public_ip else 'DISABLED'
                }
            }
        )
        print(f"ECS task started: {response}")
    except Exception as e:
        print(f"Error starting ECS task: {e}")
        raise e




def main(event, context):  
    ecs_event_handler(event, context)
    return


if __name__ == "__main__":
    main({},type('DataObject', (object,), {})())
