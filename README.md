# ct20231211
## A Prototype of a Reporting Application with associated Data Pipeline

The application consists of 2 parts:

1. The report generator pipeline
1. The reort viewer

The entire prototype is hosted on AWS, using diverse products including 

- AWS Lambda
- SQS Queues and Notification
- AWS S3
- ECR
- ECS, including ECS Tasks
- AWS S3 website (based on React)
- AWS Cloudfront
- AWS Secret Manager

All infrastructure (with the exception of the secret) is completely scripted using Terraform, using two seperate deployments for the two parts of this application (frontend and pipeline)

### The Report Generator Pipeline

All the code for this pipeline lives in the `data` subfolder of the repository. There are several parts to this workflow:

1. [File]`productivity/productivity.py`: A python function to check two API providers and download new data when available. This downloaded data is stored in the `ct20231211-staging` bucket. The function is deployed to AWS Lambda and automatically executed every 6 hours.

1. [AWS]`staging_file_change_notification_queue`: Any change to files in the ct20231211-staging bucket triggers a notification that is put into this SQS queue.

1. [File]`sqslistener/sqs-listener.py`: This python function is deployed to another AWS Lambda function and configured to handle new messages on the queue. The only step this function executes is to launch an ECS Task.

1. [File]`reports/docker/*`: This combination of a container definition and a python function (`app.py`) takes the files in the `ct20231211-staging` bucket as input and generates a report in form of a Jupyter Notebook. The notbook, with all outputs valued, is then saved to the `ct20231211-reports` bucket.
The example report contains simple data ingesting and cleaning steps, followed by some agregation and 'joins'.

#### Files

The `data` directory contains four folders:

- `productivity`: Here you find all the required files for the `productivity` function that gets the API responses into the `ct20231211-staging` bucket.
- `reports`: All files to facilitate the generation of the `.ipynb` reports using an ECS Task.
- `sqslistener`: All files for the function that listens the bucket-change-notification queue.
- `terraform`: The files needed to orchestrate the infrastructure build. Here you also find the definition for the parts of the application that do not require application code, like the SQS Queue.

There are a few usefull development scripts directly in `data` as well as the `template.yml` needed to build and package the two functions in a way that can be deployed to AWS Lambda.

#### Architecture Notes

While some decisions might seem over the top for this small application, they were made with a more large-scale process in mind. For example, the application logic conatins synching logic for on of the sources to make sure files only get uploaded to the bucket if they are either new, or have changed. 

The state for this synching logic is saved in a separate file in the bucket, a decision that should be revisited, based on actual requirements. If provides more flexibility, but at the same time increases surface area for problems to appear. An alternative would be to use manually provided file meta-data in the bucket to maintain state. 

The synchronization logic is using a Pandas DataFrame. That is certainly over the top, unless you are dealing with multiple 100k of files. So it might make sense to rewrite this using simple built-in python constructs.

The ECS Task to generate the report might not be needed. For small reports, the generation could be handled by the SQS listener lambda function. However, for larger reports, the 15-minute max execution time for lambda functions can be a problem. ECS Tasks do not have this limitation.

### The Report Viewer

The report viewer is a simple React app that does not require a backend and therefore can be hosted on AWS S3 Websites. The parts involved here are several React typical files in the `frontent/public` and `frontend/src` folders. The main functionality lives in the `frontend/src/App.js` file. There is also a `frontend/terraform` folder that contains the code necessary for the infrastructure build.

`App.js` makes use of a cascade of `useState` and `useEffect` hooks to facilitate the drop-down and the display of the reports. the drop-down is dynamically loaded based on the files in the `ct20231211-reports` bucket. Any change to the drop-down causes the app to load the new report and display it (read-only). There is also a download button if you want to further peruse the report.

The site is hosted as a static website on S3. Some caching as well as TLS is provided through cloudfront. At the time of this commit, the report viewer can be reached [here](https://dq96sqmscyf67.cloudfront.net/). However, that might change over time. 

#### Architecture Notes

This app is primarily optimized for simplicity. To achive getting away without a backend that would allow for authentication, the `ct20231211-reports` bucket had to be opened for public read, including accessing the list of files. That is generally considered a security faupax, so in a real world scenario this should be revisited. 

You might notice that the `ct20231211-staging` bucket is also read enabled. That is not required by the functionality presented here and was a deliberate decision to allow for manual 'monitoring'. However, the directory listing is disabled on this bucket.

### Additional thoughts

- Overall the app is following the least-privilege principle closely. However, to speed up the development time, a few shortcuts where taken. For example, the cloudfront setup allows for put and post access which does not make sense for a static site. Similarly, the CORS policy is rather wide open, something that should probably be revisited. Some of the internal policies might be able to be tightened up slightly, too.

- The file synching at this time does not handle deletes. If that is needed, that functionality has to be added.

- One of the two data sources requires a contact email to be sent with every request. To not publish my email in this repository, I decided to put the email used in a secret. This secret is the only infrastructure item that is not managed through Terraform.

- The upload of the ECS Task container image to AWS ECR is handled through a so-called null-resource in Terraform. In general, you want to separate deployment from infrastructure creation. But in this case, I wanted to demonstrate that uploading a container image to a registry is possible in Terraform. Note - Terraform provides a docker resource that can do the same thing in a managed way. However, I do not believe it is possible to use it in the same .tf file that created the target ECR Repository.

- There is ample opportunity to improve the visual appeal of the output of this app. Artistic design was not part of the requirements for this project.