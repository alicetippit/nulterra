# Terraforming NUL

## Initialization

1. Download and install [Terraform](https://www.terraform.io/downloads.html)
1. Clone this repo
1. Create an S3 bucket to hold the terraform state.
1. Create a `terraform.tfvars` file with the specifics of the stack you want to create:
    ```
    stack_name = "my_repo_stack"
    project_name = "infrastructure"
    hosted_zone_name = "nulterra.rdc-staging.library.northwestern.edu"
    ec2_keyname = "my_keypair"
    ```
  * Note: You can have more than one variable file and pass the name on the command line to manage more than one stack.
1. Execute `terraform init`.
  * You will be prompted for an S3 bucket, key, and region in which to store the state. This is useful when
    executing terraform on multiple machines (or working as a team) because it allows state to remain in sync.
  * If the state file already exists in S3, you _may_ be prompted to create a local copy.

## Bringing up the stack

If you are bringing up the stack for the first time, you need to let it create the database before it can plan
out the rest of the process. This is due to how Terraform handles provider dependencies. If the stack already has
an RDS instance under its control, you can skip the targeted step.

To see the changes Terraform will make:

    terraform plan -target aws_db_instance.db

To actually make those changes:

    terraform apply -target aws_db_instance.db

Once the database is created, you can proceed with `terraform plan` and `terraform apply` to see and apply changes to
the stack. Changes you make to the `*.tf` files in the root directory will automatically be reflected in the resources
under Terraform's control.
