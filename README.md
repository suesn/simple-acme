# simple-acme

申请ssl证书简单化

# 使用

```shell
bash <(curl -L https://github.com/tdjnodj/simple-acme/releases/latest/download/simple-acme.sh)
```

此后使用:
```shell
simple-acme.sh
```

# 特性

- 自动安装一些依赖（不会耗费太多时间）
- 自动检测端口是否占用
- 自动拷贝证书
- 可生成自签证书
- 支持ipv6
- 对错误的提示不足
- 界面简洁
- 可申请多种 加密方式/密钥长度 的证书

- 可使用 DNS 手动模式申请证书
- 可使用 http 模式，通过 80 端口，与本地网页服务器共存/虚拟一个网页服务器 申请证书
- 可使用 alpn 模式，通过 443 端口，通过 tls 验证申请证书

# TODO

- cloudflare api

# 常见问题

Q: 为什么证书没有自动续签？/为什么手动续签失败？

A: 你需要确保续签的时候80端口占用情况跟申请的时候一样。比如你使用 standalone 模式申请证书，那你续签的时候就不能有 nginx、apache 之类的占用80端口。**所以，建议如果你之后要用网页服务器，那就先安装网页服务器，再使用对应模式申请。**

# DEVELOP

```shell
wget https://raw.githubusercontent.com/tdjnodj/simple-acme/main/simple-acme.sh && bash simple-acme.sh
```

# Credits

主要代码来源: [taffychan-acme](https://github.com/taffychan/acme)

调用脚本: [acme.sh](https://acme.sh/)

特别感谢: [Let's Encrypt](https://letsencrypt.org/)
