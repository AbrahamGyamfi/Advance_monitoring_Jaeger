resource "null_resource" "deploy_app" {
  depends_on = [var.app_instance_id]

  triggers = {
    instance_id           = var.app_instance_id
    image_tag             = var.image_tag
    docker_registry       = var.docker_registry
    aws_region            = var.aws_region
    monitoring_private_ip = var.monitoring_private_ip
    compose_file_sha      = filesha256("${path.root}/../docker-compose.prod.yml")
    promtail_config_sha   = filesha256("${path.root}/../monitoring/config/promtail-app.yml")
  }

  provisioner "file" {
    source      = "${path.root}/../docker-compose.prod.yml"
    destination = "/home/ec2-user/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }

  provisioner "file" {
    source      = "${path.root}/../monitoring/config/promtail-app.yml"
    destination = "/home/ec2-user/promtail-config.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo cloud-init status --wait || true",
      "sudo systemctl is-active --quiet docker || sudo systemctl start docker",
      "sed -i 's/MONITORING_PRIVATE_IP/${var.monitoring_private_ip}/g' /home/ec2-user/promtail-config.yml",
      "sed -i 's/APP_PUBLIC_IP/${var.app_public_ip}/g' /home/ec2-user/promtail-config.yml",
      "printf 'REGISTRY_URL=%s\\nIMAGE_TAG=%s\\nAWS_REGION=%s\\nMONITORING_HOST=%s\\n' '${var.docker_registry}' '${var.image_tag}' '${var.aws_region}' '${var.monitoring_private_ip}' > /home/ec2-user/.taskflow.env",
      "sudo docker rm -f node-exporter || true",
      "sudo docker run -d --name node-exporter --restart unless-stopped -p 9100:9100 prom/node-exporter:v1.8.2",
      "aws ecr get-login-password --region ${var.aws_region} | sudo docker login --username AWS --password-stdin ${var.docker_registry}",
      "sudo docker pull ${var.docker_registry}/taskflow-backend:${var.image_tag}",
      "sudo docker pull ${var.docker_registry}/taskflow-frontend:${var.image_tag}",
      "sudo /usr/local/bin/docker-compose --env-file /home/ec2-user/.taskflow.env -f /home/ec2-user/docker-compose.yml down || true",
      "sudo /usr/local/bin/docker-compose --env-file /home/ec2-user/.taskflow.env -f /home/ec2-user/docker-compose.yml up -d",
      "sudo docker rm -f promtail || true",
      "sudo docker run -d --name promtail --restart unless-stopped -v /var/lib/docker/containers:/var/lib/docker/containers:ro -v /var/run/docker.sock:/var/run/docker.sock:ro -v /home/ec2-user/promtail-config.yml:/etc/promtail/config.yml:ro grafana/promtail:3.1.1 -config.file=/etc/promtail/config.yml",
      "bash -c 'for i in {1..12}; do sudo docker ps --filter name=node-exporter --filter status=running --format ''{{.Names}}'' | grep -q node-exporter && exit 0; sleep 5; done; echo ''Node exporter failed to start''; exit 1'",
      "bash -c 'for i in {1..12}; do sudo docker ps --filter name=promtail --filter status=running --format ''{{.Names}}'' | grep -q promtail && exit 0; sleep 5; done; echo ''Promtail failed to start''; exit 1'",
      "bash -c 'for i in {1..18}; do curl -fsS http://localhost/health > /dev/null && exit 0; sleep 10; done; echo ''Application health check failed''; exit 1'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = var.app_public_ip
    }
  }
}
