#!/bin/bash -e

####################################################################################
# Performs automated integration tests on SSPL-LL by performing the following
#   1) Default installation directory will be /root. or sspl source code will be copied in the directory as provided by user.
#   2) Expects SSPL source to be built and resultant RPMs to be present in
#      $sspl_install_dir/sspl/dist/rpmbuild/RPMS, which will be installed for container based tests here.
#   3) Runs a series of tests by injecting actuator messages into specific RabbitMQ exchanges
#   4) Confirms the proper actuator JSON responses are generated by SSPL-LL
#   5) Confirms the proper sensor JSON responses are generated by SSPL-LL
#   6) Uses Mock objects to inject events simulating external sensors

#   It will exit 0 upon success and 1 if any tests failed or had errors
TOP_DIR=$PWD
vm_name=sspl-test
[[ $EUID -ne 0 ]] && sudo=sudo
sspl_install_dir=$1
rpms_dir=$sspl_install_dir/sspl/dist/rpmbuild/RPMS
test_dir=$sspl_install_dir/sspl/test/automated
product=EES

kill_mock_server()
{
    # Kill mock server
    $sudo lxc-attach -n $vm_name  -- pkill -f \./mock_server
}

trap cleanup 0 2

cleanup()
{
    # Stop the mock_server
    kill_mock_server
    $sudo lxc-stop -n $vm_name; $sudo lxc-destroy -n $vm_name
    exit 1
}

# checking if LXC is configured
which lxc-ls &>/dev/null || {
        echo "lxc-ls binary wasn't found on system, please configure LXC on the system.";
        exit 1;
}
[[ $($sudo lxc-ls) =~ "$vm_name" ]]  &&  $sudo lxc-stop -n $vm_name && $sudo lxc-destroy -n $vm_name
$sudo bash  -c  "lxc-create -n $vm_name -t centos -- -R 7"
echo "Xyratex" | $sudo chroot /var/lib/lxc/$vm_name/rootfs passwd --stdin  -u root
$sudo bash  -c  "lxc-start -d -n $vm_name"

# we need to wait till yum will be functioning properly, this is the easiest way
$sudo lxc-attach -n $vm_name  -- bash -c "while :; do yum install -y epel-release && break; done"

# set hostname
$sudo lxc-attach -n $vm_name  -- bash -c "echo $vm_name > /etc/hostname"

# add entry in /etc/hosts
$sudo lxc-attach -n $vm_name  -- bash -c "echo $(hostname -I) $vm_name >> /etc/hosts"

# If installation directory is user provided, create it inside the container
[[ ! -z "$sspl_install_dir" ]] && $sudo lxc-attach -n $vm_name -- bash -c "/usr/bin/mkdir -p $sspl_install_dir"

# Extract sspl source directory in /root directory inside container
BASE_DIR=$(realpath $(dirname $0)/..)
pushd $TOP_DIR; tar cf -  --owner=0 --group=0 $BASE_DIR/../sspl |  $sudo \
lxc-attach -n $vm_name -- bash -c "tar -xf  - -C  $sspl_install_dir"; popd

$sudo lxc-attach -n $vm_name  -- bash -c " [ ! -f $sspl_install_dir/sspl/dist/rpmbuild/RPMS/noarch/sspl-*.rpm ] " \
&& echo "Please build RPMs" && exit 1

# Install required packages
# Removing installation of httpd package from this list and replacing it with
# chronyd as httpd was conflicting with other service during testing.
$sudo lxc-attach -n $vm_name  -- yum -y install chrony python2-pip rpm-build git \
graphviz openssl-devel check-devel python-pep8 doxygen libtool sudo make

# Install lettuce
$sudo lxc-attach -n $vm_name  -- pip install lettuce==0.2.23
$sudo lxc-attach -n $vm_name  -- pip install Flask==1.1.1
# Removing installation of python-requests package
# This package gets installed as dependency of sspl RPM

# Extract simulation data
# Disabling for EES-non-requirement
#$sudo lxc-attach -n $vm_name  -- bash -c "tar xvf $test_dir/../5u84_dcs_dump.tgz -C /tmp"

# Install sspl and libsspl_sec packages
$sudo lxc-attach -n $vm_name  -- yum --enablerepo=updates clean metadata
$sudo lxc-attach -n $vm_name  -- bash -c "yum -y localinstall $rpms_dir/x86_64/libsspl_sec-*.rpm"
$sudo lxc-attach -n $vm_name  -- bash -c "yum -y localinstall $rpms_dir/noarch/sspl-*.rpm"
$sudo lxc-attach -n $vm_name  -- cp /opt/seagate/eos/sspl/conf/sspl.conf."${product}" /etc/sspl.conf
#Taking the backup of /etc/sspl.conf before running test cases and place back as it is after test.
#for testing purpose need to generating the alerts for CPU usage, Memory Usage and disk usage the
#making the threshold value less than the actual usage for HOst, CPU and DIsk we update the the
#threshold values (e.g. # Disk Usage Threshold value in terms of usage percentage (i.e. 0 to 100)
#disk_usage_threshold=28
# CPU Usage Threshold value in terms of usage in percentage (i.e. 0 to 100%)
#cpu_usage_threshold=1
# Memory Usage Threshold value in terms of usage in percentage (i.e. 0 to 100%)
#host_memory_usage_threshold=34.3)
$sudo lxc-attach -n $vm_name  -- cp /etc/sspl.conf /etc/sspl.conf.back


# Configure and start RabbitMQ
$sudo lxc-attach -n $vm_name  --  bash -c 'echo AFYDPNYXGNARCABLNENP >> /var/lib/rabbitmq/.erlang.cookie'
$sudo lxc-attach -n $vm_name  --  bash -c 'echo AFYDPNYXGNARCABLNENP >> /root/.erlang.cookie'
$sudo lxc-attach -n $vm_name  --  bash -c 'echo NODENAME=rabbit >> /etc/rabbitmq/rabbitmq-env.conf'
$sudo lxc-attach -n $vm_name  --  chmod 400 /var/lib/rabbitmq/.erlang.cookie
$sudo lxc-attach -n $vm_name  --  chmod 400 /root/.erlang.cookie
$sudo lxc-attach -n $vm_name  --  chown -R rabbitmq:rabbitmq /var/lib/rabbitmq/
$sudo lxc-attach -n $vm_name  --  chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
$sudo lxc-attach -n $vm_name  -- systemctl start rabbitmq-server -l
$sudo lxc-attach -n $vm_name  -- systemctl start chronyd

# Start mock API server
$sudo lxc-attach -n $vm_name  -- $sspl_install_dir/sspl/test/mock_server &

# Change setup to vm in sspl configurations
[ "${product}" = "EES" ] && $sudo lxc-attach -n $vm_name  -- sed -i 's/setup=vm/setup=eos/g' /etc/sspl.conf
$sudo lxc-attach -n $vm_name  -- sed -i 's/primary_controller_port=80/primary_controller_port=8090/g' /etc/sspl.conf
#updating the /etc/sspl.conf with respect to threshold value for Host, Cpu, Disk
$sudo lxc-attach -n $vm_name  -- $sspl_install_dir/sspl/test/set_threshold.sh
$sudo lxc-attach -n $vm_name  -- $sspl_install_dir/sspl/low-level/framework/sspl_init
$sudo lxc-attach -n $vm_name  -- $sspl_install_dir/sspl/test/rabbitmq_start_checker sspl-out actuator-resp-key

# Execute tests
$sudo lxc-attach -n $vm_name -- bash -c "$test_dir/run_sspl-ll_tests.sh"

#Updating the /etc/sspl.conf with respect to there original changes.
$sudo lxc-attach -n $vm_name -- mv /etc/sspl.conf.back /etc/sspl.conf

retcode=$?
exit $retcode
