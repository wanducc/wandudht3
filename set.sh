#!/bin/bash
##BY Wandu 2023.4

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
    systemctl enable mariadb.service

else
    echo "您启用了远程数据库！"
    systemctl disable mariadb.service
fi
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

sphinxpath=$(whereis sphinx-jieba | awk -F ' ' '{print $2}')
echo "sphinx-jiebapath路径： ${sphinxpath}"



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
echo '0 5 * * * /usr/local/sphinx-jieba/bin/indexer -c $(pwd)/sphinx.conf film --rotate&&/usr/local/sphinx-jieba/bin/searchd --config $(pwd)/sphinx.conf' >> /tmp/crontab.bak
crontab /tmp/crontab.bak
systemctl restart gunicorn
systemctl daemon-reload
nginx -s reload
echo '当前进程运行状态:'
pgrep -l nginx
pgrep -l searchd
pgrep -l gunicorn

echo "重启爬虫命令为: sh redht.sh"