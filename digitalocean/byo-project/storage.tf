resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "digitalocean_spaces_bucket" "software_installers" {
  name   = "${var.prefix}-installers-${random_id.bucket_suffix.hex}"
  region = var.region
  acl    = "private"

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}
