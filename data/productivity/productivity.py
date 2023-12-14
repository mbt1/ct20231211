import requests
import os
from bs4 import BeautifulSoup, NavigableString
import pandas as pd
import re
import boto3
from io import StringIO, BytesIO
from get_secret import get_secret
import time
import random

def read_from_url(url):
    # On MacOs, setting the environment variable CT20231211_CONTACT_EMAIL requires the use of launchctl:
    # launchctl setenv CT20231211_CONTACT_EMAIL your_email_address
    
    time.sleep(1)
    contact_email = get_secret("CT20231211_CONTACT_EMAIL")
    headers = {
        "User-Agent": f"ct20231211 ({contact_email})"
    }   
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response

def parse_directory_listing(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    pre_tag = soup.find('pre')

    file_data = []
    date, size, name, link, has_data = None, None, None, None, False

    for sibling in pre_tag.children:
        if sibling.name == 'br':
            if has_data and link.startswith("/pub/time.series/pr/"):
                file_data.append({'name': name, 'date': date, 'size': size, 'link': link})
            date, size, name, link, has_data = None, None, None, None, False

        elif isinstance(sibling, NavigableString):
            text = sibling.strip()
            match = re.match(r'(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}\s+[APM]{0,2})\s+(\d+)', text)
            if match:
                date, size = match.groups()
                has_data = True

        elif sibling.name == 'a':
            name = sibling.get_text()
            link = sibling.get('href')
            has_data = True

    # Add the last entry after exiting the loop
    if has_data and link.startswith("/pub/time.series/pr/"):
        file_data.append({'name': name, 'date': date, 'size': size, 'link': link})

    return pd.read_json(pd.DataFrame(file_data).to_json()) #force data type conversion

def get_state(bucket_name, state_file_key):
    try:
        s3 = boto3.client('s3')
        obj = s3.get_object(Bucket=bucket_name, Key=state_file_key)
        state_df = pd.read_json(StringIO(obj['Body'].read().decode('utf-8')))
        if len(state_df.columns) == 0:
            state_df = pd.DataFrame(columns=['name', 'date', 'size', 'link'])    

    except s3.exceptions.NoSuchKey:
        # If the file does not exist, create an empty DataFrame
        state_df = pd.DataFrame(columns=['name', 'date', 'size', 'link'])
    return state_df

def set_state(bucket_name, state_file_key, state_data):
    state_json = state_data.to_json(orient='records')
    # print(state_json)
    write_s3_bucket(bucket_name, state_file_key, state_json)
    return

def write_s3_bucket(bucket_name, file_key, content):
    s3 = boto3.client('s3')
    s3.put_object(
        Bucket=bucket_name,
        Key=file_key,
        Body=content,
        ContentType='application/json'
    )

def copy_files_to_s3(file_list, bucket_name, url_base):
    written_files = []
    for _,file in file_list.iterrows():
        file_url = url_base + file['link']
        file_name = file['name']
        print(f"Reading {file_name} from {file_url}...")
        # if random.choice([True, False]):
        #     continue
        http_response = read_from_url(file_url)
        # http_response = type('DataObject', (object,), {"status_code":200,"content":"lorem ipsum".encode('utf-8') })()
        if http_response.status_code == 200:
            write_s3_bucket(bucket_name, file_name, BytesIO(http_response.content))
            print(f"-->Uploaded {file_name} to S3")
            written_files.append(file)
        else:
            print(f"-->Download failed. (Status Code = {http_response.status_code})")
    return pd.DataFrame(written_files)

def synch_bls_data():
    url_base = 'https://download.bls.gov'
    dir_url = url_base + '/pub/time.series/pr/'
    bucket_name = 'ct20231211-staging'  
    state_key = ".state.json"

    dir_listing = read_from_url(dir_url).text
    new_files = parse_directory_listing(dir_listing)
    old_files = get_state(bucket_name,state_key)
    changed_or_new_files = new_files.merge(old_files, on=['name', 'date', 'size', 'link'], how='left', indicator=True).query('_merge == "left_only"').drop(columns=['_merge'])
    print("------------------------------------------------------------------------------------------------------------")
    print("New or changed files to process:")
    print("------------------------------------------------------------------------------------------------------------")
    print(changed_or_new_files)
    print("------------------------------------------------------------------------------------------------------------")

    written_files = copy_files_to_s3(changed_or_new_files, bucket_name, url_base)
    combined_files = pd.concat([written_files, old_files]).drop_duplicates(subset='name', keep='first')
    print("New State:")
    print(combined_files)
    set_state(bucket_name, state_key, combined_files)

def load_population_data():
    url = "https://datausa.io/api/data?drilldowns=Nation&measures=Population"
    bucket_name = 'ct20231211-staging'

    response = requests.get(url)
    response.raise_for_status()
    print(response.text)
    write_s3_bucket(bucket_name, "us-population.json", response.text)
    return

def main(event, context):  
    synch_bls_data()
    load_population_data()
    return


if __name__ == "__main__":
    main({},type('DataObject', (object,), {})())
