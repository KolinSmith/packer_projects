packer {
 required_plugins = {
    docker = {
        version = ">= 1.0.0"
        source = "github.com/hashicorp/docker"
    }
 }
}

source "docker" "ghsr" {
    image = var.image
    commit = true
}

build {
    "ghsr-docker-build"
    sources = ["source.docker.ghsr"]


    provisioner "file" {
        var.install_script_path
        destination = "/tmp/start.sh"
    }

    provisioner "file" {
        var.private_key
        destination = "/tmp/github-app.pem"
    }

    provisioner "shell" {
        inline = [
            "echo 'Runner version: ${var.runner_version}'".
        ]
    }
    
    provisioner "shell" {
        inline = [
            "echo 'Install dependencies ...'",
            "apt-get update -y && apt-get upgrade -y && useradd -m docker",
            "apt-get update && apt-get install -y apt-utils",
            "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommmends curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip",
            "DEBIAN_FRONTEND=noninteractive apt-get install -y libicu66 tzdata",
            "mkdir -p /home/docker/actions-runner",
            "echo 'export GH_APP_ID=${var.app_id}' >> /home/docker/.bashrc",
            "echo 'export GH_ORG=${var.organization}' >> /home/docker/.bashrc",
            "echo 'export GH_INSTALL=${var.gh_install}' >> /home/docker/.bashrc",
            "echo 'export GH_APP_CLIENT_ID=${var.app_client_id}' >> /home/docker/.bashrc",
            "echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> /home/docker/.bash_profile",
            "usermod -s /bin/bash docker",
            "curl -O -L http://github.com/actions/runner/releases/download/v${var.runner_version}/actions-runner-linux-x64-${var.runner_version}.tar.gz", 
            "tar xzf /home/docker/actions-runner/actions-runner-linux-x64-${var.runner_version}.tar.gz -C /home/docker/actions-runner",
            "chown -R docker:docker /home/docker/actions-runner",
            "mv /tmp/start.sh /home/docker/start.sh",
            "mv /tmp/github-app.pem /home/docker/github-app.pem",
            "echo 'export PRIVATE_KEY_PATH=/home/docker/github-app.pem' >> /home/docker/.bashrc",
            "chown -R docker:docker /home/docker",
            "chmod +x /home/docker/bin/installdependencies.sh",
            "/home/docker/bin/installdependencies.sh",
            "chown -R docker:docker /home/docker"
        ]
    }

    provisioner {
        inline = [
            "echo 'Install Vim & other dependencies for JIT runners ...",
            "apt-get update",
            "apt-get install -y vim jq openssl coreutils"
        ]
    }

    provisioner {
        inline = {
            "echo 'Configure the runner ...'"
            "chmod +x /home/docker/start.sh",
            "chmod +x /home/docker/config.sh",
            "chmod +x /home/docker/run.sh"
        }
    }

    post-processor "docker-tag" {
        repository = "${var.acr_login_server}/github-runner"
        tag = var.tag
    }



}

