#!/bin/bash
##BY Wandu 2023.4
#
echo "本系统运行环境如下:"

echo "系统:centos 7,如果非此系统请不要继续运行，ctrl+c键 退出本脚本！"
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -qO /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum clean metadata
yum makecache
yum -y install python3

yum -y install nano
yum -y install curl
yum -y install python3-devel  gcc

#检测是否root登录
[ $(id -u) -gt 0 ] && echo "请用root用户执行此脚本！可输入:sudo -i 获取root群星" && exit 1
echo "root登录成功,确认你的系统是否为centos7"
#判断是否为centos

python --version


echo "获取系统虚拟缓存…………"
if [ $(grep SwapTotal /proc/meminfo|grep -v grep|awk '{print $2}') -eq 0 ];then
        echo "主机没有swap, 将自动创建大小为1G的swap"
        dd if=/dev/zero of=/swapfile count=1024 bs=1MiB&&
        chmod 600 /swapfile&&mkswap /swapfile&&swapon /swapfile&&
        echo '/swapfile   swap    swap    sw  0   0' >> /etc/fstab&&
        echo "swap创建成功!"
else 
    echo  "存在swap"
fi

read -p "请输入单个域名,不要带http(s)://  :" domain
if  [ -z "$domain" ] ;then
    echo "输入域名错误"
    read -p "请输入单个域名,不能有空格:" domain
else
    echo "域名: $domain"
fi

read -p "请输入本地实际访问端口,启动后ngix默认80代理,请输入默认8000 :" webport
if  [ -z "$webport" ] ;then
	webport="8000"
    echo "访问方式: http://${domain}:${webport}"
else
    echo "访问方式: http://${domain}:${webport}"
fi

read -p "请输入数据库host,默认为127.0.0.1 [留空,回车默认] ：" dbhost
if  [ -z "$dbhost" ] ;then
    dbhost="127.0.0.1"
    echo "您默认的数据库host为127.0.0.1"
else
    echo "您设置的数据库: ${dbhost}"
fi

read -p "请输入数据库端口,默认为3306 [留空,回车默认] ：" dbport
if  [ -z "$dbport" ] ;then
    dbport="3306"
    echo "您默认的数据库端口为 :${dbport}"
else
    echo "您设置的数据库: ${dbport}"
fi

read -p "请输入数据库库名,默认为wandudb [留空,回车默认] ：" dbname
if  [ -z "$dbname" ] ;then
    dbname="wandudb"
    echo "您默认的数据库端口为 :${dbname}"
else
    echo "您设置的数据库: ${dbname}"
fi

read -p "请输入数据库root密码:" dbpass
if  [ -z "$dbpass" ] ;then
    echo "请输入数据库root密码!"
    read -p "请输入数据库root密码:" dbpass
else
    echo "数据库root密码: $dbpass"
fi

nowdir=$(pwd)
echo $nowdir
#替换域名和数据库密码为自定义的内容
sed -i -e 's|www.baidu.com|'$domain'|' nginx.conf
sed -i -e 's|192.168.8.8|'$domain'|' manage.py
sed -i -e 's|goto_host|'$dbhost'|' sphinx.conf
sed -i -e 's|goto_host|'$dbhost'|' simdht_worker.py
sed -i -e 's|goto_host|'$dbhost'|' manage.py
sed -i -e 's|123456|'$dbpass'|' sphinx.conf
sed -i -e 's|123456|'$dbpass'|' simdht_worker.py
sed -i -e 's|123456|'$dbpass'|' manage.py
sed -i -e 's|3306|'$dbport'|' sphinx.conf
sed -i -e 's|3306|'$dbport'|' simdht_worker.py
sed -i -e 's|3306|'$dbport'|' manage.py
sed -i -e 's|wandudb|'$dbname'|' sphinx.conf
sed -i -e 's|wandudb|'$dbname'|' simdht_worker.py
sed -i -e 's|wandudb|'$dbname'|' manage.py
sed -i -e 's|/root/wandudht|'$nowdir'|' systemctl/gunicorn.service
sed -i -e 's|/root/wandudht|'$nowdir'|' systemctl/indexer.service
sed -i -e 's|/root/wandudht|'$nowdir'|' systemctl/searchd.service
sed -i -e 's|/root/wandudht|'$nowdir'|' supervisor/gunicorn.conf
sed -i -e 's|/root/wandudht|'$nowdir'|' supervisor/indexer.conf
sed -i -e 's|/root/wandudht|'$nowdir'|' supervisor/searchd.conf
sed -i -e 's|8000|'$webport'|' systemctl/gunicorn.service
sed -i -e 's|8000|'$webport'|' supervisor/gunicorn.conf
sed -i -e 's|8000|'$webport'|' sphinx.conf

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
yum -y install python-pip
yum -y install git gcc cmake automake g++ mysql-devel


pip3 install --upgrade pip

pip3 install  setuptools
pip3 install  greenlet
pip3 install wheel

echo "根据系统文件的requirements.txt安装必备依赖库"
pip3 install -r requirements.txt
#如果提示没有pip命令,或者你使用linode的主机,请取消下面4行的注释

