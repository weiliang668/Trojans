#!/bin/bash

#更新组件
apt-get update -y

#安装wget
wName=$(dpkg -l | grep -w wget | awk '{print $1}')
if [ "$wName" = "ii" ]; then
	echo -e "\033[102;91mwget已安装，跳过\033[0m"
else
	apt-get install -y wget
	echo -e "\033[102;91mwget安装完成\033[0m"
fi


#安装unzip
zName=$(dpkg -l | grep -w zip | awk '{print $1}')
if [ "$zName" = "ii" ]; then
	echo -e "\033[102;91mzip已安装，跳过\033[0m"
else
	apt-get install -y zip
	echo -e "\033[102;91mzip安装完成\033[0m"
fi

#安装qrencode二维码工具
qName=$(dpkg -l | grep -w qrencode | awk '{print $1}')
if [ "$qName" = "ii" ]; then
	echo -e "\033[102;91mqrencode已安装，跳过\033[0m"
else
	apt-get install -y qrencode
	echo -e "\033[102;91mqrencode安装完成\033[0m"
fi

#安装socat
sName=$(dpkg -l | grep -w socat | awk '{print $1}')
if [ "$sName" = "ii" ]; then
	echo -e "\033[102;91msocat已安装，跳过\033[0m"
else
	apt-get install -y socat
	echo -e "\033[102;91msocat安装完成\033[0m"
fi
	

#下载默认Trojan配置文件
cName=$(ls | grep -w config.json)
if [ "$cName" ]; then
	echo -e "\033[102;91m已有配置文件,无需重复下载\033[0m"
else
	curl -LJo /root/trojan/config.json --create-dirs https://raw.githubusercontent.com/weiliang668/Trojans/main/config.json
	echo -e "\033[102;91m默认配置下载完成\033[0m"
fi
cd /root/trojan

#配置密码
sed -i '8d' ./config.json
shuru=$(echo -e "\033[92m配置Trojan密码（默认回车自动随机16位密码）：\033[0m")
read -p "$shuru" Trojanwd
if [ ! "$Trojanwd" ]; then
	key="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	num=${#key}
	pass=''
	for i in {1..16}
	do
		index=$[RANDOM%num]
		pass=$pass${key:$index:1}
	done
	sed -i "8i \        \"${pass}\"" config.json
	Trojanwds=$pass
else
	sed -i "8i \        \"${Trojanwd}\"" config.json
	Trojanwds=$Trojanwd
fi

#配置端口
shuru=$(echo -e "\033[92m配置Trojan端口（默认回车6666端口）：\033[0m")
read -p "$shuru" Trojanpr
while [[ ! "$Trojanpr" =~ ^[1-9]+$ ]]
do
	echo -e "\033[91m端口必须大于等于443，小于65536，并且必须是数字！\033[0m"
	read -p "$shuru" Trojanpr
done

while [ "$Trojanpr" -lt 443 ]
do
	echo -e "\033[91m端口必须大于等于443，小于65536，并且必须是数字！\033[0m"
	read -p "$shuru" Trojanpr
done

while [ "$Trojanpr" -gt 65536 ]
do
	echo -e "\033[91m端口必须大于等于443，小于65536，并且必须是数字！\033[0m"
	read -p "$shuru" Trojanpr
done

if [ "$Trojanpr" ]; then
	sed -i "s/6666/${Trojanpr}/g" config.json
fi


 
#获取最新版本号
versionTag=$(curl -s https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest | grep tag_name | cut -f4 -d "\"")
if [ ! "$versionTag" ]; then
	echo -e "\033[91m未获取到版本号！\n请联系作者更新！\033[0m" 
	exit
else
	echo -e "\033[102;91m当前最新版本：$versionTag\033[0m"
fi

#开始下载
zName=$(ls | grep -w trojan-go)
if [ ! "$zName" ]; then
	curl -LJo /root/trojan/trojan.zip --create-dirs https://github.com/p4gefau1t/trojan-go/releases/download/"$versionTag"/trojan-go-linux-amd64.zip
	unzip ./trojan.zip
	echo -e "\033[102;91mTrojan-go装载完成\033[0m"
else
	echo -e "\033[102;91m已安装Trojan-go\033[0m"
fi

#acme签名函数
sslacme(){
	#输入域名
	shuru=$(echo -e "\033[92m输入要申请的证书域名：\033[0m")
	read -p "$shuru" sslName
	while [ ! "$sslName" ]
	do
		echo -e "\033[91m域名不能为空！\033[0m"
		read -p "shuru" sslName
	done
	
	#安装证书
	shuru=$(echo -e "\033[92m注册证书邮箱(不想填就回车默认)：\033[0m")
	read -p "$shuru" sslEmail
	if [ ! "$sslEmail" ]; then
		curl https://get.acme.sh | sh -s email=weiliang@example.com
	else
		curl https://get.acme.sh | sh -s email=$sslEmail
	fi
	
	
	
	
	#创建别名
	echo -e "\033[91m\n创建别名\n\033[0m"
	alias acme.sh=~/.acme.sh/acme.sh
	
	#开启alias
	echo -e "\033[91m\n开启alias\n\033[0m"
	shopt -s expand_aliases
	
	#申请证书
	echo -e "\033[91m\n申请证书\n\033[0m"
	acme.sh  --issue -d $sslName  --standalone -k ec-256

	#安装证书：
	echo -e "\033[91m\n安装证书\n\033[0m"
	acme.sh --installcert -d $sslName --ecc  --key-file   server.key   --fullchain-file server.crt
	
	#卸载socat
	echo -e "\033[91m\n开始卸载socat\n\033[0m"
	if [ "$sName" = "ii" ]; then
		apt-get purge -y socat
	fi

	#后台启动trojan-go
	echo -e "\033[91m\n开启后台trojan\n\033[0m"
	nohup ./trojan-go > trojan.log 2>&1 &

	#生成客户端二维码和链接
	qrencode -t UTF8 -s 1 -m 2 'trojan://$Trojanwds@$sslName:443?security=tls&type=tcp&headerType=none#Trojans'
	echo -e "\033[42;91m快速链接：trojan://$Trojanwds@$sslName:443?security=tls&type=tcp&headerType=none#Trojans\033[0m"
	echo -e "\033[42;91mTrojan密码：$Trojanwds\033[0m"
	echo -e "\033[42;91mTrojan端口：$Trojanpr\033[0m"
	echo -e "\033[42;91mTrojan域名：$sslName\033[0m"
	echo -e "\033[42;91mTrojan版本号：$versionTag\033[0m"
	echo -e "\033[42;91m安装完成！\033[0m"
}

#自签名函数
sslDomain(){
	#自签证书：
	openssl ecparam -genkey -name prime256v1 -out ca.key
	
	#生成私钥
	openssl req -new -x509 -days 36500 -key server.key -out server.crt  -subj "/CN=bing.com"
	
	#后台启动trojan-go
	nohup ./trojan-go > trojan.log 2>&1 &
	
	#卸载socat
	if [ "$sName" = "ii" ]; then
		apt-get purge -y socat
	fi
	
	#查询公网IP
	IpDomain=$(curl http://ifconfig.io)
	#生成客户端二维码和链接
	qrencode -t UTF8 -s 1 -m 2 'trojan://$Trojanwds@$IpDomain:443?security=tls&sni=bing.com&type=tcp&headerType=none#Trojans'
	echo -e "\033[42;91m快速链接：trojan://$Trojanwds@$IpDomain:443?security=tls&sni=bing.com&type=tcp&headerType=none#Trojans\033[0m"
	echo -e "\033[42;95m无域名Trojan节点链接必须在客户端手动把-跳过证书验证（allowInsecure）设置成：true\033[0m"
	echo -e "\033[42;91mTrojan密码：$Trojanwds\033[0m"
	echo -e "\033[42;91mTrojan端口：$Trojanpr\033[0m"
	echo -e "\033[42;91mTrojan域名：$IpDomain\033[0m"
	echo -e "\033[42;91mTrojan版本号：$versionTag\033[0m"
	echo -e "\033[42;91m安装完成！\033[0m"
}

#选择无域名（自签证书）还是有域名（acme证书）
echo -e "\033[93m\n选择有无域名（无域名会用自签ip）:\n  1.有域名(默认) \n  2.无域名\n\033[0m"
shuru=$(echo -e "\033[92m请选择:\033[0m")
read -p "$shuru" Domain
while [ "$Domain" ]
do
	case "$Domain" in
	1 ) sslacme;
	;;
	2 ) sslDomain;
	;;
	esac
	echo -e "\033[91m\n输入错误，重新输入！\n\033[0m"
	read -p "$shuru" Domain
done
if [ ! "$Domain" ]; then
	sslacme
fi
