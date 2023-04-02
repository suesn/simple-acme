#!/bin/bash

VERSION="1.5.1"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")

check_install() {
    if [ ! -e /usr/local/bin/simple-acme.sh ]; then
        red "检测到未安装 simple-acme.sh，正在安装"
        curl -L https://github.com/tdjnodj/simple-acme/releases/latest/download/simple-acme.sh -o /usr/local/bin/simple-acme.sh
        chmod +x /usr/local/bin/simple-acme.sh
        if [ ! -e /usr/local/bin/simple-acme.sh ]; then
            red "安装失败！"
            exit 1
        else
            green "已成功安装！下次运行直接输入 simple-acme.sh 即可！"
            rm $0
        fi
    fi
}

install_base(){
    yellow "正在安装依赖(curl socat lsof)"
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} lsof curl socat
}

install_acme(){
    install_base
    read -rp "请输入注册邮箱 (例: admin@gmail.com, 或留空自动生成一个gmail邮箱): " acmeEmail
    if [[ -z $acmeEmail ]]; then
        autoEmail=$(date +%s%N | md5sum | cut -c 1-16)
        acmeEmail=$autoEmail@gmail.com
        yellow "已取消设置邮箱, 使用自动生成的gmail邮箱: $acmeEmail"
    fi
    curl https://get.acme.sh | sh -s email=$acmeEmail
    source ~/.bashrc
    chmod +x ~/.acme.sh/acme.sh
    alias acme.sh=~/.acme.sh/acme.sh
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        green "Acme.sh证书申请脚本安装成功!"
    else
        red "抱歉, Acme.sh证书申请脚本安装失败"
        green "建议如下："
        yellow "1. 检查VPS的网络环境"
        yellow "2. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
    fi
    green "已安装acme.sh脚本，并设置短链接 acme.sh ，开启自动更新、自动续签证书，并且默认证书机构已设置为 let's encrypt !"
}

uninstall() {
    ~/.acme.sh/acme.sh --uninstall
    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
    rm -rf ~/.acme.sh
    green "Acme  一键申请证书脚本已卸载!"
    yellow "如果你想卸载simple-acme，请输入:"
    yellow "rm simple-acme.sh"
}

start_http() {
    read -rp "请输入域名: " domain
    [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
    ip4=$(curl ipv4.ip.sb)
    ip6=$(curl ipv6.ip.sb)
    server4=$(curl ipget.net/?ip="${domain}" -4)
    server6=$(curl ipget.net/?ip="${domain}" -6)
    baling=$(lsof -i:80)

    green "当前vps的ipv4为 $ip4"
    green "当前vps的ipv6为 $ip6"

    yellow "输入域名的ipv4为 $server4"
    yellow "输入域名的ipv6为 $server6"

    red "80端口占用（没有内容代表没占用）： "
    red "$baling"

    echo ""
    red "请检查域名是否解析到ip,并检查80端口是否占用！"
    red "如果有请按ctrl + c退出脚本，并使用 kill [pid] 结束进程"
    red "某些VPS自带apache2，如果你不需要，可以用 apt remove apache2 -y 删除！"
    yellow "请尽量关闭CDN申请!"
    echo ""

    read -rp "请输入是否使用ipv6申请？(Y/n)" iptype
    if [[ $iptype != n ]]; then
        ips="--listen-v6"
    else
        ips="--listen-v4"
    fi
    echo ""
    yellow "选择申请模式"
    yellow " 1. standalone(默认): acme.sh 充当 web 服务器"
    green " 2. nginx: 使用 nginx 申请"
    red " 3. apache: 使用 apache(2) 申请"
    read -p "请选择: " answer
    case $answer in
        1) serverType=standalone ;;
        2) serverType=nginx ;;
        3) serverType=apache ;;
        *) red "standalone" && serverType=standalone ;;
    esac
    yellow "当前申请模式: $serverType"
    echo ""
    yellow "ECDSA 证书安全性更高、效率更高，但兼容性更低一点。目前本脚本中只有 Let's encrypt 支持。"
    yellow "同种证书，数字越大安全性越好，但加密开销更大。"
    yellow "请选择证书类型:"
    green "1. ec-256(默认)"
    yellow "2. ec-384"
    yellow "3. ec-521"
    red "4.RSA-2048"
    red "5. RSA-3072"
    red "6. RSA-4092"
    read -p "请选择: " answer
    case $answer in
        1) keyLength=ec-256 && ecc=1 ;;
        2) keyLength=ec-384 && ecc=1 ;;
        3) keyLength=ec-521 && ecc=1 ;;
        4) keyLength=2048 && ecc=0 ;;
        5) keyLength=3072 && ecc=0 ;;
        6) keyLength=4092 && ecc=0 ;;
        *) keyLength=ec-256 && ecc=1 ;;
    esac

    yellow "即将为 ${domain} 使用 ${serverType} 申请 $keyLength 证书！"

    bash ~/.acme.sh/acme.sh --issue -d ${domain} ${ips} --${serverType} --keylength ${keyLength}

    mkdir ~/${domain}
    bash ~/.acme.sh/acme.sh --install-cert -d $domain --key-file ~/${domain}/${domain}.key --fullchain-file ~/${domain}/${domain}.crt
    green "如果申请成功，将保存到以下路径"
    green "证书(链)(fullchain): ~/${domain}/${domain}.crt"
    green "私钥: ~/${domain}/${domain}.key"
}

start_alpn() {
    read -rp "请输入域名: " domain
    [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
    ip4=$(curl ipv4.ip.sb)
    ip6=$(curl ipv6.ip.sb)
    server4=$(curl ipget.net/?ip="${domain}" -4)
    server6=$(curl ipget.net/?ip="${domain}" -6)

    green "当前vps的ipv4为 $ip4"
    green "当前vps的ipv6为 $ip6"

    yellow "输入域名的ipv4为 $server4"
    yellow "输入域名的ipv6为 $server6"

    red "80端口占用（没有内容代表没占用）： "
    lsof -i :443

    echo ""
    red "请检查域名是否解析到 ip,并检查 443 端口是否占用！"
    red "如果有请按ctrl + c退出脚本，并使用 kill [pid] 结束进程"
    yellow "请尽量关闭CDN申请!"
    echo ""

    read -rp "请输入是否使用ipv6申请？(Y/n)" iptype
    if [[ $iptype != n ]]; then
        ips="--listen-v6"
    else
        ips="--listen-v4"
    fi

    echo ""
    yellow "ECDSA 证书安全性更高、效率更高，但兼容性更低一点。目前本脚本中只有 Let's encrypt 支持。"
    yellow "同种证书，数字越大安全性越好，但加密开销更大。"
    yellow "请选择证书类型:"
    green "1. ec-256(默认)"
    yellow "2. ec-384"
    yellow "3. ec-521"
    red "4.RSA-2048"
    red "5. RSA-3072"
    red "6. RSA-4092"
    read -p "请选择: " answer
    case $answer in
        1) keyLength=ec-256 && ecc=1 ;;
        2) keyLength=ec-384 && ecc=1 ;;
        3) keyLength=ec-521 && ecc=1 ;;
        4) keyLength=2048 && ecc=0 ;;
        5) keyLength=3072 && ecc=0 ;;
        6) keyLength=4092 && ecc=0 ;;
        *) keyLength=ec-256 && ecc=1 ;;
    esac

    yellow "即将为 ${domain} 申请 $keyLength 证书！"

    bash ~/.acme.sh/acme.sh --issue -d ${domain} ${ips} --alpn --keylength ${keyLength}

    mkdir ~/${domain}
    bash ~/.acme.sh/acme.sh --install-cert -d $domain --key-file ~/${domain}/${domain}.key --fullchain-file ~/${domain}/${domain}.crt
    green "如果申请成功，将保存到以下路径"
    green "证书(链)(fullchain): ~/${domain}/${domain}.crt"
    green "私钥: ~/${domain}/${domain}.key"
}

start_txt() {
    red "警告: 该模式不会自动续签!"
    echo ""
    read -p "请输入域名(可以带 * 号): " domain
    [[ -z "$domain" ]] && red "请输入域名!" && exit 1
    echo ""
    yellow "ECDSA 证书安全性更高、效率更快，但兼容性更低一点"
    read -p "是否申请 ECDSA 类型的证书(Y/n)?" answer
    if [[ "$answer" == "n" ]]; then
        cert_type="rsa"
    else
        cert_type="ecc"
    fi
    green "当前申请 ${cert_type} 类型的证书"
    if [[ "$cert_type" == "rsa" ]]; then
        cert_add1=""
        cert_add2=""
    else
        cert_add1="--keylength ec-256"
        cert_add2="--ecc"
    fi
    echo ""
    yellow "即将开始申请"
    red "等下请留意 绿色 字体的 'Domain:' 和txt记录 'TXT value:'，并手动到 DNS 解析处填写"
    yellow "冒红字是正常的，不要在意"
    sleep 5
    bash ~/.acme.sh/acme.sh --issue -d ${domain} --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please ${cert_add1}
    green "建议: 填写完后最好等待一分钟，使 DNS 完全解析。"
    read -p "确认填写完后请回车...... " 
    bash ~/.acme.sh/acme.sh --renew -d ${domain}  --yes-I-know-dns-manual-mode-enough-go-ahead-please ${cert_add2}

    mkdir ~/${domain}
    bash ~/.acme.sh/acme.sh --install-cert -d $domain --key-file ~/${domain}/${domain}.key --fullchain-file ~/${domain}/${domain}.crt
    green "如果申请成功，将保存到以下路径"
    green "证书(链)(fullchain): ~/${domain}/${domain}.crt"
    green "私钥: ~/${domain}/${domain}.key"
}

switch_provider(){
    yellow "请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 "
    yellow "如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请."
    echo ""
    green "本脚本很多功能只有 Let's encrypt 支持，请尽量使用！"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} Letsencrypt.org"
    echo -e " ${GREEN}2.${PLAIN} BuyPass.com"
    echo -e " ${RED}3.${PLAIN} ZeroSSL.com(有发放限制，不推荐)"
    echo -e " ${RED}4.${PLAIN} Letsencrypt.org (${RED}测试版，不受浏览器信任${PLAIN})"
    read -rp "请选择证书提供商 [1-3，默认1]: " provider
    case $provider in
        1) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！" ;;
        2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && green "切换证书提供商为 BuyPass.com 成功！" ;;
        3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && green "切换证书提供商为 ZeroSSL.com 成功！" ;;
        4) bash ~/.acme.sh/acme.sh --set-default-ca --server https://acme-staging-v02.api.letsencrypt.org/directory && red " 切换证书提供商为 Letsencrypt.org (测试版) 成功!" ;;
        *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！" ;;
    esac
}

own_cert() {
    yellow "注: 除域名外，其他值回车即代表使用默认值"
    echo ""
    echo ""
    read -p "请输入您的域名(支持*): " domain
    [[ -z "$domain" ]] && red "请输入域名！" && exit 1
    echo ""
    read -p "请输入有效天数(默认:9999): " days
    [[ -z "$days" ]] && days=9999
    yellow "当前有效天数: $days"
    echo ""
    read -p "请输入国家代码(可以乱编，示例:CN): " country
    [[ -z "$country" ]] && country="CN"
    yellow "当前国家: $country"
    echo ""
    read -p "请输入行政省名称(可以编，示例: Guangdong): " state
    [[ -z "$state" ]] && state="Guangdong"
    yellow "当前行政省: $state"
    echo ""
    read -p "请输入城市名(可以编，示例: Shanghai): " city
    [[ -z "$city" ]] && city="Shenzhen"
    yellow "当前城市: $city"
    echo ""
    read -p "请输入组织名(编，示例: Tencent): " company
    [[ -z "$company" ]] && company="Tencent"
    yellow "当前组织: $company"
    echo ""
    read -p "请输入组织单位名(编，示例: Shoping): " section
    [[ -z "$section" ]] && section="Shoping"
    yellow "当前单位: $section"
    echo ""

    mkdir ~/${domain}
    cd ~/${domain}
    openssl genrsa -out ${domain}.key 1024
    openssl req -new -x509 -days ${days} -key ${domain}.key -out ${domain}.crt -subj "/C=${country}/ST=${state}/L=${city}/O=${company}/OU=${section}/CN=${domain}"
    yellow "生成成功，证书位于 /root/${domain}/${domain}.crt "
    yellow "私钥位于: /root/${domain}/${domain}.key"
}

renew_http() {
    red "提示: "
    yellow "1. 如果你使用 http 模式申请，证书会自动续签"
    yellow "2. DNS 手动模式不能使用"
    echo ""
    read -p "输入任意内容继续，按 crtl + c 退出" rubbish

    echo ""
    read -p "请输入你要续签的域名" domain
    echo ""
    read -p "是否为 ecc 证书(y/N)? "answer
    if [[ "$answer" == "y" ]]; then
        cert_add1="ecc"
    else
        cert_add1=""
    fi

    bash ~/.acme.sh/acme.sh --renew -d ${domain} --force ${cert_add1}
}

install_cert() {
    echo ""
    read -p " 请输入域名(必须先用 acme.sh 申请过证书！)" domain
    echo ""
    yellow " 请选择安装的程序: "
    red " 1. apache2"
    green " 2. nginx"
    yellow " 3. 自定义"
    read -p "请选择: " answer
    if [ "$answer" == "1" ]; then
        bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --reloadcmd  "service apache2 force-reload"
    elif [ "$answer" == "2" ]; then
        bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --reloadcmd  "service nginx force-reload"
    else
        yellow "请输入你想安装到的路径(例: /etc/nginx/cert.pem): "
        read -p "证书: " cert
        yellow "即将安装 证书 到 $cert"
        echo ""
        read -p "密钥: " key
        yellow "即将安装 密钥 到 $key"
        echo ""
        read -p "请输入重载目标程序的命令(例: systemctl reload nginx / xui restar): " reloadOrder
        bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --reloadcmd  "${reloadOrder}" --key-file "$key" --fullchain-file "$cert"
    fi
}

renew_simple() {
    newVersion=$(curl -L https://raw.githubusercontent.com/tdjnodj/simple-acme/main/VERSION)
    if [ "$newVersion" != "$VERSION" ]; then
        red "检测到版本变化: "
        yellow "当前版本: $VERSION"
        yellow "最新版本: $newVersion"
        read -p "是否更新？(Y/n)" answer
        if [ "$answer" == "n" ] || [ "$answer" == "N" ]; then
            exit 0
        else
            wget https://github.com/tdjnodj/simple-acme/releases/latest/download/simple-acme.sh -O /usr/local/bin/simple-acme.sh
            chmod +x /usr/local/bin/simple-acme.sh
            green "更新成功！"
        fi
    fi
}

menu() {
    clear
    echo " ############################################################"
    echo " #                   simple acme                            #"
    echo " #助您方便申请证书                                          #"
    echo " #版本：$VERSION                                               #"
    echo -e " #快捷命令: ${GREEN} simple-acme.sh ${PLAIN}                                #"
    echo " ############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装/更新 Acme.sh 域名证书申请脚本"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Acme.sh 域名证书申请脚本${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 申请单域名证书 ${YELLOW}(通过 80 端口申请/http 模式)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 申请单域名证书 ${YELLOW}(通过 443 端口申请/alpn 模式)${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}5.${PLAIN} 自签证书(可申请泛域名证书)"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 申请单/泛域名证书 ${YELLOW}(手动填写 DNS txt 记录)${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}9.${PLAIN} 切换证书颁发机构"
    echo " -------------"
    echo -e " ${GREEN}10.${PLAIN} 续签证书 ${YELLOW}(仅支持 http 模式)${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}20.${PLAIN} 为网页服务器安装证书"
    echo -e " ${GREEN}21.${PLAIN} ${RED}更新 simple-acme.sh ${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp " 请输入选项 [0-9]: " NumberInput
    case "$NumberInput" in
        1) install_acme ;;
        2) uninstall ;;
        3) start_http ;;
        4) start_alpn ;;
        5) own_cert ;;
        6) start_txt ;;
        9) switch_provider ;;
        10) renew_http ;;
        20) install_cert ;;
        21) renew_simple ;;
        *) exit 0 ;;
    esac
}

check_install

menu
