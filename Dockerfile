# CLion remote docker environment (How to build docker container, run and stop it)
#
# Build and run:
#   docker build -t clion/centos7-cpp-env:0.1 -f Dockerfile.centos7-cpp-env .
#   docker run -d --cap-add sys_ptrace -p127.0.0.1:2222:22 clion/centos7-cpp-env:0.1
#   ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2222"
#
# stop:
#   docker stop clion_remote_env
# 
# ssh credentials (test user):
#   user@password 

FROM centos:7

#Install custom packages
RUN yum install -y epel-release
RUN yum -y update && yum clean all

RUN yum groupinstall -y "Development Tools"
RUN yum -y install openssh-server \
        build-essentail \
        clang \
        texinfo \
        tar \
        wget \
        rsync \
        python \
        sudo \
        vim \
        pandoc

RUN mkdir -p /opt/cmake;\
    curl -L -s -S \
        https://cmake.org/files/v3.1/cmake-3.1.0-Linux-x86_64.tar.gz \
        -o /opt/cmake.tar.gz;\
    tar xzf /opt/cmake.tar.gz --strip-components 1 -C /opt/cmake
ENV CMAKE_HOME /opt/cmake
ENV PATH "/opt/cmake/bin:${PATH}"

#compile gdb to CLion support

RUN mkdir /temp

RUN cd /temp;\
    wget https://ftp.gnu.org/gnu/gdb/gdb-9.2.tar.gz;\
    tar -xf gdb-9.2.tar.gz;\
    cd gdb-9.2;\
    mkdir build;\
    cd build;\
    ../configure --prefix=/usr;\
    make -j;\
    make install

# ssh

RUN ssh-keygen -A

RUN ( \
        echo 'LogLevel DEBUG2'; \
        echo 'PermitRootLogin yes'; \
        echo 'PasswordAuthentication yes'; \
        echo 'Subsystem sftp /usr/libexec/openssh/sftp-server'; \
    ) > /etc/ssh/sshd_config_test_clion

RUN echo 'root:ihepcc' | chpasswd

RUN useradd -m xialb;\
    yes ihepcc | passwd xialb;\
    usermod -aG wheel xialb

CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config_test_clion"]

######
## Install Apache Maven 3.3.9 (3.3.9 ships with Xenial)
#######
RUN curl -L -S -s \
        https://downloads.apache.org/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
        -o /temp/maven.tar.gz;\
    cd /temp;\
    tar xvf maven.tar.gz -C /opt
ENV PATH "/opt/apache-maven-3.3.9/bin:${PATH}"


# JAVA ENV
RUN yum install -y java-1.8.0-openjdk-devel maven
RUN echo 'JAVA_HOME=/usr/lib/jvm/java' >> /etc/environment

RUN cd /temp;\
    git config --global http.proxy http://172.16.0.2:10809;\
    git clone https://github.com/protocolbuffers/protobuf;\
    cd protobuf;\
    git checkout v2.5.0;\
    autoreconf -i;\
    ./configure --prefix=/usr/local;\
    make;\
    sudo make install

RUN yum install -y install libtirpc-devel \
    zlib-devel \
    lz4-devel \
    bzip2-devel \
    openssl-devel \
    cyrus-sasl-devel \
    libpmem-devel

# Hadoop compile optional
RUN yum install -y snappy-devel \
    libzstd-devel \
    fuse-devel \
    fuse

RUN wget https://www.nasm.us/pub/nasm/releasebuilds/2.13.02/linux/nasm-2.13.02-0.fc24.x86_64.rpm;\
    rpm -i nasm-2.13.02-0.fc24.x86_64.rpm

RUN cd /temp;\
    git config --global http.proxy http://172.16.0.2:10809;\
    git clone https://github.com/intel/isa-l;\
    cd isa-l/;\
    ./autogen.sh;\
    ./configure;\
    make;\
    make install

#spark
RUN cd /temp;\
    curl -S -s -L https://downloads.lightbend.com/scala/2.12.10/scala-2.12.10.rpm \
        -o scala.rpm;\
    rpm -i scala.rpm


RUN echo "export $(cat /proc/1/environ |tr '\0' '\n' |sed 's/HOME=\/root//g'| xargs)" >> /etc/profile 
RUN sed -i 's/HOME=\/root//g' /etc/profile
RUN rm -rf /opt/*.gz

# Hadoop
ENV HADOOP_HOME /opt/hadoop
ENV PATH "${HADOOP_HOME}/bin:${PATH}"

# HDFS NN DN NN_ui DN_ui
EXPOSE 9820:9820 9866:9866 9870:9870 9864:9864

#YARN web_ui
EXPOSE 8088:8088

#Spark master_comm history_server_web master_web worker_web driver_sch_web
EXPOSE 7077:7077 18080:18080 8080:8080 8081:8081 4044:4044



# ====================================================
# !!! BE CAREFULL !!! ONLY BE USED IN IHEP CLUSTER !!!
# ====================================================

# expect for ssh & sync 
#
#RUN echo $'\
#spawn rsync -a root@helion01.ihep.ac.cn:/home/xialb/data/docker/* /opt \n\
#expect "(yes\/no)" \n\
#send "yes\\r" \n\
#expect "password:" \n\ 
#send "ihep;test\\r" \n\
#interact' > /temp/rsync.exp
#
#RUN yum -y install expect
#RUN whoami
#RUN expect /temp/rsync.exp

COPY --chown=xialb:xialb opt/ /opt

ENV JAVA_HOME /usr/lib/jvm/java
ENV HADOOP_HOME /opt/hadoop
ENV SPARK_HOME /opt/spark
ENV OMPI_HOME /opt/ompi
ENV PATH ${HADOOP_HOME}/bin:${SPARK_HOME}/bin:${OMPI_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH "${JAVA_HOME}/jre/lib/amd64/server:${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}"

# hadoop operations

RUN su -c "\
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa;\
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys;\
    chmod 0600 ~/.ssh/authorized_keys" xialb
