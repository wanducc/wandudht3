#!/bin/bash
##BY Wandu 2023.4
#
echo "本系统运行环境如下:"

echo "系统:centos 7,如果非此系统请不要继续运行，ctrl+c键 退出本脚本！"
yum -y install python3

yum -y install nano
yum -y install curl
yum -y install python3-devel  gcc

#检测是否root登录
[ $(id -u) -gt 0 ] && echo "请用root用户执行此脚本！可输入:sudo -i 获取root群星" && exit 1
echo "root登录成功,确认你的系统是否为centos7"
#判断是否为centos

python --version



echo "修改时区"
\cp -rpf /usr/share/zoneinfo/Asia/Chongqing /etc/localtime
echo "关闭防火墙"
systemctl stop firewalld.service  
systemctl disable firewalld.service   
systemctl stop iptables.service  
systemctl disable iptables.service  

echo "禁用SELINUX"
setenforce 0  
sed -i s/"SELINUX=enforcing"/"SELINUX=disabled"/g  /etc/selinux/config
echo "优化内核参数"
cat << EOF > /etc/sysctl.conf
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_fin_timeout = 2
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_wmem = 8192 131072 16777216
net.ipv4.tcp_rmem = 32768 131072 16777216
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.ip_conntrack_max = 65536
net.ipv4.netfilter.ip_conntrack_max=65536
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established=180
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 16384
vm.overcommit_memory = 1
net.core.somaxconn = 511
EOF

/sbin/sysctl -p /etc/sysctl.conf
/sbin/sysctl -w net.ipv4.route.flush=1
echo 'ulimit -HSn 65536' >> /etc/rc.local
echo 'ulimit -HSn 65536' >>/root/.bash_profile
echo '*  soft  nofile 65536' >> /etc/security/limits.conf
echo '*  hard  nofile 65536' >> /etc/security/limits.conf
ulimit -HSn 65536

echo "安装必备组件中..."
yum -y install wget gcc gcc-c++ python-devel mariadb mariadb-devel mariadb-server
yum -y install psmisc net-tools lsof epel-release
yum -y install redis
yum -y install git gcc cmake automake g++ mysql-devel
yum -y install  vixie-cron crontabs

pip3 install --upgrade pip
pip3 install  setuptools
pip3 install  greenlet
pip3 install wheel
pip3 install redis
pip3 install libtorrent



echo "根据系统文件的requirements.txt安装必备依赖库"
pip3 install -r requirements.txt

echo "清除80端口"
kill -9 $(lsof -i:80|tail -1|awk '"$1"!=""{print $2}')



