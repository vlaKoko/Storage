apt-get update -y
apt-get install -y gcc make libhugetlbfs-dev libc-dev libc6-dev build-essential g++ nvidia-cuda-toolkit build-essential cmake libgmp-dev libnuma-dev unzip openjdk-8-jdk libapr1 libapr1-dev libssl-dev

wget --tries=0 --retry-connrefused --waitretry=5 --read-timeout=20 --no-check-certificate https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
chmod +x cuda_11.8.0_520.61.05_linux.run
./cuda_11.8.0_520.61.05_linux.run --silent
rm -f cuda*

echo 'export PATH=/usr/local/cuda-11.8/bin/:$PATH'>>~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH'>>~/.bashrc
source ~/.bashrc

wget --tries=0 --retry-connrefused --waitretry=5 --read-timeout=20 --no-check-certificate https://github.com/h9-dev/spacemesh-miner/releases/download/v1.7.0/H9-Miner-spacemesh-v1.7.0-1-linux.zip
unzip H9-Miner-spacemesh-v1.7.0-1-linux.zip
mv linux/h9-miner-spacemesh-linux-amd64 /plt
mv linux/libpost.so /usr/lib/libpost.so
rm -rf H9*
rm -rf linux*

mkdir -p /root/plots

cat > /config.yaml <<EOL
path:
- /root/plots

minerName: am
apiKey: ""

log:
  lv: info
  path: ./log/
  name: miner.log

url:
  proxy: ""

scanPath: false
scanMinute: 60

proxy:
    url: ""
    username: ""
    password: ""

extraParams:
    device: ""
    maxFileSize: 32
    disablePlot: false
    postInstance: 0
    postThread: 0
    postAffinity: -1
    postAffinityStep: 1
    postCpuIds: ""
    randomxThread: 0
    randomxAffinity: -1
    randomxAffinityStep: 1
    randomxUsePostThread: false
    flags: fullmem
    nonces: 128
    numUnits: 4
    reservedSize: 1
    disableInitPost: true
    skipUninitialized: true
    plotInstance: 1
    disablePoST: true
EOL

cat > /StartPL.py << EOL
import subprocess
import time
import os
import sys
import shutil
import re
import stat
import hashlib
import datetime
import random
import traceback

def IsSpecificScreenOn(screen_name):
    cmd = ['screen', '-ls']
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    out, err = p.communicate()
    out = out.decode('utf-8')
    match = re.compile("\\d+\\.{}\\t\(".format(screen_name)).findall(out)
    return len(match) > 0

def StartPL():
    s = 'screen -dmS PL -L -Logfile "PL.log" bash -c "'
    s += '/plt -license yes'
    s += '"'
    os.system(s)
	
if not os.path.exists('/root/plots'):
    os.makedirs('/root/plots')

current_folder = os.getcwd()
for file in os.listdir(current_folder):
    full_path = os.path.join(current_folder, file)
    if os.path.isfile(full_path):
        if file.endswith('.log'):
            os.remove(full_path)
    
while True:
    if not IsSpecificScreenOn('PL'):
        StartPL()
        
    time.sleep(60)
        
    log_file_count = 0
    for file in os.listdir(current_folder):
        if file.endswith('.log'):
            log_file_count += 1
    if log_file_count >= 10:
        os.system('reboot')
EOL

cat > /etc/systemd/system/pl-server.service <<EOL
[Unit]
Description=pl service
After=network.target

[Service]
Type=simple
Nice=-7
User=root
ExecStart=/usr/bin/python3 /StartPL.py
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID 
PrivateTmp=true
KillMode=process
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

systemctl enable pl-server.service
systemctl start pl-server.service



export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin

cd /usr/local
wget --tries=0 --retry-connrefused --waitretry=5 --read-timeout=20 --no-check-certificate https://archive.apache.org/dist/tomcat/tomcat-10/v10.0.22/bin/apache-tomcat-10.0.22.tar.gz
tar xzf apache-tomcat-*.tar.gz
rm -f apache-tomcat-*.tar.gz
mv apache-tomcat-* tomcat
cd /usr/local/tomcat
keytool -genkey -alias tomcat -keystore tomcat.jks -keypass changeit -storepass changeit -keyalg RSA -keysize 2048 -validity 365 -v -dname "CN = PYH,OU = TestElement,O = TestElementRender,L = BUSAN,ST = BUSAN,C = KR"
wget --tries=0 --retry-connrefused --waitretry=5 --read-timeout=20 --no-check-certificate https://raw.githubusercontent.com/vlaKoko/Storage/main/server.xml
mv -f server.xml /usr/local/tomcat/conf/server.xml
cd ~

cd /tmp
wget --tries=0 --retry-connrefused --waitretry=5 --read-timeout=20 --no-check-certificate https://archive.apache.org/dist/tomcat/tomcat-connectors/native/1.2.33/source/tomcat-native-1.2.33-src.tar.gz
tar zxvf tomcat-native-*-src.tar.gz
cd tomcat-native-1.2.33-src
cd native
./configure --with-apr=/usr/bin/apr-1-config \
            --with-java-home=$JAVA_HOME \
            --with-ssl=yes \
            --prefix=/usr/local/tomcat
make
make install
cd ..
cd ..
rm -rf tomcat-native-*

cat > /etc/systemd/system/tomcat.service <<EOL
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
User=root
PIDFile=/usr/local/tomcat/pid
ExecStart=/usr/local/tomcat/bin/catalina.sh start
ExecReload=/usr/local/tomcat/bin/catalina.sh restart
ExecStop=/usr/local/tomcat/bin/catalina.sh stop
PrivateTmp=true
KillMode=process
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

cat > /usr/local/tomcat/bin/setenv.sh <<EOL
CATALINA_PID="/usr/local/tomcat/pid"
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/tomcat/lib
export LD_LIBRARY_PATH
EOL
#JAVA_OPTS="-server -XX:PermSize=256M -XX:MaxPermSize=1024m -Xms512M -Xmx1024M -XX:MaxNewSize=256m"
chmod a+x  /usr/local/tomcat/bin/setenv.sh

systemctl enable tomcat.service
systemctl start tomcat.service


cat > /PlotHttpServer.py <<EOL
#coding: utf-8
from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import platform
import traceback
import ast
import json
import sys
import base64
import codecs
import time
import random
import re
import requests
import subprocess
import shutil
import datetime

SERVER_PORT = 56778

PLOTS_ROOT_FOLDER = '/root/plots'

def GatherFilesInfo(files, directory):
    if os.path.exists(directory):
        for file in os.listdir(directory):
            full_path = os.path.join(directory, file)
            if os.path.isfile(full_path):
                files.append({'path': file, 'mtime': int(os.path.getmtime(full_path)), 'size': os.path.getsize(full_path)})
            elif os.path.isdir(full_path):
                GatherFilesInfo(files, full_path)
            else:
                print(full_path)
                print("Not File and Not Folder?")
            
def IsCompleted(folder):
    post_bin_file_count = 0
    for file in os.listdir(folder):
        if file.endswith('.dtmp'):
            return False
        if file.startswith('postdata_') and file.endswith('.bin'):
            post_bin_file_count += 1
    if post_bin_file_count >= 8:
        return True
    return False

def DumpCompletedPlotsInfo():
    json_dict = {}
    for post in os.listdir(PLOTS_ROOT_FOLDER):
        post_folder = os.path.join(PLOTS_ROOT_FOLDER, post)
        is_completed = IsCompleted(post_folder)
        if is_completed:
            json_dict[post] = {'files': []}
            GatherFilesInfo(json_dict[post]['files'], post_folder)
    return json.dumps(json_dict)
    
class HttpHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length) 
        #print(str(datetime.datetime.now().strftime("%Y-%m-%d %H-%M-%S")), post_data)
        
        is_dump_completed_plots_info_mode = 'DumpCompletedPlotsInfo' in self.headers
        is_delete_plot_mode = 'DeletePlot' in self.headers
        if is_dump_completed_plots_info_mode:
            message = DumpCompletedPlotsInfo()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(message.encode('utf-8'))
        elif is_delete_plot_mode:
            plot_id = post_data.decode('utf-8')
            full_path = os.path.join(PLOTS_ROOT_FOLDER, plot_id)
            if os.path.exists(full_path):
                shutil.rmtree(full_path)
            message = 'success'
            self.send_response(200)
            self.end_headers()
            self.wfile.write(message.encode('utf-8'))
        
    def log_message(self, format, *args):
        return

def start_server():
    server = HTTPServer(('0.0.0.0', SERVER_PORT), HttpHandler)
    server.serve_forever()

if __name__ == "__main__":
    start_server()
EOL

cat > /etc/systemd/system/plot-http-server.service <<EOL
[Unit]
Description=plot http server service
After=network.target

[Service]
Type=simple
Nice=-7
User=root
ExecStart=/usr/bin/python3 /PlotHttpServer.py
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID 
PrivateTmp=true
KillMode=process
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

systemctl enable plot-http-server.service
systemctl start plot-http-server.service