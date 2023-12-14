import boto3
from datetime import datetime
import nbformat
from nbconvert.preprocessors import ExecutePreprocessor
from nbconvert import NotebookExporter

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

def process_ipynb(ipynb_path, replacements):
    with open(ipynb_path, 'r') as file:
        nb = nbformat.read(file, as_version=4)

    for cell in nb['cells']:
        if cell['cell_type'] == 'markdown':
            for search_str,replace_str in replacements.items():
                cell['source'] = cell['source'].replace(search_str,replace_str)

    # Clear existing outputs and execute all cells
    ep = ExecutePreprocessor(timeout=600, kernel_name='python3')
    ep.preprocess(nb)

    return nb

def write_ipynb(nb,file):
    nbformat.write(nb, file)

current_date = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
file_name = "report-"+current_date+".ipynb"

print("processing ",file_name,"...")
replacements = {
    '<!--CT20231211FileDate-->': current_date
    }
with open(file_name, 'w') as fp:
    write_ipynb(process_ipynb('ReportTemplate.ipynb', replacements),fp)
print("uploading ",file_name,"...")
upload_file_to_s3(file_name, bucket_name)
print("finished.")