ps -ef|grep simdht_worker.py|grep -v grep|awk '{print $2}'|xargs kill -9
nohup python3 simdht_worker.py>$(pwd)/spider.log 2>&1&