# terraform_ixia_cloudlens_saas_sensors

This is an example on how to automate Cloud infrastructure creation that supports Ixia Cloudlens SaaS sensors

# How to use

Create a Cloudlens project in https://www.ixia-sandbox.cloud as shown in Cloudlens_Project.png

# Update the following variables

terraform_credentials/credentials.tfvars

    --- AWS Provider info
    private_key_path = <PATH_TO_YOUR_SSH_PRIVATE_KEY>

    key_name = <YOUR_SSH_KEY_NAME_IN_AWS>

    aws_access_key_id = "THE_KEY"

    aws_secret_access_key = "THE_KEY"

    aws_session_token = "THE_KEY"

CL_Demo_Terraform/CL_project.tfvars

    CL_project_key = <YOUR_CLOUDLENS_PROJECT_KEY>

# Commands to run
 cd scripts
 terraform init

# Deploy infrastructure
 terraform.exe apply --var-file="..\terraform_credentials\credentials.tfvars" --var-file=".\CL_Demo_Terraform\CL_project.tfvars"

 If you want to scale the VMs, just edit the following variables:
   CL_Demo_Terraform/CL_project.tfvars

     num_web_srv = 1
     num_db = 2

  and redeploy
    terraform.exe apply --var-file="..\terraform_credentials\credentials.tfvars" --var-file=".\CL_Demo_Terraform\CL_project.tfvars"
# Delete infrastructure
terraform.exe destroy --var-file="..\terraform_credentials\credentials.tfvars" --var-file=".\CL_Demo_Terraform\CL_project.tfvars" --force

## License
MIT / BSD

## Author Information
Created in 2019 Gustavo AMADOR NIETO.
