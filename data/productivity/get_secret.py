import os
import boto3

def get_secret(secret_name):

    if secret_name in os.environ:
        return os.environ[secret_name]

    try:
        session = boto3.session.Session()
        client = session.client(service_name='secretsmanager')
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        return get_secret_value_response['SecretString']
    except Exception as e:
        raise e
