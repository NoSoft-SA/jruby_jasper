# Jruby Jasper distributed service

A distributed Ruby class running in Java, called from MRuby to produce Jasper Reports.

## Usage

Run: `java -jar jruby_jasper.jar` (or use the `start.sh` script.

Configure:

- `config/.env.local` for the host/port to listen at.
- `config/log4j2xml` for logging settings.

A restart is required for configuration changes to take effect.

Call from client Ruby code:

```ruby
require 'drb/drb'

SERVER_URI = 'druby://localhost:9998' # Or another ip:port
DRb.start_service
service = DRbObject.new_with_uri(SERVER_URI)
db_opts = DB.opts.select { |k, _| %i[user password port host database].include?(k) },
res = service.make_jasper_report(report_name_without_ext,
                                 path_to_report_name_file,
                                 :pdf, # OR: :xls, :rtf, :csv
                                 db_opts,
                                 params)
puts res[:msg]
File.open('./report_name.pdf', 'w') { |f| f << res[:doc] } if res[:success]
# Do something with res[:msg] if res[:success] is false...
```

## Requirements

- Java. Currently restricted to version 8.
- Postgresql.

## Generate jar file

For development, JRuby 9.2.13 is required.

Run `bundle exec warble` to generate the jar file.

