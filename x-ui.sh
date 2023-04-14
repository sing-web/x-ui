#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

#Add some basic function here
function LOGD() {
    echo -e "${YELLOW}[DEG] $* ${PLAIN}"
}

function LOGE() {
    echo -e "${RED}[ERR] $* ${PLAIN}"
}

function LOGI() {
    echo -e "${GREEN}[INF] $* ${PLAIN}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "错误:  必须使用root用户运行此脚本!\n" && exit 1

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
    LOGE "未检测到系统版本，请联系脚本作者！\n" && exit 1
fi

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
        LOGE "请使用 CentOS 7 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "请使用 Ubuntu 16 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "请使用 Debian 8 或更高版本的系统！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart the panel, restarting the panel will also restart the xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${YELLOW}Press Enter to return to the main menu. ${PLAIN}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/sing-web/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstallation of the current latest version without data loss, will it continue?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Canceled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/sing-web/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "The update is complete and the panel has been automatically restarted"
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel, xray will uninstall it too?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf
    rm /usr/bin/x-ui -f

    echo ""
    echo -e "x-ui panel has been uninstalled successfully"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset the username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "The username and password have been reset to ${GREEN}admin${PLAIN}, now please restart the panel"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all the panel settings, the account data will not be lost, the username and password will not be changed" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to their default values, now please restart the panel and use the default ${GREEN}54321${PLAIN} port to access the panel"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Enter the port number [1-65535]. " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Canceled"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "After setting the port, now please restart the panel and use the newly set port ${GREEN}${port}${PLAIN} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Panel is running, no need to start again, if you want to restart please select restart"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui started successfully"
        else
            LOGE "The panel failed to start, probably because it took more than two seconds to start, please check the log information later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Panel is stopped, no need to stop again"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui and xray stop successfully"
        else
            LOGE "The panel failed to stop, probably because it took more than two seconds to stop, please check the log message later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui and xray restarted successfully"
    else
        LOGE "Panel restart failed, probably because the startup time exceeded two seconds, please check the log information later"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui set boot up successfully"
    else
        LOGE "x-ui failed to set boot-up"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Cancel boot up successfully"
    else
        LOGE "x-ui Failed to cancel boot-up"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/sing-web/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Download script failed, please check if you can connect to Github on your local machine"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Upgrade script successfully, please re-run the script" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Panel is already installed, please do not repeat the installation"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Please install the panel first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel Status: ${GREEN}running${PLAIN}"
        show_enable_status
        ;;
    1)
        echo -e "Panel Status: ${YELLOW}stopped${PLAIN}"
        show_enable_status
        ;;
    2)
        echo -e "Panel Status: ${RED}Not installed${PLAIN}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to boot up or not: ${GREEN}yes${PLAIN}"
    else
        echo -e "Whether to boot up or not: ${RED}not${PLAIN}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray Status: ${GREEN}running${PLAIN}"
    else
        echo -e "xray Status: ${RED}stopped${PLAIN}"
    fi
}

ssl_cert_issue() {
    wget -N --no-check-certificate https://raw.githubusercontent.com/Misaka-blog/acme-script/main/acme.sh && bash acme.sh
}

open_ports(){
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    green "All ports have been released successfully!"
}

x25519() {
    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    elif [[ $arch == "s390x" ]]; then
        arch="s390x"
    else
        arch="amd64"
    fi
    
    keys=$(/usr/local/x-ui/bin/xray-linux-${arch} x25519)
    public_key=$(echo $keys | awk -F " " '{print $6}')
    private_key=$(echo $keys | awk -F " " '{print $3}')
    short_id=$(openssl rand -hex 8)
    green "The public and private keys and shortId for xray Reality have been generated successfully!"
    yellow "Please save this content for use in creating Reality nodes"
    red "Public key: $public_key"
    red "private key: $private_key"
    red "shortId: $short_id"
    echo ""
    before_show_menu
}

show_usage() {
    echo "How to use the x-ui administration script: "
    echo "------------------------------------------"
    echo "x-ui - Show admin menu (more features)"
    echo "x-ui start - start x-ui panel"
    echo "x-ui stop - stop the x-ui panel"
    echo "x-ui restart - restart the x-ui panel"
    echo "x-ui status - View x-ui status"
    echo "x-ui enable - set x-ui to start on its own"
    echo "x-ui disable - disable x-ui power on"
    echo "x-ui log - View x-ui logs" echo "x-ui log - View x-ui logs"
    echo "x-ui update - Update the x-ui panel"
    echo "x-ui install - Install the x-ui panel"
    echo "x-ui uninstall - uninstall the x-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${GREEN}x-ui panel management script ${PLAIN}
  ${GREEN}0.${PLAIN} Exit script
————————————————————————————————————————————————
  ${GREEN}1.${PLAIN} Install x-ui
  ${GREEN}2.${PLAIN} Update x-ui
  ${GREEN}3.${PLAIN} Uninstall x-ui
————————————————————————————————————————————————
  ${GREEN}4.${PLAIN} Reset username password
  ${GREEN}5.${PLAIN} Reset panel settings
  ${GREEN}6.${PLAIN} Set the panel port
  ${GREEN}7.${PLAIN} View current panel settings
————————————————————————————————————————————————
  ${GREEN}8.${PLAIN} Start x-ui
  ${GREEN}9.${PLAIN} Stop x-ui
  ${GREEN}10.${PLAIN} restart x-ui
  ${GREEN}11.${PLAIN} Check x-ui status
  ${GREEN}12.${PLAIN} View x-ui logs
————————————————————————————————————————————————
  ${GREEN}13.${PLAIN} Set x-ui to boot up
  ${GREEN}14.${PLAIN} Cancel x-ui boot-up
————————————————————————————————————————————————
  ${GREEN}15.${PLAIN} Install bbr with one click (latest kernel)
  ${GREEN}16.${PLAIN} Apply SSL certificate with one click (acme application)
  ${GREEN}17.${PLAIN} One click to release all network ports
 "
    show_status
    echo && read -p "Please enter your choice [0-17]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    17)
        open_ports
        ;;
    *)
        LOGE "Please enter the correct number [0-18]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi