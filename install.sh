#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red} error: ${plain} Must run this script with root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}No system version detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "i386" || $arch == "i686" ]]; then
    arch="386"
elif [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Failed to detect architecture, use default architecture: ${arch}${plain}"
fi

echo "Arch: ${arch}"

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt-get update
        apt install wget curl tar -y
    fi
}

# This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, you need to force a port and account password change after the installation/update is complete ${plain}"
    read -p "Confirmation to continue? [y/n]: " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name (8 random characters if not filled in): " config_account
        [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
        echo -e "${yellow} your account name will be set to: ${config_account}${plain}"
        read -p "Please set your account password (8 random characters if not filled in): " config_password
        [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
        echo -e "${yellow} your account password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port (or random port number if not filled in): " config_port
        [[ -z $config_port ]] && config_port=$(shuf -i 2000-65535 -n 1)
        until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
                echo -e "${red} $config_port ${plain} The port is already occupied by another program, please change the panel port number"
                read -p "Please set the panel access port (or random port number if not filled in): " config_port
                [[ -z $config_port ]] && config_port=$(shuf -i 2000-65535 -n 1)
            fi
        done
        echo -e "${yellow} your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm setting, setting in ${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow} account password setting complete ${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow} panel port setting complete ${plain}"
    else
        config_port=$(/usr/local/x-ui/x-ui setting -show | sed -n 4p | awk -F ": " '{print $2}')
        echo -e "${red}Account setting got cancelled, all settings are default, please change it as soon as possible!${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/sing-web/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect x-ui version, may be out of Github API limit, please try again later, or manually specify x-ui version to install${plain}"
            exit 1
        fi
        echo -e "The latest version of x-ui is detected: ${last_version}, start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/sing-web/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please make sure your server can download the Github file${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/sing-web/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui v$1 failed, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/sing-web/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    systemctl stop warp-go >/dev/null 2>&1
    wg-quick down wgcf >/dev/null 2>&1
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
    systemctl start warp-go >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    echo -e "${green}x-ui ${last_version}${plain} Installation completed, panel started"
    echo -e ""
    echo -e "How to use the x-ui administration script: "
    echo -e "----------------------------------------------"
    echo -e "x-ui - Show admin menu (more features)"
    echo -e "x-ui start - Start x-ui panel"
    echo -e "x-ui stop - stop the x-ui panel"
    echo -e "x-ui restart - restart the x-ui panel"
    echo -e "x-ui status - check x-ui status"
    echo -e "x-ui enable - set x-ui to start on its own"
    echo -e "x-ui disable - disable x-ui boot-up"
    echo -e "x-ui log - View x-ui logs"
    echo -e "x-ui update - Update the x-ui panel"
    echo -e "x-ui install - Install the x-ui panel"
    echo -e "x-ui uninstall - uninstall the x-ui panel"
    echo -e "----------------------------------------------"
    echo ""
    if [[ -n $ipv4 ]]; then
        echo -e "${yellow}The panel IPv4 access address is:${plain} ${green}http://$ipv4:$config_port ${plain}"
    fi
    if [[ -n $ipv6 ]]; then
        echo -e "${yellow}The panel IPv6 access address is:${plain} ${green}http://[$ipv6]:$config_port ${plain}"
    fi
    echo -e "Please make sure that this port is not occupied by another application, ${yellow} and that the ${plain} ${red} $config_port ${plain} ${yellow} port is released ${plain}"
}

echo -e "${green}Begin installation${plain}"
install_base
install_x-ui $1