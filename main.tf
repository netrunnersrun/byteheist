# Define the provider and its configuration. 
# In this case, it's Google Cloud Platform (GCP).

provider "google" {
  # Path to the JSON file containing your GCP credentials.
  credentials = file("/path/to/service/account/key/gcpservicekey.json")
  project     = "gold-pier-406022"   # GCP project ID.
  region      = "us-central1"        # Default region for resources.
  zone        = "europe-central2-a"
}

# Declare a resource of type 'google_compute_instance' to create a VM instance.
resource "google_compute_instance" "vm_instance" {
  name         = "deploybyteheist"   # VM instance name
  machine_type = "e2-medium"         # VM instance size/computer power

# Configuration for the boot disk of the VM.
# The image variable is used to specify the VM linux distro.
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11-bullseye-v20240110"
    }
  }

# Network interface configuration.
  network_interface {
    network = "default"   # The network to attach this interface to.
    access_config {       # Configuration for the access config (enables an external IP).
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y python3
    mkdir -p /home/alex/byteheist   # Create the byteheist folder to transfer content there.
    chown alex:alex /home/alex/byteheist  # Change ownership to user 'alex'
  EOT

# Content from 'byteHeist_v1' will be copied to the GCP VM instance at '/home/alex/byteheist/'
  provisioner "file" {
    source      = "/Users/dom/SynologyDrive/1.coding/6.byteHeist/byteHeist_v1/" 
    destination = "/home/alex/byteheist/"
  }
# This area executes commands on the newly create GCP VM Instance.
  provisioner "remote-exec" {
    inline = [
      "chmod 755 /home/alex/byteheist",         # Change permissions of the directory.
      "chmod +x /home/alex/byteheist/setup.sh", # Make setup.sh executable.
      "/home/alex/byteheist/setup.sh",          # execute setup.sh
      # Start the Flask app in the background and save stdout(1) and stderr(2) to server.log
      "sudo bash -c 'nohup python3 /home/alex/byteheist/server.py > /home/alex/byteheist/server.log 2>&1 &'",
      "sleep 5", # Pause the script 5 seconds so terraform doesnt cut the ssh connection to the VM before the App fully starts.
    ]
  }

# SSH connection configuration for remote-exec provisioner.
  connection {
    type        = "ssh"
    user        = "alex"
    private_key = file("/Users/dom/.ssh/id_ed25519")
    host        = self.network_interface[0].access_config[0].nat_ip
  }
}

# Output the external IP address of the newly created VM instance.
output "instance_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

# Null resource to run local commands after the VM instance is created.
resource "null_resource" "local_commands" {
  depends_on = [google_compute_instance.vm_instance]

# Local-exec provisioner to run commands on the machine where Terraform is executed.
  provisioner "local-exec" {
    command = <<EOT
      gcloud config set compute/zone europe-central2-a
      gcloud compute instances add-tags deploybyteheist --tags http-server,https-server
    EOT
  }
}
