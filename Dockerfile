# Blaze remote development docker environment 


FROM centos:7

# Install custom packages
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


###        
# Install cmake 3.1.0
###
RUN mkdir -p /opt/cmake;\
    curl -L -s -S \
        https://cmake.org/files/v3.1/cmake-3.1.0-Linux-x86_64.tar.gz \
        -o /opt/cmake.tar.gz;\
    tar xzf /opt/cmake.tar.gz --strip-components 1 -C /opt/cmake
ENV CMAKE_HOME /opt/cmake
ENV PATH "/opt/cmake/bin:${PATH}"


###
# Compile gdb 9.2 to CLion support
###
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


# ssh login support 
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


###
## Install Apache Maven 3.3.9 (3.3.9 ships with Xenial)
###
RUN curl -L -S -s \
        https://downloads.apache.org/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
        -o /temp/maven.tar.gz;\
    cd /temp;\
    tar xvf maven.tar.gz -C /opt
ENV PATH "/opt/apache-maven-3.3.9/bin:${PATH}"


# JAVA ENV
RUN yum install -y java-1.8.0-openjdk-devel maven
RUN echo 'JAVA_HOME=/usr/lib/jvm/java' >> /etc/environment
ENV JAVA_HOME /usr/lib/jvm/java


###
# Install Google Protobuffer 2.5.0
###
RUN cd /temp;\
    git clone https://github.com/protocolbuffers/protobuf;\
    cd protobuf;\
    git checkout v2.5.0;\
    autoreconf -i;\
    ./configure --prefix=/usr/local;\
    make;\
    sudo make install


# Option support for Hadoop native library
RUN yum install -y install libtirpc-devel \
    zlib-devel \
    lz4-devel \
    bzip2-devel \
    openssl-devel \
    cyrus-sasl-devel \
    libpmem-devel

RUN yum install -y snappy-devel \
    libzstd-devel \
    fuse-devel \
    fuse

RUN cd /temp;\
    curl -S -s -L \
        https://www.nasm.us/pub/nasm/releasebuilds/2.13.02/linux/nasm-2.13.02-0.fc24.x86_64.rpm \
        -o /temp/nasm.rpm;\
    rpm -i nasm.rpm

RUN cd /temp;\
    git clone https://github.com/intel/isa-l;\
    cd isa-l/;\
    ./autogen.sh;\
    ./configure;\
    make;\
    make install


###
# Install Scala-2.12.10
###
RUN cd /temp;\
    curl -S -s -L \
        https://downloads.lightbend.com/scala/2.12.10/scala-2.12.10.rpm \
        -o scala.rpm;\
    rpm -i scala.rpm


# Enable ENV to ssh environment 
RUN echo "export $(cat /proc/1/environ |tr '\0' '\n' |sed 's/HOME=\/root//g'| xargs)" >> /etc/profile 
RUN sed -i 's/HOME=\/root//g' /etc/profile
RUN rm -rf /opt/*.gz


# Hadoop
ENV HADOOP_HOME /opt/hadoop
ENV PATH "${HADOOP_HOME}/bin:${PATH}"


###
# Expose port mapping
###
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

#COPY --chown=xialb:xialb opt/ /opt


###
# Build Hadoop 3.2.0
###
RUN cd /temp;\
    git clone https://github.com/bentleyxia/hadoop.git;\
    cd hadoop;\
    git switch branch-3.2.0;\
    mvn clean package -Pdist,native -DskipTests -Dtar;\
    tar xvf hadoop-dist/target/hadoop-3.2.0.tar.gz -C /opt

ENV HADOOP_HOME /opt/hadoop-3.2.0

# Hadoop native lib
ENV LD_LIBRARY_PATH "${JAVA_HOME}/jre/lib/amd64/server:${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}"

RUN su -c "\
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa;\
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys;\
    chmod 0600 ~/.ssh/authorized_keys" xialb

###
# Build Spark 3.0.1
###

RUN cd temp;\
    git clone https://github.com/bentleyxia/spark.git;\
    cd spark;\
    git switch branch-3.0;\
    export MAVEN_OPTS="-Xmx2g -XX:ReservedCodeCacheSize=1g";\
    ./build/mvn -Pyarn -Pkubernetes -Dhadoop.version=3.2.0 -DskipTests clean package;\
    cd ..;\
    cp -r spark /opt

ENV SPARK_HOME /opt/spark


### 
# Build OpenMPI debug version
###
RUN cd /temp;\
    git clone https://github.com/bentleyxia/ompi.git;\
    cd ompi;\
    ./autogen.pl;\
    ./configure --prefix=/opt/ompi --enable-mpi-java --enable-debug --enable-mem-debug --enable-mem-profile;\
    make;\
    make install

ENV OMPI_HOME /opt/ompi


# ENV
ENV PATH ${HADOOP_HOME}/bin:${SPARK_HOME}/bin:${OMPI_HOME}/bin:${PATH}



