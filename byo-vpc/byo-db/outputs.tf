output "byo-ecs" {
  value = module.ecs
}

output "cluster" {
  value = module.cluster
}

output "alb" {
  value = var.alb_config.enabled ? merge(module.alb[0], {
    lb_dns_name               = module.alb[0].dns_name
    lb_zone_id                = module.alb[0].zone_id
    target_group_names        = [for k, tg in module.alb[0].target_groups : tg.name]
    target_group_arn_suffixes = [for k, tg in module.alb[0].target_groups : tg.arn_suffix]
    target_group_arns         = [for k, tg in module.alb[0].target_groups : tg.arn]
    lb_arn_suffix             = module.alb[0].arn_suffix
  }) : null
}
