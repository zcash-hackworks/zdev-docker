FROM ubuntu:18.04

COPY * /root/docker/
RUN /root/docker/install-basics.sh
RUN /root/docker/install-build-dependencies.sh

# Set environment variables.
ENV HOME /root

# Define working directory.
WORKDIR /root

# Define default command.
CMD ["bash"]
