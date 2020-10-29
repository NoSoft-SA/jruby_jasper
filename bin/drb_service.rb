# frozen_string_literal: true

# puts ''
# puts '--------------------------------------------------------------------------------------'
# puts '--- NB. Must run with Java 8. Later versions incompatible with current Jasper jars ---'
# puts '--------------------------------------------------------------------------------------'
# puts "        (Running with java #{java.lang.System.get_property('java.version')})"
# puts ''
#
require 'drb/drb'
require 'dotenv'
require 'pathname'

# Some setup
# ----------
# ROOT_PATH is the root folder. When run in a jar it is the jar's root.
pn = Pathname.new(__dir__)
ROOT_PATH = pn.parent

# The on-disk root folder. This must be defined by config when run as a jar via java.
JAR_BASE = ENV.fetch('JAR_BASE', File.expand_path('../', __dir__))
raise ArgumentError, 'When running via java, the JAR_BASE environment variable must be set.' if JAR_BASE.start_with?('uri:classloader:')

# Load environment variables
Dotenv.load(File.join(JAR_BASE, 'config/.env.local'), File.join(JAR_BASE, 'config/.env'))

# Load the class that interacts with Jasper.
require ROOT_PATH + 'lib/jasper_report'

# A globally available Log4j logger instance
LOGGER = LogManager.getLogger('JasperRuby')

# Distributed Ruby class for executing Japser reports
class Service
  def make_jasper_report(user, report_name, path, mode, db_opts, params)
    LOGGER.info("Generating report #{report_name} for user #{user}")
    LOGGER.debug("Parameters: #{params.inspect}")

    jr = JasperReport.new(report_name, path, db_opts, params)

    { success: true, msg: "Generated #{report_name}", doc: jr.export(mode) }
  rescue StandardError => e
    LOGGER.error e.class.name
    LOGGER.error e.message
    LOGGER.error e.backtrace.join("\n")
    { success: false, msg: e.message, error_type: e.class.name, backtrace: e.backtrace }
  end

  def version
    File.read(File.join(ROOT_PATH, 'VERSION'))
  end
end

DRb.start_service "druby://#{ENV['JASPER_REPORTS_HOST_PORT']}", Service.new

puts "Listening on #{ENV['JASPER_REPORTS_HOST_PORT']}"
LOGGER.info("Listening on #{ENV['JASPER_REPORTS_HOST_PORT']}")
# puts "Running with java #{java.lang.System.get_property('java.version')}"

# Wait for the drb server thread to finish before exiting.
DRb.thread.join
