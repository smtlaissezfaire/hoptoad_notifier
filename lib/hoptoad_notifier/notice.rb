module HoptoadNotifier
  class Notice

    attr_reader :notifier, :api_key, :error, :request, :server_environment

    class Notifier < Struct.new(:name, :version, :url); end

    class Line < Struct.new(:file, :number, :method)
      def to_s
        "#{file}:#{number}#{": in `#{method}'" if method}"
      end
    end
   
    class Error < Struct.new(:class, :message, :backtrace)
      def backtrace=(backtrace)
        super(parse(filter(backtrace)))
      end

      BACKTRACE_LINE = %r{^([^:]+):(\d+)(?::in `([^']+)')?$}.freeze
      def parse(backtrace)
        backtrace.map do |line|
          _, file, number, methodname = line.match(BACKTRACE_LINE).to_a
          Line.new(file, number, methodname)
        end
      end

      def filter(backtrace)
        backtrace.map do |line|
          HoptoadNotifier.backtrace_filters.inject(line) do |mod_line, proc|
            proc.call(mod_line)
          end
        end.compact
      end
    end

    module Filterable
      def filter hash, filters #:nodoc:
        hash.each do |k, v|
          hash[k] = "[FILTERED]" if filters.any? do |filter|
            k.to_s.match(/#{filter}/)
          end

          hash[k] = filter(v, filters) if v.is_a?(Hash)
        end
      end
    end

    class Request < Struct.new(:controller, :action, :url, :params, :session, :cgi_data)
      def initialize(controller = nil,
                     action = nil,
                     url = nil,
                     params = nil,
                     session = nil,
                     cgi_data = nil)
        super(controller, action, url, params || {}, session || {}, cgi_data || {})
      end

      include Filterable
        
      def params
        filter(super, HoptoadNotifier.params_filters)
      end
    end

    class ServerEnvironment < Struct.new(:project_root, :environment_name, :vars)
      def initialize(project_root = nil, environment_name = nil, vars = nil)
        super(project_root, environment_name, vars || {})
      end

      include Filterable
        
      def vars
        filter(super, HoptoadNotifier.environment_filters)
      end
    end

    def initialize
      @api_key            = HoptoadNotifier.api_key
      @notifier           = Notifier.new(HoptoadNotifier::NAME,
                                         HoptoadNotifier::VERSION,
                                         HoptoadNotifier::URL)
      @error              = Error.new
      @request            = Request.new
      @server_environment = ServerEnvironment.new
    end

    def error=(error)
      @error.class = error.class.name
      @error.message = error.message
      @error.backtrace = error.backtrace
    end

    def to_xml
      builder = Builder::XmlMarkup.new
      builder.instruct!
      xml = builder.notice(:version => HoptoadNotifier::VERSION) do |notice| 
        notice.tag!("api-key", api_key)
        notice.notifier do |notifier|
          notifier.name(@notifier.name)
          notifier.version(@notifier.version)
          notifier.url(@notifier.url)
        end
        notice.error do |error|
          error.class(@error.class)
          error.message(@error.message)
          error.backtrace do |backtrace|
            @error.backtrace.each do |line|
              backtrace.line(:number => line.number,
                             :file   => line.file,
                             :method => line.method)
            end
          end
        end
        notice.request do |request|
          request.url(@request.url)
          request.controller(@request.controller)
          request.action(@request.action)
          unless @request.params.blank?
            request.params do |params|
              xml_vars_for(params, @request.params)
            end
          end
          unless @request.session.blank?
            request.session do |session|
              xml_vars_for(session, @request.session)
            end
          end
          unless @request.cgi_data.blank?
            request.tag!("cgi-data") do |cgi_datum|
              xml_vars_for(cgi_datum, @request.cgi_data)
            end
          end
        end
        notice.tag!("server-environment") do |env|
          env.tag!("project-root", @server_environment.project_root)
          env.tag!("environment-name", @server_environment.environment_name)
          xml_vars_for(env, @server_environment.vars)
        end
      end
      xml.to_s
    end    

    protected

    def xml_vars_for(builder, hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          builder.var(:key => key){|b| xml_vars_for(b, value) }
        else
          builder.var(value.to_s, :key => key)
        end
      end
    end    

    def clean!
      clean_backtrace
      clean_hash(request_parameters, HoptoadNotifier.params_filters)
      clean_hash(server_environment, HoptoadNotifier.environment_filters)
      clean_non_serializable_data(@notice)
    end

    def clean_backtrace
    end

    def clean_non_serializable_data(data) #:nodoc:
      case data
      when Hash
        data.inject({}) do |result, (key, value)|
          result.update(key => clean_non_serializable_data(value))
        end
      when Fixnum, Array, String, Bignum
        data
      else
        data.to_s
      end
    end

    def field(key)
      @notice[key]
    end

  end
end
