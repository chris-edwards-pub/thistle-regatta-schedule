# --- Container Service ---

resource "aws_lightsail_container_service" "app" {
  name  = var.instance_name
  power = var.container_power
  scale = var.container_scale

  public_domain_names {
    certificate {
      certificate_name = aws_lightsail_certificate.app.name
      domain_names     = ["www.${var.domain_name}"]
    }
  }

  tags = {
    Project = "race-crew-network"
  }
}

# --- SSL Certificate ---

resource "aws_lightsail_certificate" "app" {
  name        = "${var.instance_name}-cert"
  domain_name = "www.${var.domain_name}"
}

# DNS validation record for the SSL certificate
resource "aws_route53_record" "cert_validation" {
  zone_id = var.route53_zone_id
  name    = tolist(aws_lightsail_certificate.app.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_lightsail_certificate.app.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_lightsail_certificate.app.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

# --- Managed MySQL Database ---

resource "aws_lightsail_database" "app" {
  relational_database_name = "${var.instance_name}-db"
  availability_zone        = var.availability_zone
  master_database_name     = var.db_name
  master_username          = var.db_username
  master_password          = var.db_password
  blueprint_id             = "mysql_8_0"
  bundle_id                = var.db_bundle_id
  publicly_accessible      = true

  tags = {
    Project = "race-crew-network"
  }
}

# --- Object Storage (S3-compatible) ---

resource "aws_lightsail_bucket" "uploads" {
  name      = "${var.instance_name}-uploads"
  bundle_id = "small_1_0"

  tags = {
    Project = "race-crew-network"
  }
}

resource "aws_lightsail_bucket_access_key" "app" {
  bucket_name = aws_lightsail_bucket.uploads.name
}

# --- Container Deployment ---

resource "aws_lightsail_container_service_deployment_version" "app" {
  service_name = aws_lightsail_container_service.app.name

  container {
    container_name = "web"
    image          = var.ghcr_image

    environment = {
      DATABASE_URL          = "mysql+pymysql://${var.db_username}:${var.db_password}@${aws_lightsail_database.app.master_endpoint_address}:${aws_lightsail_database.app.master_endpoint_port}/${var.db_name}"
      SECRET_KEY            = var.secret_key
      UPLOAD_FOLDER         = "/app/uploads"
      BUCKET_NAME           = aws_lightsail_bucket.uploads.name
      AWS_ACCESS_KEY_ID     = aws_lightsail_bucket_access_key.app.access_key_id
      AWS_SECRET_ACCESS_KEY = aws_lightsail_bucket_access_key.app.secret_access_key
      AWS_REGION            = var.aws_region
    }

    ports = {
      8000 = "HTTP"
    }
  }

  public_endpoint {
    container_name = "web"
    container_port = 8000

    health_check {
      path             = "/"
      success_codes    = "200-499"
      interval_seconds = 30
      timeout_seconds  = 5
    }
  }
}

# --- DNS ---
# www subdomain CNAME pointing to the container service.

resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [replace(aws_lightsail_container_service.app.url, "/^https?://|/$/", "")]
}

# Naked domain redirect: S3 bucket redirects racecrew.net -> www.racecrew.net
# Route 53 alias at zone apex points to the S3 website endpoint.

resource "aws_s3_bucket" "redirect" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  redirect_all_requests_to {
    host_name = "www.${var.domain_name}"
    protocol  = "https"
  }
}

resource "aws_route53_record" "apex" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_s3_bucket_website_configuration.redirect.website_domain
    zone_id                = aws_s3_bucket.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}
