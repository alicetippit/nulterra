locals {
  app_name = "arch"
}

resource "random_id" "secret_key_base" {
  byte_length = 32
}

resource "random_pet" "app_version_name" {
  keepers = {
    source = "${data.archive_file.arch_source.output_md5}"
  }
}

module "arch_derivative_volume" {
  source  = "cloudposse/efs/aws"
  version = "0.3.3"

  namespace          = "${data.terraform_remote_state.stack.stack_name}"
  stage              = "${local.app_name}"
  name               = "derivatives"
  aws_region         = "${data.terraform_remote_state.stack.aws_region}"
  vpc_id             = "${data.terraform_remote_state.stack.vpc_id}"
  subnets            = "${data.terraform_remote_state.stack.private_subnets}"
  availability_zones = ["${data.terraform_remote_state.stack.azs}"]
  security_groups    = [
    "${module.webapp.security_group_id}",
    "${module.worker.security_group_id}",
    "${module.batch_worker.security_group_id}"
  ]

  zone_id = "${data.terraform_remote_state.stack.private_zone_id}"

  tags = "${local.common_tags}"
}

module "arch_working_volume" {
  source  = "cloudposse/efs/aws"
  version = "0.3.3"

  namespace          = "${data.terraform_remote_state.stack.stack_name}"
  stage              = "${local.app_name}"
  name               = "working"
  aws_region         = "${data.terraform_remote_state.stack.aws_region}"
  vpc_id             = "${data.terraform_remote_state.stack.vpc_id}"
  subnets            = "${data.terraform_remote_state.stack.private_subnets}"
  availability_zones = ["${data.terraform_remote_state.stack.azs}"]
  security_groups    = [
    "${module.webapp.security_group_id}",
    "${module.worker.security_group_id}",
    "${module.batch_worker.security_group_id}"
  ]

  zone_id = "${data.terraform_remote_state.stack.private_zone_id}"

  tags = "${local.common_tags}"
}

data "archive_file" "arch_source" {
  type        = "zip"
  source_dir  = "${path.module}/application"
  output_path = "${path.module}/build/${local.app_name}.zip"
}

resource "aws_s3_bucket_object" "arch_source" {
  bucket = "${data.terraform_remote_state.stack.application_source_bucket}"
  key    = "${local.app_name}-${random_pet.app_version_name.id}.zip"
  source = "${data.archive_file.arch_source.output_path}"
  etag   = "${data.archive_file.arch_source.output_md5}"
}

resource "aws_elastic_beanstalk_application" "arch" {
  name = "${local.namespace}-${local.app_name}"
}

resource "aws_elastic_beanstalk_application_version" "arch" {
  depends_on = [
    "aws_elastic_beanstalk_application.arch",
    "module.arch_derivative_volume",
    "module.arch_working_volume"
  ]
  description     = "application version created by terraform"
  bucket          = "${data.terraform_remote_state.stack.application_source_bucket}"
  application     = "${local.namespace}-${local.app_name}"
  key             = "${local.app_name}-${random_pet.app_version_name.id}.zip"
  name            = "${random_pet.app_version_name.id}"
}

module "archdb" {
  source          = "../../modules/database"
  schema          = "${local.app_name}"
  host            = "${data.terraform_remote_state.stack.db_address}"
  port            = "${data.terraform_remote_state.stack.db_port}"
  master_username = "${data.terraform_remote_state.stack.db_master_username}"
  master_password = "${data.terraform_remote_state.stack.db_master_password}"

  connection = {
    user        = "ec2-user"
    host        = "${data.terraform_remote_state.stack.bastion_address}"
    private_key = "${file(data.terraform_remote_state.stack.ec2_private_keyfile)}"
  }
}

resource "aws_sqs_queue" "arch_ui_fifo_deadletter_queue" {
  name                        = "${data.terraform_remote_state.stack.stack_name}-arch-ui-dead-letter-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  tags                        = "${local.common_tags}"
}

resource "aws_sqs_queue" "arch_ui_fifo_queue" {
  name                        = "${data.terraform_remote_state.stack.stack_name}-arch-ui-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  delay_seconds               = 0
  visibility_timeout_seconds  = 3600
  redrive_policy              = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.arch_ui_fifo_deadletter_queue.arn}\",\"maxReceiveCount\":5}"
  tags                        = "${local.common_tags}"
}

resource "aws_sqs_queue" "arch_batch_fifo_deadletter_queue" {
  name                        = "${data.terraform_remote_state.stack.stack_name}-arch-batch-dead-letter-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  tags                        = "${local.common_tags}"
}

resource "aws_sqs_queue" "arch_batch_fifo_queue" {
  name                        = "${data.terraform_remote_state.stack.stack_name}-arch-batch-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  delay_seconds               = 0
  visibility_timeout_seconds  = 3600
  redrive_policy              = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.arch_batch_fifo_deadletter_queue.arn}\",\"maxReceiveCount\":5}"
  tags                        = "${local.common_tags}"
}

resource "aws_s3_bucket" "arch_batch" {
  bucket = "${local.namespace}-arch-batch"
  acl    = "private"
  tags   = "${local.common_tags}"
}

resource "aws_s3_bucket" "arch_dropbox" {
  bucket = "${local.namespace}-arch-dropbox"
  acl    = "private"
  tags   = "${local.common_tags}"
}

resource "aws_s3_bucket" "arch_uploads" {
  bucket = "${local.namespace}-arch-uploads"
  acl    = "private"
  tags   = "${local.common_tags}"
}

data "aws_iam_policy_document" "arch_bucket_access" {
  statement {
    effect = "Allow"
    actions = ["s3:ListAllMyBuckets"]
    resources = ["arn:aws:s3:::*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "${aws_s3_bucket.arch_batch.arn}",
      "${aws_s3_bucket.arch_dropbox.arn}",
      "${aws_s3_bucket.arch_uploads.arn}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.arch_batch.arn}/*",
      "${aws_s3_bucket.arch_dropbox.arn}/*",
      "${aws_s3_bucket.arch_uploads.arn}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "sqs:ListQueues",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "arch_bucket_policy" {
  name = "${data.terraform_remote_state.stack.stack_name}-${local.app_name}-bucket-access"
  policy = "${data.aws_iam_policy_document.arch_bucket_access.json}"
}

data "aws_iam_policy_document" "arch_batch_ingest_access" {
  statement {
    effect    = "Allow"
    actions   = ["iam:Passrole"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:*"]
    resources = ["${aws_sqs_queue.arch_batch_fifo_queue.arn}"]
  }
}

module "arch_batch_ingest" {
  source = "git://github.com/claranet/terraform-aws-lambda"

  function_name = "${data.terraform_remote_state.stack.stack_name}-${local.app_name}-batch-ingest"
  description   = "Batch Ingest trigger for ${local.app_name}"
  handler       = "index.handler"
  runtime       = "nodejs8.10"
  timeout       = 300

  attach_policy = true
  policy        = "${data.aws_iam_policy_document.arch_batch_ingest_access.json}"

  source_path = "${path.module}/lambdas/batch_ingest_notification"
  environment {
    variables {
      JobClassName = "S3ImportJob"
      Secret = "${random_id.secret_key_base.hex}"
      QueueUrl = "${aws_sqs_queue.arch_batch_fifo_queue.id}"
    }
  }
}

resource "aws_lambda_permission" "allow_trigger" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${module.arch_batch_ingest.function_arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.arch_batch.arn}"
}

resource "aws_s3_bucket_notification" "batch_ingest_notification" {
  bucket     = "${aws_s3_bucket.arch_batch.id}"
  lambda_function {
    lambda_function_arn = "${module.arch_batch_ingest.function_arn}"
    filter_suffix       = ".csv"
    events = [
      "s3:ObjectCreated:Put",
      "s3:ObjectCreated:Post",
      "s3:ObjectCreated:CompleteMultipartUpload"
    ]
  }
}

data "null_data_source" "ssm_parameters" {
  inputs = "${map(
    "aws/buckets/batch",        "${aws_s3_bucket.arch_batch.id}",
    "aws/buckets/dropbox",      "${aws_s3_bucket.arch_dropbox.id}",
    "aws/buckets/uploads",      "${aws_s3_bucket.arch_uploads.id}",
    "domain/host",              "${local.app_name}.${data.terraform_remote_state.stack.stack_name}.${data.terraform_remote_state.stack.hosted_zone_name}",
    "geonames_username",        "nul_rdc",
    "solr/url",                 "${data.terraform_remote_state.stack.index_endpoint}arch",
    "zookeeper/connection_str", "${data.terraform_remote_state.stack.zookeeper_address}:2181/configs"
  )}"
}

resource "aws_ssm_parameter" "arch_config_setting" {
  count = 9
  name  = "/${data.terraform_remote_state.stack.stack_name}-${local.app_name}/Settings/${element(keys(data.null_data_source.ssm_parameters.outputs), count.index)}"
  type  = "String"
  value = "${lookup(data.null_data_source.ssm_parameters.outputs, element(keys(data.null_data_source.ssm_parameters.outputs), count.index))}"
}
