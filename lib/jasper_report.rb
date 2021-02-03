# frozen_string_literal: true

# Add the on-disk config folder to Java classpath so the Log4j config can be found
$CLASSPATH << File.join(JAR_BASE, 'config')

require 'tempfile'
require 'java'

# Load all the .jar files required by JasperReports:
Dir.entries(ROOT_PATH + 'lib/jasperreports').each do |lib|
  require File.join(ROOT_PATH, 'lib/jasperreports', lib) if lib =~ /\.jar$/
end

# Java classes to be called from Ruby:
java_import 'net.sf.jasperreports.engine.JasperFillManager'

java_import 'net.sf.jasperreports.engine.JasperExportManager'
java_import 'net.sf.jasperreports.export.SimpleExporterInput'
java_import 'net.sf.jasperreports.export.SimpleWriterExporterOutput'
java_import 'net.sf.jasperreports.export.SimpleOutputStreamExporterOutput'

java_import 'net.sf.jasperreports.engine.export.JRCsvExporter'
java_import 'net.sf.jasperreports.engine.export.JRRtfExporter'

java_import 'net.sf.jasperreports.engine.export.ooxml.JRXlsxExporter'
java_import 'net.sf.jasperreports.export.SimpleXlsxReportConfiguration'
java_import 'net.sf.jasperreports.export.SimpleXlsxExporterConfiguration'

java_import java.sql.Connection
java_import java.sql.DriverManager
java_import java.sql.SQLException
java_import org.postgresql.Driver
java_import org.apache.logging.log4j.LogManager
Java::JavaClass.for_name 'org.postgresql.Driver'
Java::JavaClass.for_name 'java.util.Properties'

# Print imports
java_import javax.print.PrintServiceLookup
java_import javax.print.attribute.HashPrintServiceAttributeSet
java_import javax.print.attribute.HashPrintRequestAttributeSet
java_import javax.print.attribute.standard.MediaSizeName
java_import javax.print.attribute.standard.PrinterName
java_import javax.print.attribute.standard.Copies
java_import javax.print.attribute.standard.OrientationRequested
java_import 'net.sf.jasperreports.engine.export.JRPrintServiceExporter'
java_import 'net.sf.jasperreports.export.SimplePrintServiceExporterConfiguration'


# Integrate with the JapserReports java classes
class JasperReport # rubocop:disable Metrics/ClassLength
  EXPORTERS = {
    pdf: :to_pdf,
    xls: :to_xls,
    rtf: :to_rtf,
    csv: :to_csv,
    print: :to_printer
  }.freeze

  def initialize(report_name, path, db_opts, params)
    @report_name = report_name
    @path = "#{path}/#{report_name}"
    @printer_name = params.delete(:_printer_name)
    prepare_parameters(params)

    @db_opts = db_opts

    @was_at = Dir.pwd
  rescue StandardError => e
    LOGGER.error e.class.name
    LOGGER.error e.message
    LOGGER.error e.backtrace.join("\n")
    raise e.message
  end

  def export(output_format)
    Dir.chdir @path
    @conn = make_db_connection

    fill = fill_report
    meth = EXPORTERS[output_format]
    raise ArgumentError, "#{output_format} is not a valid output format for Jasper reports." if meth.nil?

    send(meth, fill)
  ensure
    Dir.chdir @was_at
    @conn.close if @conn
  end

  private

  def to_printer(fill)
    services = PrintServiceLookup.lookupPrintServices(nil, nil)
    raise 'There are no available printers' if services.nil? || services.length.zero?

    printer = nil
    services.each do |service|
      if @printer_name == service.get_name
        printer = service
        break
      end
    end
    raise "Could not print - printer #{@printer_name} not found" if printer.nil?

    exporter = JRPrintServiceExporter.new
    exporter.setExporterInput(SimpleExporterInput.new(fill))

    req_attr = HashPrintRequestAttributeSet.new
    req_attr.add(MediaSizeName::ISO_A4);
    req_attr.add(Copies.new(1));
    # The orientation setting may not be required - Jasper seems to handle it automatically.
    # if fill.get_orientation_value == 'LANDSCAPE'
    #   req_attr.add(OrientationRequested::LANDSCAPE)
    # else
    #   req_attr.add(OrientationRequested::PORTRAIT)
    # end
    service_attrs = HashPrintServiceAttributeSet.new
    service_attrs.add(PrinterName.new(@printer_name, nil));
    

    print_config = SimplePrintServiceExporterConfiguration.new
    print_config.setPrintRequestAttributeSet(req_attr)
    print_config.setPrintServiceAttributeSet(service_attrs)
    print_config.setDisplayPageDialog(false)
    print_config.setDisplayPrintDialog(false)

    exporter.setConfiguration(print_config)
    exporter.exportReport
    'Sent to printer'
  end

  def to_pdf(fill)
    pdf = JasperExportManager.export_report_to_pdf(fill)
    String.from_java_bytes(pdf)
  end

  def to_rtf(fill)
    exporter = JRRtfExporter.new
    exporter.setExporterInput(SimpleExporterInput.new(fill))
    strm = java.io.ByteArrayOutputStream.new
    exporter.setExporterOutput(SimpleWriterExporterOutput.new(strm))
    exporter.exportReport
    strm.to_s
  end

  def to_csv(fill)
    exporter = JRCsvExporter.new
    exporter.setExporterInput(SimpleExporterInput.new(fill))
    strm = java.io.ByteArrayOutputStream.new
    exporter.setExporterOutput(SimpleWriterExporterOutput.new(strm))
    exporter.exportReport
    strm.to_s
  end

  def to_xls(fill) # rubocop:disable Metrics/AbcSize
    exporter = JRXlsxExporter.new
    exporter.setExporterInput(SimpleExporterInput.new(fill))
    exporter.setConfiguration(excel_export_config)
    exporter.setConfiguration(excel_report_config)

    Tempfile.create do |f|
      f.binmode
      exporter.setExporterOutput(SimpleOutputStreamExporterOutput.new(f.path))

      exporter.exportReport
      f.rewind
      f.read
    end
  end

  def excel_export_config
    ex_conf = SimpleXlsxExporterConfiguration.new
    ex_conf.setMetadataTitle('rpt name here')
    ex_conf
  end

  def excel_report_config
    configuration = SimpleXlsxReportConfiguration.new
    configuration.setOnePagePerSheet(false)
    configuration.setIgnoreCellBorder(true)
    configuration.setDetectCellType(true)
    configuration.setRemoveEmptySpaceBetweenColumns(true)
    configuration.setRemoveEmptySpaceBetweenRows(true)
    configuration.setWhitePageBackground(true)
    configuration.setIgnoreGraphics(false)
    configuration
  end

  def make_db_connection
    props = java.util.Properties.new
    props.set_property :user, @db_opts[:user]
    props.set_property :password, @db_opts[:password]

    @conn = org.postgresql.Driver.new.connect(build_connection_string, props)
  end

  def build_connection_string
    "jdbc:postgresql://#{@db_opts[:host]}:#{@db_opts[:port] || '5432'}/#{@db_opts[:database]}"
  end

  def fill_report
    report_source = "#{@path}/#{@report_name}.jasper"
    raise ArgumentError, "Jasper Report #{@report_name} does not exist." unless File.exist?(report_source)

    # perhaps... read the report def and find the required parameter types & build like that?
    params = Java::JavaUtil::HashMap.new
    params['SUBREPORT_DIR'] = "#{@path.chomp('/')}/"
    @report_params.each do |k, v|
      params[k] = v
    end
    JasperFillManager.fill_report(report_source, params, @conn)
  end

  # Parameters for Jasper must have String keys.
  # Also JRuby can convert integer literals to Longs which might not match the
  # report definition.
  def prepare_parameters(params)
    @report_params = (params || {}).transform_keys(&:to_s).transform_values do |val|
      if val.is_a?(Integer)
        java.lang.Integer.new(val) # Avoid running into Long vs Int problem
      else
        val
      end
    end
  end
end
