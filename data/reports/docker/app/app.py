import boto3
from datetime import datetime

bucket_name = 'ct20231211-reports'

def upload_file_to_s3(file_name, bucket, object_name=None):
    if object_name is None:
        object_name = file_name

    s3_client = boto3.client('s3')
    try:
        s3_client.upload_file(file_name, bucket, object_name)
    except Exception as e:
        print(f"Error uploading file to S3: {e}")
        return False
    return True


x = datetime.now()
file_name = x.strftime('%Y-%m-%d-%H-%M-%S.txt')
with open(file_name, 'w') as fp:
    print('hello world', file_name)
upload_file_to_s3(file_name, bucket_name)
