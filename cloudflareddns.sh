#!/bin/bash
set -e;

ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
ipv6Regex="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"


http_body=""
http_code=""
curl_code=0

http_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local response
    set +e
    if [ -n "$data" ]; then
        response=$(curl -s -S --connect-timeout 10 --max-time 20 -o - -w "HTTPSTATUS:%{http_code}" -X "$method" "$url" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "$data" 2>/dev/null)
        curl_code=$?
    else
        response=$(curl -s -S --connect-timeout 10 --max-time 20 -o - -w "HTTPSTATUS:%{http_code}" -X "$method" "$url" -H "Authorization: Bearer $password" -H "Content-Type:application/json" 2>/dev/null)
        curl_code=$?
    fi
    set -e
    http_code="${response##*HTTPSTATUS:}"
    http_body="${response%HTTPSTATUS:*}"
}

handle_curl_error() {
    local c=$curl_code
    if [ "$c" -ne 0 ]; then
        if [ "$c" -eq 6 ]; then
            echo "badresolv"; exit 0
        fi
        if [ "$c" -eq 7 ] || [ "$c" -eq 28 ]; then
            echo "badconn"; exit 0
        fi
        echo "badconn"; exit 0
    fi
}

handle_http_error() {
    local code="$1"
    if [[ "$code" =~ ^5 ]]; then
        echo "911"; exit 0
    fi
    if [ "$code" = "429" ]; then
        echo "abuse"; exit 0
    fi
    if [ "$code" = "401" ] || [ "$code" = "403" ]; then
        echo "badauth"; exit 0
    fi
    if [ "$code" = "400" ] || [ "$code" = "405" ] || [ "$code" = "415" ]; then
        echo "badagent"; exit 0
    fi
}




# DSM Config
username="$1"
password="$2"
hostname="$3"
ipAddr="$4"


# 解析hostname参数格式: host.domain.com-46-T
# 第二个参数: 4=仅IPv4, 6=仅IPv6, 46=IPv4+IPv6
# 第三个参数: T=开启proxy, F=关闭proxy
if [[ "$hostname" == *"-"* ]]; then
    # 分割hostname和参数
    IFS='-' read -ra PARTS <<< "$hostname"
    if [ ${#PARTS[@]} -eq 3 ]; then
        real_hostname="${PARTS[0]}"
        ip_type="${PARTS[1]}"
        proxy_setting="${PARTS[2]}"
        
        # 验证参数
        if [[ "$ip_type" =~ ^[46]+$ ]] && [[ "$proxy_setting" =~ ^[TF]$ ]]; then
            hostname="$real_hostname"
        else
            echo "badagent"
            exit 0
        fi
    else
        echo "badagent"
        exit 0
    fi
else
    # 默认设置: 自动检测IPv6, 关闭proxy
    ip_type="46"
    proxy_setting="F"
fi

# 根据参数设置IPv4和IPv6更新标志
update_ipv4=false
update_ipv6=false

if [[ "$ip_type" == *"4"* ]]; then
    update_ipv4=true
fi

if [[ "$ip_type" == *"6"* ]]; then
    update_ipv6=true
fi

# 根据参数设置proxy
if [[ "$proxy_setting" == "T" ]]; then
    proxy="true"
else
    proxy="false"
fi



# 获取IPv6地址（如果需要）
ip6Addr=""
if [[ "$update_ipv6" == "true" ]]; then
    ip6fetch=$(ip -6 addr show eth0 | grep -oP "$ipv6Regex" || true)
    ip6Addr=$(if [ -z "$ip6fetch" ]; then echo ""; else echo "${ip6fetch:0:$((${#ip6fetch})) - 7}"; fi)
    if [[ -z "$ip6Addr" ]]; then
        update_ipv6=false
    fi
    
fi

# 验证IPv4地址
if [[ "$update_ipv4" == "true" ]] && [[ ! "$ipAddr" =~ $ipv4Regex ]]; then
    echo "badagent"; exit 0
fi

# 如果没有有效的IP地址需要更新，退出
if [[ "$update_ipv4" == "false" ]] && [[ "$update_ipv6" == "false" ]]; then
    echo "badagent"; exit 0
fi

# 记录类型设置
if [[ "$update_ipv4" == "true" ]]; then
    recordType="A"
fi

if [[ "$update_ipv6" == "true" ]]; then
    recType6="AAAA"
fi

# 校验 zone 并确认 hostname 隶属关系
http_request "GET" "https://api.cloudflare.com/client/v4/zones/${username}" ""
handle_curl_error
handle_http_error "$http_code"
zone_ok=$(echo "$http_body" | jq -r ".success" 2>/dev/null || echo "false")
if [ "$zone_ok" != "true" ]; then
    echo "badagent"; exit 0
fi
zone_name=$(echo "$http_body" | jq -r ".result.name")
if [ -z "$zone_name" ] || [ "$zone_name" = "null" ]; then
    echo "badauth"; exit 0
fi
case "$hostname" in
    "$zone_name"|*.$zone_name) ;;
    *) echo "nohost"; exit 0;;
esac

# Cloudflare API调用 - 列出现有记录
if [[ "$update_ipv4" == "true" ]]; then
    listDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records?type=${recordType}&name=${hostname}"
    http_request "GET" "$listDnsApi" ""
    handle_curl_error
    handle_http_error "$http_code"
    resSuccess=$(echo "$http_body" | jq -r ".success" 2>/dev/null || echo "false")
    if [[ $resSuccess != "true" ]]; then
        echo "badagent"; exit 0
    fi
    recordId=$(echo "$http_body" | jq -r ".result[0].id")
    recordIp=$(echo "$http_body" | jq -r ".result[0].content")
    recordProx=$(echo "$http_body" | jq -r ".result[0].proxied")
    
fi

if [[ "$update_ipv6" == "true" ]]; then
    listDnsv6Api="https://api.cloudflare.com/client/v4/zones/${username}/dns_records?type=${recType6}&name=${hostname}"
    http_request "GET" "$listDnsv6Api" ""
    handle_curl_error
    handle_http_error "$http_code"
    resv6Success=$(echo "$http_body" | jq -r ".success" 2>/dev/null || echo "false")
    if [[ $resv6Success != "true" ]]; then
        echo "badagent"; exit 0
    fi
    recordIdv6=$(echo "$http_body" | jq -r ".result[0].id")
    recordIpv6=$(echo "$http_body" | jq -r ".result[0].content")
    recordProxv6=$(echo "$http_body" | jq -r ".result[0].proxied")
    
fi

# API端点
createDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records"

# 检查是否需要更新
need_update=false
if [[ "$update_ipv4" == "true" ]] && [[ "$recordIp" != "$ipAddr" ]]; then
    need_update=true
fi

if [[ "$update_ipv6" == "true" ]] && [[ "$recordIpv6" != "$ip6Addr" ]]; then
    need_update=true
fi

if [[ "$need_update" == "false" ]]; then
    echo "nochg"; exit 0
fi

# 更新IPv4记录
if [[ "$update_ipv4" == "true" ]]; then
    if [[ "$recordId" == "null" ]]; then
        # 创建新记录
        http_request "POST" "$createDnsApi" "{\"type\":\"$recordType\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}"
    else
        # 更新现有记录
        updateDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordId}"
        http_request "PUT" "$updateDnsApi" "{\"type\":\"$recordType\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}"
    fi
    handle_curl_error
    handle_http_error "$http_code"
    resSuccess=$(echo "$http_body" | jq -r ".success" 2>/dev/null || echo "false")
    if [[ $resSuccess != "true" ]]; then
        echo "badagent"; exit 0
    fi
fi

# 更新IPv6记录
if [[ "$update_ipv6" == "true" ]]; then
    if [[ "$recordIdv6" == "null" ]]; then
        # 创建新记录
        http_request "POST" "$createDnsApi" "{\"type\":\"$recType6\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$proxy}"
    else
        # 更新现有记录
        update6DnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordIdv6}"
        http_request "PUT" "$update6DnsApi" "{\"type\":\"$recType6\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$proxy}"
    fi
    handle_curl_error
    handle_http_error "$http_code"
    res6Success=$(echo "$http_body" | jq -r ".success" 2>/dev/null || echo "false")
    if [[ $res6Success != "true" ]]; then
        echo "badagent"; exit 0
    fi
fi

 echo "good"