import boto3
import os

def ecs_event_handler(event, context):
    ecs_client = boto3.client('ecs')

    cluster_name = os.getenv('ECS_CLUSTER_NAME')
    task_definition = os.getenv('ECS_TASK_DEFINITION')
    launch_type = 'FARGATE'  # Or 'EC2' depending on your setup

    try:
        response = ecs_client.run_task(
            cluster=cluster_name,
            launchType=launch_type,
            taskDefinition=task_definition,
        )
        print(f"ECS task started: {response}")
    except Exception as e:
        print(f"Error starting ECS task: {e}")
        raise e




def main(event, context):  
    return


if __name__ == "__main__":
    main({},type('DataObject', (object,), {})())
