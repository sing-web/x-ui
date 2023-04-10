# x-ui

Multi-protocol, multi-user xray panel support

# Features

- System status monitoring
- Support multi-user multi-protocol, web visualization operation
- Supported protocols: vmess, vless, trojan, shadowsocks, dokodemo-door, socks, http
- Support vless / trojan reality
- Support for configuring more transport configurations
- Traffic statistics, limit traffic, limit expiration time
- Customizable xray configuration templates
- Support https access panel (self-provided domain + ssl certificate)
- Support one-click SSL certificate application and automatic renewal
- More advanced configuration items, see panel for details

# Installation & Upgrade

```
bash <(wget -qO- https://raw.githubusercontent.com/sing-web/x-ui/main/install.sh)
```

## Manual installation & upgrade

1. First download the latest tarball from the project, usually choose the `amd64` architecture
2. Then upload the tarball to the `/root/` directory on the server and login to the server with the `root` user

> If your server cpu architecture is not `amd64`, replace `amd64` in the command with another architecture

```
cd /root/
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
tar zxvf x-ui-linux-amd64.tar.gz
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
cp x-ui/x-ui.sh /usr/bin/x-ui
cp -f x-ui/x-ui.service /etc/systemd/system/
mv x-ui/ /usr/local/
systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui
```

## Installing with docker

> This docker tutorial and docker image is provided by [Chasing66](https://github.com/Chasing66)

1. Installing docker

```shell
curl -fsSL https://get.docker.com | sh
```

2. install x-ui

```shell
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:latest
```

> Build your own image

```shell
docker build -t x-ui .
```

## TG bot usage

> This feature and tutorial is provided by [FranzKafkaYu](https://github.com/FranzKafkaYu)

X-UI supports daily traffic notification and panel login reminder via Tg bot.
The specific application tutorial can be found in [blog link](https://coderfan.net/how-to-use-telegram-bot-to-alarm-you-when-someone-login-into-your-vps.html)
Instructions:Set the bot-related parameters in the background of the panel, including

- Tg Robot Token
- Tg bot ChatId
- Tg robot cycle running time, using crontab syntax  

Reference syntax:
- 30 * * * * * * //notify on the 30ths of every minute
- @hourly // hourly notification
- @daily //daily notification (at 00:00 am sharp)
- @every 8h //notify every 8 hours  

TG notification content:
- Node traffic usage
- Panel login reminder
- Node expiration reminder
- Traffic alert reminder  

More features are being planned...

## Recommended Systems

- CentOS 7+
- Ubuntu 16+
- Debian 8+

## FAQ

## Migrating from v2-ui

First install the latest version of x-ui on the server where v2-ui is installed, then use the following command to migrate `all inbound account data` from v2-ui to x-ui, `panel settings and username and password will not be migrated`.

> After successful migration, please ``shut down v2-ui`` and ``restart x-ui``, otherwise the inbound of v2-ui will have ``port conflict`` with the inbound of x-ui

```
x-ui v2-ui
```

## Acknowledgements

vaxilu's x-ui project: https://github.com/vaxilu/x-ui

qist's xray-ui project: https://github.com/qist/xray-ui

## Sponsorship

afdian: https://afdian.net/a/Misaka-blog

![afdian-MisakaNo の 小破站](https://user-images.githubusercontent.com/122191366/211533469-351009fb-9ae8-4601-992a-abbf54665b68.jpg)

## Disclaimer

* This program is for learning and understanding only, not for profit, please delete within 24 hours after downloading, not for any commercial use, text, data and images are copyrighted, if reproduced, please indicate the source.
* Use of this program is subject to the deployment disclaimer. Use of this program is subject to the laws and regulations of the country where the server is deployed and the country where the user is located, and the author of the program is not responsible for any misconduct of the user.

Translated with www.DeepL.com/Translator (free version)