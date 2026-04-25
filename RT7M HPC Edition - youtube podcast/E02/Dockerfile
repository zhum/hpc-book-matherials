FROM ubuntu:latest

# Prevent interactive prompts
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles
# ^ Or Etc/UTC

# Install ssh, MariaDB client, and networking tools
RUN apt-get update && \
    apt-get install -y ubuntu-minimal && \
    rm /etc/dpkg/dpkg.cfg.d/excludes && \
    apt-get install -y \
    mariadb-client \
    slurm-client \
    tzdata \
    openssh-client \
    openssh-server \
    iputils-ping \
    curl \
    vim && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get clean

# Ensure Slurm directories exist with correct permissions
RUN mkdir -p /run/sshd /var/spool/slurmd /var/spool/slurmctld /var/log/slurm && \
    chown slurm:slurm /var/spool/slurmd /var/spool/slurmctld /var/log/slurm 

RUN adduser tester && mkdir /home/tester/.ssh && \
    ssh-keygen -t ecdsa -N '' -f /home/tester/.ssh/id_ecdsa && \
    cat /home/tester/.ssh/id_ecdsa.pub > /home/tester/.ssh/authorized_keys && \
    chown -R tester /home/tester/.ssh

RUN ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa && \
    cat /root/.ssh/id_ecdsa.pub > /root/.ssh/authorized_keys

CMD ["tail", "-f", "/dev/null"]

