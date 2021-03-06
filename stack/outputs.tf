# Variable Passthroughs

output "aws_region" {
  value = "${var.aws_region}"
}

output "azs" {
  value = "${local.azs}"
}

output "ec2_keyname" {
  value = "${local.ec2_keyname}"
}

output "ec2_private_keyfile" {
  value = "${local.ec2_private_keyfile}"
}

output "environment" {
  value = "${local.environment}"
}

output "hosted_zone_name" {
  value = "${local.hosted_zone_name}"
}

output "stack_name" {
  value = "${var.stack_name}"
}

output "subnet_config" {
  value = "${local.subnet_config}"
}

output "tags" {
  value = "${local.tags}"
}

output "vpc_cidr_block" {
  value = "${local.vpc_cidr_block}"
}

# Security Groups

output "security_groups" {
  value = {
    bastion    = "${aws_security_group.bastion.id}"
    cache      = "${aws_security_group.redis.id}"
    cantaloupe = "${module.cantaloupe_service.lb_security_group}"
    db         = "${aws_security_group.db.id}"
    fcrepo     = "${module.fcrepo_environment.security_group_id}"
    index      = "${module.solr_environment.security_group_id}"
    zookeeper  = "${module.zookeeper_environment.security_group_id}"
  }
}

# Resource Outputs

output "application_source_bucket" {
  value = "${aws_s3_bucket.app_sources.id}"
}

output "bastion_address" {
  value = "${aws_route53_record.bastion.name}"
}

output "cache_address" {
  value = "${aws_route53_record.redis.name}"
}

output "cache_port" {
  value = "${aws_elasticache_cluster.redis.cache_nodes.0.port}"
}

output "zookeeper_address" {
  value = "zk.${local.private_zone_name}"
}

output "zookeeper_port" {
  value = "2181"
}

output "db_address" {
  value = "${module.db.this_db_instance_address}"
}

output "db_port" {
  value = "${module.db.this_db_instance_port}"
}

output "db_master_username" {
  value = "${module.db.this_db_instance_username}"
}

output "db_master_password" {
  value = "${module.db.this_db_instance_password}"
}

output "elasticsearch_endpoint" {
  value = "https://${aws_elasticsearch_domain.elasticsearch.endpoint}/"
}

output "exhibitor_endpoint" {
  value = "http://${aws_route53_record.zookeeper.name}/exhibitor/v1/ui/index.html"
}

output "iiif_endpoint" {
  value = "http://${element(concat(aws_cloudfront_distribution.cantaloupe.*.domain_name, list(aws_route53_record.cantaloupe.name)), 0)}/iiif/2"
}

output "iiif_pyramid_bucket" {
  value = "${aws_s3_bucket.pyramid_tiff_bucket.id}"
}

output "iiif_pyramid_bucket_arn" {
  value = "${aws_s3_bucket.pyramid_tiff_bucket.arn}"
}

output "index_endpoint" {
  value = "http://${aws_route53_record.solr.name}/solr/"
}

output "private_subnets" {
  value = "${module.vpc.private_subnets}"
}

output "private_zone_id" {
  value = "${module.dns.private_zone_id}"
}

output "public_subnets" {
  value = "${module.vpc.public_subnets}"
}

output "public_zone_id" {
  value = "${module.dns.public_zone_id}"
}

output "repo_endpoint" {
  value = "http://${aws_route53_record.fcrepo.name}/rest"
}

output "send_email_policy_arn" {
  value = "${aws_iam_policy.send_email.arn}"
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}
