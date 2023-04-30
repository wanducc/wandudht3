#!/bin/bash
##BY Wandu 2023.4
#
echo "本系统运行环境如下:"

echo "系统:centos 7,如果非此系统请不要继续运行，ctrl+c键 退出本脚本！"
#wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
#wget -qO /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
#yum clean metadata
#yum makecache
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
yum -y install  vixie-cron crontabs
pip3 install --upgrade werkzeug
pip3 install  setuptools
pip3 install --upgrade setuptools
pip3 install greenlet
pip3 install wheel

echo "根据系统文件的requirements.txt安装必备依赖库"
pip3 install -r requirements.txt
#如果提示没有pip命令,或者你使用linode的主机,请取消下面4行的注释
echo "创建上传目录:"
mkdir -p uploads  uploads/nvyou  uploads/fanhao
#注册服务
gunicornpath=$(whereis gunicorn | awk -F ' ' '{print $2}')
echo "gunicornpath路径： ${gunicornpath}"
sed -i -e 's|/usr/bin/gunicorn|'$gunicornpath'|' systemctl/gunicorn.service
sed -i -e 's|/usr/bin/gunicorn|'$gunicornpath'|' supervisor/gunicorn.conf
\cp -rpf systemctl/gunicorn.service  systemctl/indexer.service  systemctl/searchd.service /etc/systemd/system
systemctl daemon-reload
\cp -rpf my.cnf  /etc/my.cnf 
systemctl start mariadb.service 

echo $nowdir
read -p "是否数据库在本地:?[y/n]" mysqlwhere
if [[ x"${mysqlwhere}" == x"y" || x"${mysqlwhere}" == x"Y" ]]; then
    echo "正在创建数据库信息……直接回车"
    mysqladmin -uroot -p password ${dbpass}
    cesql="create database IF NOT EXISTS ${dbname} default character set utf8mb4;set global max_allowed_packet = 64*1024*1024;set global max_connections = 100000;" 
    mysql -uroot -p${dbpass} -e "$cesql"
else
    echo "您启用了远程数据库！"
fi
systemctl enable mariadb.service
systemctl start redis.service
systemctl enable redis.service

echo "数据库建表"
python3 manage.py init_db
echo "创建管理员,会提示输入管理员用户名和密码,邮箱"
python3 manage.py create_user
kill -9 $(lsof -i:${$webport}|tail -1|awk '"$1"!=""{print $2}')
echo "配置前端ngxin……"
yum -y install nginx
systemctl start  nginx.service
systemctl enable  nginx.service

\cp -rpf nginx.conf  /etc/nginx/nginx.conf 
nginx -s reload
echo "启动前端网站，并且加载网络库"
systemctl start gunicorn
systemctl enable gunicorn
echo "后台开启爬虫,并且开启日志，后续可定时清理"
nohup python3 $(pwd)/simdht_worker.py >$(pwd)/spider.log 2>&1& 


sphinxpath=$(whereis sphinx-jieba | awk -F ' ' '{print $2}')
echo "sphinx-jiebapath路径： ${sphinxpath}"
read -p "是否安装了sphinx:?[y/n]" sphinxwhere
if [[ x"${sphinxwhere}" == x"y" || x"${sphinxwhere}" == x"Y" ]]; then
    echo "已经安装！"
else
    echo "编译分词索引工具sphinx……"
    yum -y install git gcc cmake automake g++ mysql-devel
    git clone https://github.com/wanducc/sphinx-jieba
    cd sphinx-jieba
    git submodule update --init --recursive
    ./configure --prefix=/usr/local/sphinx-jieba
    \cp -r cppjieba/include/cppjieba src/ 
    \cp -r cppjieba/deps/limonp src/ 
    make install
    \cp -r cppjieba/dict/* /usr/local/sphinx-jieba/etc/ 
    cd /usr/local/sphinx-jieba/
    \cp etc/jieba.dict.utf8 etc/xdictjieba.dict.utf8
    \cp etc/user.dict.utf8 etc/xdictuser.dict.utf8
    \cp etc/hmm_model.utf8 etc/xdicthmm_model.utf8
    \cp etc/idf.utf8 etc/xdictidf.utf8
    \cp etc/stop_words.utf8 etc/xdictstop_words.utf8
    cd ..
fi




echo "开启索引……"
systemctl start indexer
systemctl enable indexer
echo "开启分词搜索……"
systemctl start searchd
systemctl enable searchd



echo "正在将必要程序进行开机自动启动"
chmod +x /etc/rc.local
echo "systemctl start  mariadb.service" >> /etc/rc.local
echo "systemctl start  redis.service" >> /etc/rc.local
echo "systemctl start  nginx.service" >> /etc/rc.local
echo "systemctl start  gunicorn.service" >> /etc/rc.local
echo "systemctl start  indexer.service" >> /etc/rc.local
echo "systemctl start  searchd.service" >> /etc/rc.local
echo "nohup python3 $(pwd)/simdht_worker.py>$(pwd)/spider.log 2>&1&" >> /etc/rc.local 
echo "开启标准大页hugePage"
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local

echo "开启定时时间为早上4点"
systemctl start crond.service
systemctl enable crond.service
crontab -l > /tmp/crontab.bak
echo "0 5 * * * /usr/local/sphinx-jieba/bin/indexer -c $(pwd)/sphinx.conf film --rotate&&/usr/local/sphinx-jieba/bin/searchd --config $(pwd)/sphinx.conf" >> /tmp/crontab.bak
crontab /tmp/crontab.bak

echo '当前进程运行状态:'
pgrep -l nginx

pgrep -l searchd

pgrep -l gunicorn


echo "重启爬虫命令为: sh redht.sh"