resource "aws_security_group" "sg_msk" {
  name   = "sg_msk"
  vpc_id = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_outbound" {
  name   = "sg_outbound"
  vpc_id = aws_vpc.custom_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_kms_key" "kms_key" {
  description = "KMS Key for MSK"
  deletion_window_in_days = 7
}
resource "aws_cloudwatch_log_group" "kafka_log_group" {
  name = "kafka_broker_logs"
}
resource "aws_msk_configuration" "kafka_config" {
  kafka_versions    = ["3.4.0"] 
  name              = "mskcluster1"
  server_properties = <<EOF
auto.create.topics.enable = true
delete.topic.enable = true
EOF
}

resource "aws_msk_cluster" "msk_cluster" {
  cluster_name = "mskcluster1"
  kafka_version = "3.4.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large" # default value
    client_subnets  = [aws_subnet.private_subnet3.id, aws_subnet.private_subnet4.id]
    storage_info {
      ebs_storage_info {
        volume_size = 1000
      }
    }
    security_groups = [aws_security_group.sg_msk.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT"
      in_cluster    = true
    }

    encryption_at_rest_kms_key_arn = aws_kms_key.kms_key.arn
  }
  configuration_info {
    arn      = aws_msk_configuration.kafka_config.arn
    revision = aws_msk_configuration.kafka_config.latest_revision
  }
  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.kafka_log_group.name
      }
    }
  }
}



/*output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.arn
}*/

output "msk_cluster_zookeeper_connect_string" {
  description = "Zookeeper connect string of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.zookeeper_connect_string
}

output "msk_cluster_bootstrap_brokers" {
  description = "Bootstrap broker endpoints of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers
}
# la création des fonctions lamda pour la production ou la consommation dans environnement KAFKA

