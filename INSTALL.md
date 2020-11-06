# Install as a systemd service

1. Unzip `jruby_jasper.zip` in a dir (typically `jruby_jasper`).
2. Run the following commands in order: 
```
cp jruby_jasper.service.template jruby_jasper.service
sed -i "s/\$USER/$(whoami)/g" jruby_jasper.service
sed -i "s?\$PWD?$(pwd)?g" jruby_jasper.service
sudo cp jruby_jasper.service /etc/systemd/system/
sudo systemctl enable jruby_jasper.service
sudo systemctl start jruby_jasper.service
sudo systemctl status jruby_jasper.service
```

3. If the `status` command shows an error, debug with:
```
journalctl -xe
tail -n100 /var/log/syslog
```
