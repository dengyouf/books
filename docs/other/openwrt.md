```shell
sudo virt-install --name immortalwrt \
--osinfo=linux2022 --ram 1024 --vcpus 2 \
--disk path=immortalwrt-23.05.1-x86-64-generic-ext4-combined-efi.img,bus=virtio,cache=writeback \
--network bridge=br0,model=virtio  \
--graphics=vnc,password=123456,port=5967,listen=0.0.0.0 \
--noautoconsole --import --autostart
```

插件：
- luci-i18n-argon-config-zh-cn
- luci-app-openclash
- luci-i18n-passwall-zh-cn
- luci-i18n-homeproxy-zh-cn
