#!/bin/bash
##BY Wandu 2023.4
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


echo "创建上传目录:"
mkdir -p uploads  uploads/nvyou  uploads/fanhao
#注册服务
gunicornpath=$(whereis gunicorn)
sed -i -e 's|/usr/bin/gunicorn|'$gunicornpath'|' systemctl/gunicorn.service
sed -i -e 's|/usr/bin/gunicorn|'$gunicornpath'|' supervisor/gunicorn.conf
sphinx-jiebapath=$(whereis sphinx-jieba)

sed -i -e 's|/usr/local/sphinx-jieba|'$sphinx-jiebapath'|' systemctl/indexer.service
sed -i -e 's|/usr/local/sphinx-jieba|'$sphinx-jiebapath'|' supervisor/indexer.conf
sed -i -e 's|/usr/local/sphinx-jieba|'$sphinx-jiebapath'|' systemctl/searchd.service
sed -i -e 's|/usr/local/sphinx-jieba|'$sphinx-jiebapath'|' supervisor/searchd.conf
sed -i -e 's|/usr/local/sphinx-jieba|'$sphinx-jiebapath'|' sphinx.conf
\cp -rpf systemctl/gunicorn.service /etc/systemd/system
\cp -rpf systemctl/indexer.service /etc/systemd/system
\cp -rpf systemctl/searchd.service /etc/systemd/system
systemctl daemon-reload	
read -p "是否安装了sphinx:?[y/n]" mysqlwhere
if [[ x"${sphinxwhere}" == x"y" || x"${sphinxwhere}" == x"Y" ]]; then
    echo "已经安装！"
else
    echo "编译分词索引工具sphinx……"
    git clone https://github.com/wenguonideshou/sphinx-jieba
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

read -p "是否数据库在本地:?[y/n]" mysqlwhere
if [[ x"${mysqlwhere}" == x"y" || x"${mysqlwhere}" == x"Y" ]]; then
    echo "请输入数据库root密码!"
	\cp -rpf my.cnf  /etc/my.cnf 
	systemctl start  mariadb.service 
	echo "正在创建数据库信息……直接回车"
	mysqladmin -uroot -p password ${dbpass}
	cesql="create database IF NOT EXISTS ${dbname} default character set utf8mb4;set global max_allowed_packet = 64*1024*1024;set global max_connections = 100000;" 
	mysql -uroot -p${dbpass} -e "$cesql"
	systemctl enable mariadb.service
else
	echo "您启用了远程数据库！"
    systemctl enable mariadb.service
fi

echo "开启队列信息……"
systemctl start redis.service
systemctl enable redis.service

echo "数据库建表"
python3 manage.py init_db
echo "创建管理员,会提示输入管理员用户名和密码,邮箱"
python3 manage.py create_user

kill -9 $(lsof -i:${$webport}|tail -1|awk '"$1"!=""{print $2}')

sleep 3
echo "配置前端ngxin……"
\cp -rpf nginx.conf  /etc/nginx/nginx.conf 
nginx -s reload
echo "启动前端网站，并且加载网络库"

systemctl start gunicorn
systemctl enable gunicorn



echo "后台开启爬虫,并且开启日志，后续可定时清理"
nohup python3 $(pwd)/simdht_worker.py >$(pwd)/spider.log 2>&1& 



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
sleep 5
echo "开启标准大页hugePage"
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local

echo "开启定时时间为早上4点"
systemctl start crond.service
systemctl enable crond.service
crontab -l > /tmp/crontab.bak
echo '0 5 * * * /usr/local/sphinx-jieba/bin/indexer -c $(pwd)/sphinx.conf film --rotate&&/usr/local/sphinx-jieba/bin/searchd --config $(pwd)/sphinx.conf' >> /tmp/crontab.bak
crontab /tmp/crontab.bak

echo '当前进程运行状态:'
pgrep -l nginx
pgrep -l searchd
pgrep -l gunicorn

echo "重启爬虫命令为: sh redht.sh"